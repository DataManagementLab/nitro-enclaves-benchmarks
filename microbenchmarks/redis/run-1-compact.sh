#!/bin/bash

n_runs=${n_runs:-10}

instance_type=$(ec2-metadata --instance-type | cut -d ' ' -f 2)
datetyme=$(date --utc +%FT%TZ | tr : _ | tr - _)
git_ref=$(git rev-parse --short HEAD)
export PATH_METADATA="$instance_type-$datetyme-$git_ref"

# resource queries are influenced by the enclave allocator service already...
make ENCLAVE_MEMORY=4096 ENCLAVE_VCPUS=2 prepare
hw_threads=$(($(nproc)+2))
hw_mem=$(($(free --mebi | awk '/Mem:/ {print $2}')+4096)) 
# the resulting total memory determined via this method is not constant for different ENCLAVE_MEMORY sizes...
# at time of experimenting, using 4096 yielded the highest value closest to the specified theoretical instance memory
# thus the memory left for the ec2 host can not be controlled 100% accurately... however we considered this sufficient for our purposes
echo "The following runs assume the following system resources: \nhw_threads: $hw_threads, hw_mem: $hw_mem MiB"


# Experiment 1: compact
for i in $(seq 1 "$n_runs"); do

    echo ""
    echo "[$(date +"%y-%m-%d-%H:%M:%S")] ##### Experiment 1 - Run $i #####"
    echo ""
    num_clients="50 1000"
    pipeline="64"

    # enclave
    make ENCLAVE_MEMORY=$((hw_mem-8192)) ENCLAVE_VCPUS=$((hw_threads-2)) allocate &&\
    for nc in $num_clients; do
        for pl in $pipeline; do
            make REDIS_NUM_CLIENTS="$nc" REDIS_PIPELINE="$pl" ENCLAVE_MEMORY=$((hw_mem-8192)) ENCLAVE_VCPUS=$((hw_threads-2)) run-benchmark-compact-in-enclave
            while true; do
                output=$(nitro-cli describe-enclaves)

                if [[ "$output" == "[]" ]]; then
                    break
                fi
                echo "waiting for enclave to finish..."

                sleep 1
            done
            echo "[$(date +"%y-%m-%d-%H:%M:%S")] COMPACT ENCLAVE - setting done."
            make reown-results upload-results
            
        done
    done

    # native
    make ENCLAVE_MEMORY=2048 ENCLAVE_VCPUS=2 allocate &&\
    for nc in $num_clients; do
        for pl in $pipeline; do
            make REDIS_NUM_CLIENTS="$nc" REDIS_PIPELINE="$pl" run-benchmark-compact-on-host
            echo "[$(date +"%y-%m-%d-%H:%M:%S")] COMPACT NATIVE - setting done."
            make reown-results upload-results
        done
    done

done
