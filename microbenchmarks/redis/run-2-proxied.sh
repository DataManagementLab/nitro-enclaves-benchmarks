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


# Experiment 2: enclave+proxy vs. docker+proxy vs. docker
for i in $(seq 1 "$n_runs"); do

    echo ""
    echo "[$(date +"%y-%m-%d-%H:%M:%S")] ##### Experiment 2 - Run $i #####"
    echo ""
    num_clients="10 $((hw_threads/2-1))"
    pipeline="1 3 10 1000"
    tests="ping set lrange_100"
    export REDIS_TESTS="${tests//[[:space:]]/,}"

    # baseline
    make ENCLAVE_MEMORY=2048 ENCLAVE_VCPUS=2 allocate &&\
    make run-host-server-background &&\
    sleep 1 &&\
    for nc in $(echo "$num_clients $((hw_threads-4))" | tr " " "\n"); do
        for pl in $pipeline; do
            make REDIS_NUM_CLIENTS="$nc" REDIS_PIPELINE="$pl" run-benchmark-2-host
            echo "[$(date +"%y-%m-%d-%H:%M:%S")] BASELINE - setting done."
            make reown-results upload-results
        done
    done
    make terminate-host-server

    # socat optimized
    proxy_reuse_depth=$((hw_threads/2-1))

    for prd in $proxy_reuse_depth; do
        export PROXY_REUSE_DEPTH=$prd
        export SO_NO_DELAY=yes
        export SO_NONBLOCKING=yes

        # enclave
        make ENCLAVE_MEMORY=$((hw_mem/2)) ENCLAVE_VCPUS=$((hw_threads/2)) allocate run-enclave-server &&\
        sleep 1 &&\
        for nc in $num_clients; do
            for pl in $pipeline; do
                for test in $tests; do
                    make REDIS_NUM_CLIENTS="$nc" REDIS_PIPELINE="$pl" REDIS_TESTS="$test" run-benchmark-2-enclave
                    echo "[$(date +"%y-%m-%d-%H:%M:%S")] SOCAT TUNED ENCLAVE - setting done."
                    make reown-results upload-results
                done
            done
        done
        make terminate-enclave-server

        # host
        make ENCLAVE_MEMORY=2048 ENCLAVE_VCPUS=2 allocate run-host-server-proxied-background &&\
        sleep 1 &&\
        for nc in $num_clients; do
            for pl in $pipeline; do
                make REDIS_NUM_CLIENTS="$nc" REDIS_PIPELINE="$pl" run-benchmark-2-host-proxied
                echo "[$(date +"%y-%m-%d-%H:%M:%S")] SOCAT TUNED NATIVE - setting done."
                make reown-results upload-results
            done
        done
        make terminate-host-server
    done

done
