#!/bin/bash

variation=${1:-"s"}

source ./expose-host-proxy.sh
./run-cross-instance.sh "" "" "$variation"
