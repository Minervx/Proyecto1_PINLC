'use strict';

const client = require('prom-client');

// Registro dedicado para no mezclar con metricas globales por defecto
const register = new client.Registry();

// Metricas por defecto del proceso (CPU, memoria, event loop, etc.)
client.collectDefaultMetrics({ register, prefix: 'pinlc_app_' });

// Metrica custom: duracion de requests HTTP, base de los dashboards de Grafana
const httpRequestDurationMicroseconds = new client.Histogram({
  name: 'pinlc_app_http_request_duration_seconds',
  help: 'Duracion de las requests HTTP en segundos',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 2, 5],
});

register.registerMetric(httpRequestDurationMicroseconds);

module.exports = { register, httpRequestDurationMicroseconds };
