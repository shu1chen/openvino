# Copyright (C) 2026 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
# Link Time Optimization (LTO) support
#
# Supports:
#   - MSVC:      /GL (compile) + /LTCG (link)
#   - ICX Win:   -Qipo (Intel IPO, compile + link)
#   - ICX Linux: -flto (LLVM LTO, compile + link)
#   - GCC:       -flto (compile + link)
#   - Clang:     -flto=thin (compile + link)
#
# Usage:
#   cmake -DENABLE_LTO=ON ...
#

# Default: IPO not supported (used by per-target property settings)
set(OV_IPO_SUPPORTED OFF CACHE INTERNAL
    "Whether CMake INTERPROCEDURAL_OPTIMIZATION is supported" FORCE)

if(NOT ENABLE_LTO)
    return()
endif()

# --- Try CMake's built-in IPO support first ---

set(CMAKE_POLICY_DEFAULT_CMP0069 NEW)
include(CheckIPOSupported)

check_ipo_supported(RESULT _ov_ipo_result
                    OUTPUT _ov_ipo_output
                    LANGUAGES C CXX)

if(_ov_ipo_result)
    # CMake IPO works — per-target INTERPROCEDURAL_OPTIMIZATION_RELEASE
    # will be set in frontends.cmake, openvino.cmake, etc.
    set(OV_IPO_SUPPORTED ON CACHE INTERNAL
        "Whether CMake INTERPROCEDURAL_OPTIMIZATION is supported" FORCE)
    message(STATUS "LTO (Link Time Optimization) is enabled (CMake IPO supported)")
else()
    # --- Fallback: set compiler-specific flags globally ---
    message(STATUS "CMake IPO check failed (${_ov_ipo_output}), trying compiler-specific LTO flags")

    set(_lto_fallback_ok OFF)

    if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        # MSVC Whole Program Optimization
        add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/GL>)
        set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} /LTCG")
        foreach(_type IN ITEMS SHARED MODULE EXE)
            set(CMAKE_${_type}_LINKER_FLAGS "${CMAKE_${_type}_LINKER_FLAGS} /LTCG")
        endforeach()
        set(_lto_fallback_ok ON)
        message(STATUS "LTO: MSVC — /GL (compile) + /LTCG (link)")

    elseif(OV_COMPILER_IS_INTEL_LLVM)
        if(WIN32)
            # Intel IPO on Windows (works with MSVC linker)
            ov_add_compiler_flags(-Qipo)
            foreach(_type IN ITEMS SHARED MODULE EXE)
                set(CMAKE_${_type}_LINKER_FLAGS "${CMAKE_${_type}_LINKER_FLAGS} -Qipo")
            endforeach()
            message(STATUS "LTO: Intel LLVM (ICX) Windows — -Qipo")
        else()
            # LLVM LTO on Linux
            ov_add_compiler_flags(-flto)
            foreach(_type IN ITEMS SHARED MODULE EXE)
                set(CMAKE_${_type}_LINKER_FLAGS "${CMAKE_${_type}_LINKER_FLAGS} -flto")
            endforeach()
            message(STATUS "LTO: Intel LLVM (ICX) Linux — -flto")
        endif()
        set(_lto_fallback_ok ON)

    elseif(CMAKE_COMPILER_IS_GNUCXX)
        ov_add_compiler_flags(-flto)
        foreach(_type IN ITEMS SHARED MODULE EXE)
            set(CMAKE_${_type}_LINKER_FLAGS "${CMAKE_${_type}_LINKER_FLAGS} -flto")
        endforeach()
        set(_lto_fallback_ok ON)
        message(STATUS "LTO: GCC — -flto")

    elseif(OV_COMPILER_IS_CLANG)
        ov_add_compiler_flags(-flto=thin)
        foreach(_type IN ITEMS SHARED MODULE EXE)
            set(CMAKE_${_type}_LINKER_FLAGS "${CMAKE_${_type}_LINKER_FLAGS} -flto=thin")
        endforeach()
        set(_lto_fallback_ok ON)
        message(STATUS "LTO: Clang — -flto=thin")
    endif()

    if(NOT _lto_fallback_ok)
        set(ENABLE_LTO OFF CACHE BOOL "Enable Link Time Optimization" FORCE)
        message(WARNING "LTO is not supported for compiler ${CMAKE_CXX_COMPILER_ID}: ${_ov_ipo_output}")
    endif()
endif()
