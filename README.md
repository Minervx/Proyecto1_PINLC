# Proyecto 1: CI/CD con GitHub Actions + Terraform + Docker

Proyecto Integrador Final (PIN) — Diplomatura DevOps (UNC / FCEFyN / mundosE).
**Equipo: PIN-LC**

[![Quick check](https://img.shields.io/badge/setup-run%20validate.sh-blue)](./validate.sh)

## Objetivo

Pipeline en **GitHub Actions** que compila, testea y despliega una aplicación
(generada con asistencia de IA) en un contenedor **Docker**, con la
infraestructura gestionada por **Terraform**, controles de seguridad
integrados y observabilidad con **Prometheus + Grafana**.

Siguiendo la consigna del manual ("Opción local **y** opción nube en cada
caso"), este proyecto trae **ambas opciones completamente ejecutables**, no
solo documentadas: local con Docker Compose/Terraform, y nube con AWS
(ECS Fargate + ALB + Cloud Map), con Prometheus y Grafana corriendo en
ambos entornos.

## Stack utilizado

| Categoría | Herramienta |
|---|---|
| CI/CD | GitHub Actions (9 jobs: local + AWS opcional + resumen automático) |
| IaC | Terraform (`kreuzwerker/docker` local, `hashicorp/aws` con backend remoto S3 + ALB) |
| Contenedores | Docker (build multi-stage, usuario no-root, healthcheck) |
| Seguridad | ESLint + Snyk + SBOM (CycloneDX vía Syft) + Trivy (reportes SARIF en GitHub Security) |
| Observabilidad | Prometheus + Grafana (local y AWS) |
| Testing | Jest + Supertest, con umbral de cobertura mínimo (70% líneas/funciones) |
| Framework | Express + prom-client |
| Extras | Colección Postman, script `validate.sh` de chequeo de entorno |

## Aplicación base

API REST de gestión de tareas (Node.js + Express), con persistencia en
memoria. Se mantuvo simple a propósito: la rúbrica evalúa el pipeline y la
infraestructura alrededor, no la complejidad funcional de la app. Expone:

| Endpoint | Uso |
|---|---|
| `GET /health` | Health check (usado por Docker y por el Load Balancer en AWS) |
| `GET /metrics` | Métricas en formato Prometheus (vía `prom-client`) |
| `GET /api/tasks`, `GET /api/tasks/:id` | Listar / obtener tareas |
| `POST /api/tasks` | Crear tarea |
| `PUT /api/tasks/:id` | Actualizar tarea |
| `DELETE /api/tasks/:id` | Eliminar tarea |

## Estructura del repositorio

```
.
├── app/                        # API Node.js/Express (base generada con IA)
├── Dockerfile                  # Build multi-stage, usuario no-root, healthcheck
├── docker-compose.yml          # Stack local: app + Prometheus + Grafana
├── validate.sh                 # Chequeo rápido de entorno y estructura del repo
├── PIN-LC-Task-API.postman_collection.json
├── .github/workflows/ci-cd.yml
├── terraform/
│   ├── local/                  # Opción local (provider Docker)
│   └── aws/                    # Opción nube: ECR + ECS Fargate + ALB + Cloud Map + backend S3
├── monitoring/
│   ├── prometheus.yml, grafana/   # Config para la opción local
│   └── aws/                       # Dockerfiles + config para Prometheus/Grafana en ECS
├── security/README.md          # Resumen de seguridad (detalle en docs/)
├── sbom/                        # Instrucciones + SBOM real generado por el pipeline
└── docs/
    ├── CI_CD_GUIDE.md           # Detalle de cada job del pipeline
    ├── DEPLOYMENT_TERRAFORM.md  # Guía de despliegue (local + AWS)
    ├── MONITORING.md            # Guía de Prometheus + Grafana
    ├── SECURITY_COMPLIANCE.md   # Controles, secretos/variables, política IAM
    └── entregables-checklist.md # Mapeo de cada entregable pedido en el manual
```

## Chequeo rápido antes de arrancar

```bash
bash validate.sh
```

Verifica que estén los archivos clave del repo y las herramientas necesarias
(`node`, `npm`, `docker`, `terraform`, `git`) instaladas en tu máquina.

## Cómo correrlo en local (Docker + Terraform)

Requisitos: Docker Desktop (o Docker Engine + Compose), Node.js 20 solo si se
quiere correr la app fuera de Docker.

```bash
# 0. Generar el lockfile una sola vez (requiere internet; no viene incluido)
cd app && npm install && cd ..

# 1. Levantar el stack completo (app + Prometheus + Grafana)
docker compose up -d --build

# 2. Probar la app (o importar PIN-LC-Task-API.postman_collection.json en Postman)
curl http://localhost:3000/health
curl http://localhost:3000/api/tasks

# 3. Ver métricas crudas
curl http://localhost:3000/metrics

# 4. Prometheus → Status → Targets (debería verse "UP")
open http://localhost:9090

# 5. Grafana (usuario/clave: admin/admin la primera vez) → Dashboards
open http://localhost:3001
```

Alternativamente, en vez de `docker-compose.yml` se puede desplegar solo la
app con Terraform (ver `terraform/local/README.md`):

```bash
cd terraform/local
terraform init
terraform apply -var="image_name=pin-lc-task-api" -var="image_tag=local"
```

## Cómo correrlo en AWS (opción nube)

Requiere: cuenta de AWS, usuario IAM con permisos programáticos, rol de
ejecución de ECS, VPC con subnets en al menos 2 zonas de disponibilidad
(lo exige el Load Balancer), AWS CLI configurado, y el bucket S3 del backend
ya creado (una sola vez). Guía completa paso a paso, incluyendo la política
IAM exacta necesaria, en `docs/DEPLOYMENT_TERRAFORM.md`,
`docs/SECURITY_COMPLIANCE.md` y `terraform/aws/README.md`.

Con todo eso configurado, el pipeline hace el resto solo (ver más abajo). Para
correrlo manualmente en cambio:

```bash
# 1. Crear primero los repositorios ECR (docker push los necesita antes de existir)
cd terraform/aws
terraform init
terraform apply -auto-approve \
  -target=aws_ecr_repository.app -target=aws_ecr_repository.prometheus -target=aws_ecr_repository.grafana \
  -var="ecs_execution_role_arn=<ARN>" -var="vpc_id=<vpc-xxxx>" \
  -var='subnet_ids=["subnet-aaaa","subnet-bbbb"]'
cd ../..

# 2. Build & push de las 3 imágenes a ECR (detalle completo en terraform/aws/README.md)

# 3. Aplicar el resto de la infraestructura (cluster, Cloud Map, ALB, servicios)
cd terraform/aws
terraform apply \
  -var="ecs_execution_role_arn=<ARN>" -var="vpc_id=<vpc-xxxx>" \
  -var='subnet_ids=["subnet-aaaa","subnet-bbbb"]' -var="image_tag=v1"

# 4. URLs estables (vía ALB, no cambian aunque ECS recree una tarea)
terraform output app_url
terraform output prometheus_url
terraform output grafana_url
```

Al terminar de sacar las capturas, `terraform destroy` con las mismas
variables para no dejar nada facturando.

## Cómo funciona el pipeline (GitHub Actions)

Detalle completo en `docs/CI_CD_GUIDE.md`. Resumen: los jobs de la opción
local corren siempre; los de AWS solo si se configura la variable de repo
`AWS_ENABLED=true` (checklist de secretos/variables en
`docs/SECURITY_COMPLIANCE.md`).

**Opción local:** `build-and-test` (lint + tests) → `security-scan` (Snyk +
SBOM) → `docker-build-push` (GHCR) → `container-scan` (Trivy, reporte SARIF
en la pestaña Security) → `terraform-deploy` (`plan` siempre, `apply` en
`main`).

**Opción AWS** (si `AWS_ENABLED=true`): `aws-ecr-bootstrap` (crea primero los
3 repositorios ECR, necesarios antes de poder publicar ninguna imagen) →
`aws-docker-build-push` (build & push de las 3 imágenes) →
`terraform-deploy-aws` (cluster ECS, Cloud Map, ALB y servicios).

**Al final, siempre:** `summary` — si algún job falló, crea automáticamente
un Issue en el repo con el link directo a la ejecución.

Cada imagen se tagea con el hash corto del commit **más el número de
corrida** (`ej: 1d0bac0-14`), no solo el commit, para que reintentar el
pipeline sobre el mismo código no choque con los tags inmutables de ECR.

## Fuentes y documentación oficial utilizada

- GitHub Actions: https://docs.github.com/actions
- Docker (Dockerfile best practices): https://docs.docker.com/build/building/best-practices/
- Docker Compose: https://docs.docker.com/compose/
- Terraform / provider Docker: https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs
- Terraform / provider AWS: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- Terraform backend S3: https://developer.hashicorp.com/terraform/language/backend/s3
- ALB: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html
- ECS Service Discovery / Cloud Map: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-discovery.html
- Prometheus: https://prometheus.io/docs/
- Grafana provisioning: https://grafana.com/docs/grafana/latest/administration/provisioning/
- Snyk GitHub Actions: https://github.com/snyk/actions
- Anchore SBOM Action / Syft: https://github.com/anchore/sbom-action
- CycloneDX: https://cyclonedx.org/specification/overview/
- Trivy Action: https://github.com/aquasecurity/trivy-action
- ESLint: https://eslint.org/docs/latest/

