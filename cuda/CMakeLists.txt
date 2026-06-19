cmake_minimum_required(VERSION 3.18)
project(gpu_zbuffer_renderer LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CUDA_STANDARD 14)

add_executable(renderer src/renderer.cu)

# Turing(75) / Ampere(86) / Ada-RTX40xx(89). Adjust to your GPU if needed.
set_target_properties(renderer PROPERTIES CUDA_ARCHITECTURES "75;86;89")

if(MSVC)
    target_compile_options(renderer PRIVATE $<$<COMPILE_LANGUAGE:CUDA>:-O2>)
else()
    target_compile_options(renderer PRIVATE $<$<COMPILE_LANGUAGE:CUDA>:-O2>)
endif()
