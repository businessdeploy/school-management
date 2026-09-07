FROM node:22-bookworm-slim

# 1. Install Apache and pre-compiled PHP 8.2 packages (cached layer)
RUN apt-get update && apt-get install -y --no-install-recommends \
    apache2 \
    php \
    libapache2-mod-php \
    php-mysql \
    php-gd \
    php-mbstring \
    php-zip \
    php-curl \
    zip \
    unzip \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. Configure Apache: internal port 8080, mod_rewrite, mpm_prefork tuning, .htaccess overrides (cached layer)
RUN sed -i 's/Listen 80$/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:8080>/' /etc/apache2/sites-available/000-default.conf \
    && a2enmod rewrite \
    && sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf \
    && echo "<IfModule mpm_prefork_module>\n    StartServers             5\n    MinSpareServers          5\n    MaxSpareServers         10\n    MaxRequestWorkers       80\n    MaxConnectionsPerChild 1000\n</IfModule>" > /etc/apache2/mods-available/mpm_prefork.conf

# 3. PHP configuration (cached layer)
RUN echo "memory_limit = 512M\nupload_max_filesize = 100M\npost_max_size = 100M\nmax_execution_time = 300\ndate.timezone = UTC\nallow_url_fopen = On" > /etc/php/8.2/apache2/conf.d/smartschool.ini

# 4. Master Dashboard dependencies (cached layer - package.json rarely changes)
WORKDIR /app
COPY master-dashboard/package*.json ./
RUN npm install --omit=dev
COPY master-dashboard/dist ./dist
COPY master-dashboard/public ./public

# 5. Smart School PHP Application (fast single-copy with owner flag, no slow chown -R)
WORKDIR /var/www/html
COPY --chown=www-data:www-data . /var/www/html
RUN rm -f /var/www/html/index.html \
    && rm -rf /var/www/html/application/controllers/install \
    && chmod -R 775 /var/www/html/uploads /var/www/html/application/config 2>/dev/null || true

# 6. Startup Entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3000

CMD ["/usr/local/bin/docker-entrypoint.sh"]
