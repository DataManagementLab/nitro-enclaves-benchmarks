.PHONY: all prepare allocate build build-server build-client build-proxy run-enclave-server debug-enclave-server run-host-server run-host-server-background run-host-server-tcp run-host-server-tcp-background run-proxies run-proxies-background run-host-client run-host-size-client run-host-clients-different-enclaves run-host-clients-same-enclave run-host-inet-client run-enclave-client debug-enclave-client terminate process-results plot help

# nitro-cli console always fails when the monitored enclave terminates
.IGNORE: debug-enclave-server debug-enclave-client

ENCLAVE_SERVER_CID ?= 15		# The CID of the enclave server
ENCLAVE_CLIENT_CID ?= 17
ALLOCATOR_MEMORY ?= 4096		# Memory in MiB to allocate to the allocator
ALLOCATOR_VCPUS ?= 4			# Number of vCPUs to allocate to the enclaves
ENCLAVE_MEMORY ?= 2048			# Memory in MiB to assign to the enclave
ENCLAVE_VCPUS ?= 2				# Number of vCPUs to assign to the enclave
NUM_SERVERS ?= 2				# Number of concurrent servers to run or connect to (for multi-server benchmarks)
HOST_SERVER_ADDR ?= 127.0.0.1	# The address of the host server
S3_BUCKET ?= nitro-enclaves-result-bucket/iperf	# The S3 bucket to upload/download results
S3_PROFILE ?=					# The AWS profile to use for the S3 operations (if u want to authenticate via profiles)


# QUICK START COMMANDS

help:  ## Show this help message
	@echo "Usage: make [<VAR=value> ...] <subcommand>"
	@echo ""
	@echo "Variables:"
	@grep -E '^[A-Z0-9_]+\s*\?=' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = " \\?= | # "}; {printf "\033[36m%-30s\033[0m = \033[33m%s\033[0m\n\t%s\n", $$1, $$2, ($$3 ? $$3 : "")}'
	@echo ""
	@echo "Subcommands:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

all: prepare run-enclave-server run-host-client2enclave terminate-enclave-server run-host-server-background debug-enclave-client terminate-host-server ## Prepare, build, run and terminate client-server-pairs once both with the enclave and the host as server

prepare: build allocate ## Prepare the environment by building the enclaves and then allocating resources

allocate_configure: ## Allocate memory and cpu cores via the enclave allocator service
	docker run --rm -v "$(shell pwd)":/workdir mikefarah/yq -i '.cpu_count = $(ALLOCATOR_VCPUS) | .memory_mib = $(ALLOCATOR_MEMORY)' deploy/allocator.yaml

allocate: allocate_configure  ## Allocate memory and cpu cores via the enclave allocator service
	sudo cp deploy/allocator.yaml /etc/nitro_enclaves/allocator.yaml &&\
	sudo systemctl restart --now nitro-enclaves-allocator.service


# BUILD COMMANDS

build: build-server build-multi-server build-client build-proxy ## Build all containers and enclaves

build-server: ## Build the server container and enclave
	docker build -t iperf3-vsock:server -f deploy/server.Dockerfile .
	nitro-cli build-enclave --docker-uri iperf3-vsock:server  --output-file enclave-server.eif

build-multi-server:
	docker build -t iperf3-vsock:server-2 -f deploy/server.Dockerfile --build-arg NUM_SERVERS_ARG=$(NUM_SERVERS) .
	nitro-cli build-enclave --docker-uri iperf3-vsock:server-2  --output-file enclave-server-multi.eif

build-client: ## Build the client container and enclave (for the ec2 host being the server)
	docker build -t iperf3-vsock:client -f deploy/client.Dockerfile --build-arg IPERF_SERVER_CID=3 .
	nitro-cli build-enclave --docker-uri iperf3-vsock:client  --output-file enclave-client.eif

build-proxy: ## Build the proxy container
	docker build -t iperf3-vsock:proxy -f deploy/proxy.Dockerfile .

# RUN COMMANDS

run-enclave-server: ## Run the iperf server in an enclave
	nitro-cli run-enclave --enclave-cid $(ENCLAVE_SERVER_CID) --eif-path enclave-server.eif --cpu-count $(ENCLAVE_VCPUS) --memory $(ENCLAVE_MEMORY)

run-enclave-servers: ## Run the iperf server in two enclaves
	scripts/start_enclaves.sh $(NUM_SERVERS) $(ENCLAVE_VCPUS) $(ENCLAVE_MEMORY)

run-enclave-multi-server: ## Run multiple iperf servers in the same enclave. Number of servers is defined during build-multi-server with the NUM_SERVERS variable
	nitro-cli run-enclave --enclave-cid $(ENCLAVE_SERVER_CID) --eif-path enclave-server-multi.eif --cpu-count $(ENCLAVE_VCPUS) --memory $(ENCLAVE_MEMORY)

debug-enclave-server: ## Debug the iperf server in an enclave
	nitro-cli run-enclave --enclave-cid $(ENCLAVE_SERVER_CID) --eif-path enclave-server.eif --cpu-count $(ENCLAVE_VCPUS) --memory $(ENCLAVE_MEMORY) --debug-mode &&\
	nitro-cli console --enclave-name enclave-server

run-host-server: ## Run the iperf server on the host
	docker run --rm -it --privileged --name iperf3-vsock-server iperf3-vsock:server

run-host-server-background: ## Run the iperf server on the host in the background
	docker run --rm -d --privileged --name iperf3-vsock-server iperf3-vsock:server

run-host-server-tcp: ## Run the iperf server on the host (using TCP/IP)
	docker run --rm -it --net=host --name iperf3-tcp-server -e PROTOCOL=tcp -e NUM_SERVERS=$(NUM_SERVERS) iperf3-vsock:server

run-host-server-tcp-background: ## Run the iperf server on the host in the background (using TCP/IP)
	docker run --rm -d --net=host --name iperf3-tcp-server -e PROTOCOL=tcp -e NUM_SERVERS=$(NUM_SERVERS) iperf3-vsock:server

run-proxies:  ## Run the proxy container
	docker run --rm -it --net=host --privileged --name iperf3-vsock-proxy \
	-e NUM_SERVERS=$(NUM_SERVERS) -e SERVER_CID=$(ENCLAVE_SERVER_CID) iperf3-vsock:proxy

run-proxies-background:  ## Run the proxy container in the background
	docker run --rm -d --net=host --privileged --name iperf3-vsock-proxy \
	-e NUM_SERVERS=$(NUM_SERVERS) -e SERVER_CID=$(ENCLAVE_SERVER_CID) iperf3-vsock:proxy

run-host-client: ## Run the iperf client on the host to connect to the enclave server
	docker run --rm -it --privileged -e IPERF_SERVER_CID=$(ENCLAVE_SERVER_CID) iperf3-vsock:client

run-host-size-client:  ## Run the iperf client on the host to connect to the enclave server with the msg sizes specified in bench-size.sh
	docker run --rm -it --privileged -e IPERF_SERVER_CID=$(ENCLAVE_SERVER_CID) --entrypoint=/app/build/src/bench-size.sh iperf3-vsock:client

run-host-clients-different-enclaves:
	scripts/run_clients.sh enclaves $(NUM_SERVERS)

run-host-clients-same-enclave:
	scripts/run_clients.sh servers $(NUM_SERVERS)

run-host-inet-client:
	docker run --rm -it --net=host --entrypoint=/app/build/src/bench-inet.sh -e IPERF_SERVER_IPADDR=$(HOST_SERVER_ADDR) iperf3-vsock:client

run-enclave-client: ## Run the iperf client in an enclave to connect to the host server
	nitro-cli run-enclave --enclave-cid $(ENCLAVE_CLIENT_CID) --eif-path enclave-client.eif --cpu-count $(ENCLAVE_VCPUS) --memory $(ENCLAVE_MEMORY)

debug-enclave-client: ## Debug the iperf client in an enclave to connect to the host server
	nitro-cli run-enclave --enclave-cid $(ENCLAVE_CLIENT_CID) --eif-path enclave-client.eif --cpu-count $(ENCLAVE_VCPUS) --memory $(ENCLAVE_MEMORY) --debug-mode &&\
	nitro-cli console --enclave-name enclave-client

run-host-shell: ## Run a shell on the host in the iperf docker container in privileged mode sharing the native network
	docker run --rm -it --net=host --privileged --entrypoint bash iperf3-vsock:client

# CLEAN/TERMINATE COMMANDS

terminate: ## Terminate all iperf servers (ignoring errors)
	-nitro-cli terminate-enclave --all
	-docker stop $(shell docker ps -a -q)


# S3 SYNC COMMANDS

download-results: ## Download the results from the S3 bucket
	aws $(if $(S3_PROFILE),--profile $(S3_PROFILE)) s3 sync s3://$(strip $(S3_BUCKET)) results/data/

# PLOT COMMAND

process-results: ## Process the results of the iperf benchmarks
	@echo "Converting and combining result data to CSV..."
	(cd results && ./convert_to_csv.py -p data/cross_instance -c)
	(cd results && ./convert_to_csv.py -p data/message-size -c)
	(cd results && ./convert_to_csv.py -p data/multi)
	(cd results && ./convert_to_csv.py -p data/single-enclave -c)

plot: ## Plot the results of the iperf benchmarks
	@echo "Plotting results..."
	(cd results && ./plot.py)
	(cd results && ./combine_multi.py)
	@echo "Results plotted to results/img"
