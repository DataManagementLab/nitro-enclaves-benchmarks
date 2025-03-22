#!/bin/sh

# starts as many proxies as given by the $NUM_SERVERS argument. Default 1. Ports are 5201 and following.
# Copied into the proxy docker container to run there

echo "Starting $NUM_SERVERS socat proxy processes!"

so_opts_tcp="reuseaddr,fork,nodelay,nonblock"
so_opts_vsock="nonblock"

i=1
while [ "$i" -lt "$NUM_SERVERS" ]; do
    port=$((5201 + i - 1))
    echo "Starting proxy $i on port $port"
    socat tcp-listen:$port,$so_opts_tcp vsock-connect:"$SERVER_CID":$port,$so_opts_vsock &
    i=$((i + 1))
done

port=$((5201 + NUM_SERVERS - 1))
echo "Starting proxy $NUM_SERVERS on port $port"
socat tcp-listen:$port,$so_opts_tcp vsock-connect:"$SERVER_CID":$port,$so_opts_vsock
