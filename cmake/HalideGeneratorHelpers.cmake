cmake_minimum_required(VERSION 3.14)

# TODO: find a use for these, or remove them?
define_property(TARGET PROPERTY HL_GEN_TARGET
                BRIEF_DOCS "On a Halide library target, names the generator target used to create it"
                FULL_DOCS "On a Halide library target, names the generator target used to create it")

define_property(TARGET PROPERTY HL_FILTER_NAME
                BRIEF_DOCS "On a Halide library target, names the filter this library corresponds to"
                FULL_DOCS "On a Halide library target, names the filter this library corresponds to")

define_property(TARGET PROPERTY HL_LIBNAME
                BRIEF_DOCS "On a Halide library target, names the function it provides"
                FULL_DOCS "On a Halide library target, names the function it provides")

define_property(TARGET PROPERTY HL_RUNTIME
                BRIEF_DOCS "On a Halide library target, names the runtime target it depends on"
                FULL_DOCS "On a Halide library target, names the runtime target it depends on")

define_property(TARGET PROPERTY HL_PARAMS
                BRIEF_DOCS "On a Halide library target, lists the parameters used to configure the filter"
                FULL_DOCS "On a Halide library target, lists the parameters used to configure the filter")

define_property(TARGET PROPERTY HL_TARGET
                BRIEF_DOCS "On a Halide library target, lists the runtime targets supported by the filter"
                FULL_DOCS "On a Halide library target, lists the runtime targets supported by the filter")

function(add_halide_library TARGET)
    set(options GRADIENT_DESCENT)
    set(oneValueArgs FROM GENERATOR FUNCTION_NAME USE_RUNTIME PYTHON_EXTENSION)
    set(multiValueArgs PARAMS TARGETS FEATURES)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (ARG_GRADIENT_DESCENT)
        set(GRADIENT_DESCENT 1)
    else ()
        set(GRADIENT_DESCENT 0)
    endif ()

    if (NOT ARG_FROM)
        message(FATAL_ERROR "Missing FROM argument specifying a Halide generator target")
    endif ()

    if (NOT ARG_GENERATOR)
        set(ARG_GENERATOR "${TARGET}")
    endif ()

    if (NOT ARG_FUNCTION_NAME)
        set(ARG_FUNCTION_NAME "${TARGET}")
    endif ()

    if (NOT ARG_TARGETS)
        set(ARG_TARGETS host)
    endif ()

    set(generatorCommand ${ARG_FROM})
    if (WIN32)
        set(generatorCommand ${CMAKE_COMMAND} -E env "PATH=$<SHELL_PATH:$<TARGET_FILE_DIR:Halide::Halide>>" "$<TARGET_FILE:${ARG_FROM}>")
    endif ()

    if (opengl IN_LIST ARG_FEATURES)
        if (NOT TARGET X11::X11)
            message(AUTHOR_WARNING "OpenGL with Halide requires target X11::X11. Attempting to find_package(X11) and create target X11::X11.")

            find_package(X11 QUIET REQUIRED)
            add_library(Halide_Generator_Helpers_X11 INTERFACE)
            add_library(X11::X11 ALIAS Halide_Generator_Helpers_X11)
            target_link_libraries(Halide_Generator_Helpers_X11 INTERFACE ${X11_LIBRARIES})
            target_include_directories(Halide_Generator_Helpers_X11 INTERFACE ${X11_INCLUDE_DIR})
        endif ()

        if (NOT TARGET OpenGL::GL)
            message(AUTHOR_WARNING "OpenGL with Halide requires target OpenGL::GL. Attempting to find_package(OpenGL).")
            find_package(OpenGL QUIET REQUIRED)
        endif ()

        set(EXTRA_RT_LIBS OpenGL::GL X11::X11)
    endif ()

    unset(TARGETS)
    foreach (T IN LISTS ARG_TARGETS)
        if ("${T}" STREQUAL "")
            set(T host)
        endif ()
        foreach (F IN LISTS ARG_FEATURES)
            set(T "${T}-${F}")
        endforeach ()
        list(APPEND TARGETS "${T}-no_runtime")
    endforeach ()
    string(REPLACE ";" "," TARGETS "${TARGETS}")

    if (NOT ARG_USE_RUNTIME)
        add_library("${TARGET}.runtime" STATIC IMPORTED)
        target_link_libraries("${TARGET}.runtime"
                              INTERFACE
                              Threads::Threads
                              ${CMAKE_DL_LIBS}
                              ${EXTRA_RT_LIBS})
        set_target_properties("${TARGET}.runtime"
                              PROPERTIES
                              IMPORTED_LOCATION "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}.runtime${CMAKE_STATIC_LIBRARY_SUFFIX}")

        # Remove features that should not be attached to a runtime
        # The fact that profile being here fixes a linker error on Windows smells like a bug.
        # It complains about a symbol being duplicated between the runtime and the object.
        set(RT_TARGETS ${TARGETS})
        foreach (T IN ITEMS user_context no_asserts no_bounds_query no_runtime profile)
            string(REPLACE "-${T}" "" RT_TARGETS "${RT_TARGETS}")
        endforeach ()
        
        add_custom_command(OUTPUT "${TARGET}.runtime${CMAKE_STATIC_LIBRARY_SUFFIX}"
                           COMMAND ${generatorCommand} -r "${TARGET}.runtime" -o . target=${RT_TARGETS}
                           DEPENDS "${ARG_FROM}")

        add_custom_target("${TARGET}.runtime.update"
                          DEPENDS "${TARGET}.runtime${CMAKE_STATIC_LIBRARY_SUFFIX}")

        add_dependencies("${TARGET}.runtime" "${TARGET}.runtime.update")
        set(ARG_USE_RUNTIME "${TARGET}.runtime")
    endif ()

    if (NOT TARGET ${ARG_USE_RUNTIME})
        message(FATAL_ERROR "Invalid runtime target ${ARG_USE_RUNTIME}")
    endif ()

    ##
    # Handle extra outputs
    ##

    set(GENERATOR_OUTPUTS static_library c_header registration)
    set(GENERATOR_OUTPUT_FILES
        "${TARGET}${CMAKE_STATIC_LIBRARY_SUFFIX}"
        "${TARGET}.h"
        "${TARGET}.registration.cpp")

    if (ARG_PYTHON_EXTENSION)
        set(${ARG_PYTHON_EXTENSION} "${TARGET}.py.cpp" PARENT_SCOPE)
        list(APPEND GENERATOR_OUTPUT_FILES "${TARGET}.py.cpp")
        list(APPEND GENERATOR_OUTPUTS python_extension)
    endif ()

    ##
    # Main library target for filter.
    ##

    add_library("${TARGET}" STATIC IMPORTED)

    set_target_properties("${TARGET}" PROPERTIES
                          HL_GEN_TARGET "${ARG_FROM}"
                          HL_FILTER_NAME "${ARG_GENERATOR}"
                          HL_LIBNAME "${ARG_FUNCTION_NAME}"
                          HL_PARAMS "${ARG_PARAMS}"
                          HL_TARGET "${TARGETS}")

    add_custom_command(OUTPUT ${GENERATOR_OUTPUT_FILES}
                       COMMAND ${generatorCommand}
                       -n "${TARGET}"
                       -d "${GRADIENT_DESCENT}"
                       -g "${ARG_GENERATOR}"
                       -f "${ARG_FUNCTION_NAME}"
                       -e "$<JOIN:${GENERATOR_OUTPUTS},$<COMMA>>"
                       -o .
                       "target=${TARGETS}"
                       ${ARG_PARAMS}
                       DEPENDS "${ARG_FROM}")

    list(TRANSFORM GENERATOR_OUTPUT_FILES PREPEND "${CMAKE_CURRENT_BINARY_DIR}/")
    add_custom_target("${TARGET}.update" DEPENDS ${GENERATOR_OUTPUT_FILES})

    set_target_properties("${TARGET}" PROPERTIES IMPORTED_LOCATION "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}${CMAKE_STATIC_LIBRARY_SUFFIX}")
    add_dependencies("${TARGET}" "${TARGET}.update")

    target_include_directories("${TARGET}" INTERFACE "${CMAKE_CURRENT_BINARY_DIR}")
    target_link_libraries("${TARGET}" INTERFACE "${ARG_USE_RUNTIME}")
endfunction()
