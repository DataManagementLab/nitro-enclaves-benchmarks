#!/bin/sh

# start the server and wait for it to be ready
./server.sh &
sleep 3

# run the benchmark
./benchmark.sh
