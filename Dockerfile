FROM webdevops/php-nginx:8.2

# Set working directory
WORKDIR /app

# Copy application code
COPY . .

# Remove problematic scripts from composer.json during build
RUN sed -i '/"scripts":/,/}/d' composer.json

# Install composer dependencies without scripts
RUN composer install --no-dev --ignore-platform-reqs --no-interaction

# Set permissions
RUN chown -R application:application /app && \
    chmod -R 777 /app/storage /app/bootstrap/cache

# Configure web server
ENV WEB_DOCUMENT_ROOT="/app/public"

EXPOSE 80
