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
            cp -f /var/www/html/uploads/school_content/admin_logo/* "$t_dir/uploads/school_content/admin_logo/" 2>/dev/null || true
        fi
        if [ -d "$t_dir/uploads/school_content/admin_small_logo" ]; then
            cp -f /var/www/html/uploads/school_content/admin_small_logo/* "$t_dir/uploads/school_content/admin_small_logo/" 2>/dev/null || true
        fi
        if [ -d "$t_dir/uploads/school_content/logo" ]; then
            cp -f /var/www/html/uploads/school_content/logo/* "$t_dir/uploads/school_content/logo/" 2>/dev/null || true
        fi
    done
fi
mkdir -p /app/public
cp -r /var/www/html/master-dashboard/public/* /app/public/ 2>/dev/null || true

echo "[DockerEntrypoint] Passing container environment to Apache..."
for var in FLEET_DB_HOST FLEET_DB_PORT FLEET_DB_USER FLEET_DB_PASSWORD MASTER_DB_NAME DOCKER_NETWORK DB_HOST DB_USER DB_PASS DB_NAME MASTER_SSO_SECRET SESSION_SECRET NODE_ENV CI_ENV; do
    val=$(eval echo "\"\$$var\"")
    if [ -n "$val" ]; then
        echo "export $var=\"$val\"" >> /etc/apache2/envvars
    fi
done
echo "PassEnv FLEET_DB_HOST FLEET_DB_PORT FLEET_DB_USER FLEET_DB_PASSWORD MASTER_DB_NAME DOCKER_NETWORK DB_HOST DB_USER DB_PASS DB_NAME MASTER_SSO_SECRET SESSION_SECRET NODE_ENV CI_ENV" >> /etc/apache2/apache2.conf 2>/dev/null || true

service apache2 start || apache2ctl start || true

echo "[DockerEntrypoint] Starting Prime School Fleet Master Orchestrator on port 3000..."
export NODE_OPTIONS="--max-old-space-size=1024"
cd /app
exec node dist/index.js
