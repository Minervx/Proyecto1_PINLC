variable "image_name" {
  description = "Nombre/repositorio de la imagen construida en el pipeline (GHCR)"
  type        = string
  default     = "ghcr.io/OWNER/REPO"
}

variable "image_tag" {
  description = "Tag de la imagen a desplegar (por defecto: recibido desde el job docker-build-push del workflow)"
  type        = string
  default     = "latest"
}

variable "app_port" {
  description = "Puerto expuesto en el host para la aplicacion"
  type        = number
  default     = 3000
}
