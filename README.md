# An Analysis of AWS Nitro Enclaves for Database Workloads
This is the source code for our (Adrian Lutsch, Christian Franck, Muhammad El-Hindi, Zsolt István, and Carsten Binnig) paper "An Analysis of AWS Nitro Enclaves for Database Workloads"

## Abstract
Cloud databases have become prevalent, as evidenced by the rapid growth of systems such as BigQuery,
Snowflake, and Databricks. Concurrently, there has been a significant increase in the requirements
for secure data processing when outsourcing databases to the cloud. For this, Trusted Execution
Environments (TEEs) have emerged as a key technology in the cloud, which is witnessed by the fact
that all cloud providers offer TEEs in the service portfolio. However, Amazon Web Services' (AWS)
approach to TEEs based on Nitro Enclaves fundamentally differs from that of other cloud providers
like Microsoft and Google or standard technologies such as Intel SGX. In this paper, we thus set
out the goal to understand the implications of using AWS Nitro Enclaves for cloud databases. Although
Nitro Enclaves initially appear to be a promising platform for pure TEE performance, they come with
significant limitations regarding communication with the Nitro Enclave. Our benchmark results provide
insight into the performance and practical challenges of deploying database workloads in AWS Nitro
Enclaves, offering valuable guidance for practitioners and researchers.

## Repo Overview
This Repository is structured as follows:

- [`aws/`](./aws/) contains utilities, which we used to automate the instance creation, setup and management
- `microbenchmarks/`
  - [`iperf/`](./microbenchmarks/iperf/) measures network throughput (especially including *`VSOCK`* to and from AWS Nitro Enclaves)
  - [`redis/`](./microbenchmarks/redis/) containas full DBMS / end-to-end benchmarks with redis
  - [`SockLatency/`](./microbenchmarks/SockLatency/) profiles the network latency (especially including *`VSOCK`* to and from AWS Nitro Enclaves)

## Reproduction of Results

We were not yet able to make all configurations in this repository independent of our AWS account and to upload our measurements as CSV files. We will improve this in the coming days.

All plots and intermediate results can be reproduced with the code and README descriptions in the microbenchmarks directories mentioned above.
Our results are part of this repo as well for exploration and replotting. Make sure to [prepare the according tools](#plotting).
To rerun the benchmarks make sure to follow the [requirements instructions](#requirements) below.

### Requirements

Make sure to have an AWS account ready, with:
1) the ability to create EC2 instances in the according size (We used up to 2 simultanuously running `c6in.16xlarge` instances, requiring `2x 64 = 128` total vCPUs). Always enable the nitro enclaves option in the launch configuration
1) an S3 bucket for storing experiment results

For instance setup you can reuse the `ec2c` (instance creation) and `ec2setup` (instance setup) command provided by our [`awsrc`](./aws/awsrc) or create instances yourself and run our [`setup_ec2.sh`](./aws/setup_ec2.sh) there, which installs and initializes all required tools on the EC2 instance, e.g.:
- `docker`
- `nitro-cli` and initialize the `nitro-allocator-service`
- `python`
- build tools and other utilities

### Plotting
The results can be plotted either on the producing EC2 instances or any other device of your choice. Therefore make sure to:
- install `Rscript` and all libraries mentioned in [`setup_r.sh`](./aws/setup_r.sh) (for result processing and optionally plotting)
- install `python` and create and source an environment with the packages listed in our [`requirements.txt`](./requirements.txt)

In order to access your own results ensure to:
- install `aws cli`
- authenticate to get access to your S3 bucket
