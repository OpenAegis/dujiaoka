FROM webdevops/php-nginx:8.2

# Set working directory
WORKDIR /app

# Copy application code
COPY . .

# Create a minimal composer.json for build to avoid scripts
RUN cp composer.json composer.json.orig && \
    php -r '$composer = json_decode(file_get_contents("composer.json"), true); unset($composer["scripts"]); file_put_contents("composer.json", json_encode($composer, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));'

# Install composer dependencies without scripts
RUN composer install --no-dev --ignore-platform-reqs --no-interaction

# Restore original composer.json
RUN mv composer.json.orig composer.json

# Set permissions
RUN chown -R application:application /app && \
    chmod -R 777 /app/storage /app/bootstrap/cache

# Configure web server for Laravel
ENV WEB_DOCUMENT_ROOT="/app/public"
ENV WEB_DOCUMENT_INDEX="index.php"
ENV WEB_ALIAS_DOMAIN="*.vm"
ENV WEB_PHP_TIMEOUT=600

# Create nginx Laravel configuration
RUN echo 'server { \
    listen 80; \
    server_name _; \
    root /app/public; \
    index index.php index.html; \
    \
    # Laravel rewrite rules \
    location / { \
        try_files $uri $uri/ /index.php?$query_string; \
    } \
    \
    # PHP-FPM configuration \
    location ~ \.php$ { \
        fastcgi_pass 127.0.0.1:9000; \
        fastcgi_index index.php; \
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; \
        include fastcgi_params; \
    } \
    \
    # Deny access to hidden files \
    location ~ /\. { \
        deny all; \
    } \
    \
    # Security headers \
    add_header X-Frame-Options "SAMEORIGIN" always; \
    add_header X-XSS-Protection "1; mode=block" always; \
    add_header X-Content-Type-Options "nosniff" always; \
}' > /opt/docker/etc/nginx/vhost.conf

EXPOSE 80
