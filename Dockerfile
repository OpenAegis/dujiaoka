FROM webdevops/php-nginx:8.2

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /app

# Copy composer files first for better caching
COPY composer.json composer.lock ./

# Install PHP dependencies
RUN composer install --no-dev --no-scripts --no-autoloader --ignore-platform-reqs

# Copy application code
COPY . .

# Generate autoloader and run post-install scripts
RUN composer dump-autoload --optimize && \
    composer run-script post-install-cmd --no-interaction || true

# Set permissions
RUN chown -R application:application /app && \
    chmod -R 755 /app && \
    chmod -R 777 /app/storage /app/bootstrap/cache

# Configure web server
ENV WEB_DOCUMENT_ROOT="/app/public"
ENV WEB_DOCUMENT_INDEX="index.php"
ENV WEB_ALIAS_DOMAIN="*.vm"
ENV WEB_PHP_TIMEOUT=600
ENV WEB_PHP_SOCKET=""

EXPOSE 80 443
