FROM iperf3-vsock:server

WORKDIR /app/build/src
COPY scripts/bench*.sh .

RUN chmod +x bench*.sh

ARG IPERF_SERVER_CID
ENV IPERF_SERVER_CID=$IPERF_SERVER_CID
RUN echo "building client for server cid: ${IPERF_SERVER_CID}"

# Run the iperf server
ENTRYPOINT [ "/app/build/src/bench.sh" ]
