FROM debian:bullseye

RUN apt update -y && apt install nginx -y

RUN mkdir -p /var/www/html

COPY ./site/ /var/www/html/

CMD ["nginx", "-g", "daemon off;"]
