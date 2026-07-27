# Terraform - Opción local

Gestiona con Terraform (provider oficial `kreuzwerker/docker`) el contenedor de la
aplicación sobre un host con Docker Engine (por ejemplo, una VM Ubuntu en VirtualBox
con Docker instalado).

## Uso

```bash
cd terraform/local
terraform init
terraform plan  -var="image_name=pin-lc-task-api" -var="image_tag=local"
terraform apply -var="image_name=pin-lc-task-api" -var="image_tag=local"
```

Luego de aplicar, la app queda disponible en `http://localhost:3000`.

Para destruir los recursos:

```bash
terraform destroy -var="image_name=pin-lc-task-api" -var="image_tag=local"
```

Referencia oficial del provider: https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs
