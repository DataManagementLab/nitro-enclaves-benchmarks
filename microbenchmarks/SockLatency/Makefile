.PHONY: all prepare allocate build build-server build-server-container build-server-enclave build-proxy run-enclave-server debug-enclave-server run-host-server run-host-server-background run-host-client2host run-host-client2enclave run-proxy run-proxy-background run-proxy-tcp run-proxy-tcp-background reown-results upload-results download-results terminate-enclave-server terminate-host-server terminate-proxy terminate plot help

# nitro-cli console always fails when the monitored enclave terminates
.IGNORE: debug-enclave-server

ENCLAVE_SERVER_CID ?= 16   # The CID for the enclave server
ENCLAVE_MEMORY ?= 4096 	   # Memory allocated for the enclave in MiB
ENCLAVE_VCPUS ?= 4         # Number of vCPUs allocated for the enclave
ENCLAVE_VCPU_POOL ?= "1,2,5,6" # CPU id list allocated to the nitro allocator service - should align with ENCLAVE_VCPUS
PRINT_HEADER ?= yes        # Print the header in the results file. Set empty to disable.
CLIENT_TARGET_ADDR ?= 127.0.0.1 # The target host address for the client (inet/2host)
CLIENT_BUF_SIZE ?= 1024    # The buffer size for the client
CLIENT_MSG_SIZE ?= 64      # The message size for the client
CLIENT_PIN_CPU ?= 4        # pin the client to this CPU core (numactl)
NUM_SAMPLES ?= 1000000     # Number of roundtrip samples
NUM_WARMUP_ROUNDS ?= 10000 # Number of rounds to warmup (first N samples ignored in the results)
TIMEOUT_SEC ?= 0           # Timeout in seconds for the experiment
SERVER_PIN_CPU ?= 3        # pin the server to this CPU core (numactl) - WARNING: build-time only!
SERVER_BUF_SIZE ?= 1024    # The buffer size for the server - WARNING: build-time value used initially during run-enclave-server, but updated and adjusted eventually via client config after hello message.
SERVER_RSP_SIZE ?= 64      # The message size for the server
SERVER_PORT ?= 5005		   # Listen on this port
CLIENT_PORT ?= 5005		   # Connect on this port
DEBUG ?= OFF			   # Compile with -DDEBUG=ON flag
RESULT_FILE ?= results.csv # The file to save the results
S3_BUCKET ?= nitro-enclaves-result-bucket/SockLatency # The S3 bucket to upload/download results
S3_PROFILE ?= 			   # The AWS profile to use for the S3 operations (if u want to authenticate via profiles)


# QUICK START COMMANDS

help:  ## Show this help message
	@echo "Usage: make [<VAR=value> ...] <subcommand>"
	@echo ""
	@echo "Variables:"
	@grep -E '^[A-Z0-9_]+\s*\?=' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = " \\?= | # "}; {printf "\033[36m%-30s\033[0m = \033[33m%s\033[0m\n\t%s\n", $$1, $$2, ($$3 ? $$3 : "")}'
	@echo ""
	@echo "Subcommands:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

all: prepare ## All in one line - Prepare env, run benchmark (vsock + inet/loopback), shutdown servers, plot results
	@echo "Running Socket Latency benchmark (Host <--vsock--> Nitro Enclave)..."
	$(MAKE) run-enclave-server run-host-client2enclave terminate-enclave-server
	@echo "Running Socket Latency benchmark (Host <--inet--> Host)..."
	$(MAKE) PRINT_HEADER= run-host-server-background run-host-client2host terminate-host-server
	@echo "Plotting results..."
	$(MAKE) plot

all-no-nitro: build-server-container run-host-server-background run-host-client2host terminate-host-server plot ## All in one line (without nitro) - Build server container, run benchmark (inet/loopback), shutdown server, plot results

prepare: build allocate ## Prepare the environment by building the enclaves and then allocating resources

allocate-configure: ## Configure the allocator.yaml for the enclave allocator service
	docker run --rm -v "$(shell pwd)/deploy":/workdir mikefarah/yq -i '.cpu_pool = "$(ENCLAVE_VCPU_POOL)" | .memory_mib = $(ENCLAVE_MEMORY)' allocator.yaml

allocate: allocate-configure ## Allocate memory and cpu cores via the enclave allocator service
	sudo cp deploy/allocator.yaml /etc/nitro_enclaves/allocator.yaml &&\
	sudo systemctl restart --now nitro-enclaves-allocator.service


# BUILD COMMANDS

build: build-server build-proxy ## Build all containers and enclaves

build-server: build-server-container build-server-enclave ## Build the server container and enclave

build-server-container: ## Build the server container
	docker build \
	$(if $(DEBUG),--build-arg DEBUG=$(DEBUG)) \
	--build-arg $(SERVER_PORT) \
	-t socklatency:app -f deploy/Dockerfile .

build-server-enclave: ## Build the server enclave
	nitro-cli build-enclave --docker-uri socklatency:app --output-file socklatency-server.eif

build-proxy: ## Build the proxy container
	docker build -t socklatency:proxy -f deploy/Dockerfile-proxy .


# RUN COMMANDS

run-enclave-server: ## Run the server in an enclave
	nitro-cli run-enclave --enclave-cid $(ENCLAVE_SERVER_CID) --eif-path socklatency-server.eif --cpu-count $(ENCLAVE_VCPUS) --memory $(ENCLAVE_MEMORY)

debug-enclave-server: ## Debug the server in an enclave
	nitro-cli run-enclave --enclave-cid $(ENCLAVE_SERVER_CID) --eif-path socklatency-server.eif --cpu-count $(ENCLAVE_VCPUS) --memory $(ENCLAVE_MEMORY) --debug-mode &&\
	nitro-cli console --enclave-name socklatency-server

run-host-server: ## Run the server on the host
	docker run --rm --name socklatency-server --network=host \
		-e PROTOCOL=inet -e ADDRESS=0.0.0.0 -e PORT=$(SERVER_PORT) \
		-e BUF_SIZE=$(SERVER_BUF_SIZE) -e PIN_CPU=$(SERVER_PIN_CPU) \
		--entrypoint /scripts/run-server.sh socklatency:app

run-host-server-background: ## Run the server on the host in the background
	docker run -d --rm --name socklatency-server --network=host \
		-e PROTOCOL=inet -e ADDRESS=0.0.0.0 -e PORT=$(SERVER_PORT) \
		-e BUF_SIZE=$(SERVER_BUF_SIZE) -e PIN_CPU=$(SERVER_PIN_CPU) \
		--entrypoint /scripts/run-server.sh socklatency:app

run-host-client2host: ## Run the client (host to host) and save the results to results/data
	docker run --rm --name socklatency-client-inet --network=host \
		-e PROTOCOL=inet -e ADDRESS=$(CLIENT_TARGET_ADDR) -e PORT=$(CLIENT_PORT) \
		-v "$(shell pwd)/results/data":/data \
		-e RESULT_NAME=$(RESULT_FILE) -e PRINT_HEADER=$(PRINT_HEADER) \
		-e BUF_SIZE=$(CLIENT_BUF_SIZE) -e MSG_SIZE=$(CLIENT_MSG_SIZE) -e PIN_CPU=$(CLIENT_PIN_CPU) \
		-e SERVER_BUF_SIZE=$(SERVER_BUF_SIZE) -e SERVER_RSP_SIZE=$(SERVER_RSP_SIZE) \
		-e NUM_SAMPLES=$(NUM_SAMPLES) -e NUM_WARMUP_ROUNDS=$(NUM_WARMUP_ROUNDS) -e TIMEOUT_SEC=$(TIMEOUT_SEC) \
		--entrypoint /scripts/run-client.sh socklatency:app
	@echo "Results saved to results/data/${RESULT_FILE}"

run-host-client2enclave: ## Run the client (host to enclave) and save the results to results/data
	docker run --rm --name socklatency-client-vsock --privileged \
		-e PROTOCOL=vsock -e ADDRESS=$(ENCLAVE_SERVER_CID) -e PORT=$(CLIENT_PORT) \
		-v "$(shell pwd)/results/data":/data \
		-e RESULT_NAME=$(RESULT_FILE) -e PRINT_HEADER=$(PRINT_HEADER) \
		-e BUF_SIZE=$(CLIENT_BUF_SIZE) -e MSG_SIZE=$(CLIENT_MSG_SIZE) -e PIN_CPU=$(CLIENT_PIN_CPU) \
		-e SERVER_BUF_SIZE=$(SERVER_BUF_SIZE) -e SERVER_RSP_SIZE=$(SERVER_RSP_SIZE) \
		-e NUM_SAMPLES=$(NUM_SAMPLES) -e NUM_WARMUP_ROUNDS=$(NUM_WARMUP_ROUNDS) -e TIMEOUT_SEC=$(TIMEOUT_SEC) \
		--entrypoint /scripts/run-client.sh socklatency:app
	@echo "Results saved to results/data/${RESULT_FILE}"

run-proxy: ## Run the proxy container
	docker run --rm --name socklatency-proxy --network=host --privileged \
		-e SERVER_CID=$(ENCLAVE_SERVER_CID) -e CLIENT_PORT=$(CLIENT_PORT) -e SERVER_PORT=$(SERVER_PORT) socklatency:proxy

run-proxy-background: ## Run the proxy container in the background
	docker run -d --rm --name socklatency-proxy --network=host --privileged \
		-e SERVER_CID=$(ENCLAVE_SERVER_CID) -e CLIENT_PORT=$(CLIENT_PORT) -e SERVER_PORT=$(SERVER_PORT) socklatency:proxy

run-proxy-tcp: ## Run the proxy container
	docker run --rm --name socklatency-proxy --network=host --privileged \
		-e SERVER_CID=$(ENCLAVE_SERVER_CID) -e CLIENT_PORT=$(CLIENT_PORT) -e SERVER_PORT=$(SERVER_PORT) socklatency:proxy

run-proxy-tcp-background: ## Run the proxy container in the background
	docker run -d --rm --name socklatency-proxy --network=host --privileged \
		-e PROTOCOL=tcp -e CLIENT_PORT=$(CLIENT_PORT) -e SERVER_PORT=$(SERVER_PORT) socklatency:proxy


# TRANSFER RESULTS

reown-results: ## Reown the results directory
	sudo chown -R $(shell whoami):$(shell whoami) results

upload-results: ## Upload the results to the S3 bucket
	aws $(if $(S3_PROFILE),--profile $(S3_PROFILE)) s3 cp results/data/$(strip $(RESULT_FILE)) s3://$(strip $(S3_BUCKET))/$(strip $(RESULT_FILE))

download-results: ## Download the results from the S3 bucket
	aws $(if $(S3_PROFILE),--profile $(S3_PROFILE)) s3 sync s3://$(strip $(S3_BUCKET))/ results/data/


# PLOT COMMANDS

plot: ## Plot the results
	(cd plot && Rscript plot.R)
	# mv plot/Rplots.pdf results/img/Rplots.pdf
	(cd plot && ./plot.py)
	@echo "Results plotted to results/img"

# CLEAN/TERMINATE COMMANDS

terminate: ## Terminate all servers (ignoring errors)
	-$(MAKE) terminate-enclave-server
	-$(MAKE) terminate-host-server
	-$(MAKE) terminate-proxy

terminate-enclave-server: ## Terminate the server enclave
	nitro-cli terminate-enclave --all

terminate-host-server: ## Terminate the server on the host
	docker stop socklatency-server

terminate-proxy: ## Terminate the proxy container
	docker stop socklatency-proxy
