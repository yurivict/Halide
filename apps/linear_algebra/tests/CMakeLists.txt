add_executable(test_halide_blas test_halide_blas.cpp)
target_link_libraries(test_halide_blas PRIVATE ${DEFAULT_BLAS} halide_blas)
add_test(NAME test_halide_blas COMMAND test_halide_blas)
