#!/bin/bash

# Runs iperf with different parameters. Alternative for bench.sh
# Usage: bench-size.sh [server_cid] [server_port]
# Run from inside the client docker container
# If server_cid is not set, will use the IPERF_SERVER_CID environment variable, which can be set via an argument for the client docker container.

threads="1 4 8"
sizes="64 128 256 512 1K 2K 4K 8K 16K 32K 64K 128K 256K 512K 1M"

if [[ "$1" != "" ]]; then
    server_cid="$1"
else
    server_cid=${IPERF_SERVER_CID}
fi

if [[ "$2" != "" ]]; then
    port="$2"
else
    port=5201
fi

for i in ${threads[@]}
do
    for l in ${sizes[@]}
    do
        echo "[C -> S] $i parallel threads length $l"
        ./iperf3 --vsock -Z -c ${server_cid} -P $i -t 10 -p ${port} -l $l -M 8000 -w 500M
    done
done
