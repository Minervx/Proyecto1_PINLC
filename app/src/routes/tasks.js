'use strict';

const express = require('express');

const router = express.Router();

// Almacenamiento en memoria (alcanza para demostrar el pipeline CI/CD)
let tasks = [
  { id: 1, title: 'Configurar pipeline CI/CD', done: false },
  { id: 2, title: 'Documentar entregables', done: false },
];
let nextId = 3;

router.get('/', (req, res) => {
  res.json(tasks);
});

router.get('/:id', (req, res) => {
  const task = tasks.find((t) => t.id === Number(req.params.id));
  if (!task) return res.status(404).json({ error: 'Tarea no encontrada' });
  return res.json(task);
});

router.post('/', (req, res) => {
  const { title } = req.body;
  if (!title || typeof title !== 'string') {
    return res.status(400).json({ error: 'El campo "title" es obligatorio' });
  }
  const task = { id: nextId++, title, done: false };
  tasks.push(task);
  return res.status(201).json(task);
});

router.put('/:id', (req, res) => {
  const task = tasks.find((t) => t.id === Number(req.params.id));
  if (!task) return res.status(404).json({ error: 'Tarea no encontrada' });
  const { title, done } = req.body;
  if (title !== undefined) task.title = title;
  if (done !== undefined) task.done = done;
  return res.json(task);
});

router.delete('/:id', (req, res) => {
  const initialLength = tasks.length;
  tasks = tasks.filter((t) => t.id !== Number(req.params.id));
  if (tasks.length === initialLength) {
    return res.status(404).json({ error: 'Tarea no encontrada' });
  }
  return res.status(204).send();
});

module.exports = router;
