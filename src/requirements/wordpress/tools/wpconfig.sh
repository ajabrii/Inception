#!/bin/bash

while ! mariadb -h mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --silent; do
    echo "⏳ Waiting for MariaDB to be ready..."
    sleep 2
done

echo "✅ MariaDB connection established!"

# Fix file permissions and ownership FIRST (after volume mount)
echo "🔧 Setting proper file permissions..."
chown -R www-data:www-data /var/www/wordpress
chmod -R 755 /var/www/wordpress
chmod -R 775 /var/www/wordpress/wp-content

# Create necessary directories with proper permissions
mkdir -p /var/www/wordpress/wp-content/uploads
mkdir -p /var/www/wordpress/wp-content/upgrade
chown -R www-data:www-data /var/www/wordpress/wp-content
chmod -R 775 /var/www/wordpress/wp-content

echo "✅ File permissions set correctly!"

# Configure WordPress with wp-cli
echo "⚙️  Creating wp-config.php..."
wp config create --allow-root \
    --dbname="$MYSQL_DATABASE" \
    --dbuser="$MYSQL_USER" \
    --dbpass="$MYSQL_PASSWORD" \
    --dbhost="mariadb" \
    --path="/var/www/wordpress"

echo "🚀 Installing WordPress core..."
wp core install --allow-root \
    --url="$DOMAIN_NAME" \
    --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN_NAME" \
    --admin_password="$WP_ADMIN_PASSWORD" \
    --admin_email="$WP_ADMIN_MAIL" \
    --skip-email \
    --path="/var/www/wordpress"

echo "👤 Creating additional user..."
wp user create --allow-root \
    "$WP_USER_NAME" "$WP_USER_MAIL" \
    --user_pass="$WP_USER_PASSWORD" \
    --role=author \
    --path="/var/www/wordpress"

echo "✅ WordPress setup complete!"

# ✅ Fix PHP-FPM crash: make sure PID directory exists
echo "🚦 Starting PHP-FPM..."
mkdir -p /run/php
exec php-fpm7.4 -F
