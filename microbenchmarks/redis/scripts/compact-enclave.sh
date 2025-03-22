#!/bin/sh

ip addr add 127.0.0.1/32 dev lo
ip link set dev lo up

./compact.sh
./stream-results-2-vsock.sh
