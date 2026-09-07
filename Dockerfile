FROM php:8.2-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libzip-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    zip \
    unzip \
    curl \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd mysqli pdo_mysql mbstring zip curl

# Enable Apache mod_rewrite & .htaccess overrides
RUN a2enmod rewrite && sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf

# Configure PHP settings required by Smart School
RUN echo "memory_limit = 512M" > /usr/local/etc/php/conf.d/smartschool.ini \
    && echo "upload_max_filesize = 100M" >> /usr/local/etc/php/conf.d/smartschool.ini \
    && echo "post_max_size = 100M" >> /usr/local/etc/php/conf.d/smartschool.ini \
    && echo "max_execution_time = 300" >> /usr/local/etc/php/conf.d/smartschool.ini \
    && echo "date.timezone = UTC" >> /usr/local/etc/php/conf.d/smartschool.ini \
    && echo "allow_url_fopen = On" >> /usr/local/etc/php/conf.d/smartschool.ini

WORKDIR /var/www/html
COPY . /var/www/html
RUN chown -R www-data:www-data /var/www/html

EXPOSE 80
