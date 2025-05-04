FROM php:8.2-apache

# install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# set workdir
WORKDIR /var/www/html

# install os dependencies
RUN apt-get update && apt-get install -y \
    git \
    nano \
    curl \
    wget \
    zip \
    mariadb-client \
    libonig-dev \
    libxml2-dev \
    zlib1g-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libmemcached-dev \
    libmemcached11 \
    libmemcachedutil2 \
    libsodium-dev \
    libssl-dev \
    libicu-dev \
    ca-certificates \
    imagemagick \
    libmagickwand-dev \
    && update-ca-certificates

# install php extensions
RUN docker-php-ext-install -j$(nproc) iconv \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install pdo pdo_mysql mysqli mbstring exif pcntl bcmath zip sockets sodium intl \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl \
    && pecl install redis \
    && pecl install memcached \
    && docker-php-ext-enable redis memcached \
    && pecl install mongodb \
    && docker-php-ext-enable mongodb \
    # Install and enable imagick PHP extension
    && pecl install imagick \
    && docker-php-ext-enable imagick

# create user with UID 1000 and add to www-data group
RUN groupadd -g 1000 appuser \
    && useradd -u 1000 -ms /bin/bash -g appuser appuser \
    && usermod -a -G www-data appuser

# add aliases to bash runcom file
RUN echo 'alias ll="ls -lFah"' >> /home/appuser/.bashrc

# Change the Apache user and group
RUN sed -i 's/www-data/appuser/g' /etc/apache2/apache2.conf && \
    sed -i 's/www-data/appuser/g' /etc/apache2/envvars

# permissions
RUN chown -R appuser:appuser /var/www

# enable apache modules
RUN a2enmod rewrite headers ssl

# use the created user
USER appuser

CMD ["apache2-foreground"]
