# syntax=docker/dockerfile:1

# Bagisto eğitimi için PHP-FPM geliştirme imajı.
# Uygulama, kuyruk işçisi, zamanlayıcı ve Vite servisleri bu imajı kullanır.
# Derleme: docker-bake.hcl (yerelde: docker buildx bake --load php)

ARG PHP_VERSION=8.4
ARG NODE_VERSION=22

FROM node:${NODE_VERSION}-trixie-slim AS node

FROM php:${PHP_VERSION}-fpm-trixie

# PHP eklentileri. Temel imajda zaten olanlar: ctype, curl, dom, fileinfo, filter, hash, iconv,
# json, libxml, mbstring, openssl, pcre, pdo, session, simplexml, sodium, tokenizer, xml,
# xmlreader, xmlwriter, zlib. Aşağıdakiler Bagisto'nun zorunlu, yükleyicinin denetlediği ve
# isteğe bağlı eklentilerinin geri kalanıdır.
COPY --from=mlocati/php-extension-installer:2 /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions \
        bcmath \
        calendar \
        exif \
        gd \
        gmp \
        imagick \
        intl \
        mysqli \
        opcache \
        pcntl \
        pdo_mysql \
        pdo_pgsql \
        pgsql \
        redis \
        soap \
        sockets \
        zip \
        xdebug

RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip \
    && rm -rf /var/lib/apt/lists/* \
    && git config --system --add safe.directory '*'

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Node.js yalnızca ön yüz varlıklarını derlemek ve Vite geliştirme sunucusu için.
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
COPY php.ini "$PHP_INI_DIR/conf.d/zz-bagisto-egitimi.ini"
COPY php-fpm.conf /usr/local/etc/php-fpm.d/zz-bagisto-egitimi.conf
COPY vite-proxy.mjs /usr/local/lib/bagisto-egitimi/vite-proxy.mjs
COPY --chmod=755 vite-dev.sh /usr/local/bin/vite-dev

# Konteynerler ana makinedeki kullanıcının UID/GID değeriyle çalışır (compose.yaml: user).
# Bu yüzden ev dizini ve önbellek dizinleri her kullanıcıya yazılabilir olmalı.
RUN mkdir -p /home/app /opt/cache/composer /opt/cache/npm \
    && chmod 1777 /home/app /opt/cache/composer /opt/cache/npm

ENV HOME=/home/app \
    COMPOSER_HOME=/home/app/.composer \
    COMPOSER_CACHE_DIR=/opt/cache/composer \
    npm_config_cache=/opt/cache/npm

WORKDIR /var/www/html
