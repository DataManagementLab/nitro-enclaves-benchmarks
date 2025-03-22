#!/bin/sh

# ensure network is set up correctly
ip addr add 127.0.0.1/32 dev lo
ip link set dev lo up

# ensure the data directory exists
mkdir -p /data

# Setup socket proxy and exit if it fails
PROXY_ROUTE=${PROXY_ROUTE:-tcp-2-vsock}
./proxy-$PROXY_ROUTE.sh &> /data/proxy.log.txt || { echo "proxy-$PROXY_ROUTE.sh failed"; exit 1; }

# run the benchmark
./benchmark.sh
