# Guía de CI/CD

Pipeline definido en `.github/workflows/ci-cd.yml`. Se dispara en cada `push`
a `main`/`develop` y en cada Pull Request contra `main`.

## Jobs — opción local (siempre activos)

| # | Job | Qué hace | Referencia oficial |
|---|---|---|---|
| 1 | `build-and-test` | `npm ci`, ESLint, tests (Jest/Supertest), sube el reporte de cobertura como artifact | https://github.com/actions/setup-node |
| 2 | `security-scan` | Snyk sobre dependencias + genera el SBOM (CycloneDX) con Syft/Anchore | https://github.com/snyk/actions, https://github.com/anchore/sbom-action |
| 3 | `docker-build-push` | Build multi-stage con Buildx, push a GHCR | https://github.com/docker/build-push-action |
| 4 | `container-scan` | Trivy escanea la imagen publicada y sube el reporte SARIF a la pestaña **Security** del repo | https://github.com/aquasecurity/trivy-action |
| 5 | `terraform-deploy` | `fmt`, `validate`, `plan` en cada corrida; `apply` solo en `main` | https://github.com/hashicorp/setup-terraform |

## Jobs — opción AWS (activos solo con `AWS_ENABLED=true`)

| # | Job | Qué hace |
|---|---|---|
| 6 | `aws-docker-build-push` | Login en ECR, build & push de las 3 imágenes (app, prometheus, grafana) |
| 7 | `terraform-deploy-aws` | `fmt`, `validate`, `plan`/`apply` de `terraform/aws` (ECS Fargate + ALB + Cloud Map) |

## Job final

`summary`: corre siempre (`if: always()`). Si algún job de arriba falló, crea
automáticamente un **Issue** en el repo con el link directo a la ejecución que
falló, usando `actions/github-script` — así no hay que ir a revisar los logs
de Actions a mano para enterarse de que algo rompió.

## Cómo activar la opción AWS en el pipeline

Ver la tabla de secretos y variables en `SECURITY_COMPLIANCE.md`. Resumen:
configurar `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` como *secrets*, y
`AWS_ENABLED=true` + el resto de las `AWS_*` como *variables* de repositorio
(Settings → Secrets and variables → Actions).

## Cobertura mínima

`app/package.json` define un `coverageThreshold` (líneas/funciones 70%,
ramas 60%) para que `npm test` (que corre `jest --coverage`) falle si la
cobertura cae por debajo de eso — mismo criterio que usan otros equipos del
curso para asegurar un piso de calidad en los tests.
