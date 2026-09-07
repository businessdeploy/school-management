#!/bin/bash
set -e

echo "[DockerEntrypoint] Ensuring Apache port configuration on 8080..."
sed -i 's/Listen 80$/Listen 8080/' /etc/apache2/ports.conf 2>/dev/null || true
sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:8080>/' /etc/apache2/sites-available/000-default.conf 2>/dev/null || true

echo "[DockerEntrypoint] Starting Apache HTTP server..."
service apache2 start || apache2ctl start || true

echo "[DockerEntrypoint] Starting Smart School Master Orchestrator on port 3000..."
cd /app
exec node dist/index.js
