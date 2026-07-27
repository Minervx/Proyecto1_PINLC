'use strict';

const request = require('supertest');
const app = require('../server');

describe('Health & Metrics', () => {
  it('GET /health devuelve estado ok', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  it('GET /metrics expone metricas en formato Prometheus', async () => {
    const res = await request(app).get('/metrics');
    expect(res.statusCode).toBe(200);
    expect(res.text).toContain('pinlc_app_');
  });
});

describe('Tasks API', () => {
  it('GET /api/tasks devuelve un arreglo', async () => {
    const res = await request(app).get('/api/tasks');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('POST /api/tasks crea una tarea', async () => {
    const res = await request(app).post('/api/tasks').send({ title: 'Nueva tarea' });
    expect(res.statusCode).toBe(201);
    expect(res.body.title).toBe('Nueva tarea');
  });

  it('POST /api/tasks sin titulo devuelve 400', async () => {
    const res = await request(app).post('/api/tasks').send({});
    expect(res.statusCode).toBe(400);
  });

  it('DELETE /api/tasks/:id inexistente devuelve 404', async () => {
    const res = await request(app).delete('/api/tasks/9999');
    expect(res.statusCode).toBe(404);
  });
});
