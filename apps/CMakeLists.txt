##
# Test apps from the perspective of a consuming project.
##

# Set up a test fixture for installing the main project into a build directory

set(HALIDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/_Halide_install")

# TODO: "remove_directory" deprecated and replaced by "rm -rf" as of CMake 3.17.
add_test(NAME delete_halide_distrib
         COMMAND ${CMAKE_COMMAND} -E remove_directory "${HALIDE_DIR}")

set_tests_properties(delete_halide_distrib PROPERTIES
                     FIXTURES_SETUP apps)

# TODO: if we can support CMake 3.15+, we can use ${CMAKE_COMMAND} --install ...
add_test(NAME create_halide_distrib
         COMMAND ${CMAKE_COMMAND} "-DCMAKE_INSTALL_PREFIX=${HALIDE_DIR}" -P cmake_install.cmake
         WORKING_DIRECTORY ${Halide_BINARY_DIR})

set_tests_properties(create_halide_distrib PROPERTIES
                     FIXTURES_SETUP apps
                     DEPENDS delete_halide_distrib)

function(add_app_test NAME)
    unset(cmakeOpts)
    if (NOT "${CMAKE_TOOLCHAIN_FILE}" STREQUAL "")
        set(cmakeOpts "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
    endif ()

    unset(cmakeGenOpts)
    if (NOT "${CMAKE_GENERATOR_TOOLSET}" STREQUAL "")
        list(APPEND cmakeGenOpts --build-generator-toolset "${CMAKE_GENERATOR_TOOLSET}")
    endif ()
    if (NOT "${CMAKE_GENERATOR_PLATFORM}" STREQUAL "")
        list(APPEND cmakeGenOpts --build-generator-platform "${CMAKE_GENERATOR_PLATFORM}")
    endif ()

    add_test(NAME ${NAME}
             COMMAND ${CMAKE_CTEST_COMMAND}
             --build-and-test "${CMAKE_CURRENT_SOURCE_DIR}/${NAME}" "${CMAKE_CURRENT_BINARY_DIR}/${NAME}"
             --build-generator "${CMAKE_GENERATOR}"
             ${cmakeGenOpts}
             --build-config "${CMAKE_BUILD_TYPE}"
             --build-options
             "-DCMAKE_PREFIX_PATH=${HALIDE_DIR}"
             "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
             "-DLLVM_DIR=${LLVM_DIR}"
             ${cmakeOpts}
             --test-command ${CMAKE_CTEST_COMMAND} -C ${CMAKE_BUILD_TYPE} -V)
    set_tests_properties(${NAME} PROPERTIES FIXTURES_REQUIRED apps LABELS apps)
endfunction()

# Actually add the apps

add_app_test(bgu)
add_app_test(bilateral_grid)
add_app_test(blur)
#add_app_test(c_backend)  # TODO: implement support for the C backend.
add_app_test(camera_pipe)
add_app_test(conv_layer)
add_app_test(cuda_mat_mul)
#add_app_test(glsl)  # TODO: bugged on my computer; not built by Makefile
add_app_test(harris)
add_app_test(hist)
add_app_test(iir_blur)
add_app_test(interpolate)
add_app_test(lens_blur)
#add_app_test(linear_algebra)  # TODO: halide blas has issues; see #4631
#add_app_test(linear_blur)  # TODO: uses stubs, for which we're dropping CMake support
add_app_test(local_laplacian)
add_app_test(max_filter)
add_app_test(nl_means)
add_app_test(resize)
add_app_test(stencil_chain)
add_app_test(unsharp)
add_app_test(wavelet)

# Add the autoschedulers. TODO: refactor into separate modules
add_subdirectory(autoscheduler)
add_subdirectory(gradient_autoscheduler)
