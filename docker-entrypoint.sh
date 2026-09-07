#!/bin/bash
set -e

echo "[DockerEntrypoint] Ensuring Apache port configuration on 8080..."
sed -i 's/Listen 80$/Listen 8080/' /etc/apache2/ports.conf 2>/dev/null || true
sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:8080>/' /etc/apache2/sites-available/000-default.conf 2>/dev/null || true

echo "[DockerEntrypoint] Starting Apache HTTP server..."
# Synchronize latest Prime School brand graphics to all tenant persistent volumes
if [ -d "/var/www/html/tenants" ]; then
    echo "[DockerEntrypoint] Syncing Prime School brand assets to tenant storage..."
    for t_dir in /var/www/html/tenants/*; do
        if [ -d "$t_dir/uploads/school_content/admin_logo" ]; then
            cp -f /var/www/html/uploads/school_content/admin_logo/1.png "$t_dir/uploads/school_content/admin_logo/1.png" 2>/dev/null || true
        fi
        if [ -d "$t_dir/uploads/school_content/admin_small_logo" ]; then
            cp -f /var/www/html/uploads/school_content/admin_small_logo/1.png "$t_dir/uploads/school_content/admin_small_logo/1.png" 2>/dev/null || true
        fi
    done
fi
service apache2 start || apache2ctl start || true

echo "[DockerEntrypoint] Starting Prime School Fleet Master Orchestrator on port 3000..."
export NODE_OPTIONS="--max-old-space-size=1024"
cd /app
exec node dist/index.js
