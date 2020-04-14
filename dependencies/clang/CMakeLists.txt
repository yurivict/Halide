find_package(Clang)

if (NOT TARGET clang)
    if (DEFINED LLVM_DIR)
        message(STATUS "Could not find Clang in module path. Trying from LLVM_DIR...")
        set(Clang_DIR "${LLVM_DIR}/../clang")
        find_package(Clang REQUIRED)
    else ()
        message(FATAL_ERROR "Could not find Clang!")
    endif ()
endif ()

set_target_properties(clang PROPERTIES IMPORTED_GLOBAL TRUE)