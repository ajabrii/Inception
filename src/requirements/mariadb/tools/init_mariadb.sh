#!/bin/bash

# Create mysql directories with proper permissions
mkdir -p /var/run/mysqld /var/log/mysql
chown -R mysql:mysql /var/run/mysqld /var/log/mysql /var/lib/mysql

# Check if database is already initialized
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing database..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql --auth-root-authentication-method=normal
fi

echo "Starting temporary MariaDB for setup..."
mysqld_safe --datadir='/var/lib/mysql' --user=mysql \
    --bind-address=0.0.0.0 \
    --port=3306 \
    --skip-networking=0 &

# Wait for MariaDB to be ready
until mysqladmin ping >/dev/null 2>&1; do
    echo "Waiting for database connection..."
    sleep 2
done

# Setup database and users
echo "Setting up database..."

# Check if this is first-time initialization
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "First-time database initialization..."
    mysql << EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF
    WORKING_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}"
else
    echo "Existing database - checking passwords..."
    WORKING_ROOT_PASSWORD=""
    
    # Try current root password from .env first
    if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
        echo "Root password is current - updating user password..."
        WORKING_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}"
        mysql -u root -p"${MYSQL_ROOT_PASSWORD}" << EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF
    else
        echo "Root password changed - trying fallback passwords..."
        # Try common previous passwords
        for old_pass in "root_pass1" "root_pass" "root" ""; do
            echo "Trying with password: '$old_pass'"
            if mysql -u root -p"$old_pass" -e "SELECT 1;" >/dev/null 2>&1; then
                echo "Connected with old password - updating both passwords..."
                WORKING_ROOT_PASSWORD="$old_pass"
                mysql -u root -p"$old_pass" << EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF
                WORKING_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}"  # Update to new password
                break
            fi
        done
        
        # If no password worked, kill existing processes and start fresh
        if [ -z "$WORKING_ROOT_PASSWORD" ]; then
            echo "ERROR: Could not connect with any password."
            echo "Killing existing MariaDB processes and starting fresh..."
            pkill -f mysqld || true
            sleep 2
            exec mysqld_safe --datadir='/var/lib/mysql' --user=mysql \
                --bind-address=0.0.0.0 \
                --port=3306 \
                --skip-networking=0 \
                --skip-grant-tables
        fi
    fi
fi

echo "Stopping temporary MariaDB..."
# Use the working password for shutdown, or force kill if needed
if [ -n "$WORKING_ROOT_PASSWORD" ]; then
    mysqladmin -u root -p"$WORKING_ROOT_PASSWORD" shutdown 2>/dev/null || pkill -f mysqld
else
    pkill -f mysqld || true
fi
sleep 2

echo "Starting MariaDB..."
exec mysqld_safe --datadir='/var/lib/mysql' --user=mysql \
    --bind-address=0.0.0.0 \
    --port=3306 \
    --skip-networking=0
