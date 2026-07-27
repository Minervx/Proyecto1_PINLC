# Guía de despliegue con Terraform

Este proyecto trae **dos opciones completamente ejecutables** (no una
alternativa excluyente), según pide el manual del PIN: "Opción local y
opción nube en cada caso".

## Opción local (`terraform/local/`)

Gestiona el contenedor de la app directamente sobre el Docker Engine del host,
usando el provider oficial `kreuzwerker/docker`. No requiere ninguna cuenta
externa.

```bash
cd terraform/local
terraform init
terraform apply -var="image_name=pin-lc-task-api" -var="image_tag=local"
```

App disponible en `http://localhost:3000`. Detalle completo en
`terraform/local/README.md`.

## Opción nube — AWS (`terraform/aws/`)

Despliega el mismo stack (app + Prometheus + Grafana) sobre **ECS Fargate**,
con:

- **3 repositorios ECR** (imágenes de app, Prometheus y Grafana — estas dos
  últimas con su configuración horneada en la imagen, ya que Fargate no
  soporta bind mounts).
- **Cloud Map** (`pin-lc.local`) para que los tres servicios se resuelvan entre
  sí por nombre, igual que hace la red interna de Docker Compose en local.
- **Application Load Balancer** con 3 listeners (80 → app, 9090 → Prometheus,
  3001 → Grafana), así las URLs son estables y no hay que buscar la IP de
  cada tarea a mano.
- **Backend remoto en S3** para el state de Terraform (`terraform/aws/backend.tf`),
  para no perderlo entre corridas locales y del pipeline.

```bash
cd terraform/aws
terraform init
terraform apply \
  -var="ecs_execution_role_arn=<ARN>" \
  -var="vpc_id=<vpc-xxxx>" \
  -var='subnet_ids=["subnet-aaaa","subnet-bbbb"]' \
  -var="image_tag=v1"

terraform output app_url
terraform output prometheus_url
terraform output grafana_url
```

Guía completa, con el bootstrap del bucket S3 y el build/push de las 3
imágenes a ECR, en `terraform/aws/README.md`.

## Diagrama simplificado (opción AWS)

```
Internet
   │
   ▼
 ALB (pin-lc-task-api-alb)
   ├── :80   → target group app        → ECS task "app"        (Cloud Map: app.pin-lc.local)
   ├── :9090 → target group prometheus → ECS task "prometheus"  (Cloud Map: prometheus.pin-lc.local)
   └── :3001 → target group grafana    → ECS task "grafana"     (datasource → prometheus.pin-lc.local:9090)
```

## Referencias oficiales

- Provider Docker: https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs
- Provider AWS: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- Backend S3: https://developer.hashicorp.com/terraform/language/backend/s3
- ALB: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html
- ECS Service Discovery / Cloud Map: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-discovery.html
