#!/bin/sh

VSOCK_TARGET_PORT=${VSOCK_TARGET_PORT:-5005}

# receive the results
socat vsock-listen:$VSOCK_TARGET_PORT,reuseaddr - > /data/config.yaml &
socat vsock-listen:$(expr $VSOCK_TARGET_PORT + 1),reuseaddr - > /data/redis-benchmark.csv
