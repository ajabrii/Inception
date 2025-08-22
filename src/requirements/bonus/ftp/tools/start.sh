#!/bin/bash

useradd -m -d /var/www/wordpress $FTP_USER
echo "$FTP_USER:$FTP_PASSWORD" | chpasswd

exec vsftpd /etc/vsftpd.conf