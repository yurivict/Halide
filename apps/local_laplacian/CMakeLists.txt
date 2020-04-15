cmake_minimum_required(VERSION 3.14)
project(local_laplacian)

enable_testing()

# Set up language settings
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED YES)
set(CMAKE_CXX_EXTENSIONS NO)

# Find Halide
find_package(Halide REQUIRED)

# Generator
add_executable(local_laplacian.generator local_laplacian_generator.cpp)
target_link_libraries(local_laplacian.generator PRIVATE Halide::Generator Halide::Tools)

# Filters
add_halide_library(local_laplacian FROM local_laplacian.generator)
add_halide_library(local_laplacian_auto_schedule FROM local_laplacian.generator
                   GENERATOR local_laplacian
                   PARAMS auto_schedule=true)

# Main executable
add_executable(local_laplacian_process process.cpp)
target_link_libraries(local_laplacian_process
                      PRIVATE
                      Halide::Runtime
                      Halide::ImageIO
                      local_laplacian
                      local_laplacian_auto_schedule)

# Test that the app actually works!
set(IMAGE ${CMAKE_CURRENT_LIST_DIR}/../images/rgb.png)
if (EXISTS ${IMAGE})
    configure_file(${IMAGE} rgb.png COPYONLY)
    add_test(NAME local_laplacian_process
             COMMAND local_laplacian_process rgb.png 8 1 1 10 out.png)

    if (WIN32)
        # On Windows, need Halide.dll to be in the PATH
        set_tests_properties(local_laplacian_filter PROPERTIES
                             ENVIRONMENT "PATH=$<SHELL_PATH:$<TARGET_FILE_DIR:Halide::Halide>>$<SEMICOLON>$ENV{PATH}")
    endif ()
endif ()
