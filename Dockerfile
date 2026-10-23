FROM php:8.5-fpm-alpine

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
        zip

# phpredis (fof/redis nutzt die Extension automatisch, sonst Predis)
RUN pecl install redis \
    && docker-php-ext-enable redis

# Produktiv-Einstellungen: Fehler ins Log, nie in Antworten; OPcache gross genug fuer Flarum 2.
# validate_timestamps=0: nach jedem Composer-/extend.php-Deploy php-fpm neu laden (reload-fpm.sh)
COPY php-prod.ini /usr/local/etc/php/conf.d/zz-prod.ini
COPY fpm-pool.conf /usr/local/etc/php-fpm.d/zz-pool.conf

# Composer aus offiziellem Image übernehmen
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Entrypoint kopieren
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
