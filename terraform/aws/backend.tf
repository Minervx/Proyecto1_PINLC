# Backend remoto para el state de Terraform (opción AWS).
# Evita perder el state si se corre "apply" desde máquinas distintas (tu compu
# y el runner del pipeline), y permite locking para que dos aplicaciones no
# choquen entre sí.
# Documentación oficial: https://developer.hashicorp.com/terraform/language/backend/s3
#
# IMPORTANTE: el bucket NO lo crea Terraform (no puede crear el backend que va
# a usar para sí mismo). Hay que crearlo una sola vez, a mano, antes del primer
# "terraform init". Ver el bloque "Bootstrap del backend" en README.md de esta
# carpeta para el comando exacto.

terraform {
  backend "s3" {
    bucket = "pin-lc-task-api-terraform-state" # cambiar por un nombre unico global
    key    = "proyecto1/terraform.tfstate"
    region = "us-east-1"

    # Bloqueo de state para evitar aplicaciones concurrentes.
    # Desde Terraform 1.10+, S3 soporta locking nativo sin necesidad de una
    # tabla DynamoDB aparte (usa un archivo .tflock en el propio bucket).
    use_lockfile = true
  }
}
