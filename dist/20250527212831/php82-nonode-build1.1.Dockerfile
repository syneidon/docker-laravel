FROM php:8.2-apache

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    composer self-update --stable

# Set workdir
WORKDIR /var/www/html

# Install system dependencies
RUN apt-get update && apt-get install -y \
  git nano curl wget zip unzip mariadb-client \
  libonig-dev libxml2-dev zlib1g-dev libpng-dev libjpeg-dev \
  libfreetype6-dev libzip-dev libmemcached-dev libmemcached11 libmemcachedutil2 \
  libsodium-dev libssl-dev libicu-dev ca-certificates imagemagick libmagickwand-dev \
  build-essential pkg-config p7zip-full \
  && update-ca-certificates

# Install PHP extensions
RUN docker-php-ext-install -j$(nproc) iconv \
  && docker-php-ext-install -j$(nproc) gd \
  && docker-php-ext-install pdo pdo_mysql mysqli mbstring exif pcntl bcmath zip sockets sodium intl \
  && docker-php-ext-configure intl \
  && docker-php-ext-install intl

# Install and enable compatible PECL extensions
RUN set -eux; \
  PHP_VERSION_SHORT="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')"; \
  case "$PHP_VERSION_SHORT" in \
    7.2|7.3) \
      pecl install redis-5.3.7 && \
      pecl install memcached-3.1.5 && \
      pecl install mongodb-1.9.2 ;; \
    7.4) \
      pecl install redis-5.3.7 && \
      pecl install memcached-3.1.5 ;; \
    8.0) \
      pecl install redis && \
      pecl install memcached ;; \
    *) \
      pecl install redis && \
      pecl install memcached && \
      pecl install mongodb ;; \
  esac && \
  docker-php-ext-enable redis memcached mongodb || true && \
  pecl install imagick && docker-php-ext-enable imagick

# Create appuser (UID 1000) and assign to www-data group
RUN groupadd -g 1000 appuser \
  && useradd -u 1000 -ms /bin/bash -g appuser appuser \
  && usermod -a -G www-data appuser

# Add bash aliases
RUN echo 'alias ll="ls -lFah"' >> /home/appuser/.bashrc

# Change Apache user to appuser
RUN sed -i 's/www-data/appuser/g' /etc/apache2/apache2.conf && \
  sed -i 's/www-data/appuser/g' /etc/apache2/envvars

# Install default virtual host
COPY ./src/apache.conf /etc/apache2/sites-available/000-default.conf

# Fix permissions
RUN chown -R appuser:appuser /var/www

# Enable Apache modules
RUN a2enmod rewrite headers ssl

# Use non-root user
USER appuser

CMD ["apache2-foreground"]
