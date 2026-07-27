'use strict';

const express = require('express');
const { register, httpRequestDurationMicroseconds } = require('./src/metrics');
const tasksRouter = require('./src/routes/tasks');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// Middleware de metricas: mide duracion de cada request para Prometheus
app.use((req, res, next) => {
  const end = httpRequestDurationMicroseconds.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.path, status_code: res.statusCode });
  });
  next();
});

// Endpoint de salud, usado por Docker HEALTHCHECK y por Kubernetes/monitoreo
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', uptime: process.uptime() });
});

// Endpoint de metricas en formato Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.use('/api/tasks', tasksRouter);

app.get('/', (req, res) => {
  res.status(200).json({ message: 'PIN-LC Task API', docs: '/api/tasks', health: '/health', metrics: '/metrics' });
});

if (require.main === module) {
  app.listen(PORT, () => {
    // eslint-disable-next-line no-console
    console.log(`PIN-LC Task API escuchando en el puerto ${PORT}`);
  });
}

module.exports = app;
