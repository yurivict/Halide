# TODO: rename gradient_autoscheduler target to Li2018 or something similar.

add_library(gradient_autoscheduler MODULE GradientAutoscheduler.cpp ASLog.cpp)
target_link_libraries(gradient_autoscheduler PRIVATE Halide::Halide)

if (NOT HALIDE_ENABLE_RTTI)
    target_compile_options(gradient_autoscheduler PRIVATE
                           $<$<COMPILE_LANG_AND_ID:CXX,MSVC>:/GR->
                           $<$<AND:$<COMPILE_LANGUAGE:CXX>,$<NOT:$<CXX_COMPILER_ID:MSVC>>>:-fno-rtti>)
endif ()

# TODO: move to /packaging
include(GNUInstallDirs)
install(TARGETS gradient_autoscheduler
        EXPORT Halide_Targets

        RUNTIME
        DESTINATION ${CMAKE_INSTALL_BINDIR}
        COMPONENT Halide_Runtime

        LIBRARY
        DESTINATION ${CMAKE_INSTALL_LIBDIR}
        COMPONENT Halide_Runtime
        NAMELINK_COMPONENT Halide_Development

        ARCHIVE
        DESTINATION ${CMAKE_INSTALL_LIBDIR}
        COMPONENT Halide_Development)

# ==========================================================
# TODO: move these to a separate folder since they're tests.

add_executable(demo_gradient.generator demo_generator.cpp)
target_link_libraries(demo_gradient.generator PRIVATE Halide::Generator)

add_halide_library(demo_gradient FROM demo_gradient.generator
                   GENERATOR demo
                   FUNCTION_NAME demo
                   PARAMS auto_schedule=true
                   PLUGINS gradient_autoscheduler
                   SCHEDULER Li2018
                   REGISTRATION DEMO_REGISTRATION_FILE)

add_executable(demo_gradient_autoscheduler ${DEMO_REGISTRATION_FILE})
target_link_libraries(demo_gradient_autoscheduler PRIVATE demo_gradient Halide::RunGenMain)

add_test(NAME demo_gradient_autoscheduler
         COMMAND demo_gradient_autoscheduler --benchmarks=all --benchmark_min_time=1 --estimate_all)

set_tests_properties(demo_gradient_autoscheduler PROPERTIES LABELS Li2018)

##

add_executable(gradient_autoscheduler_test_cpp test.cpp)
target_link_libraries(gradient_autoscheduler_test_cpp PRIVATE Halide::Halide)

add_test(NAME gradient_autoscheduler_test_cpp
         COMMAND gradient_autoscheduler_test_cpp
         WORKING_DIRECTORY $<TARGET_FILE_DIR:gradient_autoscheduler>)

set_tests_properties(gradient_autoscheduler_test_cpp PROPERTIES LABELS Li2018)

##

if (WITH_PYTHON_BINDINGS)
    # TODO: rework this as an app under python_bindings.
    # Disabled due to issue #4876
    if (FALSE)
        find_package(Python3 REQUIRED COMPONENTS Interpreter Development)

        add_test(NAME gradient_autoscheduler_test_py
                 COMMAND Python3::Interpreter "${CMAKE_CURRENT_SOURCE_DIR}/test.py")

        set(PYTHONPATH "$<SHELL_PATH:$<TARGET_FILE_DIR:Halide::Python>>")

        if (WIN32)
            set(SEP "\\$<SEMICOLON>")
        else ()
            set(SEP ":")
        endif ()

        set(_PATH "$<SHELL_PATH:$<TARGET_FILE_DIR:gradient_autoscheduler>>;$<SHELL_PATH:$<TARGET_FILE_DIR:Halide::Halide>>;$ENV{PATH}")
        string(REPLACE ";" "${SEP}" _PATH "${_PATH}")
        set_tests_properties(gradient_autoscheduler_test_py PROPERTIES 
                             LABELS Li2018
                             ENVIRONMENT "PYTHONPATH=${PYTHONPATH};PATH=${_PATH}")
    endif ()
endif ()
