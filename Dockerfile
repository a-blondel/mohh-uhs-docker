FROM debian:12.7-slim

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends wine wine32 systemd procps && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY ./bin /var/www/mohh-uhs
COPY ./start_uhs_instances.sh /var/www/mohh-uhs/start_uhs_instances.sh
COPY ./mohh-uhs.service /etc/systemd/system/mohh-uhs.service
COPY ./mohh-uhs.timer /etc/systemd/system/mohh-uhs.timer

RUN mkdir -p /var/log/mohh-uhs && \
    touch /var/log/mohh-uhs/mohz.log && \
    chmod +x /var/www/mohh-uhs/start_uhs_instances.sh && \
    systemctl enable mohh-uhs.timer

VOLUME /var/www/mohh-uhs/maplist.txt
ENTRYPOINT ["/lib/systemd/systemd"]
