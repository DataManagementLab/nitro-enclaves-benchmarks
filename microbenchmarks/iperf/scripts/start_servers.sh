#!/bin/bash

# starts as many servers as given by NUM_SERVERS. Default 1. Ports are 5201 and following.
# If PROTOCOL is not overridden with something else than "vsock", the servers will use vsock instead of TCP.
# Copied into the server docker container/enclave to run there

PROTOCOL=${PROTOCOL:-vsock}
NUM_SERVERS=${NUM_SERVERS:-1}

echo "Starting $NUM_SERVERS iperf3 servers listening via $([ "$PROTOCOL" = "vsock" ] && echo "vsock" || echo "tcp")!"

for (( i=1; i<$NUM_SERVERS; i++ ))
do
    port=$((5201+$i-1))
    echo "Starting server $i on port $port"
    /app/build/src/iperf3 $([ "$PROTOCOL" = "vsock" ] && echo "--vsock") -s -p $port --daemon
done

port=$((5201+$NUM_SERVERS-1))
echo "Starting server $NUM_SERVERS on port $port"
/app/build/src/iperf3 $([ "$PROTOCOL" = "vsock" ] && echo "--vsock") -s -p $port
