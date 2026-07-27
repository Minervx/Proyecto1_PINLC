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
| CI/CD | GitHub Actions (7 jobs: local + AWS opcional + resumen automático) |
| IaC | Terraform (`kreuzwerker/docker` local, `hashicorp/aws` con backend remoto S3 + ALB) |
| Contenedores | Docker |
| Seguridad | ESLint + Snyk + SBOM (CycloneDX) + Trivy (reportes SARIF en GitHub Security) |
| Observabilidad | Prometheus + Grafana (local y AWS) |
| Testing | Jest + Supertest, con umbral de cobertura mínimo (70%) |
| Extras | Colección Postman, script `validate.sh` de chequeo de entorno |

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
├── sbom/README.md              # Cómo se genera y dónde queda el SBOM
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

Requisitos: Docker Engine y Docker Compose instalados (por ejemplo, en una VM
Ubuntu de VirtualBox), Node.js 20 solo si se quiere correr la app fuera de Docker.

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

# 4. Prometheus
open http://localhost:9090

# 5. Grafana (usuario/clave: admin/admin la primera vez)
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

Requiere cuenta de AWS, rol IAM de ejecución de ECS, VPC con subnets en al
menos 2 AZs, AWS CLI configurado, y el bucket S3 del backend ya creado (una
sola vez). Guía completa paso a paso en `docs/DEPLOYMENT_TERRAFORM.md` y
`terraform/aws/README.md`. Resumen:

```bash
# 1. Build & push de las 3 imágenes (app, prometheus, grafana) a ECR
#    (detalle completo en terraform/aws/README.md)

# 2. Aplicar la infraestructura
cd terraform/aws
terraform init
terraform apply \
  -var="ecs_execution_role_arn=<ARN>" \
  -var="vpc_id=<vpc-xxxx>" \
  -var='subnet_ids=["subnet-aaaa","subnet-bbbb"]' \
  -var="image_tag=v1"

# 3. URLs estables (vía ALB, no cambian aunque ECS recree una tarea)
terraform output app_url
terraform output prometheus_url
terraform output grafana_url
```

Al terminar de sacar las capturas, `terraform destroy` con las mismas
variables para no dejar nada facturando.

## Cómo funciona el pipeline (GitHub Actions)

Detalle completo en `docs/CI_CD_GUIDE.md`. Resumen: los jobs de la opción
local corren siempre; los de AWS solo si se configura la variable de repo
`AWS_ENABLED=true` (ver `docs/SECURITY_COMPLIANCE.md`).

**Opción local:** `build-and-test` → `security-scan` (Snyk + SBOM) →
`docker-build-push` (GHCR) → `container-scan` (Trivy, reporte SARIF en la
pestaña Security) → `terraform-deploy` (`plan` siempre, `apply` en `main`).

**Opción AWS** (si `AWS_ENABLED=true`): `aws-docker-build-push` (ECR, 3
imágenes) → `terraform-deploy-aws` (ECS Fargate + ALB + Cloud Map).

**Al final, siempre:** `summary` — si algún job falló, crea automáticamente
un Issue en el repo con el link directo a la ejecución.

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

## Antes de entregar

Ver `docs/entregables-checklist.md`: hay evidencias que deben generarse
corriendo el pipeline/stack al menos una vez (imagen Docker publicada, SBOM
real, capturas de los dashboards de Grafana en local y en AWS), ya que no
corresponde fabricarlas manualmente para la entrega.
