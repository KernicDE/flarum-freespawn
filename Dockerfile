FROM php:8.3-fpm-alpine

# System-Abhängigkeiten für PHP-Extensions und Composer
RUN apk add --no-cache \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libzip-dev \
    icu-dev \
    curl \
    curl-dev \
    git \
    unzip \
    oniguruma-dev \
    libxml2-dev \
    $PHPIZE_DEPS

# PHP-Extensions bauen
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        gd \
        intl \
        pdo_mysql \
        mbstring \
        zip \
        curl \
        dom \
        opcache

# Composer aus offiziellem Image übernehmen
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Entrypoint kopieren
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
