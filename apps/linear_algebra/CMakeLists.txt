cmake_minimum_required(VERSION 3.14)
project(linear_algebra)

enable_testing()

# Set up language settings
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED YES)
set(CMAKE_CXX_EXTENSIONS NO)

# Find Halide
find_package(Halide REQUIRED COMPONENTS Halide)

# Find BLAS-es
unset(DEFAULT_BLAS)
unset(BLAS_TARGETS)
set(BLAS_VENDORS OpenBLAS)  # TODO: add ATLAS and its weird extra linking requirements

message(STATUS "Checking for available CBLAS implementations")
foreach (BLA_VENDOR IN LISTS BLAS_VENDORS)
    find_package(BLAS QUIET)
    if (NOT BLAS_FOUND)
        message(STATUS "${BLA_VENDOR}: Missing")
    else ()
        find_path(CBLAS_PATH cblas.h)
        if (NOT CBLAS_PATH)
            message(FATAL_ERROR "Could not find cblas.h in the include path and FindBLAS doesn't report it.")
        endif ()

        message(STATUS "${BLA_VENDOR}: Found")
        add_library(BLAS_${BLA_VENDOR} INTERFACE)
        add_library(${BLA_VENDOR}::${BLA_VENDOR} ALIAS BLAS_${BLA_VENDOR})

        target_link_libraries(BLAS_${BLA_VENDOR} INTERFACE ${BLAS_LIBRARIES})
        target_link_options(BLAS_${BLA_VENDOR} INTERFACE ${BLAS_LINKER_FLAGS})
        target_include_directories(BLAS_${BLA_VENDOR} INTERFACE ${CBLAS_PATH})

        # Work around packaging issue in vcpkg on x64-windows
        if (WIN32 AND CMAKE_SIZEOF_VOID_P EQUAL 8 AND "${BLA_VENDOR}" STREQUAL "OpenBLAS")
            target_compile_definitions(BLAS_${BLA_VENDOR} INTERFACE OS_WINNT __64BIT__)
        endif ()

        if (NOT DEFAULT_BLAS)
            set(DEFAULT_BLAS ${BLA_VENDOR}::${BLA_VENDOR})
        endif ()

        list(APPEND BLAS_TARGETS ${BLA_VENDOR})
    endif ()
endforeach ()

if (NOT BLAS_TARGETS)
    message(FATAL_ERROR "Could not find any BLAS libraries! Searched among ${BLAS_VENDORS}")
endif ()

# Load in the rest of the project.
add_subdirectory(src)
add_subdirectory(tests)
add_subdirectory(benchmarks)
