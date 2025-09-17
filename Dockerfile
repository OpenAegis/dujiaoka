FROM webdevops/php-nginx:8.2

# Copy application code
COPY . /app

# Set working directory
WORKDIR /app

# Install composer dependencies
RUN composer install --no-dev --ignore-platform-reqs --no-interaction

# Set permissions
RUN chown -R application:application /app && \
    chmod -R 777 /app/storage /app/bootstrap/cache

# Configure web server
ENV WEB_DOCUMENT_ROOT="/app/public"

EXPOSE 80
