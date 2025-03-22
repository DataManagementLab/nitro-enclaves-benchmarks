#!/bin/sh

# set defaults
PROXY_TOOL=${PROXY_TOOL:-socat}
PROXY_REUSE_DEPTH=${PROXY_REUSE_DEPTH:-1}
TCP_LISTEN_PORT=${TCP_LISTEN_PORT:-5000}
TCP_CONNECT_PORT=${TCP_CONNECT_PORT:-6379}
TCP_CONNECT_HOST=${TCP_CONNECT_HOST:-127.0.0.1}

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

# start the proxy(s) for tcp->tcp
# socat
if [ "$PROXY_TOOL" = "socat" ]; then
    SOCAT_FORK=${SOCAT_FORK:-yes}

    # tune socat options
    so_opts_listen="reuseaddr"
    so_opts_connect=""
    test -n "$SO_RCVBUF_SIZE"       && so_opts_listen="$so_opts_listen,so_rcvbuf=$SO_RCVBUF_SIZE" && so_opts_connect="$so_opts_connect,rcvbuf=$SO_RCVBUF_SIZE"
    test -n "$SO_SNDBUF_SIZE"       && so_opts_listen="$so_opts_listen,so_sndbuf=$SO_SNDBUF_SIZE" && so_opts_connect="$so_opts_connect,sndbuf=$SO_SNDBUF_SIZE"
    test -n "$SO_NONBLOCKING"       && so_opts_listen="$so_opts_listen,nonblock" && so_opts_connect="$so_opts_connect,nonblock"
    test -n "$SO_NO_DELAY"          && so_opts_connect="$so_opts_connect,nodelay" && so_opts_listen="$so_opts_listen,nodelay"
    [ "$PROXY_REUSE_DEPTH" -ne 1 ]  && so_opts_listen="$so_opts_listen,reuseport"
    test -n "$SOCAT_FORK"           && so_opts_listen="$so_opts_listen,fork"

    for i in $(seq 1 $PROXY_REUSE_DEPTH); do
        socat tcp-listen:$TCP_LISTEN_PORT,$so_opts_listen tcp-connect:$TCP_CONNECT_HOST:$TCP_CONNECT_PORT$so_opts_connect &
    done

# ncat
elif [ "$PROXY_TOOL" = "ncat" ]; then
    if [ "$PROXY_REUSE_DEPTH" -ne 1 ]; then
        echo "ncat does not support PROXY_REUSE_DEPTH > 1"
    else
        ncat -l $TCP_LISTEN_PORT --sh-exec "ncat $TCP_CONNECT_HOST $TCP_CONNECT_PORT" &
    fi

else
    echo "Unsupported PROXY_TOOL: $PROXY_TOOL"
    exit 1
fi
