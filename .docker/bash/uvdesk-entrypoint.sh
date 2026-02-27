#!/bin/bash
set -e

echo "=========================================="
echo "UVDesk Container Starting..."
echo "=========================================="

# Function to wait for database
wait_for_db() {
    echo "Waiting for MySQL database to be ready..."
    local max_attempts=60
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" --silent 2>/dev/null; then
            echo "✓ Database is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        echo "  Waiting for database... ($attempt/$max_attempts)"
        sleep 2
    done

    echo "✗ Database connection timeout!"
    return 1
}

# Function to wait for Redis
wait_for_redis() {
    echo "Waiting for Redis to be ready..."
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" ping > /dev/null 2>&1; then
            echo "✓ Redis is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        echo "  Waiting for Redis... ($attempt/$max_attempts)"
        sleep 2
    done

    echo "⚠ Redis connection timeout! Continuing anyway..."
    return 0
}

# Wait for services
wait_for_db
wait_for_redis

# Generate .env file from environment variables
echo "Generating .env configuration file..."
cat > /var/www/uvdesk/.env <<EOF
###> symfony/framework-bundle ###
APP_ENV=${APP_ENV:-dev}
APP_SECRET=${APP_SECRET}
###< symfony/framework-bundle ###

UV_SESSION_COOKIE_LIFETIME=${UV_SESSION_COOKIE_LIFETIME:-3600}

###> doctrine/doctrine-bundle ###
DATABASE_URL=${DATABASE_URL:-mysql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_DATABASE}?serverVersion=8.0}
###< doctrine/doctrine-bundle ###

###> symfony/mailer ###
MAILER_DSN=${MAILER_DSN:-null://null}
###< symfony/mailer ###

###> redis configuration ###
REDIS_HOST=${REDIS_HOST}
REDIS_PORT=${REDIS_PORT}
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_DB=${REDIS_DB:-0}
REDIS_URL=${REDIS_URL:-redis://:${REDIS_PASSWORD}@${REDIS_HOST}:${REDIS_PORT}/${REDIS_DB}}
###< redis configuration ###

###> cache/session/queue configuration ###
CACHE_DRIVER=${CACHE_DRIVER:-file}
SESSION_DRIVER=${SESSION_DRIVER:-file}
QUEUE_CONNECTION=${QUEUE_CONNECTION:-sync}
###< cache/session/queue configuration ###
EOF

# Set proper ownership and permissions
echo "Setting file permissions..."
chown uvdesk:uvdesk /var/www/uvdesk/.env
chmod 644 /var/www/uvdesk/.env

# Seed config volume on first run (PVC is empty initially on k8s/k3s)
if [ ! -f /var/www/uvdesk/config/bundles.php ]; then
    echo "Config directory is empty, seeding from image backup..."
    cp -rn /var/www/uvdesk/config.bak/. /var/www/uvdesk/config/
    chown -R uvdesk:uvdesk /var/www/uvdesk/config
    chmod -R 775 /var/www/uvdesk/config
    echo "✓ Config seeded!"
fi

# Seed public volume on first run (PVC is empty initially on k8s/k3s)
if [ ! -f /var/www/uvdesk/public/index.php ]; then
    echo "Public directory is empty, seeding from image backup..."
    cp -rn /var/www/uvdesk/public.bak/. /var/www/uvdesk/public/
    chown -R uvdesk:uvdesk /var/www/uvdesk/public
    chmod -R 775 /var/www/uvdesk/public
    echo "✓ Public seeded!"
fi

# Ensure necessary directories exist
mkdir -p /var/www/uvdesk/var/cache \
    /var/www/uvdesk/var/log \
    /var/www/uvdesk/var/sessions \
    /var/www/uvdesk/config/packages \
    /var/www/uvdesk/public/uploads

chown -R uvdesk:uvdesk /var/www/uvdesk/var /var/www/uvdesk/config /var/www/uvdesk/public
chmod -R 775 /var/www/uvdesk/var /var/www/uvdesk/config /var/www/uvdesk/public

# Clear Symfony cache
if [ -f /var/www/uvdesk/bin/console ]; then
    echo "Clearing Symfony cache..."
    cd /var/www/uvdesk
    gosu uvdesk php bin/console cache:clear --no-warmup 2>/dev/null || echo "Cache clear skipped"
    gosu uvdesk php bin/console assets:install public --symlink 2>/dev/null || \
    gosu uvdesk php bin/console assets:install public 2>/dev/null || echo "Assets install skipped"
fi

# Set proper Apache permissions
mkdir -p /var/log/apache2 /var/run/apache2 /var/lock/apache2
chown -R uvdesk:uvdesk /var/log/apache2 /var/run/apache2 /var/lock/apache2

echo "=========================================="
echo "Configuration complete! Starting Apache..."
echo "=========================================="

exec "$@"
