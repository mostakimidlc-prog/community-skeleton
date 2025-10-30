#!/bin/bash

# Restart apache & mysql server
service apache2 restart
service mysql restart

# Create necessary directories with correct permissions
mkdir -p /var/www/uvdesk/var
mkdir -p /var/www/uvdesk/public/uploads
chown -R uvdesk:uvdesk /var/www/uvdesk
chmod -R 775 /var/www/uvdesk/var /var/www/uvdesk/public/uploads

# Wait for MySQL
until mysqladmin ping -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" --silent; do
  echo "Waiting for MySQL..."
  sleep 2
done

# Run any database setup if variables are defined
if [[ ! -z "$MYSQL_USER" && ! -z "$MYSQL_PASSWORD" && ! -z "$MYSQL_DATABASE" ]]; then
  mysql -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE;"
fi

# Step down to uvdesk user
exec gosu uvdesk "$@"
