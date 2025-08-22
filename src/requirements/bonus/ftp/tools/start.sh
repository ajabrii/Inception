#!/bin/bash

useradd -m -d /var/www/wordpress $FTP_USR
echo "$FTP_USR:$FTP_PWD" | chpasswd

# Add FTP user to www-data group
usermod -aG www-data $FTP_USR

# Ensure wordpress files are owned by www-data
chown -R www-data:www-data /var/www/wordpress

# Group needs write perms
chmod -R 775 /var/www/wordpress

exec vsftpd /etc/vsftpd.conf