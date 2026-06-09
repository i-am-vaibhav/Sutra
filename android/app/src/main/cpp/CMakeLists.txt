cmake_minimum_required(VERSION 3.22.1)

project(sutra_native)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Disable unsupported ARMv7 build
set(ANDROID_ABI arm64-v8a)

# llama.cpp options
set(GGML_LLAMAFILE OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP ON CACHE BOOL "" FORCE)

add_subdirectory(llama.cpp)

add_library(
    sutra_native
    SHARED
    sutra_llama.cpp
)

target_include_directories(
    sutra_native PRIVATE
    llama.cpp
    llama.cpp/include
)

target_link_libraries(
    sutra_native
    llama
    android
    log
)