FROM debian:bullseye

RUN		apt update -y && apt-get install -y redis

COPY ./tools/redis.sh /tmp/redis.sh

EXPOSE 6379

CMD ["sh", "/tmp/redis.sh"]
