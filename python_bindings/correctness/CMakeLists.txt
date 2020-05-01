set(GENERATORS
    complexstub_generator.cpp
    nobuildmethod_generator.cpp
    partialbuildmethod_generator.cpp
    simplestub_generator.cpp
    )

foreach (GEN IN LISTS GENERATORS)
    string(REPLACE "_generator.cpp" "" TARGET "${GEN}")
    add_generator_python(${TARGET} ${GEN})
endforeach ()

# Handle addconstant, bit, user_context
add_subdirectory(ext)

add_library(the_sort_function MODULE the_sort_function.c)
target_link_libraries(the_sort_function PRIVATE Halide::Runtime)

set(TESTS
    addconstant_test.py
    atomics.py
    autodiff.py
    basics.py
    bit_test.py
    boundary_conditions.py
    buffer.py
    compile_to.py
    division.py
    extern.py
    float_precision_test.py
    iroperator.py
    multipass_constraints.py
    pystub.py
    rdom.py
    target.py
    tuple_select.py
    type.py
    user_context_test.py
    var.py
    )

foreach (TEST IN LISTS TESTS)
    get_filename_component(TEST_NAME ${TEST} NAME_WE)
    add_test(NAME python_correctness_${TEST_NAME}
             COMMAND Python3::Interpreter "$<SHELL_PATH:${CMAKE_CURRENT_SOURCE_DIR}/${TEST}>")

    make_shell_path(PYTHONPATH "${CMAKE_CURRENT_BINARY_DIR}/ext" "${CMAKE_CURRENT_BINARY_DIR}" "$<TARGET_FILE_DIR:Halide::Python>")
    set_tests_properties(python_correctness_${TEST_NAME} PROPERTIES
                         LABELS "python;python-correctness"
                         ENVIRONMENT "PYTHONPATH=${PYTHONPATH};HL_TARGET=host")
endforeach ()
