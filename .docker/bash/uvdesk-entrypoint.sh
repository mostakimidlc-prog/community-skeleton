#!/bin/bash
set -e

# -----------------------------
# Color codes for output
# -----------------------------
COLOR_NC='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_LIGHT_YELLOW='\033[1;33m'

# -----------------------------
# Required environment variables
# -----------------------------
: "${DB_HOST:=db}"
: "${DB_PORT:=3306}"
: "${DB_DATABASE:=uvdesk}"
: "${DB_USERNAME:=uvdesk}"
: "${DB_PASSWORD:=uvdesk_password}"
: "${UV_SESSION_COOKIE_LIFETIME:=3600}"

# -----------------------------
# Wait for external MySQL database to be ready
# -----------------------------
echo -e "${COLOR_GREEN}Waiting for database at ${DB_HOST}:${DB_PORT}...${COLOR_NC}"

MAX_TRIES=30
COUNT=0

while [ $COUNT -lt $MAX_TRIES ]; do
    if mysqladmin ping -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" --silent 2>/dev/null; then
        echo -e "${COLOR_GREEN}Database is ready!${COLOR_NC}"
        break
    fi
    COUNT=$((COUNT + 1))
    echo -e "${COLOR_LIGHT_YELLOW}Waiting for database... (attempt $COUNT/$MAX_TRIES)${COLOR_NC}"
    sleep 2
done

if [ $COUNT -eq $MAX_TRIES ]; then
    echo -e "${COLOR_RED}ERROR: Database did not become ready in time${COLOR_NC}"
    exit 1
fi

# -----------------------------
# Fix permissions for UVDesk
# -----------------------------
echo -e "${COLOR_GREEN}Fixing permissions...${COLOR_NC}"
mkdir -p /var/www/uvdesk/{var,config,public,migrations}
chown -R uvdesk:uvdesk /var/www/uvdesk
chmod -R 775 /var/www/uvdesk/var /var/www/uvdesk/config /var/www/uvdesk/public /var/www/uvdesk/migrations /var/www/uvdesk/.env 2>/dev/null || true

# -----------------------------
# Fix Apache log permissions
# -----------------------------
echo -e "${COLOR_GREEN}Fixing Apache log permissions...${COLOR_NC}"
mkdir -p /var/log/apache2
touch /var/log/apache2/error.log /var/log/apache2/access.log /var/log/apache2/other_vhosts_access.log
chown -R uvdesk:uvdesk /var/log/apache2
chmod -R 775 /var/log/apache2

# Fix Apache run directory permissions
mkdir -p /var/run/apache2
chown -R uvdesk:uvdesk /var/run/apache2
chmod -R 775 /var/run/apache2

# Fix Apache lock directory permissions
mkdir -p /var/lock/apache2
chown -R uvdesk:uvdesk /var/lock/apache2
chmod -R 775 /var/lock/apache2

# -----------------------------
# Start Apache in foreground
# -----------------------------
echo -e "${COLOR_GREEN}Starting Apache on port ${UV_APACHE_PORT:-80}...${COLOR_NC}"

# Replace Listen port in Apache config dynamically if needed
if [ ! -z "$UV_APACHE_PORT" ]; then
    sed -i "s/Listen 80/Listen $UV_APACHE_PORT/g" /etc/apache2/ports.conf
    sed -i "s/<VirtualHost \*:80>/<VirtualHost *:$UV_APACHE_PORT>/g" /etc/apache2/sites-available/000-default.conf
fi

# Run Apache as uvdesk user
exec gosu uvdesk apachectl -D FOREGROUND
