output "container_id" {
  description = "ID del contenedor desplegado"
  value       = docker_container.app.id
}

output "container_name" {
  value = docker_container.app.name
}

output "app_url" {
  description = "URL local de la aplicacion"
  value       = "http://localhost:${var.app_port}"
}
