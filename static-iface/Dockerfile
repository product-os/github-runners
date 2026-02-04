# alpine 3.20 includes networkmanager-cli 1.46.6-r0 which is close to the balenaOS version
FROM bash:alpine3.20

# hadolint ignore=DL3018
RUN apk add --no-cache \
    curl \
    jq \
    networkmanager-cli \
    iputils \
    bind-tools \
    docker-cli

COPY run.sh /run.sh
RUN chmod +x /run.sh

ENV ENABLED=true
ENV VERBOSE=false
ENV DBUS_SYSTEM_BUS_ADDRESS=unix:path=/host/run/dbus/system_bus_socket

CMD ["/run.sh"]
