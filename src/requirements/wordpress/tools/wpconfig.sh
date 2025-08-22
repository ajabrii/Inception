#!/bin/bash
# Exit immediately if a command fails, if an unset variable is used, or if any part of a pipe fails
set -euo pipefail

WP_PATH="/var/www/wordpress"

# ⏳ Wait for MariaDB to be reachable with the app user
until mariadb -h mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --silent -e 'SELECT 1;' >/dev/null 2>&1; do
    echo "⏳ Waiting for MariaDB to be ready..."
    sleep 2
done
echo "✅ MariaDB connection established!"

# 🔧 Fix file permissions and ownership FIRST (after volume mount)
echo "🔧 Setting proper file permissions..."
chown -R www-data:www-data "$WP_PATH"
chmod -R 755 "$WP_PATH"
chmod -R 775 "$WP_PATH/wp-content"

# Create necessary directories with proper permissions
mkdir -p "$WP_PATH/wp-content/uploads" "$WP_PATH/wp-content/upgrade"
chown -R www-data:www-data "$WP_PATH/wp-content"
chmod -R 775 "$WP_PATH/wp-content"
echo "✅ File permissions set correctly!"

# ⚙️ Configure WordPress with wp-cli
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

# ✅ Verify DB connectivity from WP side
if ! wp db check --allow-root --path="$WP_PATH" >/dev/null 2>&1; then
  echo "❌ WordPress cannot reach the database with current wp-config.php values."
  echo "   Check MYSQL_* env vars and DB user privileges, then restart."
  exit 1
fi

# 🚀 Install core only if not already installed (and update existing install)
echo "🚀 Installing or updating WordPress core..."
if ! wp core is-installed --allow-root --path="$WP_PATH" >/dev/null 2>&1; then
  echo "⚙️  Running fresh WordPress install..."
  wp core install --allow-root \
      --url="$DOMAIN_NAME" \
      --title="$WP_TITLE" \
      --admin_user="$WP_ADMIN_NAME" \
      --admin_password="$WP_ADMIN_PASSWORD" \
      --admin_email="$WP_ADMIN_MAIL" \
      --skip-email \
      --path="$WP_PATH"
else
  echo "ℹ️  WordPress already installed — syncing with .env values."

  # Update site URL & title
  wp option update siteurl "$DOMAIN_NAME" --allow-root --path="$WP_PATH"
  wp option update home "$DOMAIN_NAME" --allow-root --path="$WP_PATH"
  wp option update blogname "$WP_TITLE" --allow-root --path="$WP_PATH"

  # Update admin credentials (if user exists)
  if wp user get "$WP_ADMIN_NAME" --field=ID --allow-root --path="$WP_PATH" >/dev/null 2>&1; then
    echo "🔑 Updating admin user credentials..."
    wp user update "$WP_ADMIN_NAME" \
        --user_pass="$WP_ADMIN_PASSWORD" \
        --user_email="$WP_ADMIN_MAIL" \
        --allow-root --path="$WP_PATH"
  else
    echo "⚠️ Admin user $WP_ADMIN_NAME not found, creating it..."
    wp user create "$WP_ADMIN_NAME" "$WP_ADMIN_MAIL" \
        --user_pass="$WP_ADMIN_PASSWORD" \
        --role=administrator \
        --allow-root --path="$WP_PATH"
  fi
fi
echo "✅ WordPress setup complete!"

# 👤 Create or update an additional user
echo "👤 Ensuring additional user exists and matches .env..."
if wp user get "$WP_USER_NAME" --field=ID --allow-root --path="$WP_PATH" >/dev/null 2>&1; then
  echo "ℹ️  User $WP_USER_NAME exists — updating credentials."
  wp user update "$WP_USER_NAME" \
        --user_pass="$WP_USER_PASSWORD" \
        --user_email="$WP_USER_MAIL" \
        --allow-root --path="$WP_PATH"
else
  echo "👤 Creating new user $WP_USER_NAME..."
  wp user create "$WP_USER_NAME" "$WP_USER_MAIL" \
      --user_pass="$WP_USER_PASSWORD" \
      --role=author \
      --allow-root --path="$WP_PATH"
fi  

# 🔄 Install and enable Redis cache plugin (idempotent)
echo "🔄 Activating Redis cache plugin..."
wp plugin install redis-cache --activate --force --allow-root --path="$WP_PATH" || true
wp redis enable --allow-root --path="$WP_PATH" || true

# 🚦 Fix PHP-FPM crash: make sure PID directory exists and start in foreground
echo "🚦 Starting PHP-FPM..."
mkdir -p /run/php
exec php-fpm7.4 -F
