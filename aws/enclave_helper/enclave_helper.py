#!/usr/local/bin/env python3

# This Code is based on the code from the following repository with some modifications and enhancements
# for sending command results and files from an AWS nitro enclave over vsock sockets:
# Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

from typing import Union, List
import argparse
import socket
import sys
import logging
import shlex, os
import subprocess as sp

RECV_SIZE = 1024

def logger() -> logging.Logger:
    return logging.getLogger(__name__)

class VsockStream:
    """Client"""
    def __init__(self, conn_tmo=5):
        self.conn_tmo = conn_tmo

    def connect(self, endpoint):
        """Connect to the remote endpoint"""
        self.sock = socket.socket(socket.AF_VSOCK, socket.SOCK_STREAM)
        self.sock.settimeout(self.conn_tmo)
        self.sock.connect(endpoint)

    def send_data(self, data):
        """Send data to a remote endpoint"""
        self.sock.sendall(data)

    def recv_data(self):
        """Receive data from a remote endpoint"""
        while True:
            data = self.sock.recv(RECV_SIZE).decode()
            if not data:
                break
            print(data, end='', flush=True)
        print()

    def disconnect(self):
        """Close the client socket"""
        self.sock.close()


def client_handler(args:argparse.Namespace):
    client = VsockStream()
    endpoint = (args.cid, args.port)

    logger().debug(f'client.connect({endpoint})...')
    client.connect(endpoint)

    msg = f'executing subprocess {repr(args.cmd)}...'
    logger().debug(f'connected. trying to send "{msg}"...')
    client.send_data(f'{msg}\n'.encode())

    call_sp_and_stream_stdout(client, *args.cmd)

    if args.file:
        if args.file_port:
            client.disconnect()
            client = VsockStream()
            endpoint = (args.cid, args.file_port)

            logger().debug(f'client.connect({endpoint})...')
            client.connect(endpoint)

        stream_file(client, args.file)

    client.disconnect()

def call_sp_and_stream_stdout(client:VsockStream, *cmd:str):

    proc = sp.Popen(cmd, stdout=sp.PIPE, stderr=sp.STDOUT, bufsize=0, cwd=os.getcwd(), shell=True)
    logger().info('process started')

    while proc.poll() is None:
        line = proc.stdout.readline()

        if not line:
            break

        client.send_data(line)

    term_msg = f'process terminated with code {proc.returncode}. Goodbye.'
    logger().info(term_msg)
    client.send_data(f'[enclave_helper.client] {term_msg}\n'.encode())

def stream_file(client:VsockStream, file:str):
    logger().info(f'transfer file {file}...')
    with open(file, 'r', encoding='UTF-8') as f:
        client.send_data(f.read().encode())
    pass

class VsockListener:
    """Server"""
    def __init__(self, outfile, conn_backlog=128):
        self.conn_backlog = conn_backlog
        self.out = outfile

    def bind(self, port):
        """Bind and listen for connections on the specified port"""
        self.sock = socket.socket(socket.AF_VSOCK, socket.SOCK_STREAM)
        self.sock.bind((socket.VMADDR_CID_ANY, port))
        self.sock.listen(self.conn_backlog)

    def recv_data(self):
        """Receive data from a remote endpoint"""
        while True:
            (from_client, (remote_cid, remote_port)) = self.sock.accept()
            logger().info(f"Connection opened by cid={remote_cid} port={remote_port}")
            # Read RECV_SIZE bytes at a time
            while True:
                try:
                    data = from_client.recv(RECV_SIZE).decode()
                except socket.error:
                    break
                if not data:
                    break
                self.out.write(data) 
            self.out.write('\n')
            from_client.close()
            logger().info("Connection Closed.")

    def send_data(self, data):
        """Send data to a renote endpoint"""
        while True:
            (to_client, (remote_cid, remote_port)) = self.sock.accept()
            to_client.sendall(data)
            to_client.close()

    def write_to_file(self, data:str):
        with open(self.outfile, 'a') as f:
            f.write(data)

def server_handler(args:argparse.Namespace):
    server = VsockListener(outfile=args.outfile)
    server.bind(args.port)
    server.recv_data()

def main():
    parser = argparse.ArgumentParser(prog='enclave_helper')
    parser.add_argument("--version", action="version",
                        help="Prints version information.",
                        version='%(prog)s 0.1.0')
    parser.add_argument("-l", "--loglevel", help="The logging level for log messages.",
                        choices=['NOTSET','DEBUG','INFO','WARNING','CRITICAL'],default='WARNING')
    subparsers = parser.add_subparsers(title="options")

    client_parser = subparsers.add_parser("client", description="Client",
                                          help="Connect to a given cid and port.")
    client_parser.add_argument("cid", type=int, help="The remote endpoint CID.")
    client_parser.add_argument("port", type=int, help="The remote endpoint port.")
    client_parser.add_argument("-c", "--cmd", nargs="+", help="The subprocess command to be executed.")
    client_parser.add_argument("-f","--file", required=False,
                               help="Transfer file at given path to server post-command execution.")
    client_parser.add_argument("-ep", "--error-port", type=int, help="Send STDERR of the subcommand to this seperate remote endpoint port.")
    client_parser.add_argument("-fp", "--file-port", type=int, help="Send `file` after subcommand execution to this seperate remote endpoint port.")
    client_parser.set_defaults(func=client_handler)

    server_parser = subparsers.add_parser("server", description="Server",
                                          help="Listen on a given port.")
    server_parser.add_argument("port", type=int, help="The local port to listen on.")
    server_parser.add_argument("-o", "--outfile", type=argparse.FileType('w', encoding='UTF-8', bufsize=1),
                               help="write output into given filepath",
                               default='-')
    server_parser.set_defaults(func=server_handler)

    if len(sys.argv) < 2:
        parser.print_usage()
        sys.exit(1)

    args = parser.parse_args()
    logging.basicConfig(level=args.loglevel)
    args.func(args)


if __name__ == "__main__":
    main()
