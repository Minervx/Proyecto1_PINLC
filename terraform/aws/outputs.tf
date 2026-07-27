output "ecr_repository_url_app" {
  value = aws_ecr_repository.app.repository_url
}

output "ecr_repository_url_prometheus" {
  value = aws_ecr_repository.prometheus.repository_url
}

output "ecr_repository_url_grafana" {
  value = aws_ecr_repository.grafana.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.pin_cluster.name
}

output "ecs_service_app" {
  value = aws_ecs_service.app.name
}

output "ecs_service_prometheus" {
  value = aws_ecs_service.prometheus.name
}

output "ecs_service_grafana" {
  value = aws_ecs_service.grafana.name
}

output "service_discovery_namespace" {
  description = "Namespace DNS privado (usar solo dentro de la VPC, no accesible desde internet)"
  value       = aws_service_discovery_private_dns_namespace.pin.name
}

output "alb_dns_name" {
  description = "DNS publico del Load Balancer (base para las 3 URLs de abajo)"
  value       = aws_lb.pin.dns_name
}

output "app_url" {
  value = "http://${aws_lb.pin.dns_name}"
}

output "prometheus_url" {
  value = "http://${aws_lb.pin.dns_name}:9090"
}

output "grafana_url" {
  value = "http://${aws_lb.pin.dns_name}:3001"
}
