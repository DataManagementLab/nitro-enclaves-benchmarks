#!/bin/sh

# set defaults
PROXY_TOOL=${PROXY_TOOL:-socat}
PROXY_REUSE_DEPTH=${PROXY_REUSE_DEPTH:-1}

# start the proxy(s) for tcp->vsock
# socat
if [ "$PROXY_TOOL" = "socat" ]; then
    SOCAT_FORK=${SOCAT_FORK:-yes}

    # tune socat options
    so_opts_vsock="reuseaddr"
    so_opts_tcp=""
    test -n "$SO_RCVBUF_SIZE"        && so_opts_tcp="$so_opts_tcp,so_rcvbuf=$SO_RCVBUF_SIZE" && so_opts_vsock="$so_opts_vsock,rcvbuf=$SO_RCVBUF_SIZE"
    test -n "$SO_SNDBUF_SIZE"        && so_opts_tcp="$so_opts_tcp,so_sndbuf=$SO_SNDBUF_SIZE" && so_opts_vsock="$so_opts_vsock,sndbuf=$SO_SNDBUF_SIZE"
    test -n "$SO_NONBLOCKING"        && so_opts_tcp="$so_opts_tcp,nonblock" && so_opts_vsock="$so_opts_vsock,nonblock"
    test -n "$SO_NO_DELAY"           && so_opts_tcp="$so_opts_tcp,nodelay"
    [ "$PROXY_REUSE_DEPTH" -ne 1 ]   && so_opts_vsock="$so_opts_vsock,reuseport"
    test -n "$SOCAT_FORK"            && so_opts_vsock="$so_opts_vsock,fork"

    for i in $(seq 1 $PROXY_REUSE_DEPTH); do
        socat vsock-listen:5000,$so_opts_vsock tcp-connect:127.0.0.1:6379$so_opts_tcp &
    done

# ncat
elif [ "$PROXY_TOOL" = "ncat" ]; then
    if [ "$PROXY_REUSE_DEPTH" -ne 1 ]; then
        echo "ncat does not support PROXY_REUSE_DEPTH > 1"
        exit 1
    fi
    ncat -l --vsock 5000 --keep-open --sh-exec "ncat 127.0.0.1 6379" &

else
    echo "Unknown PROXY_TOOL: $PROXY_TOOL"
    exit 1
fi
