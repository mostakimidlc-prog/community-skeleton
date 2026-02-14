# UVDesk Installation & Troubleshooting Guide

## Current Issues

### 1. Broken CSS (Assets Not Loading)
**Symptoms:**
- Login page appears but without styling
- Images/icons not loading
- Form looks plain HTML

**Causes:**
- Assets not compiled/built
- Wrong DocumentRoot in Apache
- Missing public/build or public/assets directories

### 2. Login Not Working
**Causes:**
- Database not initialized (empty tables)
- UVDesk not installed yet
- CSRF token issues

---

## Quick Fixes

### Fix 1: Check if UVDesk is Installed

```bash
# Check if database has tables
docker exec uvdesk-app mysql -h db -u uvdesk -puvdesk_password uvdesk -e "SHOW TABLES;"
```

**If empty/no tables:** UVDesk is NOT installed yet. You need to run the installer.

---

### Fix 2: Access UVDesk Web Installer

UVDesk has a web-based installation wizard:

```
http://localhost:8082/en/install
```

Or try:
```
http://localhost:8082/install.php
http://localhost:8082/wizard
http://localhost:8082/setup
```

**Installation Steps:**
1. Open browser: http://localhost:8082/en/install
2. Enter database credentials:
   - Host: `db`
   - Database: `uvdesk`
   - Username: `uvdesk`
   - Password: `uvdesk_password` (or `uvdesk123` if you kept the original)
3. Create admin account
4. Complete setup

---

### Fix 3: Manual Database Installation (If Web Installer Fails)

```bash
# Enter the container
docker exec -it uvdesk-app bash

# Run migrations (if available)
cd /var/www/uvdesk
php bin/console doctrine:migrations:migrate --no-interaction

# Or run schema update
php bin/console doctrine:schema:update --force

# Create admin user (if command exists)
php bin/console uvdesk:create-admin

# Exit container
exit
```

---

### Fix 4: Build Assets

```bash
# Check if assets directory exists
docker exec uvdesk-app ls -la /var/www/uvdesk/public/

# Install assets (Symfony)
docker exec uvdesk-app bash -c "cd /var/www/uvdesk && php bin/console assets:install public --symlink"

# If using npm/yarn for assets
docker exec uvdesk-app bash -c "cd /var/www/uvdesk && npm install && npm run build"

# Restart to apply changes
docker-compose restart app
```

---

### Fix 5: Check Apache Configuration

```bash
# Check DocumentRoot
docker exec uvdesk-app cat /etc/apache2/sites-available/000-default.conf | grep DocumentRoot

# Should be: DocumentRoot /var/www/uvdesk/public
```

If DocumentRoot is wrong, update it:

```bash
docker exec uvdesk-app sed -i 's|DocumentRoot.*|DocumentRoot /var/www/uvdesk/public|g' /etc/apache2/sites-available/000-default.conf
docker-compose restart app
```

---

### Fix 6: Check Directory Structure

The correct structure should be:
```
/var/www/uvdesk/
├── bin/
│   └── console
├── config/
├── public/
│   ├── index.php
│   ├── bundles/        <- Symfony assets
│   ├── build/          <- Compiled assets (if using Encore)
│   └── assets/         <- Static assets
├── src/
├── var/
│   ├── cache/
│   └── log/
└── vendor/
    └── autoload.php
```

Check if everything exists:
```bash
docker exec uvdesk-app ls -la /var/www/uvdesk/public/
docker exec uvdesk-app ls -la /var/www/uvdesk/vendor/
```

---

## Common Error Solutions

### Error: "Failed to open stream: No such file or directory"
**Solution:** Run composer install
```bash
docker exec uvdesk-app bash -c "cd /var/www/uvdesk && composer install"
```

### Error: "No route found"
**Solution:** Clear cache
```bash
docker exec uvdesk-app rm -rf /var/www/uvdesk/var/cache/*
docker-compose restart app
```

### Error: "SQLSTATE[HY000] [2002] Connection refused"
**Solution:** Database credentials mismatch
```bash
# Update .env file in container
docker exec uvdesk-app nano /var/www/uvdesk/.env
# Or rebuild with correct environment variables
```

### CSS Still Not Loading
**Solution:** Check browser console (F12) to see exact 404 errors for missing files

---

## Rebuild Container with Fresh Install

If all else fails:

```bash
# 1. Stop and remove everything
docker-compose down -v

# 2. Remove volumes to start fresh
docker volume ls | grep uvdesk
docker volume rm <volume_name>

# 3. Start fresh
docker-compose up -d

# 4. Access installer
# Open: http://localhost:8082/en/install
```

---

## Database Credentials Reference

**From docker-compose.yml:**
- Host: `db`
- Database: `uvdesk`
- Username: `uvdesk`
- Password: `uvdesk_password`

**From .env file in container:**
- Password might be: `uvdesk123`

**Make sure these match!**

---

## Testing URLs

Try accessing these URLs to find the installer:

1. http://localhost:8082
2. http://localhost:8082/en/install
3. http://localhost:8082/install
4. http://localhost:8082/setup
5. http://localhost:8082/public/index.php
6. http://localhost:8082/index.php

---

## Final Checklist

- [ ] Database is running and accessible
- [ ] vendor/ directory exists in container
- [ ] public/index.php exists
- [ ] Apache DocumentRoot points to /var/www/uvdesk/public
- [ ] Database credentials match between docker-compose and .env
- [ ] UVDesk installation completed (database has tables)
- [ ] Assets are installed/built
- [ ] Permissions are correct (775 for var/, public/)
