# Infraestructura como codigo - Opcion LOCAL
# Provider oficial de Docker (kreuzwerker/docker), registrado en el Terraform Registry:
# https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs
# Pensado para correr sobre un host con Docker Engine (por ejemplo una VM de VirtualBox
# con Docker instalado, o el propio runner de GitHub Actions, que ya trae Docker).

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_network" "pin_network" {
  name = "pin-lc-network"
}

resource "docker_image" "app" {
  name         = "${var.image_name}:${var.image_tag}"
  keep_locally = true
}

resource "docker_container" "app" {
  name    = "pin-lc-task-api"
  image   = docker_image.app.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.pin_network.name
  }

  ports {
    internal = 3000
    external = var.app_port
  }

  healthcheck {
    test         = ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/health"]
    interval     = "30s"
    timeout      = "5s"
    retries      = 3
    start_period = "10s"
  }
}
