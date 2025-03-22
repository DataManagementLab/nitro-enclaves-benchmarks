#!/bin/sh

# set defaults
PROXY_TOOL=${PROXY_TOOL:-socat}
PROXY_REUSE_DEPTH=${PROXY_REUSE_DEPTH:-1}

# log config
mkdir -p /data
cat >> /data/config.yaml <<EOF
proxy_on: true
proxy_tool: $PROXY_TOOL
proxy_reuse_depth: $PROXY_REUSE_DEPTH
proxy_so_rcvbuf_size: $SO_RCVBUF_SIZE
proxy_so_sndbuf_size: $SO_SNDBUF_SIZE
proxy_so_nonblocking: $SO_NONBLOCKING
proxy_so_no_delay: $SO_NO_DELAY
EOF

# start the proxy(s) for tcp->vsock
# socat
if [ "$PROXY_TOOL" = "socat" ]; then
    SOCAT_FORK=${SOCAT_FORK:-yes}

    # tune socat options
    so_opts_tcp="reuseaddr"
    so_opts_vsock=""
    test -n "$SO_RCVBUF_SIZE"        && so_opts_tcp="$so_opts_tcp,so_rcvbuf=$SO_RCVBUF_SIZE" && so_opts_vsock="$so_opts_vsock,rcvbuf=$SO_RCVBUF_SIZE"
    test -n "$SO_SNDBUF_SIZE"        && so_opts_tcp="$so_opts_tcp,so_sndbuf=$SO_SNDBUF_SIZE" && so_opts_vsock="$so_opts_vsock,sndbuf=$SO_SNDBUF_SIZE"
    test -n "$SO_NONBLOCKING"        && so_opts_tcp="$so_opts_tcp,nonblock" && so_opts_vsock="$so_opts_vsock,nonblock"
    test -n "$SO_NO_DELAY"           && so_opts_tcp="$so_opts_tcp,nodelay"
    [ "$PROXY_REUSE_DEPTH" -ne 1 ]   && so_opts_tcp="$so_opts_tcp,reuseport"
    test -n "$SOCAT_FORK"            && so_opts_tcp="$so_opts_tcp,fork"

    for i in $(seq 1 $PROXY_REUSE_DEPTH); do
        socat tcp-listen:6379,$so_opts_tcp vsock-connect:$SERVER_CID:5000$so_opts_vsock &
    done

# ncat
elif [ "$PROXY_TOOL" = "ncat" ]; then
    if [ "$PROXY_REUSE_DEPTH" -ne 1 ]; then
        echo "ncat does not support PROXY_REUSE_DEPTH > 1"
        exit 1
    fi
    ncat -l 6379 --keep-open --sh-exec "ncat --vsock $SERVER_CID 5000" &

else
    echo "Unknown PROXY_TOOL: $PROXY_TOOL"
    exit 1
fi
