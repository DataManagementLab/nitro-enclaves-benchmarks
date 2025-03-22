#!/bin/bash

# This bash script is supposed to be run on an ec2 VM from within the iperf3 directory

num_cpus=$(nproc --all)
export ALLOCATOR_MEMORY=4096
export ALLOCATOR_VCPUS=$((num_cpus/2))
make allocate

export ENCLAVE_VCPUS=$((num_cpus/2))
export NUM_SERVERS=1

echo "Starting cross-instance throughput benchmark tcp-2-vsock proxy and enclave-server with $ENCLAVE_VCPUS enclave CPUs..."

make run-enclave-server run-proxies-background
