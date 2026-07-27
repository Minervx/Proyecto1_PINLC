# Guía de monitoreo (Prometheus + Grafana)

## Métricas expuestas por la app

`GET /metrics` (formato Prometheus, via `prom-client`), con prefijo `pinlc_app_`:

- `pinlc_app_http_request_duration_seconds` (histograma; requests, latencia p95, errores 5xx salen de acá)
- Métricas por defecto del proceso Node.js: `pinlc_app_process_resident_memory_bytes`, event loop, CPU, etc.

## Opción local

```bash
docker compose up -d --build
```

- App: `http://localhost:3000`
- Prometheus: `http://localhost:9090` (scrapea `app:3000/metrics` cada 15s — `monitoring/prometheus.yml`)
- Grafana: `http://localhost:3001` (`admin` / `admin`, provisioning automático — `monitoring/grafana/`)

## Opción AWS

Prometheus y Grafana corren también como servicios ECS Fargate, con su config
horneada en imágenes custom (`monitoring/aws/*.Dockerfile`), y expuestos a
través del ALB:

```bash
terraform output prometheus_url   # http://<alb-dns>:9090
terraform output grafana_url      # http://<alb-dns>:3001
```

Prometheus scrapea la app como `app.pin-lc.local:3000` (vía Cloud Map, en vez del
nombre de servicio de Docker Compose) — ver `monitoring/aws/prometheus-aws.yml`.
El datasource de Grafana apunta a `prometheus.pin-lc.local:9090` — ver
`monitoring/aws/grafana-provisioning-aws/datasources/datasource.yml`.

## Dashboard incluido

"PIN-LC Task API - Métricas básicas" (mismo JSON para local y AWS:
`monitoring/grafana/dashboards/app-dashboard.json` /
`monitoring/aws/dashboards/app-dashboard.json`), con 4 paneles:

1. Requests por segundo, por ruta
2. Latencia p95
3. Tasa de errores 5xx
4. Memoria residente del proceso

## Crear un panel nuevo (manual)

1. Grafana → Dashboards → abrir "PIN-LC Task API" → **Edit** → **Add panel**.
2. Datasource: Prometheus (ya viene seleccionado por defecto).
3. Ejemplos de query:

```promql
rate(pinlc_app_http_request_duration_seconds_count[5m])                 # requests/seg
histogram_quantile(0.95, rate(pinlc_app_http_request_duration_seconds_bucket[5m]))  # p95
```

## Referencias oficiales

- Prometheus config: https://prometheus.io/docs/prometheus/latest/configuration/configuration/
- Grafana provisioning: https://grafana.com/docs/grafana/latest/administration/provisioning/
- prom-client: https://github.com/siimon/prom-client
