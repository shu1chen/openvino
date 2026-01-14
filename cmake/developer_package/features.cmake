# Copyright (C) 2018-2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

include(options)
include(target_flags)
include(compile_flags/functions)

if(WIN32)
    set (CPACK_GENERATOR "ZIP" CACHE STRING "Cpack generator for OpenVINO")
else()
    set (CPACK_GENERATOR "TGZ" CACHE STRING "Cpack generator for OpenVINO")
endif()

ov_option (ENABLE_LTO "Enable Link Time Optimization" OFF)

ov_option_enum(ENABLE_PGO "Profile-Guided Optimization mode: OFF | GENERATE | USE" OFF
               ALLOWED_VALUES OFF GENERATE USE)

set(PGO_PROFILES_DIR "${CMAKE_BINARY_DIR}/pgo_profiles" CACHE PATH
    "Directory for PGO profile data (instrumented PGO)")

if(OV_COMPILER_IS_INTEL_LLVM)
    set(_hwpgo_default_allowed ON)
else()
    set(_hwpgo_default_allowed OFF)
endif()

if(_hwpgo_default_allowed)
    ov_option_enum(ENABLE_HWPGO "Hardware PGO mode: OFF | GENERATE | USE (ICX only)" OFF
                   ALLOWED_VALUES OFF GENERATE USE)
else()
    set(ENABLE_HWPGO "OFF" CACHE STRING "Hardware PGO mode: OFF | GENERATE | USE (ICX only)")
endif()

set(HWPGO_PROFILE_FILE "" CACHE FILEPATH
    "Path to hardware PGO sample profile file for -fprofile-sample-use (HWPGO USE phase)")

set(OV_TARGET_ARCH "OFF" CACHE STRING
    "Target microarchitecture for global optimization (e.g., PANTHERLAKE, SAPPHIRERAPIDS, OFF)")

ov_option (OS_FOLDER "create OS dedicated folder in output" OFF)

if(OV_GENERATOR_MULTI_CONFIG)
    ov_option(USE_BUILD_TYPE_SUBFOLDER "Create dedicated sub-folder per build type for output binaries" OFF)
else()
    ov_option(USE_BUILD_TYPE_SUBFOLDER "Create dedicated sub-folder per build type for output binaries" ON)
endif()

if(DEFINED ENV{CI_BUILD_NUMBER} AND NOT (CMAKE_CROSSCOMPILING AND CMAKE_COMPILER_IS_GNUCXX AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 7.4))
    set(CMAKE_COMPILE_WARNING_AS_ERROR_DEFAULT ON)
else()
    set(CMAKE_COMPILE_WARNING_AS_ERROR_DEFAULT OFF)
endif()

ov_option (CMAKE_COMPILE_WARNING_AS_ERROR "Enable warnings as errors" ${CMAKE_COMPILE_WARNING_AS_ERROR_DEFAULT})

ov_dependent_option (ENABLE_QSPECTRE "Enable Qspectre mitigation" OFF "CMAKE_CXX_COMPILER_ID STREQUAL MSVC OR (OV_COMPILER_IS_INTEL_LLVM AND WIN32)" OFF)

ov_dependent_option (ENABLE_INTEGRITYCHECK "build DLLs with /INTEGRITYCHECK flag" OFF "CMAKE_CXX_COMPILER_ID STREQUAL MSVC OR (OV_COMPILER_IS_INTEL_LLVM AND WIN32)" OFF)

ov_option (ENABLE_SANITIZER "enable checking memory errors via AddressSanitizer" OFF)

ov_option (ENABLE_UB_SANITIZER "enable UndefinedBahavior sanitizer" OFF)

ov_option (ENABLE_THREAD_SANITIZER "enable checking data races via ThreadSanitizer" OFF)

ov_dependent_option (ENABLE_COVERAGE "enable code coverage" OFF "CMAKE_COMPILER_IS_GNUCXX OR OV_COMPILER_IS_CLANG" OFF)

ov_dependent_option (ENABLE_API_VALIDATOR "Enables API Validator usage" ON "WIN32" OFF)

ov_dependent_option (ENABLE_PDB_IN_RELEASE "Enables PDB files for Release build" OFF "WIN32" OFF)

# Defines CPU capabilities

ov_dependent_option (ENABLE_SSE42 "Enable SSE4.2 optimizations" ON "X86_64 OR (X86 AND NOT EMSCRIPTEN)" OFF)

ov_dependent_option (ENABLE_AVX2 "Enable AVX2 optimizations" ON "X86_64 OR (X86 AND NOT EMSCRIPTEN)" OFF)

ov_dependent_option (ENABLE_AVX512F "Enable AVX512 optimizations" ON "X86_64 OR (X86 AND NOT EMSCRIPTEN)" OFF)

ov_dependent_option (ENABLE_NEON_FP16 "Enable ARM FP16 optimizations" ON "AARCH64" OFF)

ov_dependent_option (ENABLE_SVE "Enable SVE optimizations" ON "AARCH64 AND NOT APPLE" OFF)

# Type of build, we add this as an explicit option to default it to ON
get_property(BUILD_SHARED_LIBS_DEFAULT GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS)
ov_option (BUILD_SHARED_LIBS "Build as a shared library" ${BUILD_SHARED_LIBS_DEFAULT})

# Android does not support SOVERSION
# see https://www.opengis.ch/2011/11/23/creating-non-versioned-shared-libraries-for-android/
ov_dependent_option (ENABLE_LIBRARY_VERSIONING "Enable libraries versioning" ON "NOT WIN32;NOT ANDROID;BUILD_SHARED_LIBS" OFF)

ov_dependent_option (ENABLE_FASTER_BUILD "Enable build features (PCH, UNITY) to speed up build time" OFF "CMAKE_VERSION VERSION_GREATER_EQUAL 3.16" OFF)

if(CMAKE_CROSSCOMPILING OR WIN32)
    set(STYLE_CHECKS_DEFAULT OFF)
else()
    set(STYLE_CHECKS_DEFAULT ON)
endif()

ov_option (ENABLE_CPPLINT "Enable cpplint checks during the build" ${STYLE_CHECKS_DEFAULT})

ov_dependent_option (ENABLE_CPPLINT_REPORT "Build cpplint report instead of failing the build" OFF "ENABLE_CPPLINT" OFF)

ov_option (ENABLE_CLANG_FORMAT "Enable clang-format checks during the build" ${STYLE_CHECKS_DEFAULT})

ov_option (ENABLE_CLANG_TIDY "Enable clang-tidy checks during the build" OFF)
ov_dependent_option (ENABLE_CLANG_TIDY_FIX "Enable clang-tidy automatic fixes during the build" OFF "ENABLE_CLANG_TIDY" OFF)

ov_option (ENABLE_NCC_STYLE "Enable ncc style check" ${STYLE_CHECKS_DEFAULT})

ov_option (ENABLE_UNSAFE_LOCATIONS "skip check for MD5 for dependency" OFF)

if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC" AND MSVC_VERSION GREATER_EQUAL 1930)
    # Visual Studio 2022: 1930-1939 = VS 17.0 (v143 toolset)
    set(_msvc_version_2022 ON)
endif()

ov_dependent_option (ENABLE_FUZZING "instrument build for fuzzing" OFF "OV_COMPILER_IS_CLANG OR _msvc_version_2022" OFF)

#
# Check features
#

if(ENABLE_AVX512F)
    if ((CMAKE_CXX_COMPILER_ID STREQUAL "MSVC") AND (MSVC_VERSION VERSION_LESS 1920))
        # 1920 version of MSVC 2019. In MSVC 2017 AVX512F not work
        set(ENABLE_AVX512F OFF CACHE BOOL "" FORCE)
    endif()
    if ((CMAKE_CXX_COMPILER_ID STREQUAL "Clang") AND (CMAKE_CXX_COMPILER_VERSION VERSION_LESS 6))
        set(ENABLE_AVX512F OFF CACHE BOOL "" FORCE)
    endif()
    if (OV_COMPILER_IS_APPLECLANG AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 10)
        # TODO: clarify which AppleClang version supports avx512
        set(ENABLE_AVX512F OFF CACHE BOOL "" FORCE)
    endif()
    if ((CMAKE_CXX_COMPILER_ID STREQUAL "GNU") AND (CMAKE_CXX_COMPILER_VERSION VERSION_LESS 4.9))
        set(ENABLE_AVX512F OFF CACHE BOOL "" FORCE)
    endif()
endif()

if(ENABLE_SVE)
    ov_check_compiler_supports_sve("-march=armv8-a+sve+fp16")

    if(NOT CXX_HAS_SVE)
        set(ENABLE_SVE OFF CACHE BOOL "Enables ARM64 SVE support" FORCE)
    endif()
endif()
