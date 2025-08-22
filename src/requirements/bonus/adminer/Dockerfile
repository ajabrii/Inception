
FROM debian:bullseye

# Install PHP + extensions + mariadb client
RUN apt-get update && apt-get install -y \
    php php-cli php-mysql curl less mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Working directory for Adminer
WORKDIR /var/www/html

# Download Adminer and set as index.php
RUN curl -L -o index.php https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1.php

# Run as the existing www-data user (UID 33 in Debian)
USER www-data

# Document exposed port
EXPOSE 8080

# Start PHP built-in server
CMD ["php", "-S", "0.0.0.0:8080", "-t", "/var/www/html"]
