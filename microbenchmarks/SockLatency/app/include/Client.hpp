// Client.hpp
#pragma once

#include <iostream>
#include <cstring>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <linux/vm_sockets.h>
#include <unistd.h>
#include <memory>
#include <vector>

// local includes
#include "Logger.hpp"
#include "myTypes.h"


struct ClientConfig {
    size_t buf_size;
    size_t msg_size;
};

struct ExperimentConfig;

class Client
{
protected:
    int sock = 0;
    Client(const SocketProtocol protocol, const size_t buf_size);
    void connectToServer();
    virtual struct sockaddr *getSockAddr(socklen_t *len) const = 0;
    virtual int checkBufferSizes(const ExperimentConfig& conf) const = 0;

private:
    std::unique_ptr<char[]> buf;
    void handshake(const ExperimentConfig &config);

    std::vector<double> measureRTT(const size_t num_samples, const size_t msg_size);
    std::vector<double> measureRTT(const size_t num_max_samples, const size_t msg_size, const double timeout_sec);
    std::vector<double> measureRTTLarge(const size_t num_max_samples, const size_t msg_size, const size_t rsp_exp_size,const double timeout_sec);
    // std::vector<double> measureRTT(double timeout_sec);

public:
    const SocketProtocol protocol;
    const size_t buf_size;

    static std::unique_ptr<Client> make(const SocketProtocol protocol, const std::string& adr, const int port, const size_t buf_size);
    ~Client();

    Client(const Client &) = delete;
    Client(Client &&) = delete;
    Client() = delete;

    void run(const ExperimentConfig &config);
};

class InetClient : public Client {
public:
    InetClient(const std::string& adr, const int port, const size_t buf_size);
    struct sockaddr *getSockAddr(socklen_t *len) const override { *len = sizeof(serv_addr); return (struct sockaddr*)&serv_addr; }
    int checkBufferSizes(const ExperimentConfig& conf) const override;
private:
    struct sockaddr_in serv_addr;
};

class VsockClient : public Client {
public:
    VsockClient(const std::string& adr, const int port, const size_t buf_size);
    struct sockaddr *getSockAddr(socklen_t *len) const override { *len = sizeof(serv_addr); return (struct sockaddr*)&serv_addr; }
    int checkBufferSizes(const ExperimentConfig& conf) const override;
private:
    struct sockaddr_vm serv_addr;
};
