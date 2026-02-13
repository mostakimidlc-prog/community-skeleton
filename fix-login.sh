#!/bin/bash

# UVDesk Login Issue Diagnosis and Fix Script

set -e

echo "=========================================="
echo "UVDesk Login Issue Diagnostic"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_question() {
    echo -e "${BLUE}[QUESTION]${NC} $1"
}

# Step 1: Check if database tables exist
echo ""
print_info "Step 1: Checking database tables..."
echo ""

DB_TABLES=$(docker exec -it uvdesk-db mysql -u uvdesk -puvdesk_password uvdesk -e "SHOW TABLES;" 2>/dev/null | wc -l)

if [ "$DB_TABLES" -lt 5 ]; then
    print_error "Database tables are missing or incomplete!"
    echo "  Found: $DB_TABLES tables"
    echo "  Expected: 30+ tables"
    echo ""
    print_warning "The installation may not have completed successfully."
    echo ""
    print_question "Do you want to see the existing tables?"
    read -p "(yes/no): " show_tables
    
    if [ "$show_tables" = "yes" ]; then
        docker exec -it uvdesk-db mysql -u uvdesk -puvdesk_password uvdesk -e "SHOW TABLES;"
    fi
    
    echo ""
    print_warning "You may need to:"
    echo "  1. Drop the database and reinstall"
    echo "  2. Or manually run schema migrations"
    echo ""
    read -p "Do you want to reset the database and reinstall? (yes/no): " reset_db
    
    if [ "$reset_db" = "yes" ]; then
        print_warning "Resetting database..."
        docker exec -it uvdesk-db mysql -u root -proot_password -e "DROP DATABASE IF EXISTS uvdesk; CREATE DATABASE uvdesk;"
        print_info "Database reset complete!"
        print_info "Please visit http://localhost:8082 to run the installation wizard again"
        exit 0
    fi
else
    print_info "✓ Database tables exist (Found: $DB_TABLES tables)"
fi

# Step 2: Check if admin user exists
echo ""
print_info "Step 2: Checking for admin users..."
echo ""

ADMIN_COUNT=$(docker exec -it uvdesk-db mysql -u uvdesk -puvdesk_password uvdesk -e "SELECT COUNT(*) as count FROM uv_user WHERE id = 1;" 2>/dev/null | tail -1 | tr -d '\r')

if [ "$ADMIN_COUNT" -lt 1 ]; then
    print_error "No admin user found in database!"
    echo ""
    print_warning "The installation wizard may not have created the admin user."
    echo ""
    print_question "What would you like to do?"
    echo "  1) Create admin user manually"
    echo "  2) Reset database and reinstall"
    echo "  3) Skip"
    read -p "Enter choice [1-3]: " user_choice
    
    case $user_choice in
        1)
            echo ""
            print_info "Creating admin user manually..."
            read -p "Enter admin email: " admin_email
            read -sp "Enter admin password: " admin_password
            echo ""
            
            # Hash password (UVDesk uses bcrypt, but we'll use a simple approach for now)
            print_info "Creating user in database..."
            
            docker exec -it uvdesk-app gosu uvdesk php bin/console uvdesk:create-user \
                --email="$admin_email" \
                --password="$admin_password" \
                --role="ROLE_ADMIN" 2>/dev/null || \
            print_error "Failed to create user via console command. You may need to create it through the web interface."
            ;;
        2)
            print_warning "Resetting database..."
            docker exec -it uvdesk-db mysql -u root -proot_password -e "DROP DATABASE IF EXISTS uvdesk; CREATE DATABASE uvdesk;"
            print_info "Database reset complete!"
            print_info "Please visit http://localhost:8082 to run the installation wizard again"
            exit 0
            ;;
        *)
            print_info "Skipping user creation"
            ;;
    esac
else
    print_info "✓ Admin user exists in database"
    
    # Show user details
    echo ""
    print_info "Checking user details..."
    docker exec -it uvdesk-db mysql -u uvdesk -puvdesk_password uvdesk -e "SELECT id, email, isEnabled FROM uv_user LIMIT 5;" 2>/dev/null || print_warning "Could not fetch user details"
fi

# Step 3: Check session configuration
echo ""
print_info "Step 3: Checking session configuration..."
echo ""

SESSION_DRIVER=$(docker exec -it uvdesk-app grep "SESSION_DRIVER" /var/www/uvdesk/.env 2>/dev/null | cut -d'=' -f2 | tr -d '\r\n ')

if [ -z "$SESSION_DRIVER" ]; then
    print_error "SESSION_DRIVER not configured!"
else
    print_info "✓ Session driver: $SESSION_DRIVER"
fi

# Step 4: Check if cache needs clearing
echo ""
print_info "Step 4: Clearing cache and sessions..."
docker exec -it uvdesk-app gosu uvdesk php bin/console cache:clear 2>/dev/null || print_warning "Cache clear failed"
docker exec -it uvdesk-app rm -rf /var/www/uvdesk/var/cache/* 2>/dev/null || true
docker exec -it uvdesk-app rm -rf /var/www/uvdesk/var/sessions/* 2>/dev/null || true
print_info "✓ Cache and sessions cleared"

# Step 5: Check .env file
echo ""
print_info "Step 5: Checking .env configuration..."
echo ""

if docker exec -it uvdesk-app test -f /var/www/uvdesk/.env; then
    print_info "✓ .env file exists"
    
    # Check critical settings
    print_info "Checking critical settings:"
    docker exec -it uvdesk-app bash -c "grep -E '(APP_ENV|APP_SECRET|DATABASE_URL|SESSION_DRIVER)' /var/www/uvdesk/.env" 2>/dev/null || print_warning "Could not read .env file"
else
    print_error ".env file missing!"
fi

# Step 6: Check Apache/PHP logs for errors
echo ""
print_info "Step 6: Checking for recent errors in logs..."
echo ""

print_info "Recent Apache errors:"
docker exec -it uvdesk-app tail -n 20 /var/log/apache2/error.log 2>/dev/null | grep -i "error\|fatal\|exception" || print_info "No recent errors found"

# Step 7: Test login functionality
echo ""
print_info "Step 7: Testing login route..."
echo ""

LOGIN_TEST=$(docker exec -it uvdesk-app gosu uvdesk php bin/console debug:router | grep login || echo "not found")
if [ "$LOGIN_TEST" = "not found" ]; then
    print_error "Login route not found in router!"
    print_warning "This suggests routes may not be properly loaded"
else
    print_info "✓ Login route exists"
fi

# Step 8: Recommendations
echo ""
echo "=========================================="
echo "Diagnostic Summary & Recommendations"
echo "=========================================="
echo ""

print_info "Common login issues and solutions:"
echo ""
echo "1. Wrong credentials:"
echo "   - Make sure you're using the email and password you set during installation"
echo "   - Email is case-sensitive"
echo ""
echo "2. Session issues:"
echo "   - Clear browser cookies for localhost:8082"
echo "   - Try incognito/private browsing mode"
echo "   - Check SESSION_DRIVER in docker-compose.yml (should be 'file' initially)"
echo ""
echo "3. CSRF token issues:"
echo "   - Clear application cache: docker exec -it uvdesk-app gosu uvdesk php bin/console cache:clear"
echo "   - Restart application: docker-compose restart app"
echo ""
echo "4. Database schema incomplete:"
echo "   - Reset database and run installation wizard again"
echo ""

print_question "What error do you see when trying to login?"
echo "a) 'Invalid credentials'"
echo "b) 'An error occurred' or blank page"
echo "c) Redirects back to login page"
echo "d) Other error message"
echo ""
read -p "Enter choice [a-d]: " error_type

case $error_type in
    a)
        echo ""
        print_info "For 'Invalid credentials' error:"
        echo "1. Verify you're using the correct email (check database):"
        echo "   docker exec -it uvdesk-db mysql -u uvdesk -puvdesk_password uvdesk -e \"SELECT email FROM uv_user;\""
        echo ""
        echo "2. Reset your password via database (if needed)"
        echo "3. Check if user is enabled:"
        echo "   docker exec -it uvdesk-db mysql -u uvdesk -puvdesk_password uvdesk -e \"UPDATE uv_user SET isEnabled=1 WHERE id=1;\""
        ;;
    b)
        echo ""
        print_info "For errors or blank page:"
        echo "1. Check PHP error logs:"
        echo "   docker-compose logs app | tail -50"
        echo ""
        echo "2. Enable debug mode (if not already):"
        echo "   Check APP_DEBUG=true in docker-compose.yml"
        echo ""
        echo "3. Clear cache completely:"
        echo "   docker exec -it uvdesk-app rm -rf /var/www/uvdesk/var/cache/*"
        echo "   docker-compose restart app"
        ;;
    c)
        echo ""
        print_info "For redirect loop:"
        echo "1. Clear browser cookies completely"
        echo "2. Clear application sessions:"
        echo "   docker exec -it uvdesk-app rm -rf /var/www/uvdesk/var/sessions/*"
        echo "3. Restart application:"
        echo "   docker-compose restart app"
        ;;
    *)
        echo ""
        print_info "For other errors:"
        echo "1. Check the full error message"
        echo "2. Look in application logs:"
        echo "   docker-compose logs app"
        echo "3. Check var/log directory:"
        echo "   docker exec -it uvdesk-app ls -la /var/www/uvdesk/var/log/"
        ;;
esac

echo ""
print_info "Restart application to apply all changes:"
echo "  docker-compose restart app"
echo ""
