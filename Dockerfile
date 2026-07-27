# syntax=docker/dockerfile:1
# Dockerfile multi-stage siguiendo las buenas practicas oficiales de Docker
# https://docs.docker.com/build/building/best-practices/

# ---- Stage 1: dependencias de produccion ----
FROM node:20-alpine AS deps
WORKDIR /usr/src/app
COPY app/package*.json ./
RUN npm ci --omit=dev

# ---- Stage 2: imagen final ----
FROM node:20-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /usr/src/app

# Usuario no-root (imagen node:alpine ya incluye el usuario "node")
COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY app/ .

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
