#!/bin/sh

if [ ! -f "/etc/redis/redis.conf.bak" ]; then

    cp /etc/redis/redis.conf /etc/redis/redis.conf.bak #We create the .bak to notify the program if it exists, don't go to the loop anymore

    sed -i "s|bind 127.0.0.1|#bind 127.0.0.1|g" /etc/redis/redis.conf # comment bind 127.0.0.1 so redis can listen on all interfaces
    sed -i "s|# maxmemory <bytes>|maxmemory 2mb|g" /etc/redis/redis.conf # set maxmemory to 2mb | default has no limit
    sed -i "s|# maxmemory-policy noeviction|maxmemory-policy allkeys-lru|g" /etc/redis/redis.conf # set maxmemory-policy to allkeys-lru | default is noeviction i change it because if i keep it and i hip maxmemory redis will return error telling me no but if i change it i will remove the lest used keys

fi

redis-server --protected-mode no
