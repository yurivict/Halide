##
# Load Python dependencies, including external pybind11
##

find_package(Python3 REQUIRED COMPONENTS Interpreter Development)

# Adding PyBind11 to the build is the recommended way of integrating with CMake.
# See: https://pybind11.readthedocs.io/en/stable/compiling.html

include(FetchContent)
FetchContent_Declare(pybind11 GIT_REPOSITORY https://github.com/pybind/pybind11.git GIT_TAG v2.5.0)

# Configure pybind11 to use the same interpreter version as was detected above.
message(STATUS "Directing pybind11 to Python3 executable ${Python3_EXECUTABLE}")
set(PYTHON_EXECUTABLE ${Python3_EXECUTABLE})

# Import PyBind11
FetchContent_MakeAvailable(pybind11)

##
# Convenience function for creating shell paths
##

function(make_shell_path OUTVAR)
    if (WIN32)
        set(SEP "\\$<SEMICOLON>")
    else ()
        set(SEP ":")
    endif ()

    list(TRANSFORM ARGN REPLACE "^(.+)$" "$<SHELL_PATH:\\1>")
    string(REPLACE ";" "${SEP}" ARGN "${ARGN}")
    set(${OUTVAR} "${ARGN}" PARENT_SCOPE)
endfunction()

##
# Add our sources to this sub-tree.
##

add_subdirectory(src)
include(stub/CMakeLists.txt)

option(WITH_TEST_PYTHON "Build Python tests" ON)
if (WITH_TESTS AND WITH_TEST_PYTHON)
    add_subdirectory(apps)
    add_subdirectory(correctness)
    add_subdirectory(tutorial)
endif ()
