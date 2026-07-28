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

  it('GET / devuelve informacion basica de la API', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body.message).toBe('PIN-LC Task API');
  });
});

describe('Tasks API', () => {
  it('GET /api/tasks devuelve un array', async () => {
    const res = await request(app).get('/api/tasks');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('GET /api/tasks/:id devuelve la tarea si existe', async () => {
    const res = await request(app).get('/api/tasks/1');
    expect(res.statusCode).toBe(200);
    expect(res.body.id).toBe(1);
  });

  it('GET /api/tasks/:id inexistente devuelve 404', async () => {
    const res = await request(app).get('/api/tasks/9999');
    expect(res.statusCode).toBe(404);
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

  it('PUT /api/tasks/:id actualiza titulo y estado', async () => {
    const created = await request(app).post('/api/tasks').send({ title: 'Para actualizar' });
    const res = await request(app)
      .put(`/api/tasks/${created.body.id}`)
      .send({ title: 'Actualizada', done: true });
    expect(res.statusCode).toBe(200);
    expect(res.body.title).toBe('Actualizada');
    expect(res.body.done).toBe(true);
  });

  it('PUT /api/tasks/:id inexistente devuelve 404', async () => {
    const res = await request(app).put('/api/tasks/9999').send({ done: true });
    expect(res.statusCode).toBe(404);
  });

  it('DELETE /api/tasks/:id existente devuelve 204', async () => {
    const created = await request(app).post('/api/tasks').send({ title: 'Para borrar' });
    const res = await request(app).delete(`/api/tasks/${created.body.id}`);
    expect(res.statusCode).toBe(204);
  });

  it('DELETE /api/tasks/:id inexistente devuelve 404', async () => {
    const res = await request(app).delete('/api/tasks/9999');
    expect(res.statusCode).toBe(404);
  });
});
