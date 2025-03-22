# End-2-End Benchmark (Redis)
These experiments profile the performance penalty of running a redis server inside an AWS nitro enclave. We reuse the official [redis-benchmark utilities](https://redis.io/docs/latest/operate/oss_and_stack/management/optimization/benchmarks/) provided by Redis Inc.

Our experiment setup allows to differentiate the individual overheads of
1) the **double socket proxying** which is required by all systems not supporting vsock out-of-the box 
2) **vsock** instead of tcp/ip

in both a local (same-host) setup and with networking between server and client.

## Running the Experiments

To list all the available workflows and config variables implemented in the [`Makefile`](./Makefile), run:

```shell
make help
```
Before you continue on the EC2 instances, ensure you have prepared the [requirements](../../README.md#requirements).

### Single Instance Experiments

To reproduce our local experiment results with different packet sizes, run:
```shell
./run-1-compact.sh
./run-2-proxied.sh
```

We compare 5 different scenarios:
1. ```direct``` - over local inet loopback (*i.e. docker network stack*)
1. ```host client to nitro-enclave server``` - *tcp/ip -> proxy -> vsock -> proxy -> tcp/ip*
1. ```double-proxy``` - *tcp/ip -> proxy -> tcp/ip -> proxy -> tcp/ip*
1. ```compact``` (host) - client & server both inside a single docker container
1. ```compact``` (enclave) - client & server both inside a single AWS nitro enclave

### Cross-Instance Experiments

Benchmark ```NIC``` vs. ```NIC + double tcp/vsock proxy + vsock``` latency with varying packet sizes. Both scenarios need to be executed seperately:

1. Start the server on 1 EC2 instance:
   ```shell
   ./expose-host-server.sh
   ```
   or
   ```shell
   ./expose-enclave-server.sh
   ```
2. Start the client on the other EC2 instance with the peer's aws-internal ip-address and the according result identifier ```host``` or ```enclave``` depending on where you are running the server:
   ```shell
   ./run-3-cross-instance.sh [server-ip-address] [result-identifier]
   ```

## Plotting
The results can be combined and plottet via:
```bash
make plot
```

We have added our results used in the paper to the repository.

If you want to rerun the experiments, see the [instructions above](#running-the-experiments) to generate your own numbers. You can then download them from your S3 Bucket via:
```bash
export S3_BUCKET=[your-s3-bucket]/redis
export S3_PROFILE=[your-aws-profile]
make download-results plot
```

## Project Structure
The entire benchmarking process is automated in the [```Makefile```](Makefile). See ```make help``` to learn about its usage.
All results are written to [```results/data```](results/data) and plotted to [```results/img```](results/img) with [```plot/plot.py)```](plot/plot.py) via ```make plot```.

The execution scripts can be found in [```scripts```](scripts). All proxy-related commands are currently defined there.
The [```deploy```](deploy) dirctory contains everything related to aws and the enclave build process.

## Instance Selection

We tested with the following EC2 instances:

**Single Instance**:
- c6i.16xlarge

**Cross-Instance** (we chose client and server instances symmetrically):
- c6in.16xlarge
