# Seguridad y cumplimiento

## Controles implementados

| Control | Herramienta | Dónde |
|---|---|---|
| Análisis estático de código | **ESLint** (`eslint:recommended`) | `app/.eslintrc.json`, job `build-and-test` |
| Auditoría de dependencias | **Snyk** | job `security-scan` (requiere secreto `SNYK_TOKEN`) |
| Software Bill of Materials | **CycloneDX** (vía Syft/Anchore) | job `security-scan` → artifact `sbom-cyclonedx` |
| Escaneo de imagen Docker | **Trivy**, con reporte **SARIF** subido a la pestaña *Security* de GitHub | job `container-scan` |
| Buenas prácticas de imagen | Usuario no-root, `HEALTHCHECK`, build multi-stage | `Dockerfile` |
| Cobertura mínima de tests | `coverageThreshold` de Jest (70% líneas/funciones, 60% ramas) | `app/package.json` |

> Nota sobre la elección de herramientas: la consigna del Proyecto 1 pide
> "SonarQube/ESLint + Snyk" (alternativa dentro de esa combinación). Se eligió
> ESLint porque no requiere levantar un servidor ni crear una cuenta externa
> adicional — es intercambiable por SonarCloud si se prefiere (snippet listo
> más abajo). Trivy se sumó como una capa extra sobre lo pedido, no como
> reemplazo de Snyk.

## Alternativa: SonarCloud en vez de ESLint

```yaml
- name: SonarCloud Scan
  uses: sonarsource/sonarcloud-github-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

Requiere un `sonar-project.properties` y una cuenta en https://sonarcloud.io.

## SBOM: cómo se obtiene

Ver detalle completo en `sbom/README.md`. Resumen: se genera automáticamente
en el job `security-scan` (Syft/Anchore, formato CycloneDX) y también se puede
generar en local con el mismo binario de Syft.

## Checklist de secretos y variables en GitHub

**Secretos** (Settings → Secrets and variables → Actions → *Secrets*):

| Secreto | Uso |
|---|---|
| `SNYK_TOKEN` | Autenticación contra Snyk |
| `GITHUB_TOKEN` | Provisto automáticamente, usado para GHCR y para crear el Issue automático |
| `AWS_ACCESS_KEY_ID` | Solo si se activa la opción AWS |
| `AWS_SECRET_ACCESS_KEY` | Solo si se activa la opción AWS |

**Variables de repositorio** (misma pantalla, pestaña *Variables*) — solo
necesarias para que el pipeline también despliegue en AWS:

| Variable | Ejemplo |
|---|---|
| `AWS_ENABLED` | `true` (si no existe o es `false`, los jobs de AWS se saltean) |
| `AWS_REGION` | `us-east-1` |
| `AWS_APP_NAME` | `pin-lc-task-api` |
| `AWS_ECS_EXECUTION_ROLE_ARN` | `arn:aws:iam::123456789012:role/ecsTaskExecutionRole` |
| `AWS_VPC_ID` | `vpc-xxxxxxxx` |
| `AWS_SUBNET_IDS` | `["subnet-aaaa","subnet-bbbb"]` (mínimo 2, en AZs distintas — lo exige el ALB) |

Con `AWS_ENABLED` en `false` (o sin definir), el pipeline corre igual y
completo para la opción local.

## Política IAM sugerida (usuario de despliegue en AWS)

Para que el usuario IAM que usa el pipeline pueda crear todo lo que define
`terraform/aws/`, necesita (al menos) estas policies administradas:

- `AmazonECS_FullAccess`
- `AmazonEC2ContainerRegistryFullAccess`
- `AmazonVPCFullAccess` (por el ALB y los security groups)
- `AmazonS3FullAccess` (backend remoto del state)
- `AWSCloudMapFullAccess` (service discovery)
- `ElasticLoadBalancingFullAccess`
- `IAMReadOnlyAccess` (para poder referenciar el rol de ejecución de ECS ya creado)

## Referencias oficiales

- ESLint: https://eslint.org/docs/latest/
- Snyk GitHub Actions: https://github.com/snyk/actions
- Anchore SBOM Action / Syft: https://github.com/anchore/sbom-action
- CycloneDX: https://cyclonedx.org/specification/overview/
- Trivy Action: https://github.com/aquasecurity/trivy-action
- SARIF y GitHub code scanning: https://docs.github.com/en/code-security/code-scanning
