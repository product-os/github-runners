FROM bash:alpine3.22

COPY run.sh /run.sh
RUN chmod +x /run.sh

ENV ENABLED=true
ENV VERBOSE=false
ENV DBUS_SYSTEM_BUS_ADDRESS=unix:path=/host/run/dbus/system_bus_socket

CMD ["/run.sh"]
