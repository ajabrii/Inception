FROM debian:bullseye

RUN apt update && apt install -y vsftpd

RUN mkdir -p /var/run/vsftpd/empty

COPY conf/vsftpd.conf /etc/vsftpd.conf
COPY tools/start.sh /start.sh

RUN chmod 777 /start.sh

EXPOSE 21 21000-21010

CMD ["bash", "start.sh"]