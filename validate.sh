#!/usr/bin/env bash
# validate.sh - Chequeo rapido de que el repo y el entorno estan listos
# para correr el Proyecto 1 (local u AWS).
#
# Uso: bash validate.sh

set -uo pipefail
ok=0
fail=0

check_file() {
  if [ -f "$1" ]; then
    echo "OK    $1"
    ok=$((ok + 1))
  else
    echo "FALTA $1"
    fail=$((fail + 1))
  fi
}

check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "OK    $1 instalado ($($1 --version 2>&1 | head -n1))"
    ok=$((ok + 1))
  else
    echo "FALTA $1 (no esta instalado o no esta en el PATH)"
    fail=$((fail + 1))
  fi
}

echo "== Estructura del repo =="
check_file "app/package.json"
check_file "app/server.js"
check_file "Dockerfile"
check_file "docker-compose.yml"
check_file ".github/workflows/ci-cd.yml"
check_file "terraform/local/main.tf"
check_file "terraform/aws/main.tf"
check_file "terraform/aws/backend.tf"
check_file "terraform/aws/alb.tf"
check_file "monitoring/prometheus.yml"
check_file "monitoring/grafana/dashboards/app-dashboard.json"
check_file "monitoring/aws/prometheus.Dockerfile"
check_file "monitoring/aws/grafana.Dockerfile"

echo
echo "== Archivo critico que hay que generar antes del primer push =="
if [ -f "app/package-lock.json" ]; then
  echo "OK    app/package-lock.json"
  ok=$((ok + 1))
else
  echo "FALTA app/package-lock.json -> correr: cd app && npm install"
  fail=$((fail + 1))
fi

echo
echo "== Herramientas del entorno =="
check_cmd node
check_cmd npm
check_cmd docker
check_cmd terraform
check_cmd git

echo
echo "== Docker Compose (plugin v2) =="
if docker compose version >/dev/null 2>&1; then
  echo "OK    docker compose (plugin)"
  ok=$((ok + 1))
else
  echo "FALTA docker compose (plugin) -> ver https://docs.docker.com/compose/install/"
  fail=$((fail + 1))
fi

echo
echo "=================================="
echo "Resultado: $ok OK / $fail pendientes"
echo "=================================="

if [ "$fail" -gt 0 ]; then
  exit 1
fi
