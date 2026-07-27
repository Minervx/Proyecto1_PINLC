variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "app_name" {
  type    = string
  default = "pin-lc-task-api"
}

variable "image_tag" {
  description = "Tag comun para las 3 imagenes (app, prometheus, grafana) publicadas en ECR"
  type        = string
  default     = "latest"
}

variable "ecs_execution_role_arn" {
  description = "ARN del rol de ejecucion de ECS (debe existir previamente, ver terraform/aws/README.md)"
  type        = string
}

variable "vpc_id" {
  description = "VPC donde se crea el namespace privado de Cloud Map (puede ser la VPC por defecto de la cuenta)"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets donde corren los 3 servicios Fargate (app, prometheus, grafana)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups ADICIONALES a los que crea este modulo (aws_security_group.ecs_tasks). Opcional."
  type        = list(string)
  default     = []
}

variable "grafana_admin_password" {
  description = "Password del usuario admin de Grafana"
  type        = string
  default     = "admin"
  sensitive   = true
}
