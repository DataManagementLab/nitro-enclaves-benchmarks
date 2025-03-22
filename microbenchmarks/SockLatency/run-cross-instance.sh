#!/bin/bash

target_host=${1:-"127.0.0.1"}
scenario=${2:-"single_instance_proxy"}
variation=${3:-"s"}  # s: server, c: client, b: both varying in size

instance_type=$(ec2-metadata --instance-type | cut -d ' ' -f 2)
file_name="$scenario-$instance_type-$(date --utc +%FT%TZ | tr : _ | tr - _)-$(git rev-parse --short HEAD).csv"
export RESULT_FILE=$file_name

msg_sizes=""
for exp in $(seq 5 20); do
    msg_sizes="$msg_sizes $((2**exp))"
done
# Find the maximum value in msg_sizes - at least 1024
buf_size=$(echo "$msg_sizes 1024" | tr ' ' '\n' | sort -n | tail -1)

n_runs=${n_runs:-10}
export TIMEOUT_SEC=${timeout_sec:-10}
export PRINT_HEADER=yes
export CLIENT_TARGET_ADDR=$target_host

for i in $(seq 1 "$n_runs"); do

    if [[ "$variation" == *"s"* ]]; then

        echo "[$(date +"%y-%m-%d-%H:%M:%S")] Run $i - fix request size (8 byte)..."
        for msg_size in $msg_sizes; do
            make CLIENT_MSG_SIZE=8 CLIENT_BUF_SIZE=$buf_size SERVER_RSP_SIZE=$msg_size run-host-client2host
            export PRINT_HEADER=""
        done
        make upload-results

    fi

    if [[ "$variation" == *"c"* ]]; then

        echo "[$(date +"%y-%m-%d-%H:%M:%S")] Run $i - fix response size (8 byte)..."
        for msg_size in $msg_sizes; do
            make CLIENT_MSG_SIZE=$msg_size SERVER_BUF_SIZE=$buf_size SERVER_RSP_SIZE=8 run-host-client2host
            export PRINT_HEADER=""
        done
        make upload-results

    fi

    if [[ "$variation" == *"b"* ]]; then

        echo "[$(date +"%y-%m-%d-%H:%M:%S")] Run $i - equal msg sizes 4 client & server..."
        for msg_size in $msg_sizes; do
            make CLIENT_MSG_SIZE=$msg_size SERVER_RSP_SIZE=$msg_size CLIENT_BUF_SIZE=$buf_size SERVER_BUF_SIZE=$buf_size run-host-client2host
            export PRINT_HEADER=""
        done
        make upload-results

    fi
done

echo "Done."
