#!/bin/bash

target_host=${1:-"localhost"}  # inject target host internal ip here
target_environment=${2:-"host"}
result_identifier="$target_environment-cross_instance"
n_runs=${n_runs:-10}
export DOCKER_NETWORK=host
export CLIENT_CONNECT_HOST=$target_host

instance_type=$(ec2-metadata --instance-type | cut -d ' ' -f 2)
datetyme=$(date --utc +%FT%TZ | tr : _ | tr - _)
git_ref=$(git rev-parse --short HEAD)
export PATH_METADATA="$instance_type-$datetyme-$git_ref"

# initialize resources
make ENCLAVE_MEMORY=2048 ENCLAVE_VCPUS=2 prepare


# check result directory
if [ ! -d "./results/data/$PATH_METADATA/host-direct" ] || [ -z "$(ls -A ./results/data/"$PATH_METADATA"/host-direct 2>/dev/null)" ]; then
    echo "Result (sub)directory does not exist or is empty. Starting experiments..."
else
    echo "Result directory ./results/data/$PATH_METADATA/host-direct is not empty! Exiting to avoid result mixup."
    exit 1
fi

# run experimets
for i in $(seq 1 "$n_runs"); do

    echo ""
    echo "[$(date +"%y-%m-%d-%H:%M:%S")] ##### Run $i #####"
    echo ""
    num_clients="10"
    pipeline="1 3 10 1000"
    tests="ping set lrange_100"

    for nc in $(echo "$num_clients" | tr " " "\n"); do
        for pl in $pipeline; do
            if [[ "$target_environment" == "host" ]]; then
                make REDIS_NUM_CLIENTS="$nc" REDIS_PIPELINE="$pl" REDIS_TESTS="${tests//[[:space:]]/,}" run-benchmark-2-host
                echo "[$(date +"%FT%T")] setting done."
            else
                for t in $tests; do
                    make REDIS_NUM_CLIENTS="$nc" REDIS_PIPELINE="$pl" REDIS_TESTS="$t" run-benchmark-2-host
                    echo "[$(date +"%FT%T")] setting done."
                done
            fi
        done
    done

    # move results
    make reown-results
    rsync -a --remove-source-files ./results/data/"$PATH_METADATA"/host-direct/ ./results/data/"$PATH_METADATA"/"$result_identifier"/ &&\
    rm -rf ./results/data/"$PATH_METADATA"/host-direct
    make upload-results

done


# to be run on following instances:
#  - c6in.16xlarge
