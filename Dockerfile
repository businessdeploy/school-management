# Multi-stage build: Master Dashboard (Node.js) + Smart School CRM (PHP 8.2 Apache)
FROM node:22-bookworm-slim AS node-builder

WORKDIR /app
COPY master-dashboard/package*.json master-dashboard/tsconfig.json ./
RUN npm install
COPY master-dashboard/src/ ./src/
RUN npm run build
RUN cp -r src/views dist/views
RUN cp src/database.sql dist/database.sql 2>/dev/null || true
RUN npm prune --production

FROM php:8.2-apache

# Install PHP extensions and dependencies
RUN apt-get update && apt-get install -y \
    curl \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libzip-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    zip \
    unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd mysqli pdo_mysql mbstring zip curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy Node.js binary from builder stage
COPY --from=node-builder /usr/local/bin/node /usr/local/bin/node
RUN ln -s /usr/local/bin/node /usr/bin/node 2>/dev/null || true

# Configure Apache: listen on internal port 8080, enable rewrite & .htaccess overrides
RUN sed -i 's/Listen 80$/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:8080>/' /etc/apache2/sites-available/000-default.conf \
    && a2enmod rewrite \
    && sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf

# PHP configuration
RUN echo "memory_limit = 512M" > /usr/local/etc/php/conf.d/smartschool.ini \
    && echo "upload_max_filesize = 100M" >> /usr/local/etc/php/conf.d/smartschool.ini \
    && echo "post_max_size = 100M" >> /usr/local/etc/php/conf.d/smartschool.ini \
    && echo "max_execution_time = 300" >> /usr/local/etc/php/conf.d/smartschool.ini \
    && echo "date.timezone = UTC" >> /usr/local/etc/php/conf.d/smartschool.ini \
    && echo "allow_url_fopen = On" >> /usr/local/etc/php/conf.d/smartschool.ini

# Smart School PHP Application
WORKDIR /var/www/html
COPY . /var/www/html
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/uploads /var/www/html/application/config 2>/dev/null || true

# Master Dashboard Application
WORKDIR /app
COPY --from=node-builder /app/package.json ./
COPY --from=node-builder /app/node_modules ./node_modules
COPY --from=node-builder /app/dist ./dist
RUN mkdir -p /app/public

# Startup Entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3000

CMD ["/usr/local/bin/docker-entrypoint.sh"]
