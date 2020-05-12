cmake_minimum_required(VERSION 3.16)
project(cuda_mat_mul)

# TODO: do we need to add automatic cuda propagation to dependent targets of add_halide_library?
find_package(CUDA)
if (NOT CUDA_FOUND)
    # This message hints to CTest ("[SKIP]") that this test should be marked as skipped rather than failed
    message(FATAL_ERROR "[SKIP] Could NOT find CUDA")
endif ()

enable_testing()

# Set up language settings
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED YES)
set(CMAKE_CXX_EXTENSIONS NO)

# Find Halide
find_package(Halide REQUIRED)

# Generator
add_executable(mat_mul.generator mat_mul_generator.cpp)
target_link_libraries(mat_mul.generator PRIVATE Halide::Generator)

# Filters
add_halide_library(mat_mul FROM mat_mul.generator
                   FEATURES cuda cuda_capability_50
                   PARAMS size=1024)

# Main executable
add_executable(runner runner.cpp)
target_include_directories(runner
                           PRIVATE
                           ${CUDA_INCLUDE_DIRS})
target_link_libraries(runner
                      PRIVATE
                      ${CUDA_LIBRARIES}
                      ${CUDA_CUBLAS_LIBRARIES}
                      Halide::Tools
                      mat_mul)

# Test that the app actually works!
add_test(NAME mat_mul COMMAND runner)
