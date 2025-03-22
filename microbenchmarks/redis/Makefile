.PHONY: help prepare allocate-configure allocate build build-containers build-enclave-server create-networks run-enclave-server debug-enclave-server expose-enclave expose-enclave-background run-host-server-background run-host-server-proxied run-host-server-proxied-background run-benchmark-2-enclave run-benchmark-2-host run-benchmark-2-host-proxied reown-results upload-results download-results plot terminate terminate-enclave-server terminate-enclave-proxy terminate-host-server

# nitro-cli console always fails when the monitored enclave terminates
.IGNORE: debug-enclave-server

ENCLAVE_SERVER_CID ?= 42   # The CID for the enclave server
ENCLAVE_MEMORY ?= 2048 	   # Memory allocated for the enclave in MiB
ENCLAVE_VCPUS ?= 2         # Number of vCPUs allocated for the enclave
PROXY_TOOL ?= socat        # The proxy tool to use (socat, ncat)
PROXY_REUSE_DEPTH ?= 1     # The number of the proxy listener processes (implying reuseport option if greater than 1)
SO_RCVBUF_SIZE ?= 		   # The receive buffer size for the proxy sockets (empty to use the system defaults)
SO_SNDBUF_SIZE ?= 		   # The send buffer size for the proxy sockets (empty to use the system defaults)
SO_NONBLOCKING ?= 		   # Use non-blocking sockets for the proxies (empty=disabled)
SO_NO_DELAY ?= 		   	   # Disable Nagle's algorithm for TCP on the proxy sockets (empty=disabled)
SOCAT_FORK ?= yes	   	   # Use fork option for socat (empty=disabled)
REDIS_NUM_CLIENTS ?= 1     # The number of concurrent benchmark clients spawned by redis-benchmark
REDIS_PIPELINE ?= 1		   # The number of commands to send in parallel per client
REDIS_TESTS ?= ping,set,get,lrange_300   # The tests to run (empty=all default tests, lrange implicitly includes lpush)
DOCKER_NETWORK ?= redis-network			 # The name of the docker network to use for tcp/ip exposed services
CLIENT_CONNECT_HOST ?= redis-server		 # The host to connect to for the benchmark clients
S3_BUCKET ?= nitro-enclaves-result-bucket/redis # The S3 bucket to upload/download results
S3_PROFILE ?= 							 # The AWS profile to use for the S3 operations (if u want to authenticate via profiles)
PATH_METADATA ?= default/ignore # This will be embedded into the result path in the format 'instance_type-timestamp-git_hash'. Results with different directory depth (e.g. default/ignore) will be ignored by the plotting script. Different formats (i.e. not exactly 2x '-') may result in errors during plotting.

# QUICK START COMMANDS

help:  ## Show this help message
	@echo "Usage: make [<VAR=value> ...] <subcommand>"
	@echo ""
	@echo "Variables:"
	@grep -E '^[A-Z0-9_]+\s*\?=' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = " \\?= | # "}; {printf "\033[36m%-30s\033[0m = \033[33m%s\033[0m\n\t%s\n", $$1, $$2, ($$3 ? $$3 : "")}'
	@echo ""
	@echo "Subcommands:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'



prepare: build allocate ## Prepare the environment by building the enclaves and then allocating resources

allocate-configure: ## Configure the allocator.yaml for the enclave allocator service
	docker run --rm -v "$(shell pwd)/deploy":/workdir mikefarah/yq -i '.cpu_count = $(ENCLAVE_VCPUS) | .memory_mib = $(ENCLAVE_MEMORY)' allocator.yaml

allocate: allocate-configure ## Allocate memory and cpu cores via the enclave allocator service
	sudo cp deploy/allocator.yaml /etc/nitro_enclaves/allocator.yaml &&\
	sudo systemctl restart --now nitro-enclaves-allocator.service


# BUILD COMMANDS

build: build-containers build-enclave-server build-enclave-compact create-networks ## Build all containers, enclaves, and networks

build-containers:  ## Build the docker containers for servers, benchmark clients, and both
	docker build -t redis-bench \
	--build-arg PROXY_TOOL=$(PROXY_TOOL) \
	--build-arg PROXY_REUSE_DEPTH=$(PROXY_REUSE_DEPTH) \
	--build-arg SO_RCVBUF_SIZE=$(SO_RCVBUF_SIZE) \
	--build-arg SO_SNDBUF_SIZE=$(SO_SNDBUF_SIZE) \
	--build-arg SO_NONBLOCKING=$(SO_NONBLOCKING) \
	--build-arg SO_NO_DELAY=$(SO_NO_DELAY) \
	--build-arg SOCAT_FORK=$(SOCAT_FORK) \
	-f deploy/Dockerfile .
	@echo "Docker container \"redis-bench\" built successfully."
	docker build -t redis-compact \
	--build-arg NUM_CLIENTS=${REDIS_NUM_CLIENTS} \
	--build-arg PIPELINE=${REDIS_PIPELINE} \
	--build-arg REDIS_TESTS=${REDIS_TESTS} \
	--build-arg SCRIPT_NAME="./compact-enclave.sh" \
	-f deploy/Dockerfile .
	@echo "Docker container \"redis-compact\" built."

build-enclave-server:  ## Build the server enclave
	nitro-cli build-enclave --docker-uri redis-bench --output-file redis-server.eif

build-enclave-compact:  ## Build the compact enclave
	nitro-cli build-enclave --docker-uri redis-compact --output-file redis-compact.eif

create-networks:  ## Create the $DOCKER_NETWORK in docker if it does not exist
	@if [ -z "$$(docker network ls --filter name=$(DOCKER_NETWORK) -q)" ]; then \
		docker network create $(DOCKER_NETWORK); \
		echo docker network \"$(DOCKER_NETWORK)\" created.; \
	else \
		echo docker network \"$(DOCKER_NETWORK)\" already exists.; \
	fi

# RUN COMMANDS

run-enclave-server: build-containers build-enclave-server  ## Rebuild & Run the server in an enclave
	nitro-cli run-enclave --enclave-cid $(ENCLAVE_SERVER_CID) --eif-path redis-server.eif --cpu-count $(ENCLAVE_VCPUS) --memory $(ENCLAVE_MEMORY)

debug-enclave-server:  ## Debug the server in an enclave
	nitro-cli run-enclave --enclave-cid $(ENCLAVE_SERVER_CID) --eif-path redis-server.eif --cpu-count $(ENCLAVE_VCPUS) --memory $(ENCLAVE_MEMORY) --debug-mode &&\
	nitro-cli console --enclave-name redis-server

expose-enclave:  ## Expose the enclave-server to the $DOCKER_NETWORK
	docker run --rm --name redis-proxy --privileged --network $(DOCKER_NETWORK) \
		-e PROXY_TOOL=$(PROXY_TOOL) \
		-e PROXY_REUSE_DEPTH=$(PROXY_REUSE_DEPTH) \
		-e SO_RCVBUF_SIZE=$(SO_RCVBUF_SIZE) \
		-e SO_SNDBUF_SIZE=$(SO_SNDBUF_SIZE) \
		-e SO_NONBLOCKING=$(SO_NONBLOCKING) \
		-e SO_NO_DELAY=$(SO_NO_DELAY) \
		-e SOCAT_FORK=$(SOCAT_FORK) \
		-e SERVER_CID=$(ENCLAVE_SERVER_CID) \
		--entrypoint ./expose.sh redis-bench

expose-enclave-background:  ## Expose the enclave-server to the $DOCKER_NETWORK in the background
	docker run -d --rm --name redis-proxy --privileged --network $(DOCKER_NETWORK) \
		-e PROXY_TOOL=$(PROXY_TOOL) \
		-e PROXY_REUSE_DEPTH=$(PROXY_REUSE_DEPTH) \
		-e SO_RCVBUF_SIZE=$(SO_RCVBUF_SIZE) \
		-e SO_SNDBUF_SIZE=$(SO_SNDBUF_SIZE) \
		-e SO_NONBLOCKING=$(SO_NONBLOCKING) \
		-e SO_NO_DELAY=$(SO_NO_DELAY) \
		-e SOCAT_FORK=$(SOCAT_FORK) \
		-e SERVER_CID=$(ENCLAVE_SERVER_CID) \
		--entrypoint ./expose.sh redis-bench

run-host-server:  ## Run the server
	docker run --rm --name redis-server --network $(DOCKER_NETWORK) \
	--entrypoint ./server.sh redis-bench

run-host-server-background:  ## Run the server in the background
	docker run -d --rm --name redis-server --network $(DOCKER_NETWORK) \
	--entrypoint ./server.sh redis-bench

run-host-server-proxied:  ## Run the server with a proxy
	docker run --rm --name redis-server --network $(DOCKER_NETWORK) \
	-e PROXY_TOOL=$(PROXY_TOOL) \
	-e PROXY_REUSE_DEPTH=$(PROXY_REUSE_DEPTH) \
	-e SO_RCVBUF_SIZE=$(SO_RCVBUF_SIZE) \
	-e SO_SNDBUF_SIZE=$(SO_SNDBUF_SIZE) \
	-e SO_NONBLOCKING=$(SO_NONBLOCKING) \
	-e SO_NO_DELAY=$(SO_NO_DELAY) \
	-e SOCAT_FORK=$(SOCAT_FORK) \
	-e PROXY_ROUTE=tcp-2-tcp \
	redis-bench

run-host-server-proxied-background:  ## Run the server with a proxy in the background
	docker run -d --rm --name redis-server --network $(DOCKER_NETWORK) \
	-e PROXY_TOOL=$(PROXY_TOOL) \
	-e PROXY_REUSE_DEPTH=$(PROXY_REUSE_DEPTH) \
	-e SO_RCVBUF_SIZE=$(SO_RCVBUF_SIZE) \
	-e SO_SNDBUF_SIZE=$(SO_SNDBUF_SIZE) \
	-e SO_NONBLOCKING=$(SO_NONBLOCKING) \
	-e SO_NO_DELAY=$(SO_NO_DELAY) \
	-e SOCAT_FORK=$(SOCAT_FORK) \
	-e PROXY_ROUTE=tcp-2-tcp \
	redis-bench

run-benchmark-2-enclave:  ## Run the benchmark client to the enclave server
	$(eval RUN_DATA_PATH := $(shell pwd)/results/data/$(strip $(PATH_METADATA))/enclave-proxied/$(shell uuidgen))
	docker run --rm --privileged \
		-v $(RUN_DATA_PATH):/data \
		-e NUM_CLIENTS=$(REDIS_NUM_CLIENTS) \
		-e PIPELINE=$(REDIS_PIPELINE) \
		-e REDIS_TESTS=$(REDIS_TESTS) \
		-e PROXY_TOOL=$(PROXY_TOOL) \
		-e PROXY_REUSE_DEPTH=$(PROXY_REUSE_DEPTH) \
		-e SO_RCVBUF_SIZE=$(SO_RCVBUF_SIZE) \
		-e SO_SNDBUF_SIZE=$(SO_SNDBUF_SIZE) \
		-e SO_NONBLOCKING=$(SO_NONBLOCKING) \
		-e SO_NO_DELAY=$(SO_NO_DELAY) \
		-e SOCAT_FORK=$(SOCAT_FORK) \
		-e SERVER_CID=$(ENCLAVE_SERVER_CID) \
		--entrypoint ./benchmark-proxied.sh redis-bench

run-benchmark-2-host:  ## Run the benchmark client to the host server
	$(eval RUN_DATA_PATH := $(shell pwd)/results/data/$(strip $(PATH_METADATA))/host-direct/$(shell uuidgen))
	docker run --rm --network $(DOCKER_NETWORK) \
		-v $(RUN_DATA_PATH):/data \
		-e NUM_CLIENTS=$(REDIS_NUM_CLIENTS) \
		-e PIPELINE=$(REDIS_PIPELINE) \
		-e REDIS_TESTS=$(REDIS_TESTS) \
		-e REDIS_HOST=$(CLIENT_CONNECT_HOST) \
		--entrypoint ./benchmark.sh redis-bench

run-benchmark-2-host-proxied:  ## Run the benchmark client to the host server with a proxy
	$(eval RUN_DATA_PATH := $(shell pwd)/results/data/$(strip $(PATH_METADATA))/host-proxied/$(shell uuidgen))
	docker run --rm --network $(DOCKER_NETWORK) \
		-v $(RUN_DATA_PATH):/data \
		-e NUM_CLIENTS=$(REDIS_NUM_CLIENTS) \
		-e PIPELINE=$(REDIS_PIPELINE) \
		-e REDIS_TESTS=$(REDIS_TESTS) \
		-e PROXY_TOOL=$(PROXY_TOOL) \
		-e PROXY_REUSE_DEPTH=$(PROXY_REUSE_DEPTH) \
		-e SO_RCVBUF_SIZE=$(SO_RCVBUF_SIZE) \
		-e SO_SNDBUF_SIZE=$(SO_SNDBUF_SIZE) \
		-e SO_NONBLOCKING=$(SO_NONBLOCKING) \
		-e SO_NO_DELAY=$(SO_NO_DELAY) \
		-e SOCAT_FORK=$(SOCAT_FORK) \
		-e PROXY_ROUTE=tcp-2-tcp -e TCP_LISTEN_PORT=6379 -e TCP_CONNECT_PORT=5000 -e TCP_CONNECT_HOST=$(CLIENT_CONNECT_HOST) \
		--entrypoint ./benchmark-proxied.sh redis-bench

run-benchmark-compact-on-host:  ## Run both the benchmark client and server in a single docker container
	$(eval RUN_DATA_PATH := $(shell pwd)/results/data/$(strip $(PATH_METADATA))/host-compact/$(shell uuidgen))
	docker run --rm \
	-v $(RUN_DATA_PATH):/data \
	-e NUM_CLIENTS=$(REDIS_NUM_CLIENTS) \
	-e PIPELINE=$(REDIS_PIPELINE) \
	-e REDIS_TESTS=$(REDIS_TESTS) \
	--entrypoint ./compact.sh redis-bench

run-result-receiver:  ## Run the result receiver for compact-in-enclave benchmark
	docker ps --filter "name=redis-result-receiver" --format "{{.ID}}" | xargs -r docker stop
	docker run --rm --privileged -d \
	-v $(RUN_DATA_PATH):/data \
	--name redis-result-receiver \
	--entrypoint ./result-receiver.sh redis-bench

run-benchmark-compact-in-enclave: build-containers build-enclave-compact  ## Rebuild & Run both the benchmark client and server in an enclave
	$(eval RUN_DATA_PATH := $(shell pwd)/results/data/$(strip $(PATH_METADATA))/enclave-compact/$(shell uuidgen))
	$(MAKE) RUN_DATA_PATH=$(RUN_DATA_PATH) run-result-receiver
	nitro-cli run-enclave --enclave-cid $(ENCLAVE_SERVER_CID) --eif-path redis-compact.eif --cpu-count $(ENCLAVE_VCPUS) --memory $(ENCLAVE_MEMORY)

debug-benchmark-compact-in-enclave: build-containers build-enclave-compact  ## Rebuild & Debug both the benchmark client and server in an enclave
	$(eval RUN_DATA_PATH := $(shell pwd)/results/data/$(strip $(PATH_METADATA))/enclave-compact/$(shell uuidgen))
	$(MAKE) RUN_DATA_PATH=$(RUN_DATA_PATH) run-result-receiver
	nitro-cli run-enclave --enclave-cid $(ENCLAVE_SERVER_CID) --eif-path redis-compact.eif --cpu-count $(ENCLAVE_VCPUS) --memory $(ENCLAVE_MEMORY) --debug-mode &&\
	nitro-cli console --enclave-name redis-compact


# TRANSFER RESULTS

reown-results: ## Reown the results directory
	sudo chown -R $(shell whoami):$(shell whoami) results

upload-results: ## Upload the results to the S3 bucket
	aws $(if $(S3_PROFILE),--profile $(S3_PROFILE)) s3 sync results/data/ s3://$(strip $(S3_BUCKET))/data/ --exclude ".gitignore" --exclude ".gitkeep" --exclude ".DS_Store"

download-results: ## Download the results from the S3 bucket
	aws $(if $(S3_PROFILE),--profile $(S3_PROFILE)) s3 sync s3://$(strip $(S3_BUCKET))/data/ results/data/

# PLOT COMMANDS

plot: ## Plot the results
	(cd plot && Rscript plot.R)
	# mv plot/Rplots.pdf results/img/Rplots.pdf
	(cd plot && ./plot.py)
	@echo "Results plotted to results/img"


# TERMINATE/CLEANUP COMMANDS

terminate-enclave-server:  ## Terminate the enclave server
	nitro-cli terminate-enclave --enclave-name redis-server

terminate-enclave-proxy:  ## Terminate the proxy server to the enclave
	docker stop redis-proxy

terminate-host-server:  ## Terminate the host server
	docker stop redis-server

terminate:  ## Terminate all servers (ignoring errors)
	-$(MAKE) terminate-enclave-server
	-$(MAKE) terminate-enclave-proxy
	-$(MAKE) terminate-host-server
