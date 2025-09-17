FROM webdevops/php-nginx:8.2

# Set working directory
WORKDIR /app

# Copy application code
COPY . .

# Install composer dependencies without running scripts and autoloader
RUN composer install --no-dev --ignore-platform-reqs --no-interaction --no-scripts --no-autoloader

# Generate optimized autoloader after all files are in place
RUN composer dump-autoload --optimize --no-dev

# Set permissions
RUN chown -R application:application /app && \
    chmod -R 777 /app/storage /app/bootstrap/cache

# Configure web server
ENV WEB_DOCUMENT_ROOT="/app/public"

EXPOSE 80
