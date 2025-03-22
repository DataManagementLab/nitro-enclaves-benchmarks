#!/bin/bash

# Runs iperf with different parameters
# Usage: bench.sh [server_addr] [server_port] [other iperf parameters except -t...]
# Run from inside the client docker container
# If server_addr is not set, will use the IPERF_SERVER_IPADDR environment variable, which can be set via an argument for the client docker container.

server_addr=${1:-$IPERF_SERVER_IPADDR}
port=${2:-5201}

threads="1 4 8"
sizes="64 128 256 512 1K 2K 4K 8K 16K 32K 64K 128K 256K 512K 1M"

for i in ${threads[@]}
do
    for l in ${sizes[@]}
    do
        echo "[C -> S] $i parallel threads length $l"
        ./iperf3 -Z -c ${server_addr} -P $i -t 10 -p ${port} -l $l -M 8000
    done
done
