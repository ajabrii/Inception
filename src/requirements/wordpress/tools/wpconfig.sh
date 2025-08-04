# #!/bin/bash

# # Wait for MariaDB to be ready
# while ! mariadb -h mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --silent; do
#     echo "⏳ Waiting for MariaDB to be ready..."
#     sleep 2
# done

# echo "✅ MariaDB connection established!"

# # Configure WordPress with wp-cli
# echo "⚙️  Creating wp-config.php..."
# wp config create --allow-root \
#     --dbname="$MYSQL_DATABASE" \
#     --dbuser="$MYSQL_USER" \
#     --dbpass="$MYSQL_PASSWORD" \
#     --dbhost="mariadb" \
#     --path="/var/www/wordpress"

# echo "🚀 Installing WordPress core..."
# wp core install --allow-root \
#     --url="$DOMAIN_NAME" \
#     --title="$WP_TITLE" \
#     --admin_user="$WP_ADMIN_NAME" \
#     --admin_password="$WP_ADMIN_PASSWORD" \
#     --admin_email="$WP_ADMIN_MAIL" \
#     --skip-email \
#     --path="/var/www/wordpress"

# echo "👤 Creating additional user..."
# wp user create --allow-root \
#     "$WP_USER_NAME" "$WP_USER_MAIL" \
#     --user_pass="$WP_USER_PASSWORD" \
#     --role=author \
#     --path="/var/www/wordpress"

# echo "✅ WordPress setup complete!"

# # Start PHP-FPM in the foreground
# echo "🚦 Starting PHP-FPM..."
# exec php-fpm7.4 -F


#!/bin/bash
# Shebang - tells system to execute this script with bash

# Wait for MariaDB to be ready
while ! mariadb -h mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --silent; do
    # Loop until MariaDB connection succeeds
    # -h mariadb: connect to 'mariadb' container hostname
    # -u"$MYSQL_USER": database username from environment variable
    # -p"$MYSQL_PASSWORD": database password from environment variable
    # --silent: suppress output, only return exit code
    echo "⏳ Waiting for MariaDB to be ready..."
    sleep 2
    # Wait 2 seconds before retrying connection
done

echo "✅ MariaDB connection established!"

# Configure WordPress with wp-cli
echo "⚙️  Creating wp-config.php..."
wp config create --allow-root \
    # Create WordPress configuration file
    # --allow-root: run wp-cli as root user (required in containers)
    --dbname="$MYSQL_DATABASE" \
    # Database name from environment variable
    --dbuser="$MYSQL_USER" \
    # Database username from environment variable
    --dbpass="$MYSQL_PASSWORD" \
    # Database password from environment variable
    --dbhost="mariadb" \
    # Database host - container name in Docker network
    --path="/var/www/wordpress"
    # WordPress installation directory

echo "🚀 Installing WordPress core..."
wp core install --allow-root \
    # Install WordPress with initial configuration
    --url="$DOMAIN_NAME" \
    # Site URL from environment variable (should be https://ajabri.42.fr)
    --title="$WP_TITLE" \
    # Website title from environment variable
    --admin_user="$WP_ADMIN_NAME" \
    # Admin username from environment variable
    --admin_password="$WP_ADMIN_PASSWORD" \
    # Admin password from environment variable
    --admin_email="$WP_ADMIN_MAIL" \
    # Admin email from environment variable
    --skip-email \
    # Don't send installation email (useful for containers)
    --path="/var/www/wordpress"
    # WordPress installation directory

echo "👤 Creating additional user..."
wp user create --allow-root \
    # Create a second WordPress user (required by subject)
    "$WP_USER_NAME" "$WP_USER_MAIL" \
    # Username and email from environment variables
    --user_pass="$WP_USER_PASSWORD" \
    # User password from environment variable
    --role=author \
    # Set user role to 'author' (can create/edit their own posts)
    --path="/var/www/wordpress"
    # WordPress installation directory

echo "✅ WordPress setup complete!"

# ✅ Fix PHP-FPM crash: make sure PID directory exists
echo "🚦 Starting PHP-FPM..."
mkdir -p /run/php
# Create PID directory for PHP-FPM (prevents startup crashes)
exec php-fpm7.4 -F
# Start PHP-FPM in foreground mode (-F)
# exec replaces shell process, keeping container running
