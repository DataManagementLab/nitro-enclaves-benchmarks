#!/bin/sh

ip addr add 127.0.0.1/32 dev lo
ip link set dev lo up

# Setup socket proxy and exit if it fails
PROXY_ROUTE=${PROXY_ROUTE:-vsock-2-tcp}
./proxy-$PROXY_ROUTE.sh || { echo "proxy-$PROXY_ROUTE.sh failed"; exit 1; }

./server.sh
