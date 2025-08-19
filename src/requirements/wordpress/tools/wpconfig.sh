#!/bin/bash

set -euo pipefail

WP_PATH="/var/www/wordpress"

# Wait for MariaDB to be reachable with the app user
until mariadb -h mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --silent -e 'SELECT 1;' >/dev/null 2>&1; do
    echo "⏳ Waiting for MariaDB to be ready..."
    sleep 2
done

echo "✅ MariaDB connection established!"

# Fix file permissions and ownership FIRST (after volume mount)
echo "🔧 Setting proper file permissions..."
chown -R www-data:www-data "$WP_PATH"
chmod -R 755 "$WP_PATH"
chmod -R 775 "$WP_PATH/wp-content"

# Create necessary directories with proper permissions
mkdir -p "$WP_PATH/wp-content/uploads" "$WP_PATH/wp-content/upgrade"
chown -R www-data:www-data "$WP_PATH/wp-content"
chmod -R 775 "$WP_PATH/wp-content"

echo "✅ File permissions set correctly!"

# Configure WordPress with wp-cli
if [ ! -f "$WP_PATH/wp-config.php" ]; then
  echo "⚙️  Creating wp-config.php..."
  wp config create --allow-root \
      --dbname="$MYSQL_DATABASE" \
      --dbuser="$MYSQL_USER" \
      --dbpass="$MYSQL_PASSWORD" \
      --dbhost="mariadb" \
      --path="$WP_PATH"
else
  echo "🛠  wp-config.php exists — updating DB constants..."
  wp config set DB_NAME "$MYSQL_DATABASE" --type=constant --allow-root --path="$WP_PATH"
  wp config set DB_USER "$MYSQL_USER" --type=constant --allow-root --path="$WP_PATH"
  wp config set DB_PASSWORD "$MYSQL_PASSWORD" --type=constant --allow-root --path="$WP_PATH"
  wp config set DB_HOST mariadb --type=constant --allow-root --path="$WP_PATH"
fi

# Add/ensure Redis constants with correct types
wp config set WP_CACHE true --raw --type=constant --allow-root --path="$WP_PATH"
wp config set WP_REDIS_HOST redis --type=constant --allow-root --path="$WP_PATH"
wp config set WP_REDIS_PORT 6379 --raw --type=constant --allow-root --path="$WP_PATH"

# Verify DB connectivity from WP side
if ! wp db check --allow-root --path="$WP_PATH" >/dev/null 2>&1; then
  echo "❌ WordPress cannot reach the database with current wp-config.php values."
  echo "   Check MYSQL_* env vars and DB user privileges, then restart."
  exit 1
fi

# Install core only if not already installed
echo "🚀 Installing WordPress core..."
if ! wp core is-installed --allow-root --path="$WP_PATH" >/dev/null 2>&1; then
  wp core install --allow-root \
      --url="$DOMAIN_NAME" \
      --title="$WP_TITLE" \
      --admin_user="$WP_ADMIN_NAME" \
      --admin_password="$WP_ADMIN_PASSWORD" \
      --admin_email="$WP_ADMIN_MAIL" \
      --skip-email \
      --path="$WP_PATH"
else
  echo "ℹ️  WordPress already installed. Skipping core install."
fi

# Create an additional user if missing
echo "👤 Creating additional user..."
if ! wp user get "$WP_USER_NAME" --field=ID --allow-root --path="$WP_PATH" >/dev/null 2>&1; then
  wp user create --allow-root \
      "$WP_USER_NAME" "$WP_USER_MAIL" \
      --user_pass="$WP_USER_PASSWORD" \
      --role=author \
      --path="$WP_PATH"
else
  echo "ℹ️  User $WP_USER_NAME already exists."
fi

# Install and enable Redis cache plugin (idempotent)
echo "🔄 Activating Redis cache plugin..."
wp plugin install redis-cache --activate --force --allow-root --path="$WP_PATH" || true
wp redis enable --allow-root --path="$WP_PATH" || true

# ✅ Fix PHP-FPM crash: make sure PID directory exists
echo "🚦 Starting PHP-FPM..."
mkdir -p /run/php
exec php-fpm7.4 -F
