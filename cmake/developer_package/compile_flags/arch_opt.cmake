# Copyright (C) 2026 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
# Architecture-Specific Optimization support
#
# Applies global compiler flags to tune the entire build for a specific
# target microarchitecture. This is different from OpenVINO's per-file
# ISA cross-compilation dispatch (ENABLE_SSE42, ENABLE_AVX2, ENABLE_AVX512F),
# which compiles individual functions multiple times for different ISAs.
#
# When OV_TARGET_ARCH is set, the entire codebase is compiled with flags
# that allow the compiler to use all ISA features of the target and optimize
# instruction scheduling for its microarchitecture.
#
# Supported compilers and flag mapping:
#   - ICX Windows:  /Qx<ARCH>      (e.g., /QxPANTHERLAKE)
#   - ICX Linux:    -x<arch>       (e.g., -xpantherlake)
#   - MSVC:         /arch:<level>  (mapped from architecture name)
#   - GCC:          -march=<arch>  (e.g., -march=pantherlake)
#   - Clang:        -march=<arch>  (e.g., -march=pantherlake)
#
# Usage:
#   cmake -DOV_TARGET_ARCH=PANTHERLAKE ...
#   cmake -DOV_TARGET_ARCH=SAPPHIRERAPIDS ...
#

if(OV_TARGET_ARCH STREQUAL "OFF")
    return()
endif()

message(STATUS "")
message(STATUS "Architecture-specific optimization:")
message(STATUS "  Target: ${OV_TARGET_ARCH}")

string(TOLOWER "${OV_TARGET_ARCH}" _arch_lower)

# =================================================================
# ICX (Intel LLVM) — /Qx<ARCH> (Windows) or -x<arch> (Linux)
# =================================================================

if(OV_COMPILER_IS_INTEL_LLVM)
    if(WIN32)
        set(_arch_flag "/Qx${OV_TARGET_ARCH}")
    else()
        set(_arch_flag "-x${_arch_lower}")
    endif()
    ov_add_compiler_flags(${_arch_flag})
    message(STATUS "  Compiler flags: ${_arch_flag}")

# =================================================================
# MSVC — maps architecture name to /arch: flag
# =================================================================

elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    # MSVC does not support microarchitecture-specific tuning like ICX.
    # Map well-known Intel architectures to the best available /arch: flag.
    #
    # Client architectures → /arch:AVX2 (256-bit preferred, no frequency penalty)
    # Server architectures → /arch:AVX512 (native 512-bit)

    # --- Architecture → MSVC /arch: mapping ---
    set(_msvc_arch_PANTHERLAKE        "AVX2")
    set(_msvc_arch_ARROWLAKE          "AVX2")
    set(_msvc_arch_ARROWLAKE_S        "AVX2")
    set(_msvc_arch_LUNARLAKE          "AVX2")
    set(_msvc_arch_METEORLAKE         "AVX2")
    set(_msvc_arch_RAPTORLAKE         "AVX2")
    set(_msvc_arch_ALDERLAKE          "AVX2")
    set(_msvc_arch_ROCKETLAKE         "AVX512")
    set(_msvc_arch_TIGERLAKE          "AVX512")
    set(_msvc_arch_ICELAKE_CLIENT     "AVX512")
    set(_msvc_arch_ICELAKE_SERVER     "AVX512")
    set(_msvc_arch_SAPPHIRERAPIDS     "AVX512")
    set(_msvc_arch_EMERALDRAPIDS      "AVX512")
    set(_msvc_arch_GRANITERAPIDS      "AVX512")
    set(_msvc_arch_SIERRAFOREST       "AVX2")
    set(_msvc_arch_CLEARWATERFOREST   "AVX2")

    if(DEFINED _msvc_arch_${OV_TARGET_ARCH})
        set(_arch_flag "/arch:${_msvc_arch_${OV_TARGET_ARCH}}")
    else()
        message(WARNING "Unknown architecture '${OV_TARGET_ARCH}' for MSVC. "
                        "Defaulting to /arch:AVX2. "
                        "Set OV_TARGET_ARCH to a known architecture or OFF.")
        set(_arch_flag "/arch:AVX2")
    endif()

    ov_add_compiler_flags(${_arch_flag})
    message(STATUS "  Compiler flags: ${_arch_flag} (MSVC mapping for ${OV_TARGET_ARCH})")

# =================================================================
# GCC / Clang — -march=<arch>
# =================================================================

elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    set(_arch_flag "-march=${_arch_lower}")
    ov_add_compiler_flags(${_arch_flag})
    message(STATUS "  Compiler flags: ${_arch_flag}")

else()
    message(WARNING "Architecture optimization not supported for compiler: "
                    "${CMAKE_CXX_COMPILER_ID}. OV_TARGET_ARCH will be ignored.")
endif()
