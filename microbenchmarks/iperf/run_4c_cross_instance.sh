#!/bin/bash

# This bash script is supposed to be run on an ec2 VM from within the iperf3 directory

num_cpus=$(nproc --all)
export ALLOCATOR_MEMORY=4096
export ALLOCATOR_VCPUS=$((num_cpus/2))
make allocate

target_ip=${1:-"localhost"}  # inject target host internal ip here
target_identifier=${2:-"host"}
instance_type=$(ec2-metadata --instance-type | cut -d ' ' -f 2)
datetyme=$(date --utc +%FT%TZ | tr : _ | tr - _)
git_ref=$(git rev-parse --short HEAD)

file_name="$target_identifier-$instance_type-$((num_cpus-ALLOCATOR_VCPUS))-$datetyme-$git_ref.txt"

echo "Running cross-instance throughput benchmark to $target_ip, saving results to $file_name."

export HOST_SERVER_ADDR=$target_ip
make run-host-inet-client | tee "$file_name"
aws s3 cp "$file_name" "s3://nitro-enclaves-result-bucket/iperf/cross_instance/$file_name"
