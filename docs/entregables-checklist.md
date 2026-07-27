# Checklist de entregables — Proyecto 1

El manual pide "Opción local **y** opción nube en cada caso" (no una u otra),
así que este repo trae ambas completamente ejecutables, no solo documentadas.

| Entregable requerido | Opción local | Opción AWS |
|---|---|---|
| Workflow `.yml` en GitHub Actions | ✅ `build-and-test` → `security-scan` → `docker-build-push` → `container-scan` (Trivy) → `terraform-deploy` | ✅ `aws-docker-build-push` → `terraform-deploy-aws` (activos con `AWS_ENABLED=true`) |
| Archivos Terraform (`.tf`) | ✅ `terraform/local/*.tf` | ✅ `terraform/aws/*.tf` (ECS Fargate + ALB + Cloud Map + backend S3) |
| `Dockerfile` y artefacto generado | ✅ `Dockerfile` — ⚠️ imagen en GHCR al correr el pipeline | ✅ `monitoring/aws/*.Dockerfile` — ⚠️ imágenes en ECR al correr el pipeline |
| SBOM (CycloneDX/SPDX) | ⚠️ Se genera al correr el pipeline o Syft local (`sbom/README.md`) | *(mismo SBOM, no depende del entorno de despliegue)* |
| Captura del dashboard de métricas | ⚠️ Grafana en `http://localhost:3001` tras `docker compose up` | ⚠️ Grafana en `terraform output grafana_url` (URL estable del ALB) |
| Escaneo de vulnerabilidades de la imagen | ✅ Trivy, visible en la pestaña **Security** del repo | *(mismas imágenes, no depende del entorno)* |

## Por qué algunos ítems dicen "⚠️ pendiente de ejecución"

La configuración, el código y el pipeline están completos y siguen la
documentación oficial de cada herramienta (GitHub Actions, Docker, Terraform,
Prometheus/Grafana, Snyk, CycloneDX). Sin embargo, **el SBOM real, la imagen
Docker publicada y la captura del dashboard son evidencia de una ejecución real**
y no deben fabricarse: hay que correr el pipeline (o el stack local) al menos
una vez y adjuntar esos artefactos/capturas antes de comprimir el `.zip` final,
tal como pide la consigna del manual.

## ⚠️ Paso obligatorio antes del primer push

Este proyecto se generó sin acceso a internet, por lo que **falta `app/package-lock.json`**.
El workflow y el `Dockerfile` usan `npm ci`, que exige ese archivo para garantizar builds
reproducibles (a diferencia de `npm install`, no resuelve versiones nuevas). Generarlo
requiere resolver versiones contra el registro de npm real, así que debe hacerse una
sola vez con conexión a internet:

```bash
cd app
npm install     # crea/actualiza package-lock.json a partir de package.json
git add package-lock.json
```

Sin este archivo, tanto el job `build-and-test` como el `docker build` van a fallar
en el paso `npm ci`.

## Pasos sugeridos antes de entregar

**Opción local (obligatoria, base del proyecto):**

1. Generar `app/package-lock.json` (ver arriba).
2. `bash validate.sh` para confirmar que el repo y el entorno están completos.
3. Crear el repo en GitHub y subir este contenido.
4. Configurar el secreto `SNYK_TOKEN` (ver `docs/SECURITY_COMPLIANCE.md`).
5. Hacer push a `main` → el workflow corre automáticamente.
6. Descargar el artifact `sbom-cyclonedx` desde la pestaña Actions y guardarlo en `sbom/`.
7. Revisar la pestaña **Security → Code scanning** para ver el resultado de Trivy.
8. Levantar `docker compose up -d --build`, generar tráfico contra `/api/tasks`
   (o importar `PIN-LC-Task-API.postman_collection.json` en Postman) y tomar una
   captura del dashboard en `http://localhost:3001` (Grafana).

**Opción AWS (también requerida según el manual):**

9. Crear cuenta AWS, usuario IAM, rol de ejecución ECS y VPC con subnets en al
   menos 2 AZs (ver `terraform/aws/README.md`).
10. Bootstrapear el bucket S3 del backend remoto (una sola vez, comando en
    `terraform/aws/README.md`).
11. Configurar en GitHub los secretos `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
    y las variables de repo (`AWS_ENABLED=true`, `AWS_REGION`, `AWS_VPC_ID`, etc. —
    ver tabla en `docs/SECURITY_COMPLIANCE.md`).
12. Push a `main` → corren también los jobs `aws-docker-build-push` y
    `terraform-deploy-aws`.
13. `terraform output grafana_url` (URL estable vía ALB) y tomar la captura
    del dashboard corriendo en AWS.
14. `terraform destroy` en `terraform/aws` al terminar, para no dejar nada facturando.

**Entrega final:**

15. Comprimir todo (incluyendo las capturas de ambas opciones) como
    `Proyecto 1_PIN-LC.zip` según indica el manual.
