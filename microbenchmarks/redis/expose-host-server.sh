#!/bin/bash

# resource setup
make terminate
make ENCLAVE_MEMORY=4096 ENCLAVE_VCPUS=2 prepare
hw_threads=$(nproc --all)
hw_mem=$(($(free --mebi | awk '/Mem:/ {print $2}')+4096))

export ENCLAVE_MEMORY=$((hw_mem/2))
export ENCLAVE_VCPUS=$((hw_threads/2))
export DOCKER_NETWORK=host

# native
make allocate run-host-server-background

# to be started on instances:
#   - c6in.16xlarge
