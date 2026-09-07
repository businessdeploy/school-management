#!/bin/bash
set -e

echo "[DockerEntrypoint] Configuring Apache internal port to 8080..."
sed -i 's/Listen 80$/Listen 8080/' /etc/apache2/ports.conf 2>/dev/null || true
sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:8080>/' /etc/apache2/sites-available/000-default.conf 2>/dev/null || true

echo "[DockerEntrypoint] Starting Apache HTTP server on port 8080..."
service apache2 start

echo "[DockerEntrypoint] Starting Smart School Master Orchestrator on port 3000..."
cd /app
exec node dist/index.js
