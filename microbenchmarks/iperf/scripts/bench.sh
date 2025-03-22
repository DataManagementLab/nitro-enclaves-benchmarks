#!/bin/bash

# Runs iperf with different parameters
# Usage: bench.sh [server_cid] [server_port] [other iperf parameters except -t...]
# Run from inside the client docker container
# If server_cid is not set, will use the IPERF_SERVER_CID environment variable, which can be set via an argument for the client docker container.

threads=("$(seq 1 8)" 16 32)

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
    echo "[C -> S] $i parallel threads"
    ./iperf3 --vsock -c ${server_cid} -P $i -t 30 -p ${port} ${@:3}
    echo "[S -> C] $i parallel threads"
    ./iperf3 --vsock -c ${server_cid} -P $i -R -t 30 -p ${port} ${@:3}
done
