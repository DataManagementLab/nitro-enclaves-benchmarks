# IPerf/vsock Nitro Enclave Benchmark

based on [Stefano Garzarella's iperf fork](https://github.com/stefano-garzarella/iperf-vsock) with vsock support.

The benchmark is composed of

- 1 ```server``` waiting for a client to connect
- and the ```client```

## Getting Started

All relevant scenario stages are prepared as make targets in the [```Makefile```](./Makefile). For viewing all available targets and options with a short description run

```bash
make help
```

The relevant experiment sets for our paper are scripted in the run_[0-4][...].sh scripts:
- [`run_0_preparation.sh`](./run_0_preparation.sh): prepare images and allocate resources
- [`run_1_single_enclave.sh`](./run_1_single_enclave.sh): run the basic experiment set with 1 enclave at a time on 1 EC2 instance
- [`run_2_multi.sh`](./run_2_multi.sh): run multi-enclave experiments on 1 EC2 instance
- [`run_3_message_sizes.sh`](./run_3_message_sizes.sh): run size variation experiments on 1 EC2 instance
- [`run_4b_expose_host.sh`](./run_4b_expose_host.sh)(server), [`run_4c_cross_instance.sh`](./run_4c_cross_instance.sh)(client): run those on different EC2 instances for cross-instance experiments. the client takes (1) the server ip and (2) a target identier (`host`/`enclave`) as positional arguments

### Running the Experiments

Before you start, ensure you have prepared the [requirements](../../README.md#requirements).

To reproduce the experiments in the paper:

- Figure 5: Run the following commands on the instance types you are interested in:
  ```shell
  cd AWSNitroBenchmark/microbenchmarks/iperf/ && ./run_0_preparation.sh && ./run_1_single_enclave.sh
  ```
- Figure 6: Run the following commands on an c6in.8xlarge instance:
  ```shell
  cd AWSNitroBenchmark/microbenchmarks/iperf/ && ./run_0_preparation.sh && ./run_3_message_sizes.sh
  ```
  TODO: commands for network baseline
- Figure 7: Run the following commands on an c6in.4xlarge instance:
  ```shell
  cd AWSNitroBenchmark/microbenchmarks/iperf/ && ./run_0_preparation.sh && ./run_2_multi.sh
  ```
- Figure 9: Run the following commands on the instance types you are interested in:
  ```shell
  cd AWSNitroBenchmark/microbenchmarks/iperf/ && ./run_0_preparation.sh && ./run_1_single_enclave.sh
  ```

### Plotting
The results can be plottet via:
```bash
make plot
```

We have added our results used in the paper to the repository.

If you want to rerun the experiments, see the [instructions above](#running-the-experiments) to generate your own numbers. You can then download and combine them from your S3 Bucket via:
```bash
export S3_BUCKET=[your-s3-bucket]/iperf
export S3_PROFILE=[your-aws-profile]
make download-results process-results
```

## Detailed Command Overview

This section explains the most important `Makefile` automations.
The commands usually follow the same semantics, which is (1) what they do (e.g. start, build, terminate, etc.), (2) the environmental context (host or enclave), and (3) the target (e.g. client, server, etc.). Additionally there are some shortcuts.

### Preparation

To prepare everything for the next steps, run ```make prepare``` which allocates enough resources for the enclaves to start and builds everything, which will be used later. To just (re)build all without (re)allocating resources ```make build```.

### Starting the server

To start the server just run the following targets:
- start server in an enclave, listening for *`VSOCK`* connections:
  ```bash
  make run-enclave-server
  ```
- start server in an enclave, listening on *`VSOCK`*, and a `socat` proxy listening on *`TCP`*:
  ```bash
  export NUM_SERVERS=1
  make run-host-server-tcp-background run-proxies-background
  ```
- starts the server on the host as docker container, listening for *`VSOCK`* connections:
  ```bash
  make run-host-server-background
  ```

### Starting the client

To start the clients, run one of the following make targets, depending on the setting (see `make help` for details). For connecting to the

- *enclave* via *`VSOCK`*, run:
  - `run-host-client`
  - `run-host-size-client`
  - `run-host-clients-different-enclaves`
  - `run-host-clients-same-enclave`
- *host* via *`TCP`*, run:
  - `run-host-inet-client`
- *host* via *`VSOCK`* from an enclave, run:
  - `run-enclave-client`

### Cleanup

The terminate commands (see `make help`) can be executed to shutdown the iperf servers again.

## Native execution without docker

If you doubt docker's overhead is negligible, try to build iperf-vsock on the host system directly.
Therefore follow the [build instructions from Stefano Garzarella](https://github.com/stefano-garzarella/iperf-vsock?tab=readme-ov-file#build) and run the following commands in ```{projectRoot}/build/src```:

- starting a client to an enclave server:

  ```bash
  ./iperf3 --vsock -c 16
  ```

  Hereby ```16``` is the CID of the enclave running the iperf server.
- starting an iperf server

  ```bash
  ./iperf3 --vsock -s
  ```
