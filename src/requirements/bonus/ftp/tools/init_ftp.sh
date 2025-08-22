
#!/bin/sh

# Ensure WordPress directory exists
mkdir -p /var/www/wordpress

# Backup and replace vsftpd.conf only on first run
if [ ! -f "/etc/vsftpd/vsftpd.conf.bak" ]; then
    echo "First time setup for vsftpd"
    cp /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bak
    mv /tmp/vsftpd.conf /etc/vsftpd/vsftpd.conf
fi

# Add or update FTP user every startup
if id "$FTP_USR" >/dev/null 2>&1; then
    echo "Updating FTP user $FTP_USR password..."
    echo "$FTP_USR:$FTP_PWD" | /usr/sbin/chpasswd
else
    echo "Creating FTP user $FTP_USR..."
    adduser --disabled-password --gecos "" $FTP_USR
    echo "$FTP_USR:$FTP_PWD" | /usr/sbin/chpasswd
fi

# Ensure FTP user owns WordPress files and has correct permissions
chown -R $FTP_USR:$FTP_USR /var/www/wordpress
usermod -aG www:data $FTP_USER
chmod -R 775 /var/www/wordpress

# Add/update FTP user in allowed user list
grep -qx "$FTP_USR" /etc/vsftpd.userlist || echo "$FTP_USR" >> /etc/vsftpd.userlist

echo "Starting FTP server on port 21..."
/usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf
