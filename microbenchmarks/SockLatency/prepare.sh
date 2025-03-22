#!/bin/bash

echo "Preparing environment..."
hw_threads=$(nproc --all)
export ENCLAVE_VCPUS=4
export ENCLAVE_VCPU_POOL="1,2,$((hw_threads/2+1)),$((hw_threads/2+2))"
export ENCLAVE_MEMORY=4096
make terminate prepare
