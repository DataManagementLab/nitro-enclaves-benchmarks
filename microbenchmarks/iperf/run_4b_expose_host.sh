#!/bin/bash

# This bash script is supposed to be run on an ec2 VM from within the iperf3 directory

num_cpus=$(nproc --all)
export ALLOCATOR_MEMORY=4096
export ALLOCATOR_VCPUS=$((num_cpus/2))
make allocate

export NUM_SERVERS=1
echo "Starting cross-instance throuput benchmark server(s)..."

make run-host-server-tcp-background
