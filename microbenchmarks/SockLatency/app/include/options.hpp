
#pragma once

#include <string>
#include <sstream>
#include <vector>
#include "gflags/gflags.h"

#include "myTypes.h"


DEFINE_int32(port, 5005, "Port number to listen on or request to connect to");
DEFINE_string(address, "127.0.0.1", "Address to listen on or request to connect to");
DEFINE_string(protocol, "inet", "Socket protocol to use (inet or vsock)");
DEFINE_uint32(buf_size, 1024, "Size of the read buffer");
// DEFINE_uint32(msg_size, 64, "The message size to send");

SocketProtocol getProtocol() {
    if (FLAGS_protocol == "inet") {
        return SocketProtocol::INET;
    } else if (FLAGS_protocol == "vsock") {
        return SocketProtocol::VSOCK;
    } else {
        throw std::runtime_error("Invalid protocol");
    }
}
