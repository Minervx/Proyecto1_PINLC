# SBOM (Software Bill of Materials)

El SBOM se genera de forma automática en el job `security-scan` del workflow,
usando la acción oficial **Anchore SBOM Action**, que internamente utiliza
**Syft** y soporta formato **CycloneDX** (y también SPDX):

- Acción: https://github.com/anchore/sbom-action
- Especificación CycloneDX: https://cyclonedx.org/specification/overview/
- Especificación SPDX: https://spdx.dev/learn/overview/

## Cómo se obtiene

1. El workflow corre automáticamente en cada push/PR y sube el archivo como
   *artifact* llamado `sbom-cyclonedx` (pestaña **Actions** → ejecución → **Artifacts**).
2. También se puede generar en forma local con Syft (sin necesidad de CI):

```bash
# Instalación oficial de Syft: https://github.com/anchore/syft#installation
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Generar SBOM en CycloneDX JSON a partir del código de la app
syft app -o cyclonedx-json > sbom/sbom-cyclonedx.json

# Formato SPDX (alternativo)
syft app -o spdx-json > sbom/sbom-spdx.json
```

## Nota importante para la entrega

Este repositorio incluye la **configuración** que genera el SBOM real de forma
reproducible (ver `.github/workflows/ci-cd.yml`), en lugar de un archivo SBOM
"pre-armado". Esto es intencional: un SBOM válido depende de las versiones
exactas resueltas por `npm ci` en el momento del build (lockfile), por lo que
el artefacto final debe obtenerse ejecutando el pipeline (o el comando de Syft
de arriba) y no debe fabricarse a mano. Antes de comprimir el entregable final,
descarguen el artifact `sbom-cyclonedx` desde la ejecución de Actions y
colóquenlo en esta carpeta como `sbom-cyclonedx.json`.
