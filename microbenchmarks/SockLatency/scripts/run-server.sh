#!/bin/bash

# This script is used to run the server side of the sock-latency microbenchmark.
cd /app || exit
CMD="./server --protocol=$PROTOCOL --address=$ADDRESS"

# Conditionally append optional config flags and numactl
test -n "$PORT"      && CMD="$CMD --port=$PORT"
test -n "$BUF_SIZE"  && CMD="$CMD --buf_size=$BUF_SIZE"
test -n "$PIN_CPU"   && CMD="numactl -C $PIN_CPU $CMD"

echo "Running server with command: $CMD"

# Execute the command
eval "$CMD"
