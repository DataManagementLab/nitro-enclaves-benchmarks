FROM ubuntu:jammy

# Install git + build tools
RUN apt-get update && apt-get install -y \
    git \
    gcc \
    g++ \
    make \
    autoconf \
    automake \
    libtool \
 && rm -rf /var/lib/apt/lists/*

# Clone your project
RUN git clone https://github.com/stefano-garzarella/iperf-vsock.git /app

# Build the project
WORKDIR /app/build
RUN \
  # ../bootstrap.sh &&\
  ../configure &&\
  make

WORKDIR /app/build/src
ADD scripts/start_servers.sh start_servers.sh
RUN chmod +x start_servers.sh

ARG NUM_SERVERS_ARG=1
ENV NUM_SERVERS=$NUM_SERVERS_ARG

# Run the iperf server
ENTRYPOINT [ "/app/build/src/start_servers.sh" ]
