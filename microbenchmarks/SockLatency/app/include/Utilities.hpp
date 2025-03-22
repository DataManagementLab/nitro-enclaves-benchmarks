#pragma once

#include <cstring>
#include <atomic>
#include <cassert>
#include <string> 
#include <iostream>
#include <fstream>
#include <sys/types.h>
#include <sys/socket.h>
#include <unistd.h>

namespace csv {

template <typename output, typename Arg>
void write_csv(output& out, Arg arg) {
   out << std::to_string(arg);
}

template <typename output>
void write_csv(output& out, std::string arg) {
   out << arg;
}

template <typename output>
void write_csv(output& out, const char*& arg) {
   out << arg;
}

template <typename output, typename First, typename... Args>
void write_csv(output &out, First first, Args... args) {
   write_csv( out, first);
   write_csv( out, std::string(","));
   if constexpr (sizeof...(Args) == 1) {
         write_csv(out, args...);
         write_csv(out, std::string("\n"));
      }else{
      write_csv(out, args...);
   }
}

}  // csv

namespace tyme {

   // CPU frequency on sgx06. 2.2 GHz. Pls change this value if you are running on a different machine!
   const float CPU_FREQUENCY = 2.9e9;
   const float CPU_FREQUENCY_kHZ = CPU_FREQUENCY / 1e3;
   const float CPU_FREQUENCY_MHZ = CPU_FREQUENCY / 1e6;
   const float CPU_FREQUENCY_GHZ = CPU_FREQUENCY / 1e9;

   static __inline__ float cycles_to_nanoseconds(uint64_t cycles) {
      return cycles / CPU_FREQUENCY_GHZ;
   }
   static __inline__ float cycles_to_microseconds(uint64_t cycles) {
      return cycles / CPU_FREQUENCY_MHZ;
   }
   static __inline__ float cycles_to_milliseconds(uint64_t cycles) {
      return cycles / CPU_FREQUENCY_kHZ;
   }
   static __inline__ float cycles_to_seconds(uint64_t cycles) {
      return cycles / CPU_FREQUENCY;
   }
}  // tyme

inline
int64_t sendall(int sock, std::string &msg) {
   size_t total = 0;
   size_t len = msg.size();
   size_t bytesleft = len;
   int n;

   while (total < len) {
      n = send(sock, msg.c_str() + total, bytesleft, 0);
      if (n <= 0) [[unlikely]] { return n; }
      total += n;
      bytesleft -= n;
   }

   return total;
}

inline
int64_t readall(int sock, char *buf, size_t len) {
   size_t total = 0;
   size_t bytesleft = len;
   int n;

   while (total < len) {
      n = read(sock, buf + total, bytesleft);
      if (n <= 0) [[unlikely]] { return n; }
      total += n;
      bytesleft -= n;
   }

   return total;

}

inline
int64_t sendall_dbg(int sock, std::string &msg, size_t &iter) {
   size_t total = 0;
   size_t len = msg.size();
   size_t bytesleft = len;
   int n;
   iter = 0;

   while (total < len) {
      n = send(sock, msg.c_str() + total, bytesleft, 0);
      iter++;
      if (n <= 0) [[unlikely]] { return n; }
      total += n;
      bytesleft -= n;
   }

   return total;
}

inline
int64_t readall_dbg(int sock, char *buf, size_t len, size_t &iter) {
   size_t total = 0;
   size_t bytesleft = len;
   int n;
   iter = 0;

   while (total < len) {
      n = read(sock, buf + total, bytesleft);
      iter++;
      if (n <= 0) [[unlikely]] { return n; }
      total += n;
      bytesleft -= n;
   }

   return total;

}