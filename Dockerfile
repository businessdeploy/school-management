FROM node:22-bookworm-slim

# Install Apache and pre-compiled PHP 8.2 packages (fast ~15s install, no compiling from source)
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

# Configure Apache: listen on internal port 8080, enable mod_rewrite, allow .htaccess overrides
RUN sed -i 's/Listen 80$/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:8080>/' /etc/apache2/sites-available/000-default.conf \
    && a2enmod rewrite \
    && sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf

# PHP configuration
RUN echo "memory_limit = 512M\nupload_max_filesize = 100M\npost_max_size = 100M\nmax_execution_time = 300\ndate.timezone = UTC\nallow_url_fopen = On" > /etc/php/8.2/apache2/conf.d/smartschool.ini

# Copy Smart School PHP Application
WORKDIR /var/www/html
COPY . /var/www/html
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/uploads /var/www/html/application/config 2>/dev/null || true

# Build Master Dashboard (TypeScript -> JavaScript)
WORKDIR /app
COPY master-dashboard/package*.json master-dashboard/tsconfig.json ./
RUN npm install
COPY master-dashboard/src/ ./src/
RUN npm run build
RUN cp -r src/views dist/views
RUN cp src/database.sql dist/database.sql 2>/dev/null || true
RUN npm prune --production
RUN mkdir -p /app/public

# Startup Entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3000

CMD ["/usr/local/bin/docker-entrypoint.sh"]
