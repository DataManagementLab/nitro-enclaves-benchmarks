#!/bin/sh

# set defaults
NUM_CLIENTS=${NUM_CLIENTS:-50}
PIPELINE=${PIPELINE:-1}
REDIS_HOST=${REDIS_HOST:-127.0.0.1}

# ensure the data directory exists
mkdir -p /data

# log config
cat >> /data/config.yaml <<EOF
num_clients: $NUM_CLIENTS
pipeline: $PIPELINE
EOF

# run the redis benchmark
redis-benchmark -h $REDIS_HOST -q --csv -c $NUM_CLIENTS -P $PIPELINE \
  ${REDIS_TESTS:+-t $REDIS_TESTS} > /data/redis-benchmark.csv


# print the results
cat /data/redis-benchmark.csv
