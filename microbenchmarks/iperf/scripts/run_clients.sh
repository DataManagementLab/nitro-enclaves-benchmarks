#!/bin/bash

# This script runs multiple clients on the host system. Run outside of docker containers/enclaves
# Usage: run_clients.sh <mode> <nr_clients>
# The first (mandatory) parameter of this script is the mode. There are two modes: 'enclaves' and 'servers'
#  enclaves: Each client started by this script will connect to a different enclave, starting with CID 15. All clients connect to the default port.
#  servers: Each client started by this script will connect to a different port, starting with port 5201. All clients connect to the same enclave with CID 15.
# The second (also mandatory) parameter of this script is the number of clients to start.

instance_type=$(ec2-metadata --instance-type | cut -d ' ' -f 2)

if [[ "$1" == "" ]];
then
    echo "Please configure 'enclaves' or 'servers' and the number of clients to start."
    exit -1
fi

if [[ "$2" == "" ]];
then
    echo "Please configure the number of clients to start."
    exit -1
fi

if [ "$1" = "enclaves" ];
then
    for (( i=1; i<$2; i++ ))
    do
        CID=$((15+$i-1))
        echo "Starting client $i connecting to CID $CID"
        docker run --rm --privileged --entrypoint=/app/build/src/bench-multi.sh iperf3-vsock:client $CID > multi-enclave-$instance_type-$2-c$i-$(date --utc +%FT%TZ).txt &
    done

    CID=$((15+$2-1))
    echo "Starting client $2 connecting to CID $CID"
    docker run --rm --privileged --entrypoint=/app/build/src/bench-multi.sh iperf3-vsock:client $CID | tee multi-enclave-$instance_type-$2-c$2-$(date --utc +%FT%TZ).txt
elif [ "$1" = "servers" ];
then
    for (( i=1; i<$2; i++ ))
    do
        port=$((5201+$i-1))
        echo "Statrting client $i connecting to port $port"
        docker run --rm --privileged --entrypoint=/app/build/src/bench-multi.sh iperf3-vsock:client 15 $port > multi-server-$instance_type-$2-c$i-$(date --utc +%FT%TZ).txt &
    done

    port=$((5201+$2-1))
    echo "Statrting client $2 connecting to port $port"
    docker run --rm --privileged --entrypoint=/app/build/src/bench-multi.sh iperf3-vsock:client 15 $port | tee multi-server-$instance_type-$2-c$2-$(date --utc +%FT%TZ).txt
else
    echo "Unknown mode! Configure 'enclaves' or 'servers'"
fi
