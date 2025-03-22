#pragma once

#include <sys/socket.h>
#include <string>

constexpr size_t THRESH_LARGE_MSG = 1024;

enum SocketProtocol {
    INET,
    VSOCK
};

// adress family conversion
int af_from_enum(const SocketProtocol protocol)
{
    switch (protocol)
    {
    case INET:
        return AF_INET;
    case VSOCK:
        return AF_VSOCK;
    default:
        return -1;
    }
}

std::string to_string(const SocketProtocol protocol)
{
    switch (protocol)
    {
    case INET:
        return "inet";
    case VSOCK:
        return "vsock";
    default:
        return "unknown";
    }
}

std::ostream& operator<<(std::ostream& os, const SocketProtocol& protocol) {
    os << to_string(protocol);
    return os;
}

struct ServerDynamicConfig {
    size_t buf_size;
    size_t rsp_size;
    size_t req_size;

    std::string to_string() const {
        return "ServerDynamicConfig{ buf_size: " + std::to_string(buf_size) + 
               ", rsp_size: " + std::to_string(rsp_size) + ", req_size: " + std::to_string(req_size) + " }";
    }
};
