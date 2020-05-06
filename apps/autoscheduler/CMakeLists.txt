# TODO: rename auto_schedule target to Adams2019 or something similar.

# weights
set(WF_CPP baseline.cpp)
configure_file(baseline.weights baseline.weights COPYONLY)
add_custom_command(OUTPUT ${WF_CPP}
                   DEPENDS baseline.weights binary2cpp
                   COMMAND binary2cpp baseline_weights < baseline.weights > ${WF_CPP}
                   VERBATIM)

# cost_model, train_cost_model
add_executable(cost_model.generator cost_model_generator.cpp)
target_link_libraries(cost_model.generator PRIVATE Halide::Generator)

add_halide_library(cost_model FROM cost_model.generator)
add_halide_library(train_cost_model FROM cost_model.generator
                   USE_RUNTIME cost_model.runtime)

# retrain_cost_model
add_executable(retrain_cost_model
               ASLog.cpp
               DefaultCostModel.cpp
               Weights.cpp
               retrain_cost_model.cpp
               ${WF_CPP})
target_include_directories(retrain_cost_model PRIVATE ${PROJECT_SOURCE_DIR}/apps/support) # TODO: relocate. just for cmdline.h
target_link_libraries(retrain_cost_model PRIVATE cost_model train_cost_model Halide::Halide)

# libauto_schedule
# Note: must use MODULE here (not SHARED) to get .so (instead of .dylib) on OSX.
# This means that this can only be opened dynamically (not linked directly), but that's ok.
add_library(auto_schedule
            MODULE
            ASLog.cpp
            AutoSchedule.cpp
            DefaultCostModel.cpp
            FunctionDAG.cpp
            LoopNest.cpp
            Weights.cpp
            ${WF_CPP})

target_link_libraries(auto_schedule PRIVATE cost_model train_cost_model Halide::Halide)

if (NOT HALIDE_ENABLE_RTTI)
    target_compile_options(auto_schedule PRIVATE
                           $<$<COMPILE_LANG_AND_ID:CXX,MSVC>:/GR->
                           $<$<AND:$<COMPILE_LANGUAGE:CXX>,$<NOT:$<CXX_COMPILER_ID:MSVC>>>:-fno-rtti>)
endif ()

# TODO: move to /packaging
include(GNUInstallDirs)
install(TARGETS auto_schedule
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
# TODO: move this to a separate folder since it's a demo/app

add_executable(demo.generator demo_generator.cpp)
target_link_libraries(demo.generator PRIVATE Halide::Generator)

add_halide_library(demo FROM demo.generator
                   PARAMS auto_schedule=true
                   PLUGINS auto_schedule
                   SCHEDULER Adams2019
                   REGISTRATION DEMO_REGISTRATION_FILE)

add_executable(demo_apps_autoscheduler ${DEMO_REGISTRATION_FILE})
target_link_libraries(demo_apps_autoscheduler PRIVATE demo Halide::RunGenMain)

add_test(NAME demo_apps_autoscheduler
         COMMAND demo_apps_autoscheduler --benchmarks=all --benchmark_min_time=1 --estimate_all)

set_tests_properties(demo_apps_autoscheduler PROPERTIES LABELS Adams2019)

# ==========================================================
# TODO: move this to a separate folder since it's a demo/app

add_executable(included_schedule_file.generator included_schedule_file_generator.cpp)
target_link_libraries(included_schedule_file.generator PRIVATE Halide::Generator)

add_halide_library(included_schedule_file FROM included_schedule_file.generator
                   PARAMS auto_schedule=true
                   PLUGINS auto_schedule
                   SCHEDULER Adams2019
                   REGISTRATION INCLUDED_SCHEDULE_FILE_REGISTRATION_FILE)

add_executable(demo_included_schedule_file ${INCLUDED_SCHEDULE_FILE_REGISTRATION_FILE})
target_link_libraries(demo_included_schedule_file PRIVATE included_schedule_file Halide::RunGenMain)

add_test(NAME demo_included_schedule_file
         COMMAND demo_included_schedule_file --benchmarks=all --benchmark_min_time=1 --estimate_all)

set_tests_properties(demo_included_schedule_file PROPERTIES LABELS Adams2019)

# =============================================
# Auto-tuning support utilities.
# TODO: implement auto-tuning support in CMake?

add_executable(featurization_to_sample featurization_to_sample.cpp)

add_executable(get_host_target get_host_target.cpp)
target_link_libraries(get_host_target PRIVATE Halide::Halide)

add_executable(weightsdir_to_weightsfile weightsdir_to_weightsfile.cpp Weights.cpp)
target_link_libraries(weightsdir_to_weightsfile PRIVATE Halide::Runtime)

# ==========================================================
# TODO: move these to a separate folder since they're tests.

add_executable(test_apps_autoscheduler test.cpp)
target_link_libraries(test_apps_autoscheduler PRIVATE Halide::Halide Halide::Tools ${CMAKE_DL_LIBS})

add_test(NAME test_apps_autoscheduler
         COMMAND test_apps_autoscheduler
         WORKING_DIRECTORY $<TARGET_FILE_DIR:auto_schedule>)

set_tests_properties(test_apps_autoscheduler PROPERTIES
                     LABELS Adams2019
                     ENVIRONMENT "LD_LIBRARY_PATH=$<TARGET_FILE_DIR:auto_schedule>")

##

add_executable(test_perfect_hash_map test_perfect_hash_map.cpp)

add_test(NAME test_perfect_hash_map COMMAND test_perfect_hash_map)
set_tests_properties(test_perfect_hash_map PROPERTIES LABELS Adams2019)

##

add_executable(test_function_dag test_function_dag.cpp FunctionDAG.cpp ASLog.cpp)
target_link_libraries(test_function_dag PRIVATE Halide::Halide Halide::Tools)

add_test(NAME test_function_dag COMMAND test_function_dag)
set_tests_properties(test_function_dag PROPERTIES LABELS Adams2019)
