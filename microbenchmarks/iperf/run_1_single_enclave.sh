#!/bin/bash

# This bash script is supposed to be run on an ec2 VM from within the iperf3 directory

num_cpus=$(nproc --all)
export ALLOCATOR_MEMORY=4096
export ALLOCATOR_VCPUS=$((num_cpus/2))
make allocate

export ENCLAVE_VCPUS=$((num_cpus/2))

instance_type=$(ec2-metadata --instance-type | cut -d ' ' -f 2)

if [ "$1" = "" ];
then
    file_name="single-enclave-$instance_type-$ENCLAVE_VCPUS-$(date --utc +%FT%TZ).txt"
else
    file_name="$1"
fi

echo "Running single enclave VSOCK throughput benchmark with $ENCLAVE_VCPUS enclave CPUs and saving results to $file_name."

make run-enclave-server
make run-host-client | tee "$file_name"
aws s3 cp "$file_name" "s3://nitro-enclaves-result-bucket/iperf/single-enclave/$file_name"
nitro-cli terminate-enclave --all
