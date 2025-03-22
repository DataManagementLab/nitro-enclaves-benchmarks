#!/bin/bash

variation=${1:-"sc"}  # s: server, c: client, b: both are varying in msg size

instance_type=$(ec2-metadata --instance-type | cut -d ' ' -f 2)
file_name="single_instance-$instance_type-$(date --utc +%FT%TZ | tr : _ | tr - _)-$(git rev-parse --short HEAD).csv"
export RESULT_FILE=$file_name

msg_sizes=""
for exp in $(seq 10 20); do
    msg_sizes="$msg_sizes $((2**exp))"
done
# Find the maximum value in msg_sizes - at least 1024
buf_size=$(echo $msg_sizes 1024 | tr ' ' '\n' | sort -n | tail -1)

n_runs=${n_runs:-10}
export TIMEOUT_SEC=${timeout_sec:-10}
export PRINT_HEADER=yes

for i in $(seq 1 "$n_runs"); do

    if [[ "$variation" == *"s"* ]]; then

        echo "[$(date +"%y-%m-%d-%H:%M:%S")] Run $i - host->enclave (vsock) with fix request size (8 byte)..."
        make run-enclave-server
        for msg_size in $msg_sizes; do
            make CLIENT_MSG_SIZE=8 CLIENT_BUF_SIZE=$buf_size SERVER_RSP_SIZE=$msg_size run-host-client2enclave
            export PRINT_HEADER=""
        done
        make terminate-enclave-server
        make upload-results

        echo "[$(date +"%y-%m-%d-%H:%M:%S")] Run $i - host->host (inet) with fix request size (8 byte)..."
        make run-host-server-background
        for msg_size in $msg_sizes; do
            make CLIENT_MSG_SIZE=8 CLIENT_BUF_SIZE=$buf_size SERVER_RSP_SIZE=$msg_size run-host-client2host
        done
        make terminate-host-server
        make upload-results

    fi

    if [[ "$variation" == *"c"* ]]; then

        echo "[$(date +"%y-%m-%d-%H:%M:%S")] Run $i - host->enclave (vsock) with fix response size (8 byte)..."
        make run-enclave-server
        for msg_size in $msg_sizes; do
            make CLIENT_MSG_SIZE=$msg_size SERVER_BUF_SIZE=$buf_size SERVER_RSP_SIZE=8 run-host-client2enclave
            export PRINT_HEADER=""
        done
        make terminate-enclave-server
        make upload-results

        echo "[$(date +"%y-%m-%d-%H:%M:%S")] Run $i - host->host (inet) with fix response size (8 byte)..."
        make run-host-server-background
        for msg_size in $msg_sizes; do
            make CLIENT_MSG_SIZE=$msg_size SERVER_BUF_SIZE=$buf_size SERVER_RSP_SIZE=8 run-host-client2host
        done
        make terminate-host-server
        make upload-results

    fi

    if [[ "$variation" == *"b"* ]]; then
    
        echo "[$(date +"%y-%m-%d-%H:%M:%S")] Run $i - host->enclave (vsock) with equal msg sizes..."
        make run-enclave-server
        for msg_size in $msg_sizes; do
            make CLIENT_BUF_SIZE=$buf_size SERVER_BUF_SIZE=$buf_size CLIENT_MSG_SIZE=$msg_size SERVER_RSP_SIZE=$msg_size run-host-client2enclave
            export PRINT_HEADER=""
        done
        make terminate-enclave-server
        make upload-results

        echo "[$(date +"%y-%m-%d-%H:%M:%S")] Run $i - host->host (inet) with equal msg sizes..."
        make run-host-server-background
        for msg_size in $msg_sizes; do
            make CLIENT_BUF_SIZE=$buf_size SERVER_BUF_SIZE=$buf_size CLIENT_MSG_SIZE=$msg_size SERVER_RSP_SIZE=$msg_size run-host-client2host
        done
        make terminate-host-server
        make upload-results

    fi
done

echo "Done."
