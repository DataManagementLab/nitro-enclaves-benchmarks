#!/bin/bash

# This bash script is supposed to be run on an ec2 VM from within the iperf3 directory

num_cpus=$(nproc --all)
max_enclaves=4  # given by AWS Nitro Enclaves limit per instance
export ALLOCATOR_MEMORY=$(($max_enclaves*2048))
export ALLOCATOR_VCPUS=$((num_cpus-2))
make allocate

export ENCLAVE_VCPUS=2
export ENCLAVE_MEMORY=2048
for num_enclaves in $(seq 1 $max_enclaves);
do
    echo "Running enclave VSOCK throughput benchmark with $num_enclaves enclaves."

    make NUM_SERVERS=$num_enclaves run-enclave-servers
    echo "Wait for enclaves to start properly"
    sleep 15

    make NUM_SERVERS=$num_enclaves run-host-clients-different-enclaves
    make terminate
done

echo "Running two servers in same enclave VSOCK throughput benchmark."
export ENCLAVE_VCPUS=$((num_cpus/2))
export ENCLAVE_MEMORY=$((ALLOCATOR_MEMORY))

make NUM_SERVERS=2 run-enclave-multi-server
echo "Wait for enclave to start properly"
sleep 15

make NUM_SERVERS=2 run-host-clients-same-enclave
make terminate

for file in multi-*.txt;
do
    aws s3 cp $file "s3://nitro-enclaves-result-bucket/iperf/multi/$file"
done
