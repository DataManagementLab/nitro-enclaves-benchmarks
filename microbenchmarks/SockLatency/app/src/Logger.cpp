#include "Logger.hpp"

#include <iostream>
#include <iomanip>
#include <ctime>
#include <sstream>
#include "gflags/gflags.h"

DEFINE_bool(debug, false, "Toggle debug outputs.");
DEFINE_bool(log_time, true, "Include Timestamp in log messages. Only Useful with debug=1.");

std::string timeStamp(){
    std::ostringstream strStream;
    std::time_t t = std::time(nullptr);
    strStream<< "[" << std::put_time(std::localtime(&t), "%F %T %Z") << "] ";
    return strStream.str();
}

void logger(const std::string &str, bool error) {
    if (FLAGS_debug && !error) {
        auto prefix = FLAGS_log_time ? timeStamp() : "";
        std::cout << prefix << str << std::endl;
    } else if (error) {
        auto prefix = FLAGS_log_time ? timeStamp() : "";
        std::cerr << prefix << str << std::endl;
    }
}

void error(const std::string &str) {
    logger(str, true);
}
