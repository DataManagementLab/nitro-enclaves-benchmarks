
// app/main.cpp
#include <iostream>
#include <cstring>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <linux/vm_sockets.h>
#include <unistd.h>
#include <memory>

// local includes
#include "myTypes.h"
#include "Utilities.hpp"

class Server
{
protected:
    int server_fd, client_con_fd;
    Server(const SocketProtocol protocol, const size_t buf_size);
    void startServer();
    void acceptConnection();
    virtual struct sockaddr *getSockAddrServer(socklen_t *len) const = 0;
    virtual struct sockaddr *getSockAddrClient(socklen_t *len) const = 0;

private:
    ServerDynamicConfig config;
    std::unique_ptr<char[]> buf;

    void applyConfig(ServerDynamicConfig &cfg);
    void handshake();
    void handleClient();

public:
    const SocketProtocol protocol;

    static std::unique_ptr<Server> make(const SocketProtocol protocol, const std::string &adr, const int port, const size_t buf_size);
    ~Server();

    Server(const Server &) = delete;
    Server(Server &&) = delete;
    Server() = delete;

    void run();
    size_t getBufSize() const { return config.buf_size; }
};

class InetServer : public Server
{
public:
    InetServer(const std::string &adr, const int port, const size_t buf_size);
    struct sockaddr *getSockAddrServer(socklen_t *len) const override { *len = sizeof(sockaddr_in); return (struct sockaddr *)&address; }
    struct sockaddr *getSockAddrClient(socklen_t *len) const override { *len = sizeof(sockaddr_in); return (struct sockaddr *)&client_addr; }
private:
    struct sockaddr_in address, client_addr;
};

class VsockServer : public Server
{
public:
    VsockServer(const std::string &adr, const int port, const size_t buf_size);
    struct sockaddr *getSockAddrServer(socklen_t *len) const override { *len = sizeof(sockaddr_vm); return (struct sockaddr *)&address; }
    struct sockaddr *getSockAddrClient(socklen_t *len) const override { *len = sizeof(sockaddr_vm); return (struct sockaddr *)&client_addr; }
private:
    struct sockaddr_vm address, client_addr;
};