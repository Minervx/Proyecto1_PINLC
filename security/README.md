# Seguridad del pipeline

Ver la guía completa y actualizada en **`docs/SECURITY_COMPLIANCE.md`**
(controles implementados, checklist de secretos/variables de GitHub, política
IAM sugerida para AWS y referencias oficiales).

Resumen rápido:

- **ESLint** (análisis estático) — alternativa intercambiable a SonarQube según
  permite la consigna.
- **Snyk** (auditoría de dependencias) — requiere el secreto `SNYK_TOKEN`.
- **SBOM en CycloneDX** — ver `sbom/README.md`.
- **Trivy** (escaneo de la imagen Docker, con reporte en la pestaña *Security*
  de GitHub) — capa extra sumada sobre lo pedido por la consigna.
