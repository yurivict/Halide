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

target_link_libraries(auto_schedule PRIVATE cost_model train_cost_model Halide::Runtime)

if (NOT HALIDE_ENABLE_RTTI)
    target_compile_options(auto_schedule PRIVATE
                           $<$<COMPILE_LANG_AND_ID:CXX,MSVC>:/GR->
                           $<$<AND:$<COMPILE_LANGUAGE:CXX>,$<NOT:$<CXX_COMPILER_ID:MSVC>>>:-fno-rtti>)
endif ()

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

set_tests_properties(demo_apps_autoscheduler PROPERTIES LABELS autoscheduler)

return()

# =======================================================
# TODO: move this to a separate folder since it's a demo/app

# demo_included_schedule_file
halide_library(included_schedule_file
               SRCS included_schedule_file_generator.cpp
               FUNCTION_NAME included_schedule_file
               GENERATOR_ARGS auto_schedule=true -p $<TARGET_FILE:auto_schedule> -s Adams2019)
add_dependencies(included_schedule_file auto_schedule)

_halide_genfiles_dir(included_schedule_file GENFILES_DIR)
set(INCLUDED_SCHEDULE_FILE_REGISTRATION_FILE
    ${GENFILES_DIR}/included_schedule_file.registration.cpp)

add_executable(demo_included_schedule_file ${HALIDE_TOOLS_DIR}/RunGenMain.cpp
               ${INCLUDED_SCHEDULE_FILE_REGISTRATION_FILE})
target_include_directories(
        demo_included_schedule_file
        PRIVATE "${HALIDE_INCLUDE_DIR}" "${HALIDE_TOOLS_DIR}")
target_link_libraries(demo_included_schedule_file PRIVATE Halide::ImageIO included_schedule_file)
add_dependencies(demo_included_schedule_file included_schedule_file
                 auto_schedule)

add_custom_command(TARGET demo_included_schedule_file POST_BUILD
                   COMMAND $<TARGET_FILE:demo_included_schedule_file>
                   --benchmarks=all
                   --benchmark_min_time=1
                   --estimate_all
                   WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})

# =======================================================
# TODO: move this to a separate folder since it's a demo/app

add_executable(featurization_to_sample featurization_to_sample.cpp)

add_executable(get_host_target get_host_target.cpp)
target_include_directories(get_host_target PRIVATE "${HALIDE_INCLUDE_DIR}")
target_link_libraries(get_host_target PRIVATE Halide)

add_executable(test_apps_autoscheduler test.cpp)
target_include_directories(
        test_apps_autoscheduler
        PRIVATE "${HALIDE_INCLUDE_DIR}" "${HALIDE_TOOLS_DIR}")
target_link_libraries(test_apps_autoscheduler PRIVATE Halide)
if (NOT WIN32)
    target_link_libraries(test_apps_autoscheduler PRIVATE dl)
endif ()

add_executable(test_perfect_hash_map test_perfect_hash_map.cpp)

add_executable(test_function_dag test_function_dag.cpp FunctionDAG.cpp ASLog.cpp)
target_include_directories(
        test_function_dag
        PRIVATE "${HALIDE_INCLUDE_DIR}" "${HALIDE_TOOLS_DIR}")
target_link_libraries(test_function_dag PRIVATE Halide)

add_executable(weightsdir_to_weightsfile weightsdir_to_weightsfile.cpp
               Weights.cpp)
