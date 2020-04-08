set(TESTS
    lesson_01_basics.py
    lesson_02_input_image.py
    lesson_03_debugging_1.py
    lesson_04_debugging_2.py
    lesson_05_scheduling_1.py
    lesson_06_realizing_over_shifted_domains.py
    lesson_07_multi_stage_pipelines.py
    lesson_08_scheduling_2.py
    lesson_09_update_definitions.py
    lesson_10_aot_compilation_generate.py
    lesson_10_aot_compilation_run.py
    lesson_11_cross_compilation.py
    lesson_12_using_the_gpu.py
    lesson_13_tuples.py
    lesson_14_types.py
    )

foreach (TEST IN LISTS TESTS)
    get_filename_component(TEST_NAME ${TEST} NAME_WE)
    file(TO_NATIVE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${TEST}" NATIVE_SCRIPT)
    add_test(NAME python_tutorial_${TEST_NAME}
             COMMAND "${CMAKE_COMMAND}"
             -E env "PYTHONPATH=${CMAKE_CURRENT_BINARY_DIR}:$<TARGET_FILE_DIR:Halide::Python>" "HL_TARGET=host"
             "$<TARGET_FILE:Python3::Interpreter>" "${NATIVE_SCRIPT}")
    set_tests_properties(python_tutorial_${TEST_NAME} PROPERTIES LABELS python)
endforeach ()

set_tests_properties(python_tutorial_lesson_10_aot_compilation_generate PROPERTIES FIXTURES_SETUP py_lesson_10)
set_tests_properties(python_tutorial_lesson_10_aot_compilation_run PROPERTIES FIXTURES_REQUIRED py_lesson_10)
