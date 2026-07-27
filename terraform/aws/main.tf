# Infraestructura como codigo - Opcion NUBE (AWS)
# Provider oficial: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
#
# Segun el manual del PIN, "Opcion local y opcion nube en cada caso" es un requisito
# del proyecto (no una alternativa excluyente), por eso esta opcion queda completamente
# ejecutable, al mismo nivel que la local: ECS Fargate para la app, y Prometheus +
# Grafana tambien corriendo como servicios ECS, descubriendose entre si via AWS Cloud
# Map (Service Discovery), ya que ECS Fargate no soporta bind mounts como Docker Compose.
#
# Referencias oficiales:
# - ECS Service Discovery / Cloud Map: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-discovery.html
# - ECR: https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html
# - ECS Fargate: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# Repositorios ECR (app + prometheus + grafana, imagenes custom con config)
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "app" {
  name                 = var.app_name
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "prometheus" {
  name                 = "${var.app_name}-prometheus"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "grafana" {
  name                 = "${var.app_name}-grafana"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# ---------------------------------------------------------------------------
# Cluster ECS + logs
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "pin_cluster" {
  name = "${var.app_name}-cluster"
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/ecs/${var.app_name}-prometheus"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/${var.app_name}-grafana"
  retention_in_days = 14
}

# ---------------------------------------------------------------------------
# Cloud Map: namespace DNS privado dentro de la VPC (equivalente a la red
# interna que crea Docker Compose para que "app", "prometheus" y "grafana"
# se resuelvan por nombre).
# ---------------------------------------------------------------------------

resource "aws_service_discovery_private_dns_namespace" "pin" {
  name = "pin-lc.local"
  vpc  = var.vpc_id
}

resource "aws_service_discovery_service" "app" {
  name = "app"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.pin.id
    dns_records {
      ttl  = 10
      type = "A"
    }
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "prometheus" {
  name = "prometheus"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.pin.id
    dns_records {
      ttl  = 10
      type = "A"
    }
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}

# ---------------------------------------------------------------------------
# Task definitions
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "app" {
  family                   = var.app_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_execution_role_arn

  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [
        { containerPort = 3000, protocol = "tcp" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "${var.app_name}-prometheus"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_execution_role_arn

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = "${aws_ecr_repository.prometheus.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [
        { containerPort = 9090, protocol = "tcp" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.prometheus.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "grafana" {
  family                   = "${var.app_name}-grafana"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_execution_role_arn

  container_definitions = jsonencode([
    {
      name      = "grafana"
      image     = "${aws_ecr_repository.grafana.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [
        { containerPort = 3000, protocol = "tcp" }
      ]
      environment = [
        { name = "GF_SECURITY_ADMIN_USER", value = "admin" },
        { name = "GF_SECURITY_ADMIN_PASSWORD", value = var.grafana_admin_password }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.grafana.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ---------------------------------------------------------------------------
# Servicios ECS, detras del ALB (ver alb.tf). Sin IP publica propia: solo
# reciben trafico del ALB (mas seguro y con URL estable), y siguen resolviendo
# entre si por nombre via Cloud Map para el scraping interno de metricas.
# ---------------------------------------------------------------------------

resource "aws_ecs_service" "app" {
  name            = var.app_name
  cluster         = aws_ecs_cluster.pin_cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    assign_public_ip = true # necesario para poder pull-ear la imagen desde ECR sin NAT Gateway
    security_groups  = concat([aws_security_group.ecs_tasks.id], var.security_group_ids)
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.app_name
    container_port   = 3000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.app.arn
  }

  depends_on = [aws_lb_listener.app]
}

resource "aws_ecs_service" "prometheus" {
  name            = "${var.app_name}-prometheus"
  cluster         = aws_ecs_cluster.pin_cluster.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    assign_public_ip = true
    security_groups  = concat([aws_security_group.ecs_tasks.id], var.security_group_ids)
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus.arn
    container_name   = "prometheus"
    container_port   = 9090
  }

  service_registries {
    registry_arn = aws_service_discovery_service.prometheus.arn
  }

  depends_on = [aws_lb_listener.prometheus, aws_ecs_service.app]
}

resource "aws_ecs_service" "grafana" {
  name            = "${var.app_name}-grafana"
  cluster         = aws_ecs_cluster.pin_cluster.id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    assign_public_ip = true
    security_groups  = concat([aws_security_group.ecs_tasks.id], var.security_group_ids)
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.grafana, aws_ecs_service.prometheus]
}
