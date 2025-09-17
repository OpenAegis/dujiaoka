FROM webdevops/php-nginx:8.2

# Set working directory
WORKDIR /app

# Copy application code
COPY . .

# Temporarily rename composer.json to avoid scripts during build
RUN mv composer.json composer.json.bak

# Install composer dependencies without running scripts and autoloader
RUN composer install --no-dev --ignore-platform-reqs --no-interaction --no-scripts --no-autoloader

# Restore composer.json and generate autoloader without triggering scripts
RUN mv composer.json.bak composer.json && \
    composer dump-autoload --optimize --no-dev --no-scripts

# Set permissions
RUN chown -R application:application /app && \
    chmod -R 777 /app/storage /app/bootstrap/cache

# Configure web server
ENV WEB_DOCUMENT_ROOT="/app/public"

EXPOSE 80
