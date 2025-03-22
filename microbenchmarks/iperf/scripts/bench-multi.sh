#!/bin/bash

# Runs iperf with different parameters. Does not vary number of threads and instead runs for 60 seconds.
# Usage: bench-multi.sh [server_cid] [server_port] [other iperf parameters except -t...]
# Run from inside the client docker container
# If server_cid is not set, will use the IPERF_SERVER_CID environment variable, which can be set via an argument for the client docker container.

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

echo "[C -> S] 4 parallel threads"
echo "Shell: Connecting to ${server_cid} port ${port}"
./iperf3 --vsock -c ${server_cid} -P 4 -t 60 -p ${port} ${@:3}
echo "Waiting for 10 Seconds to prevent overlapping"
sleep 10

echo "[S -> C] 4 parallel threads"
echo "Shell: Connecting to ${server_cid} port ${port}"
./iperf3 --vsock -c ${server_cid} -P 4 -R -t 60 -p ${port} ${@:3}
echo "Waiting for 10 Seconds for others to finish"
sleep 10
