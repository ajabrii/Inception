#!/bin/bash

# Create mysql directories with proper permissions
# those are the run time direcortys needed for mariadb to store pid and socket
mkdir -p /var/run/mysqld /var/log/mysql
chown -R mysql:mysql /var/run/mysqld /var/log/mysql /var/lib/mysql

# Check if database is already initialized
# /var/lib/mysql/mysql -> is where mariadb store data (wodpress data)

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
mysql << EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

echo "Stopping temporary MariaDB..."
mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown
#--------------------------------------------------------------------------------------------
# run temp database intrence just to update the credintial via cli without remove the volumes
mysqld_safe --datadir='/var/lib/mysql' --user=mysql \
    --bind-address=0.0.0.0 \
    --port=3306 \
    --skip-networking=0 &

until mysqladmin ping >/dev/null 2>&1; do
    echo "Waiting for database connection..."
    sleep 2
done

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<EOF
ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
FLUSH PRIVILEGES;
EOF
echo "Stopping temporary MariaDB...(for .env update)"
mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown

#----------------------------------------------------------------------------------------------



echo "Starting MariaDB..."
exec mysqld_safe --datadir='/var/lib/mysql' --user=mysql \
    --bind-address=0.0.0.0 \
    --port=3306 \
    --skip-networking=0



