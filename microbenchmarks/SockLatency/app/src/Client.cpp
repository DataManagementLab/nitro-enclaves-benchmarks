// app/Client.cpp
#include "Client.hpp"

#include "chrono"
#include "vector"
#include "numeric"
#include "algorithm"
#include "fstream"
#include "sstream"
#include <netinet/tcp.h> // For TCP_MAXSEG


#include "Logger.hpp"
#include "Utilities.hpp"

// shared opts
#include "options.hpp"
// client opts
DEFINE_uint32(msg_size, 64, "The message size to send");
DEFINE_uint32(server_buf_size, 1024, "Size of the read buffer on the server");
DEFINE_uint32(server_rsp_size, 64, "The message size to respond from the server");
DEFINE_uint64(num_samples, 100000, "Number of samples to take");
DEFINE_uint64(num_warmup_rounds, 0, "Number of rounds considered as warmup");
DEFINE_double(perc_warmup_rounds, 10.0, "Number of rounds considered as warmup in percent of actual samples");
DEFINE_double(timeout_sec, 0, "Timeout in seconds for the experiment to run. Checked every 1k round-trips.");
DEFINE_bool(output_outliers, false, "Output outliers in the results");
DEFINE_string(outfile, "", "Output file for results");
DEFINE_bool(print_header, true, "Print header in output file");

// argument parsing

struct ExperimentConfig {
    SocketProtocol protocol;
    ServerDynamicConfig server_config;
    ClientConfig client_config;
    size_t num_samples;
    size_t num_warmup_rounds;
    double perc_warmup_rounds;
    double timeout_sec;

    std::string to_string() const;
    static std::string csv_header();
    std::string to_csv() const;

    friend std::ostream& operator<<(std::ostream& os, const ExperimentConfig& config);
};

void parseExperimentConfig(ExperimentConfig &config) {
    config.protocol = getProtocol();
    config.server_config.buf_size = FLAGS_server_buf_size;
    config.server_config.rsp_size = FLAGS_server_rsp_size;
    config.server_config.req_size = FLAGS_msg_size;
    config.client_config.buf_size = FLAGS_buf_size;
    config.client_config.msg_size = FLAGS_msg_size;
    config.num_samples = FLAGS_num_samples;
    config.num_warmup_rounds = FLAGS_num_warmup_rounds;
    config.perc_warmup_rounds = FLAGS_perc_warmup_rounds;
    config.timeout_sec = FLAGS_timeout_sec;
}

std::string ExperimentConfig::to_string() const {
    std::ostringstream oss;
    oss << "ExperimentConfig{ "
            << "protocol: " << protocol << ", "
            << "server_config{ buf_size: " << server_config.buf_size << ", "
            << "rsp_size: " << server_config.rsp_size << ", "
            << "req_size: " << server_config.req_size << " }, "
            << "client_config{ buf_size: " << client_config.buf_size << ", "
            << "msg_size: " << client_config.msg_size << " }, "
            << "num_samples: " << num_samples << ", "
            << "num_warmup_rounds: " << num_warmup_rounds << ", "
            << "num_warmup_rounds: " << num_warmup_rounds << ", "
            << "timeout_sec: " << timeout_sec
        << " }";
    return oss.str();
}

std::string ExperimentConfig::csv_header() {
    return "protocol,server.buf_size,server.rsp_size,client.buf_size,client.msg_size,num_samples,num_warmup_rounds,timeout_sec";
}

std::string ExperimentConfig::to_csv() const {
    std::ostringstream oss;
    oss << protocol << ","
        << server_config.buf_size << ","
        << server_config.rsp_size << ","
        << client_config.buf_size << ","
        << client_config.msg_size << ","
        << num_samples << ","
        << num_warmup_rounds << ","
        << timeout_sec;
    return oss.str();
}

std::ostream& operator<<(std::ostream& os, const ExperimentConfig& config) {
    os << config.to_string();
    return os;
}

size_t calc_warmup_rounds(const ExperimentConfig& config, const size_t num_samples)
{
    if (config.num_warmup_rounds > 0 && config.num_warmup_rounds < num_samples)
        return config.num_warmup_rounds;
    else
        return static_cast<size_t>(num_samples * config.perc_warmup_rounds / 100.0);
}

void output_results_aggregated(const ExperimentConfig& config, const std::vector<double>& results, const bool printHeader, const bool output_outliers, const std::string outfile = "")
{
    // Ensure num_warmup_rounds is within valid range
    const size_t num_warmup_rounds = calc_warmup_rounds(config, results.size());

    // copy, convert, and sort results
    std::vector<double> sorted_results(results.begin() + num_warmup_rounds, results.end());
    std::sort(sorted_results.begin(), sorted_results.end());

    // simple statistics
    const uint64_t num_measurements = sorted_results.size();
    const double min = sorted_results[0];
    const double max = sorted_results.back();
    const double p99 = sorted_results[num_measurements * 0.99];
    const double p999 = sorted_results[num_measurements * 0.999];
    const double avg = std::accumulate(sorted_results.begin(), sorted_results.end(), 0.0) / num_measurements;
    const double median = sorted_results[num_measurements * 0.5];
    const double q25 = sorted_results[num_measurements * 0.25];
    const double q75 = sorted_results[num_measurements * 0.75];

    // advanced - boxplot outlier calculation
    const double iqr = q75 - q25;
    double lower_bound = q25 - 1.5 * iqr;
    double upper_bound = q75 + 1.5 * iqr;
    std::stringstream outliers_lo;
    std::stringstream outliers_hi;
    std::string outliers_lo_str("");
    std::string outliers_hi_str("");
    uint64_t num_outliers_lo = 0;
    uint64_t num_outliers_hi = 0;
    if (lower_bound < min)
    {
        // no outliers
        lower_bound = min;
    }
    else
    {
        // outliers exist
        auto it_end = sorted_results.begin() + (num_measurements * 0.25);  // outliers are below q25
        for (auto it = sorted_results.begin(); it != it_end ; it++)
            if (*it < lower_bound)
            {
                num_outliers_lo++;
                if (output_outliers) outliers_lo << *it << "|";
            }
            else
                break;

        if (output_outliers)
        {
            outliers_lo_str = outliers_lo.str();
            outliers_lo_str.pop_back();  // remove trailing "|"
            outliers_lo.clear();
        }
    }
    if (upper_bound > max)
    {
        // no outliers
        upper_bound = max;
    }
    else
    {
        // outliers exist
        auto it_end = sorted_results.rbegin() + (num_measurements * 0.25) + 1;  // outliers are above q75, +1 because I'm too lazy to think about one-off errors here...
        for (auto it = sorted_results.rbegin(); it != it_end; it++)
            if (*it > upper_bound)
            {
                num_outliers_hi++;
                if (output_outliers) outliers_hi << *it << "|";
            }
            else
                break;

        if (output_outliers)
        {
            outliers_hi_str = outliers_hi.str();
            outliers_hi_str.pop_back();  // remove trailing "|"
            outliers_hi.clear();
        }
    }

    // setup out stream
    std::ostream& out = outfile.size() ? *(new std::ofstream(outfile, std::ios_base::app)) : std::cout;

    // output header
    if (printHeader) csv::write_csv(out, config.csv_header(), "act_sample_count", "act_warmup_rounds",
        "min",
        "max",
        "p99",
        "p999",
        "avg",
        "median",
        "q25",
        "q75",
        "lower_bound",
        "upper_bound",
        "num_outliers_lo",
        "num_outliers_hi",
        "outliers_lo",
        "outliers_hi");
    // output results
    csv::write_csv(out, config.to_csv(), num_measurements, num_warmup_rounds,
        min,
        max,
        p99,
        p999,
        avg,
        median,
        q25,
        q75,
        lower_bound,
        upper_bound,
        num_outliers_lo,
        num_outliers_hi,
        outliers_lo_str,
        outliers_hi_str);

    // cleanup
    if (outfile.size()) delete &out;
}

Client::Client(const SocketProtocol protocol, const size_t buf_size) :
    protocol(protocol), buf_size(buf_size), buf(std::make_unique<char[]>(buf_size)) {
        if ((sock = socket(af_from_enum(protocol), SOCK_STREAM, 0)) < 0) {
            error("Socket creation error");
            throw std::runtime_error("Socket creation error");
        }
    }

Client::~Client(){}

void Client::connectToServer() {

    socklen_t addrlen;
    const sockaddr *addr = getSockAddr(&addrlen);

    if (connect(sock, addr, addrlen) < 0) {
        error("Connection failed");
        throw std::runtime_error("Connection failed");
    }
    logger("Connected to server");
}

std::unique_ptr<Client> Client::make(const SocketProtocol protocol, const std::string& adr, const int port, const size_t buf_size) {
    if (protocol == SocketProtocol::INET) {
        return std::make_unique<InetClient>(adr, port, buf_size);
    } else if (protocol == SocketProtocol::VSOCK) {
        return std::make_unique<VsockClient>(adr, port, buf_size);
    } else {
        throw std::invalid_argument("Unsupported protocol");
    }    
}

InetClient::InetClient(const std::string& adr, const int port, const size_t buf_size) : Client(SocketProtocol::INET, buf_size), serv_addr() {

    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);

    if (inet_pton(AF_INET, adr.c_str(), &serv_addr.sin_addr) <= 0) {
        error("Invalid address / Address not supported");
        throw std::runtime_error("Invalid address / Address not supported");
    }

    connectToServer();
}

VsockClient::VsockClient(const std::string& adr, const int port, const size_t buf_size) : Client(SocketProtocol::VSOCK, buf_size), serv_addr() {

    serv_addr.svm_family = AF_VSOCK;
    serv_addr.svm_port = port;
    serv_addr.svm_cid = std::stoul(adr);

    connectToServer();
}

int InetClient::checkBufferSizes(const ExperimentConfig& conf) const {

    int rc = 0;
    int sock_buf_size;
    socklen_t optlen = sizeof(sock_buf_size);

    // Check the current send buffer size
    if (getsockopt(sock, SOL_SOCKET, SO_SNDBUF, &sock_buf_size, &optlen) == -1) {
        rc--;
        error("ERROR: getsockopt (SOL_SOCKET,SO_SNDBUF) failed");
    } else {
        logger("Send buffer size: " + std::to_string(sock_buf_size));
        if (conf.server_config.buf_size < conf.client_config.msg_size) {
            rc--;
            error("ERROR: Client Message size exceeds server receive buffer size");
        }
        if (sock_buf_size < conf.client_config.msg_size) {
            // rc--;
            error("WARNING: Client Message size exceeds send buffer size");
        }
    }

    // Check the current receive buffer size
    if (getsockopt(sock, SOL_SOCKET, SO_RCVBUF, &sock_buf_size, &optlen) == -1) {
        rc--;
        error("ERROR: getsockopt (SOL_SOCKET,SO_RCVBUF) failed");
    } else {
        logger("Receive buffer size: " + std::to_string(sock_buf_size));
        if (conf.client_config.buf_size < conf.server_config.rsp_size) {
            rc--;
            error("ERROR: Server Response size exceeds client receive buffer size");
        }
        if (sock_buf_size < conf.server_config.rsp_size) {
            // rc--;
            error("WARNING: Server Response size exceeds SO_RCVBUF size");
        }
        if (sock_buf_size < conf.client_config.buf_size) {
            // rc--;
            error("WARNING: Client buffer size exceeds SO_RCVBUF size");
        }
    }

    // Get the maximum segment size
    if (getsockopt(sock, IPPROTO_TCP, TCP_MAXSEG, &sock_buf_size, &optlen) == -1) {
        rc--;
        error("ERROR: getsockopt (IPPROTO_TCP,TCP_MAXSEG) failed");
    } else {
        logger("Maximum Segment Size (MSS): " + std::to_string(sock_buf_size));
        if (sock_buf_size < conf.client_config.msg_size) {
            // rc--;
            error("WARNING: Client Message size "+ std::to_string(conf.client_config.msg_size) +" exceeds Maximum Segment Size");
        }
        if (sock_buf_size < conf.server_config.rsp_size) {
            // rc--;
            error("WARNING: Server Response size "+ std::to_string(conf.server_config.rsp_size) +" exceeds Maximum Segment Size");
        }
    }

    return rc;
}

int VsockClient::checkBufferSizes(const ExperimentConfig& conf) const {

    int rc = 0;
    int sock_buf_size;
    socklen_t optlen = sizeof(sock_buf_size);

    // Check the current send buffer size
    if (getsockopt(sock, SOL_SOCKET, SO_SNDBUF, &sock_buf_size, &optlen) == -1) {
        rc--;
        error("ERROR: getsockopt (SOL_SOCKET,SO_SNDBUF) failed");
    } else {
        logger("Send buffer size: " + std::to_string(sock_buf_size));
        if (conf.server_config.buf_size < conf.client_config.msg_size) {
            rc--;
            error("ERROR: Client Message size exceeds server receive buffer size");
        }
        if (sock_buf_size < conf.client_config.msg_size) {
            // rc--;
            error("WARNING: Client Message size exceeds send buffer size");
        }
    }

    // Check the current receive buffer size
    if (getsockopt(sock, SOL_SOCKET, SO_RCVBUF, &sock_buf_size, &optlen) == -1) {
        rc--;
        error("ERROR: getsockopt (SOL_SOCKET,SO_RCVBUF) failed");
    } else {
        logger("Receive buffer size: " + std::to_string(sock_buf_size));
        if (conf.client_config.buf_size < conf.server_config.rsp_size) {
            rc--;
            error("ERROR: Server Response size exceeds client receive buffer size");
        }
        if (sock_buf_size < conf.server_config.rsp_size) {
            // rc--;
            error("WARNING: Server Response size exceeds receive buffer size");
        }
        if (sock_buf_size < conf.client_config.buf_size) {
            // rc--;
            error("WARNING: Client buffer size exceeds receive buffer size");
        }
    }

    return rc;
}

void Client::handshake(const ExperimentConfig &config)
{
    // prepare hello/config message
    auto hello = std::make_unique<uint8_t[]>(sizeof(config.server_config));
    std::memcpy(hello.get(), &config.server_config, sizeof(config.server_config));

    // Send message to server
    send(sock, hello.get(), sizeof(config.server_config), 0);
    logger("Hello message sent to server");

    // Receive handshake message from the server
    read(sock, buf.get(), buf_size);
    logger("Message from server: " + std::string(buf.get()));
}

void Client::run(const ExperimentConfig &config)
{

    // check buffer sizes
    if (checkBufferSizes(config) < 0)
        throw std::runtime_error("Buffer size check failed");

    // handshake with server
    handshake(config);

    // run experiment
    std::vector<double> rtt_samples;
    if (config.client_config.msg_size > THRESH_LARGE_MSG || config.server_config.rsp_size > THRESH_LARGE_MSG)
        rtt_samples = measureRTTLarge(config.num_samples, config.client_config.msg_size, config.server_config.rsp_size, config.timeout_sec ? config.timeout_sec : 10.0);
    else
        if (config.timeout_sec == 0)
            rtt_samples = measureRTT(config.num_samples, config.client_config.msg_size);
        else
            rtt_samples = measureRTT(config.num_samples, config.client_config.msg_size, config.timeout_sec);

    // Close the connection
    close(sock);

    // output results
    output_results_aggregated(config, rtt_samples, FLAGS_print_header, FLAGS_output_outliers, FLAGS_outfile);
}

std::vector<double> Client::measureRTT(const size_t num_samples, const size_t msg_size)
{
    // vector to store RTT samples
    std::vector<double> rtt_samples;
    rtt_samples.reserve(num_samples);

    // allocations for RTT measurement
    std::chrono::duration<double, std::micro> rtt;
    std::chrono::time_point<std::chrono::high_resolution_clock> start;
    std::chrono::time_point<std::chrono::high_resolution_clock> end;

    logger("Measuring RTT for " + std::to_string(num_samples) + " samples...");

    std::string msg(msg_size, 'a');
    int rsp_len;
    int rc_send;

    for (size_t i = 0; i < num_samples; i++)
    {

        // capture start ts
        start = std::chrono::high_resolution_clock::now();

        // Send message to server
        rc_send = send(sock, msg.c_str(), msg.length(), 0);
        if (rc_send != msg_size) [[unlikely]] {
            error("Send failed. Error: " + std::string(strerror(errno)));
            throw std::runtime_error("Send failed");
        }
        #ifdef DEBUG
        logger("Message sent to server");
        #endif

        // Receive message from server
        rsp_len = read(sock, buf.get(), buf_size);
        #ifdef DEBUG
        logger("Response from server: " + std::to_string(rsp_len) + " (" + std::string(buf.get()) + ")");
        #endif

        // measure RTT
        end = std::chrono::high_resolution_clock::now();
        rtt = end - start;
        rtt_samples.push_back(rtt.count());

        #ifdef DEBUG
        // modify msg
        msg[i % msg_size] += ((msg[i % msg_size] - 'a' + 1) % 26 + 'a');  // rotate through alphabet
        #endif
    }

    return rtt_samples;
}

std::vector<double> Client::measureRTT(const size_t num_max_samples, const size_t msg_size, const double timeout_sec)
{
    // vector to store RTT samples
    std::vector<double> rtt_samples;
    rtt_samples.reserve(num_max_samples);
    constexpr size_t timeout_check_interval = 1000;
    if (num_max_samples % timeout_check_interval != 0)
    {
        error("WARNING: num_max_samples should be a multiple of timeout_check_interval=" + std::to_string(timeout_check_interval));
    }

    // allocations for RTT measurement and timeout
    std::chrono::duration<double, std::micro> rtt;
    std::chrono::time_point<std::chrono::high_resolution_clock> start;
    std::chrono::time_point<std::chrono::high_resolution_clock> last;
    std::chrono::time_point<std::chrono::high_resolution_clock> end;

    logger("Measuring RTT for up to " + std::to_string(num_max_samples) + " samples or " + std::to_string(timeout_sec) + " seconds...");

    std::string msg(msg_size, 'a');
    int rsp_len;
    int rc_send;

    start = std::chrono::high_resolution_clock::now();
    for (size_t i = 0; i < num_max_samples; i += timeout_check_interval)
    {
        for (size_t j = 0; j < timeout_check_interval; j++)
        {

            // capture start ts
            last = std::chrono::high_resolution_clock::now();

            // Send message to server
            rc_send = send(sock, msg.c_str(), msg.length(), 0);
            if (rc_send != msg_size) [[unlikely]] {
                error("Send failed. Error: " + std::string(strerror(errno)));
                throw std::runtime_error("Send failed");
            }
            #ifdef DEBUG
            logger("Message sent to server");
            #endif

            // Receive message from server
            rsp_len = read(sock, buf.get(), buf_size);
            #ifdef DEBUG
            logger("Response from server: " + std::to_string(rsp_len) + " (" + std::string(buf.get()) + ")");
            #endif

            // measure RTT
            end = std::chrono::high_resolution_clock::now();
            rtt = end - last;
            rtt_samples.push_back(rtt.count());

            #ifdef DEBUG
            // modify msg
            msg[i % msg_size] += ((msg[i % msg_size] - 'a' + 1) % 26 + 'a');  // rotate through alphabet
            #endif
        }

        // check timeout
        if (std::chrono::duration<double>(end - start).count() >= timeout_sec) [[unlikely]]
        {
            logger("Timeout reached after " + std::to_string(i+timeout_check_interval) + " samples");
            break;
        }

    }

    rtt_samples.shrink_to_fit();
    return rtt_samples;
}

std::vector<double> Client::measureRTTLarge(const size_t num_max_samples, const size_t msg_size, const size_t rsp_exp_size, const double timeout_sec)
{
    // sanity check
    if (rsp_exp_size > buf_size) {
        error("Internal buffer size is smaller than expected response size");
        throw std::runtime_error("Buffer size is smaller than response size");
    }

    // vector to store RTT samples
    std::vector<double> rtt_samples;
    rtt_samples.reserve(num_max_samples);
    constexpr size_t timeout_check_interval = 1000;
    if (num_max_samples % timeout_check_interval != 0)
    {
        error("WARNING: num_max_samples should be a multiple of timeout_check_interval=" + std::to_string(timeout_check_interval));
    }

    // allocations for RTT measurement and timeout
    std::chrono::duration<double, std::micro> rtt;
    std::chrono::time_point<std::chrono::high_resolution_clock> start;
    std::chrono::time_point<std::chrono::high_resolution_clock> last;
    std::chrono::time_point<std::chrono::high_resolution_clock> end;

    logger("Measuring RTT for up to " + std::to_string(num_max_samples) + " samples or " + std::to_string(timeout_sec) + " seconds...");

    std::string msg(msg_size, 'a');
    int64_t rsp_len;
    int64_t rc_send;

    start = std::chrono::high_resolution_clock::now();
    for (size_t i = 0; i < num_max_samples; i += timeout_check_interval)
    {
        for (size_t j = 0; j < timeout_check_interval; j++)
        {

            // capture start ts
            last = std::chrono::high_resolution_clock::now();

            #ifdef DEGUG
            size_t iter = 0;
            rc_send = sendall_dbg(sock, msg, iter);
            #else
            rc_send = sendall(sock, msg);
            #endif
            if (rc_send != msg_size) [[unlikely]] {
                error("Send failed. Error: " + std::string(strerror(errno)));
                throw std::runtime_error("Send failed");
            }
            #ifdef DEBUG
            logger("Message sent to server in " + std::to_string(iter) + " iterations.");
            #endif

            // Receive message from server
            #ifdef DEBUG
            rsp_len = readall_dbg(sock, buf.get(), rsp_exp_size, iter);
            #else
            rsp_len = readall(sock, buf.get(), rsp_exp_size);
            #endif
            if (rsp_len != rsp_exp_size) [[unlikely]] {
                if (rsp_len < 0)
                    error("Read failed. Error: " + std::string(strerror(errno)));
                else
                    error("Read failed. Peer disconnected.");
                throw std::runtime_error("Read failed");
            }
            #ifdef DEBUG
            logger("Response from server in " + std::to_string(iter) + " iterations: " + std::to_string(rsp_len) + " (" + std::string(buf.get()) + ")");
            #endif

            // measure RTT
            end = std::chrono::high_resolution_clock::now();
            rtt = end - last;
            rtt_samples.push_back(rtt.count());

            #ifdef DEBUG
            // modify msg
            msg[i % msg_size] += ((msg[i % msg_size] - 'a' + 1) % 26 + 'a');  // rotate through alphabet
            #endif
        }

        // check timeout
        if (std::chrono::duration<double>(end - start).count() >= timeout_sec) [[unlikely]]
        {
            logger("Timeout reached after " + std::to_string(i+timeout_check_interval) + " samples");
            break;
        }

    }

    rtt_samples.shrink_to_fit();
    return rtt_samples;
}

// main
int main(int argc, char *argv[]) {

    int rc = 0;

    gflags::SetUsageMessage("Socket latency microbenchmark - CLIENT");
    gflags::ParseCommandLineFlags(&argc, &argv, false);

    ExperimentConfig config;
    parseExperimentConfig(config);

    auto client = Client::make(config.protocol, FLAGS_address, FLAGS_port, config.client_config.buf_size);
    // Client client(getProtocol(), FLAGS_address, FLAGS_port, FLAGS_buf_size);
    client->run(config);

    return rc;
}
