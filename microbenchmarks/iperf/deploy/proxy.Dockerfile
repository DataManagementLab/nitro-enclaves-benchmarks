FROM alpine:latest

RUN apk add --no-cache socat

WORKDIR /scripts
COPY ./scripts/run_proxies.sh run_proxies.sh

RUN chmod +x run_proxies.sh

CMD ./run_proxies.sh
