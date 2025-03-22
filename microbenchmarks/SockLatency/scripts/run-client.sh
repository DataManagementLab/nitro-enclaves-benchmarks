#!/bin/bash

# Set default out to "/data/results.csv"
RESULT_DIR=${RESULT_DIR:-/data}
RESULT_NAME=${RESULT_NAME:-results.csv}
out=$RESULT_DIR/$RESULT_NAME

# This script is used to run the client side of the sock-latency microbenchmark.
cd /app || exit
CMD="./client --protocol=$PROTOCOL --address=$ADDRESS --outfile=$out"

# Conditionally append optional config flags and numactl
test -n "$PORT"              && CMD="$CMD --port=$PORT"
test -n "$PRINT_HEADER"      || CMD="$CMD --print_header=false"  # default is true
test -n "$BUF_SIZE"          && CMD="$CMD --buf_size=$BUF_SIZE"
test -n "$MSG_SIZE"          && CMD="$CMD --msg_size=$MSG_SIZE"
test -n "$SERVER_BUF_SIZE"   && CMD="$CMD --server_buf_size=$SERVER_BUF_SIZE"
test -n "$SERVER_RSP_SIZE"   && CMD="$CMD --server_rsp_size=$SERVER_RSP_SIZE"
test -n "$NUM_SAMPLES"       && CMD="$CMD --num_samples=$NUM_SAMPLES"
test -n "$NUM_WARMUP_ROUNDS" && CMD="$CMD --num_warmup_rounds=$NUM_WARMUP_ROUNDS"
test -n "$TIMEOUT_SEC"       && CMD="$CMD --timeout_sec=$TIMEOUT_SEC"
test -n "$PIN_CPU"           && CMD="numactl -C $PIN_CPU $CMD"

echo "Running client with command: $CMD"

# Execute the command
eval "$CMD"
