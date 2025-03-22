#!/bin/sh

PROTOCOL=${PROTOCOL:-vsock}
SERVER_PORT=${SERVER_PORT:-5005}
CLIENT_PORT=${CLIENT_PORT:-5005}

# proxy tcp to vsock
so_opts_tcp="reuseaddr,fork,nodelay,nonblock"
so_opts_connect="nonblock"

if [ "$PROTOCOL" = "vsock" ]; then
    socat "tcp-listen:$CLIENT_PORT,$so_opts_tcp" "vsock-connect:$SERVER_CID:$SERVER_PORT,$so_opts_connect"
elif [ "$PROTOCOL" = "tcp" ]; then
    socat "tcp-listen:$CLIENT_PORT,$so_opts_tcp" "tcp-connect:127.0.0.1:$SERVER_PORT,$so_opts_connect"
else
    echo "Unknown protocol $PROTOCOL"
    exit 1
fi
