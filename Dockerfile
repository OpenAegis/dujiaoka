FROM webdevops/php-nginx:8.2

# Set working directory
WORKDIR /app

# Copy composer files first for better caching
COPY composer.json composer.lock ./

# Install composer dependencies without running scripts
RUN composer install --no-dev --ignore-platform-reqs --no-interaction --no-scripts

# Copy application code
COPY . .

# Generate optimized autoloader
RUN composer dump-autoload --optimize --no-dev

# Set permissions
RUN chown -R application:application /app && \
    chmod -R 777 /app/storage /app/bootstrap/cache

# Configure web server
ENV WEB_DOCUMENT_ROOT="/app/public"

EXPOSE 80
