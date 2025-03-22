#!/bin/sh

# start the proxy server
./proxy-tcp-2-vsock.sh || { echo "proxy-tcp-2-vsock.sh failed"; exit 1; }

# stay busy...
sleep infinity
