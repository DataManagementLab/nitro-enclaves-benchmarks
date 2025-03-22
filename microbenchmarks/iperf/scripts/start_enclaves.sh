#!/bin/bash

# starts as many enclaves as given by the first argument. Default 2. CIDs are 15 and following.
# Run outside of docker containers/enclaves

if [[ "$1" != "" ]]; then
    servers="$1"
else
    servers=2
fi

if [[ "$2" != "" ]]; then
    vcpus="$2"
else
    vcpus=2
fi

if [[ "$3" != "" ]]; then
    memory="$3"
else
    memory=2048
fi

echo "Starting $servers iperf3 enclaves with $vcpus vCPUs and $memory MB memory!"

for (( i=0; i<$servers; i++ ))
do
    cid=$((15+$i))
    echo "Starting enclave with CID $cid"
    nitro-cli run-enclave --enclave-name server-$i --enclave-cid $cid --eif-path enclave-server.eif --cpu-count $vcpus --memory $memory
done
