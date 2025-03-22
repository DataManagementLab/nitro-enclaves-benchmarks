#!/bin/sh

VSOCK_TARGET_CID=${VSOCK_TARGET_CID:-3}
VSOCK_TARGET_PORT=${VSOCK_TARGET_PORT:-5005}

socat -u FILE:/data/config.yaml vsock-connect:$VSOCK_TARGET_CID:$VSOCK_TARGET_PORT
socat -u FILE:/data/redis-benchmark.csv vsock-connect:$VSOCK_TARGET_CID:$(expr $VSOCK_TARGET_PORT + 1)
