# Application Load Balancer delante de los 3 servicios ECS.
# Sin esto, cada tarea Fargate tiene su propia IP publica que cambia cada vez
# que se recrea (por un deploy, un health check fallido, etc.), lo que obliga
# a ir a buscarla a mano en la consola antes de cada demo. Con el ALB, la URL
# es siempre la misma.
# Documentacion oficial: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html

# ---------------------------------------------------------------------------
# Security groups
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.app_name}-alb-sg"
  description = "Trafico entrante publico hacia el ALB (app, prometheus, grafana)"
  vpc_id      = var.vpc_id

  ingress {
    description = "App"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.app_name}-ecs-tasks-sg"
  description = "Solo acepta trafico del ALB hacia los contenedores"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Desde el ALB"
    from_port       = 3000
    to_port          = 3000
    protocol         = "tcp"
    security_groups  = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Desde el ALB (Prometheus)"
    from_port       = 9090
    to_port          = 9090
    protocol         = "tcp"
    security_groups  = [aws_security_group.alb.id]
  }

  # Trafico interno entre tareas (Cloud Map: app <-> prometheus <-> grafana)
  ingress {
    description = "Trafico interno entre servicios (Cloud Map)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------
# Load Balancer
# ---------------------------------------------------------------------------

resource "aws_lb" "pin" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids
}

# --- Target groups (uno por servicio, con su propio health check) ---

resource "aws_lb_target_group" "app" {
  name        = "${var.app_name}-tg-app"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
  }
}

resource "aws_lb_target_group" "prometheus" {
  name        = "${var.app_name}-tg-prom"
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/-/healthy" # endpoint de salud oficial de Prometheus
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
  }
}

resource "aws_lb_target_group" "grafana" {
  name        = "${var.app_name}-tg-grafana"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/api/health" # endpoint de salud oficial de Grafana
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
  }
}

# --- Listeners (un puerto publico distinto por servicio) ---

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.pin.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener" "prometheus" {
  load_balancer_arn = aws_lb.pin.arn
  port              = 9090
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }
}

resource "aws_lb_listener" "grafana" {
  load_balancer_arn = aws_lb.pin.arn
  port              = 3001
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}
