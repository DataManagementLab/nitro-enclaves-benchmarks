// app/Server.cpp
#include "Server.hpp"

#include "Logger.hpp"
#include "options.hpp"

Server::Server(const SocketProtocol protocol, const size_t buf_size) : 
    protocol(protocol), buf(std::make_unique<char[]>(buf_size)), config(), server_fd(-1), client_con_fd(-1)
{
    config.buf_size = buf_size;
    int opt = 1;

    // Creating socket file descriptor
    if ((server_fd = socket(af_from_enum(protocol), SOCK_STREAM, 0)) <= 0) {
        error("Socket failed with ERROR: " + std::string(strerror(errno)));
        throw std::runtime_error("Socket failed");
    }

    // Set SO_REUSEADDR option
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt))) {
        error("Setsockopt SO_REUSEADDR failed");
        close(server_fd);
        throw std::runtime_error("Setsockopt SO_REUSEADDR failed");
    }

    // Set SO_REUSEPORT option
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt))) {
        error("Setsockopt SO_REUSEPORT failed");
        close(server_fd);
        throw std::runtime_error("Setsockopt SO_REUSEPORT failed");
    }
}

std::unique_ptr<Server> Server::make(const SocketProtocol protocol, const std::string &adr, const int port, const size_t buf_size) {
    if (protocol == SocketProtocol::INET) {
        return std::make_unique<InetServer>(adr, port, buf_size);
    } else if (protocol == SocketProtocol::VSOCK) {
        return std::make_unique<VsockServer>(adr, port, buf_size);
    } else {
        throw std::invalid_argument("Unsupported protocol");
    }
}

InetServer::InetServer(const std::string &adr, const int port, const size_t buf_size) : Server(SocketProtocol::INET, buf_size), address(), client_addr()
{
    // Define the server address
    address.sin_family = AF_INET;
    // address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(port);

    if (inet_pton(AF_INET, adr.c_str(), &address.sin_addr) <= 0) {
        error("Invalid address / Address not supported");
        throw std::runtime_error("Invalid address / Address not supported");
    }
}

VsockServer::VsockServer(const std::string &adr, const int port, const size_t buf_size) : Server(SocketProtocol::VSOCK, buf_size), address(), client_addr()
{
    // Define the server address
    address.svm_family = AF_VSOCK;
    address.svm_port = port;
    address.svm_cid = (uint32_t) std::stoul(adr);  // typically VMADDR_CID_ANY = -1U
}

void Server::startServer()
{
    socklen_t addrlen;
    const sockaddr *addr = getSockAddrServer(&addrlen);

    // Bind the socket to the address and port
    if (bind(server_fd, addr, addrlen) < 0) {
        error("Bind failed with " + std::string(strerror(errno)));
        close(server_fd);
        throw std::runtime_error("Bind failed");
    }

    // Start listening for connections
    if (listen(server_fd, 3) < 0) {
        error("Listen failed");
        close(server_fd);
        throw std::runtime_error("Listen failed");
    }

    logger("Server is waiting for connections...");
}

void Server::acceptConnection()
{
    socklen_t addrlen;
    sockaddr *addr = getSockAddrClient(&addrlen);

    // Accept an incoming connection
    if ((client_con_fd = accept(server_fd, addr, &addrlen)) < 0) {
        std::cerr << "Accept failed" << std::endl;
        close(server_fd);
        throw std::runtime_error("Accept failed");
    }

    logger("Client connected.");
}

void Server::applyConfig(ServerDynamicConfig &cfg)
{
    if (cfg.buf_size != getBufSize())
    {
        buf = std::make_unique<char[]>(cfg.buf_size);
    }
    config = cfg;
}
void Server::handshake()
{
    // Receive hello message from client
    ServerDynamicConfig cfg;
    const int msg_len = read(client_con_fd, buf.get(), getBufSize());
    cfg = *reinterpret_cast<ServerDynamicConfig*>(buf.get());
    logger("Server Config updated from client: " + cfg.to_string());

    // apply config
    applyConfig(cfg);

    // Respond with hello message to client
    char hello[] = "Hello from server";
    send(client_con_fd, hello, strlen(hello), 0);
    logger("Hello message sent to client");
}

void Server::handleClient()
{
    // Continuously read messages from the client and respond until the client closes the socket
    int64_t msg_len;
    std::string rsp(config.rsp_size, 'a');
    if (config.rsp_size > THRESH_LARGE_MSG || config.req_size > THRESH_LARGE_MSG)
    {
        while ((msg_len = readall(client_con_fd, buf.get(), config.req_size)) > 0) [[likely]] {

            #ifdef DEBUG
            logger("Message from client: " + std::to_string(msg_len) + "(" + std::string(buf.get()) + ")");
            memset(buf.get(), 0, getBufSize()); // Clear the buffer after each read
            #endif

            // respond to the client
            sendall(client_con_fd, rsp);
        }
    }

    else
    {
        while ((msg_len = read(client_con_fd, buf.get(), getBufSize())) > 0) [[likely]] {

            #ifdef DEBUG
            logger("Message from client: " + std::to_string(msg_len) + "(" + std::string(buf.get()) + ")");
            memset(buf.get(), 0, getBufSize()); // Clear the buffer after each read
            #endif

            // respond to the client
            send(client_con_fd, rsp.c_str(), rsp.length(), 0);
        }
    }

    if (msg_len == 0) {
        logger("Client disconnected.");
    } else if (msg_len < 0) {
        error("Read error occurred.");
    }

    // Close the client socket
    close(client_con_fd);
    logger("Client connection closed. waiting for new connection...");
}

void Server::run()
{

    startServer();

    while(true)
    {
        acceptConnection();

        handshake();

        handleClient();
    }

}
Server::~Server()
{
    // Close the server socket
    close(server_fd);
}


int main(int argc, char *argv[]) {

    int rc = 0;

    gflags::SetUsageMessage("Socket latency microbenchmark - SERVER");
    gflags::ParseCommandLineFlags(&argc, &argv, false);

    auto server = Server::make(getProtocol(), FLAGS_address, FLAGS_port, FLAGS_buf_size);
    server->run();

    return rc;
}
// app/Server.cpp