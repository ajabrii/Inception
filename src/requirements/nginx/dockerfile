FROM	debian:bullseye

RUN		apt update -y && \
			apt install  -y nginx openssl && \
			mkdir -p /etc/nginx/ssl

RUN 	openssl req -x509 -nodes \
			-keyout /etc/nginx/ssl/inception.key \
			-out /etc/nginx/ssl/inception.crt \
			-subj "/C=FR/ST=IDF/L=1337/O=42/OU=42/CN=UserName.42.fr/UID=UserName"

COPY	conf/nginx.conf /etc/nginx/nginx.conf


CMD		["nginx", "-g", "daemon off;"]