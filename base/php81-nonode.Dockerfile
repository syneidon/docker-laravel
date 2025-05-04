# Laravel v10 - PHP 8.1 - Node {{NODE_VERSION}}
FROM php:8.1-apache

# Update the package list
RUN apt-get update -y

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Set workdir
WORKDIR /var/www/html

# Install system dependencies
RUN apt-get install -y \
    git \
    nano \
    curl \
    wget \
    zip \
    mariadb-client \
    libpq-dev \
    libcurl4-gnutls-dev \
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

# Install PHP extensions
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
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug

# Create appuser (UID 1000) and assign to www-data group
RUN groupadd -g 1000 appuser \
    && useradd -u 1000 -ms /bin/bash -g appuser appuser \
    && usermod -a -G www-data appuser

# Add bash aliases
RUN echo 'alias ll="ls -lFah"' >> /home/appuser/.bashrc

# Change Apache user to appuser
RUN sed -i 's/www-data/appuser/g' /etc/apache2/apache2.conf && \
    sed -i 's/www-data/appuser/g' /etc/apache2/envvars

# Fix permissions
RUN chown -R appuser:appuser /var/www

# Enable Apache modules
RUN a2enmod rewrite headers ssl

# Install Node.js {{NODE_VERSION}}
RUN curl -fsSL https://deb.nodesource.com/setup_{{NODE_VERSION}}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Use non-root user
USER appuser

CMD ["apache2-foreground"]
