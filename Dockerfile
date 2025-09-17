FROM webdevops/php-nginx:8.2

# Set working directory
WORKDIR /app

# Copy application code
COPY . .

# Create a minimal composer.json for build to avoid scripts
RUN cp composer.json composer.json.orig && \
    php -r '
    $composer = json_decode(file_get_contents("composer.json"), true);
    unset($composer["scripts"]);
    file_put_contents("composer.json", json_encode($composer, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
    '

# Install composer dependencies without scripts
RUN composer install --no-dev --ignore-platform-reqs --no-interaction

# Restore original composer.json
RUN mv composer.json.orig composer.json

# Set permissions
RUN chown -R application:application /app && \
    chmod -R 777 /app/storage /app/bootstrap/cache

# Configure web server
ENV WEB_DOCUMENT_ROOT="/app/public"

EXPOSE 80
