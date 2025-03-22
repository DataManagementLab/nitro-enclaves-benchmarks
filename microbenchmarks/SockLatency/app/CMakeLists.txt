# CMakeLists.txt in the root directory
cmake_minimum_required(VERSION 3.15)
project(SockLatency VERSION 1.0 LANGUAGES CXX)

# Set the C++ standard
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# AddressSanitizer flags
set(ENABLE_ASAN OFF CACHE BOOL "Enable AddressSanitizer")
if(ENABLE_ASAN)
    message(STATUS "AddressSanitizer enabled")

    if (CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    # set(ASAN_COMP_FLAGS "-fsanitize=address -fno-omit-frame-pointer")
        set(ASAN_COMP_FLAGS "-fsanitize=address")
        set(ASAN_LNK_FLAGS "-fsanitize=address")
    endif()
endif(ENABLE_ASAN)

# Add include directory for headers
include_directories(include)

# Add external libraries
include(FetchContent)
# Fetch and build gflags
FetchContent_Declare(
    gflags
    GIT_REPOSITORY https://github.com/gflags/gflags.git
    GIT_TAG v2.2.2  # You can set the version tag or use master for the latest version
)
FetchContent_MakeAvailable(gflags)

# Add the executable from the src/main.cpp file
# add_executable(socklprof src/main.cpp src/Server.cpp src/Client.cpp src/Logger.cpp)
add_executable(server src/Server.cpp src/Logger.cpp)
add_executable(client src/Client.cpp src/Logger.cpp)

# link dependant libraries here
# target_link_libraries(socklprof gflags::gflags)
target_link_libraries(server gflags::gflags)
target_link_libraries(client gflags::gflags)

# further target configuration
# Compiler flags
if(ENABLE_ASAN)
    message(STATUS "AddressSanitizer enabled for targets server and client")
    if (ASAN_COMP_FLAGS)
        target_compile_options(server PRIVATE ${ASAN_COMP_FLAGS})
        target_compile_options(client PRIVATE ${ASAN_COMP_FLAGS})
    endif()
    if (ASAN_LNK_FLAGS)
        target_link_options(server PRIVATE ${ASAN_LNK_FLAGS})
        target_link_options(client PRIVATE ${ASAN_LNK_FLAGS})
    endif()
endif()