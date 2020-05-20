cmake_minimum_required(VERSION 3.16)

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

define_property(TARGET PROPERTY HL_TARGETS
                BRIEF_DOCS "On a Halide library target, lists the runtime targets supported by the filter"
                FULL_DOCS "On a Halide library target, lists the runtime targets supported by the filter")

define_property(TARGET PROPERTY HLRT_TARGETS
                BRIEF_DOCS "On a Halide runtime target, lists the targets the runtime backs"
                FULL_DOCS "On a Halide runtime target, lists the targets the runtime backs")

function(add_halide_library TARGET)
    set(EXTRA_OUTPUT_NAMES
        # See Module.cpp for list of extra outputs.
        # c_header is always generated
        # c_source is handled by C_BACKEND
        # static_library is the default
        # object is not available
        # cpp_stub is not available
        ASSEMBLY
        BITCODE
        COMPILER_LOG
        FEATURIZATION
        LLVM_ASSEMBLY
        PYTHON_EXTENSION
        PYTORCH_WRAPPER
        REGISTRATION
        SCHEDULE
        STMT
        STMT_HTML)

    set(ASSEMBLY_extension ".s")
    set(BITCODE_extension ".bc")
    set(COMPILER_LOG_extension ".halide_compiler_log")
    set(FEATURIZATION_extension ".featurization")
    set(LLVM_ASSEMBLY_extension ".ll")
    set(PYTHON_EXTENSION_extension ".py.cpp")
    set(PYTORCH_WRAPPER_extension ".pytorch.h")
    set(REGISTRATION_extension ".registration.cpp")
    set(SCHEDULE_extension ".schedule.h")
    set(STMT_extension ".stmt")
    set(STMT_HTML_extension ".stmt.html")

    set(options GRADIENT_DESCENT C_BACKEND)
    set(oneValueArgs FROM GENERATOR FUNCTION_NAME USE_RUNTIME AUTOSCHEDULER ${EXTRA_OUTPUT_NAMES})
    set(multiValueArgs PARAMS TARGETS FEATURES PLUGINS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (NOT "${ARG_UNPARSED_ARGUMENTS}" STREQUAL "")
        message(AUTHOR_WARNING "arguments to add_halide_library were not recognized. ${ARG_UNPARSED_ARGUMENTS}")
    endif ()

    if (NOT ARG_FROM)
        message(FATAL_ERROR "Missing FROM argument specifying a Halide generator target")
    endif ()

    if (ARG_GRADIENT_DESCENT)
        set(GRADIENT_DESCENT 1)
    else ()
        set(GRADIENT_DESCENT 0)
    endif ()

    if (NOT ARG_GENERATOR)
        set(ARG_GENERATOR "${TARGET}")
    endif ()

    if (NOT ARG_FUNCTION_NAME)
        set(ARG_FUNCTION_NAME "${TARGET}")
    endif ()

    if (NOT ARG_TARGETS)
        if (NOT "${HL_TARGET}" STREQUAL "")
            set(ARG_TARGETS "${HL_TARGET}")
        elseif (NOT "$ENV{HL_TARGET}" STREQUAL "")
            set(ARG_TARGETS "$ENV{HL_TARGET}")
        else ()
            set(ARG_TARGETS host)
        endif ()
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

    set(generatorCommand ${ARG_FROM})
    if (WIN32)
        set(generatorCommand ${CMAKE_COMMAND} -E env "PATH=$<SHELL_PATH:$<TARGET_FILE_DIR:Halide::Halide>>" "$<TARGET_FILE:${ARG_FROM}>")
    endif ()

    unset(EXTRA_RT_LIBS)
    if ("${TARGETS}" MATCHES "opengl")
        if (NOT TARGET HalideGeneratorHelpers::X11)
            add_library(HalideGeneratorHelpers_X11 INTERFACE)
            add_library(HalideGeneratorHelpers::X11 ALIAS HalideGeneratorHelpers_X11)

            find_package(X11 QUIET)
            if (NOT X11_FOUND)
                message(AUTHOR_WARNING "X11 dependency of OpenGL not found on system.")
            else ()
                target_link_libraries(HalideGeneratorHelpers_X11 INTERFACE ${X11_LIBRARIES})
                target_include_directories(HalideGeneratorHelpers_X11 INTERFACE ${X11_INCLUDE_DIR})
            endif ()
        endif ()
        list(APPEND EXTRA_RT_LIBS HalideGeneratorHelpers::X11)

        if (NOT TARGET OpenGL::GL)
            find_package(OpenGL QUIET)
            if (NOT OPENGL_FOUND)
                message(AUTHOR_WARNING "OpenGL dependency not found on system.")
            endif ()
        endif ()

        list(APPEND EXTRA_RT_LIBS OpenGL::GL)
    endif ()

    if ("${TARGETS}" MATCHES "cuda")
        if (NOT TARGET HalideGeneratorHelpers::CUDA)
            add_library(HalideGeneratorHelpers_CUDA INTERFACE)
            add_library(HalideGeneratorHelpers::CUDA ALIAS HalideGeneratorHelpers_CUDA)

            # TODO: when we are able to upgrade to 3.17, switch to find_package(CUDAToolkit)
            find_package(CUDA QUIET)
            if (NOT CUDA_FOUND)
                message(AUTHOR_WARNING "CUDA dependency not found on system.")
            else ()
                target_include_directories(HalideGeneratorHelpers_CUDA INTERFACE ${CUDA_INCLUDE_DIRS})
                target_link_libraries(HalideGeneratorHelpers_CUDA INTERFACE ${CUDA_LIBRARIES} ${CUDA_CUBLAS_LIBRARIES})
            endif ()
        endif ()

        list(APPEND EXTRA_RT_LIBS HalideGeneratorHelpers::CUDA)
    endif ()

    if ("${TARGETS}" MATCHES "metal")
        find_library(METAL_LIBRARY Metal)
        if (NOT METAL_LIBRARY)
            message(AUTHOR_WARNING "Metal framework dependency not found on system.")
        else ()
            list(APPEND EXTRA_RT_LIBS "${METAL_LIBRARY}")
        endif ()

        find_library(FOUNDATION_LIBRARY Foundation)
        if (NOT FOUNDATION_LIBRARY)
            message(AUTHOR_WARNING "Foundation framework dependency not found on system.")
        else ()
            list(APPEND EXTRA_RT_LIBS "${FOUNDATION_LIBRARY}")
        endif ()
    endif ()

    if (ARG_C_BACKEND AND ARG_USE_RUNTIME)
        message(AUTHOR_WARNING "Warning: the C backend does not use a runtime.")
    endif ()

    # The output file name might not match the host when cross compiling.
    if ("${TARGETS}" MATCHES "host")
        # Since all OSes must match across target triples, if "host" appears at all, then it must match CMake
        set(HL_STATIC_LIBRARY_SUFFIX "${CMAKE_STATIC_LIBRARY_SUFFIX}")
    elseif ("${TARGETS}" MATCHES "windows")
        # Otherwise, all targets are windows, so Halide emits a .lib
        set(HL_STATIC_LIBRARY_SUFFIX ".lib")
    else ()
        # All other targets use .a
        set(HL_STATIC_LIBRARY_SUFFIX ".a")
    endif ()

    if (NOT ARG_C_BACKEND)
        if (NOT ARG_USE_RUNTIME)
            add_library("${TARGET}.runtime" STATIC IMPORTED)
            target_link_libraries("${TARGET}.runtime"
                                  INTERFACE
                                  Threads::Threads
                                  ${CMAKE_DL_LIBS}
                                  ${EXTRA_RT_LIBS})

            set_target_properties("${TARGET}.runtime"
                                  PROPERTIES
                                  IMPORTED_LOCATION "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}.runtime${HL_STATIC_LIBRARY_SUFFIX}")

            add_custom_command(OUTPUT "${TARGET}.runtime${HL_STATIC_LIBRARY_SUFFIX}"
                               COMMAND ${generatorCommand} -r "${TARGET}.runtime" -o .
                               target=$<JOIN:$<TARGET_PROPERTY:${TARGET}.runtime,HLRT_TARGETS>,$<COMMA>>
                               DEPENDS "${ARG_FROM}")

            add_custom_target("${TARGET}.runtime.update"
                              DEPENDS "${TARGET}.runtime${HL_STATIC_LIBRARY_SUFFIX}")

            add_dependencies("${TARGET}.runtime" "${TARGET}.runtime.update")
            set(ARG_USE_RUNTIME "${TARGET}.runtime")
        endif ()

        if (NOT TARGET ${ARG_USE_RUNTIME})
            message(FATAL_ERROR "Invalid runtime target ${ARG_USE_RUNTIME}")
        endif ()

        # Add in the runtime targets but first remove features that should not be attached to a runtime
        # TODO: The fact that profile being here fixes a linker error on Windows smells like a bug.
        #       It complains about a symbol being duplicated between the runtime and the object.
        set(RT_TARGETS ${TARGETS})
        foreach (T IN ITEMS user_context no_asserts no_bounds_query no_runtime profile)
            string(REPLACE "-${T}" "" RT_TARGETS "${RT_TARGETS}")
        endforeach ()

        set_property(TARGET "${ARG_USE_RUNTIME}" APPEND PROPERTY HLRT_TARGETS "${RT_TARGETS}")
    else ()
        # The C backend does not provide a runtime.
        unset(ARG_USE_RUNTIME)
    endif ()

    ##
    # Handle extra outputs
    ##

    set(GENERATOR_OUTPUTS c_header)
    set(GENERATOR_OUTPUT_FILES "${TARGET}.h")

    if (ARG_C_BACKEND)
        list(APPEND GENERATOR_OUTPUTS c_source)
        list(APPEND GENERATOR_OUTPUT_FILES "${TARGET}.halide_generated.cpp")
    else ()
        list(APPEND GENERATOR_OUTPUTS static_library)
        list(APPEND GENERATOR_OUTPUT_FILES "${TARGET}${HL_STATIC_LIBRARY_SUFFIX}")
    endif ()

    foreach (OUT IN LISTS EXTRA_OUTPUT_NAMES)
        if (ARG_${OUT})
            set(${ARG_${OUT}} "${TARGET}${${OUT}_extension}" PARENT_SCOPE)
            list(APPEND GENERATOR_OUTPUT_FILES "${TARGET}${${OUT}_extension}")
            string(TOLOWER "${OUT}" OUT)
            list(APPEND GENERATOR_OUTPUTS ${OUT})
        endif ()
    endforeach ()

    unset(GEN_AUTOSCHEDULER)
    if (ARG_AUTOSCHEDULER)
        if ("${ARG_AUTOSCHEDULER}" MATCHES "::" AND TARGET "${ARG_AUTOSCHEDULER}")
            # Convention: if the argument names a target like "Namespace::Scheduler" then
            # it is assumed to be a plugin providing a scheduler named "Scheduler".
            list(APPEND ARG_PLUGINS "${ARG_AUTOSCHEDULER}")
            string(REGEX REPLACE ".*::(.*)" "\\1" ARG_AUTOSCHEDULER "${ARG_AUTOSCHEDULER}")
        else ()
            if (NOT ARG_PLUGINS)
                message(AUTHOR_WARNING "AUTOSCHEDULER set to a scheduler name but no plugins were loaded")
            endif ()
        endif ()
        set(GEN_AUTOSCHEDULER -s "${ARG_AUTOSCHEDULER}")
    endif ()

    ##
    # Main library target for filter.
    ##

    if (ARG_C_BACKEND)
        add_library("${TARGET}" STATIC "${TARGET}.halide_generated.cpp")
    else ()
        add_library("${TARGET}" STATIC IMPORTED)
        set_target_properties("${TARGET}" PROPERTIES POSITION_INDEPENDENT_CODE ON)
    endif ()

    # load the plugins and setup dependencies
    unset(GEN_PLUGINS)
    if (ARG_PLUGINS)
        add_dependencies("${TARGET}" ${ARG_PLUGINS})
        foreach (P IN LISTS ARG_PLUGINS)
            list(APPEND GEN_PLUGINS "$<TARGET_FILE:${P}>")
        endforeach ()
        set(GEN_PLUGINS -p "$<JOIN:${GEN_PLUGINS},$<COMMA>>")
    endif ()

    set_target_properties("${TARGET}" PROPERTIES
                          HL_GEN_TARGET "${ARG_FROM}"
                          HL_FILTER_NAME "${ARG_GENERATOR}"
                          HL_LIBNAME "${ARG_FUNCTION_NAME}"
                          HL_PARAMS "${ARG_PARAMS}"
                          HL_RUNTIME "${ARG_USE_RUNTIME}"
                          HL_TARGETS "${TARGETS}")

    add_custom_command(OUTPUT ${GENERATOR_OUTPUT_FILES}
                       COMMAND ${generatorCommand}
                       -n "${TARGET}"
                       -d "${GRADIENT_DESCENT}"
                       -g "${ARG_GENERATOR}"
                       -f "${ARG_FUNCTION_NAME}"
                       -e "$<JOIN:${GENERATOR_OUTPUTS},$<COMMA>>"
                       ${GEN_PLUGINS}
                       ${GEN_AUTOSCHEDULER}
                       -o .
                       "target=$<JOIN:${TARGETS},$<COMMA>>"
                       ${ARG_PARAMS}
                       DEPENDS "${ARG_FROM}")

    list(TRANSFORM GENERATOR_OUTPUT_FILES PREPEND "${CMAKE_CURRENT_BINARY_DIR}/")
    add_custom_target("${TARGET}.update" DEPENDS ${GENERATOR_OUTPUT_FILES})

    if (NOT ARG_C_BACKEND)
        set_target_properties("${TARGET}" PROPERTIES IMPORTED_LOCATION "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}${HL_STATIC_LIBRARY_SUFFIX}")
    endif ()

    add_dependencies("${TARGET}" "${TARGET}.update")

    target_include_directories("${TARGET}" INTERFACE "${CMAKE_CURRENT_BINARY_DIR}")
    target_link_libraries("${TARGET}" INTERFACE "${ARG_USE_RUNTIME}" Halide::Runtime)
endfunction()
