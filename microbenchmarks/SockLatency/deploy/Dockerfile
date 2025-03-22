# this file requires to be built with the build context pointing to microbenchmarks/SockLatency
FROM amazonlinux:2

# Install git + build tools
RUN yum update -y && yum install -y \
  unzip \
  tar \
  bzip2 \
  autoconf \
  curl \
  git \
  openssl \
  cmake3 \
  gcc10 gcc10-c++ \
  make \
  numactl \
  && yum clean all

ARG CC=gcc10-gcc
ARG CXX=gcc10-g++

WORKDIR /tmp

# copy source code & build project
COPY ./app /tmp/src
ARG DEBUG=OFF
RUN cmake3 \
  -DCMAKE_BUILD_TYPE:STRING=Release \
  -DCMAKE_EXPORT_COMPILE_COMMANDS:BOOL=FALSE \
  -DCMAKE_AR:FILEPATH=gcc10-ar \
  $([ "${DEBUG}" = "ON" ] && echo "-DDEBUG=ON") \
  --no-warn-unused-cli \
  -S/tmp/src \
  -B/tmp/build \
  -G "Unix Makefiles" && \
  cmake3 --build /tmp/build --config Release --target all && \
  mkdir /app && \
  cp /tmp/build/server /app/server && \
  cp /tmp/build/client /app/client && \
  rm -rf /tmp/

# copy the entrypoint scripts
COPY ./scripts /scripts
RUN chmod +x /scripts/*

# set the config environment variables
ARG PORT=
ENV PROTOCOL="vsock"
ENV ADDRESS="-1"
ENV PORT=$PORT

# run the server
ENTRYPOINT /scripts/run-server.sh
