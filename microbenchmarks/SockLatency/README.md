# Socket Latency Benchmark

This microbenchmark compares socket latency of standard inet/loopback vs. host to nitro enclave communication over vsock.

## Running the Experiments

To list all the available workflows and config variables implemented in the [`Makefile`](./Makefile), run:

```shell
make help
```
Before you continue on the EC2 instances, ensure you have prepared the [requirements](../../README.md#requirements).

### Single Instance Experiments
Benchmark ```inet/local-loopback``` vs ```vsock``` latency with varying packet sizes, via:

```shell
./run.sh
```

### Cross-Instance Experiments

Benchmark ```NIC``` vs. ```NIC + tcp/vsock proxy + vsock``` latency with varying packet sizes. Both scenarios need to be executed seperately:

1. Start the server on 1 EC2 instance:
   ```shell
   source prepare.sh && ./expose-host-server.sh
   ```
   or
   ```shell
   source prepare.sh && ./expose-enclave-server.sh
   ```
2. Start the client on the other EC2 instance with the peer's aws-internal ip-address and the according result identifier ```cross_instance_host2host``` or ```cross_instance_host2enclave```:
   ```shell
   source prepare.sh && ./run-cross-instance.sh [server-ip-address] [result-identifier]
   ```

### Proxy Reference Experiment
For profiling the proxy overhead the client-server rountrip can be extended with a tcp-proxy in between as baseline against the vsock/tcp-proxy. 

- This can be run either on a single instance:
  ```shell
  source prepare.sh && ./run-proxy-local.sh
  ```
- or across EC2 instances:
  1. On the server Instance:
     ```shell
     source prepare.sh && ./expose-host-proxy.sh
     ```
  2. On the client Instance:
     ```shell
     export CLIENT_PORT=5006
     source prepare.sh && ./run-cross-instance.sh [server-ip-address] "cross_instance_proxy" 
     ```

## Plotting
The results can be combined and plottet via:
```bash
make plot
```

We have added our results used in the paper to the repository.

If you want to rerun the experiments, see the [instructions above](#running-the-experiments) to generate your own numbers. You can then download them from your S3 Bucket via:
```bash
export S3_BUCKET=[your-s3-bucket]/SockLatency
export S3_PROFILE=[your-aws-profile]
make download-results plot
```

## Project Structure

The entire benchmarking process is automated in the [```Makefile```](Makefile). See ```make help``` to learn about its usage.
All results are written to [```results/data```](results/data) and plotted to [```results/img```](results/img) with [```plot/plot.py```](plot/plot.py) via ```make plot```.

The [```app```](app) directory contains the c++ application for latency measurement between 2 peers (client, server)
over ```inet``` or ```vsock```.

The execution scripts can be found in [```scripts```](scripts). This includes a minimal proxy script, to expose the enclave server for cross-instance experiments.
The [```deploy```](deploy) directory contains everything related to aws, docker and the enclave build process.

## Instance Selection

We tested with the following EC2 instances:

**Single Instance**:
- Instance Sizes:
  - c6i.2xlarge
  - c6i.4xlarge
  - c6i.8xlarge
  - c6i.16xlarge
- Instance Generations:
  - c5i.2xlarge
  - c6i.2xlarge
  - c7i.2xlarge
- CPU architecture:
  - c6i.2xlarge
  - c6a.2xlarge
  - c6g.2xlarge
- Premium NICs:
  - c6in.2xlarge
  - c6in.4xlarge

**Cross-Instance** (we chose client and server instances symmetrically):
- c6in.16xlarge
