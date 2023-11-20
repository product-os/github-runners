FROM alpine:3.18

# hadolint ignore=DL3018
RUN apk add --no-cache bash docker-cli flock

COPY monitor.sh /monitor.sh

RUN chmod +x /monitor.sh

CMD [ "/monitor.sh" ]
