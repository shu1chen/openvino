# Copyright (C) 2026 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
# Profile-Guided Optimization (PGO) and Hardware PGO (HWPGO) support
#
# Instrumented PGO (ENABLE_PGO):
#   Two-phase workflow:
#     Phase 1 — GENERATE: build with instrumentation, run workloads to collect profiles
#     Phase 2 — USE:      rebuild using collected profiles for optimization
#
#   Supported compilers:
#     - ICX Windows:  -Qprof-gen / -Qprof-use  + -Qprof-dir=<dir>
#     - ICX Linux:    -fprofile-generate / -fprofile-use
#     - MSVC:         /GL (compile) + /GENPROFILE / /USEPROFILE (link)
#     - GCC:          -fprofile-generate / -fprofile-use
#     - Clang:        -fprofile-generate / -fprofile-use
#
# Hardware PGO (ENABLE_HWPGO, ICX only):
#   Two-phase workflow using hardware-collected sample profiles (VTune, perf):
#     Phase 1 — GENERATE: build with -fprofile-sample-generate (adds frame
#               pointers and debug metadata for accurate profiling)
#     Phase 2 — USE:      rebuild with -fprofile-sample-use=<file>
#
# Usage examples:
#   # ICX + LTO + HWPGO (generate phase — build instrumented binary)
#   cmake -DENABLE_LTO=ON -DENABLE_HWPGO=GENERATE ...
#
#   # ICX + LTO + HWPGO (use phase — rebuild with collected profile)
#   cmake -DENABLE_LTO=ON -DENABLE_HWPGO=USE -DHWPGO_PROFILE_FILE=/path/to/profile.afdo ...
#
#   # MSVC + LTO + PGO (generate phase)
#   cmake -DENABLE_LTO=ON -DENABLE_PGO=GENERATE ...
#
#   # MSVC + LTO + PGO (use phase)
#   cmake -DENABLE_LTO=ON -DENABLE_PGO=USE -DPGO_PROFILES_DIR=/path/to/profiles ...
#

# ============================================================================
# Validate mutual exclusivity
# ============================================================================

if(NOT ENABLE_PGO STREQUAL "OFF" AND NOT ENABLE_HWPGO STREQUAL "OFF")
    message(FATAL_ERROR
        "ENABLE_PGO and ENABLE_HWPGO are mutually exclusive.\n"
        "Use either instrumented PGO (ENABLE_PGO=GENERATE|USE) or "
        "hardware PGO (ENABLE_HWPGO=GENERATE|USE), not both.")
endif()

# ============================================================================
# Instrumented PGO  (ENABLE_PGO = GENERATE | USE)
# ============================================================================

if(NOT ENABLE_PGO STREQUAL "OFF")

    message(STATUS "")
    message(STATUS "PGO (Profile-Guided Optimization) configuration:")
    message(STATUS "  Mode:               ${ENABLE_PGO}")
    message(STATUS "  Profiles directory: ${PGO_PROFILES_DIR}")

    # --- Ensure / validate profiles directory ---
    if(ENABLE_PGO STREQUAL "GENERATE")
        file(MAKE_DIRECTORY "${PGO_PROFILES_DIR}")
    elseif(ENABLE_PGO STREQUAL "USE")
        if(NOT EXISTS "${PGO_PROFILES_DIR}")
            message(FATAL_ERROR
                "PGO USE mode requires PGO_PROFILES_DIR to point to an existing "
                "directory containing profile data.\n"
                "  Current value: '${PGO_PROFILES_DIR}'")
        endif()
    endif()

    # --- Recommend LTO ---
    if(NOT ENABLE_LTO)
        message(STATUS "  Note: LTO is not enabled. Combining LTO with PGO is recommended "
                       "for best optimization results (-DENABLE_LTO=ON).")
    endif()

    # =================================================================
    # MSVC
    # =================================================================
    if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")

        # MSVC PGO requires /GL (Whole Program Optimization)
        if(NOT ENABLE_LTO)
            add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/GL>)
            message(STATUS "  Auto-enabled /GL (required for MSVC PGO)")
        endif()

        # Use a .pgd file in the profiles directory
        set(_msvc_pgd_file "${PGO_PROFILES_DIR}/openvino.pgd")

        if(ENABLE_PGO STREQUAL "GENERATE")
            foreach(_type IN ITEMS SHARED MODULE EXE)
                set(CMAKE_${_type}_LINKER_FLAGS
                    "${CMAKE_${_type}_LINKER_FLAGS} /GENPROFILE:PGD=${_msvc_pgd_file}")
            endforeach()
            message(STATUS "  Compile flags: /GL")
            message(STATUS "  Link flags:    /GENPROFILE:PGD=${_msvc_pgd_file}")
            message(STATUS "")
            message(STATUS "  ── PGO GENERATE workflow ──")
            message(STATUS "  1. Build the project with this configuration")
            message(STATUS "  2. Run representative workloads with the instrumented binaries")
            message(STATUS "  3. Profile data (.pgc files) will be written near the .pgd file")
            message(STATUS "  4. Reconfigure with:")
            message(STATUS "       -DENABLE_PGO=USE -DPGO_PROFILES_DIR=${PGO_PROFILES_DIR}")

        elseif(ENABLE_PGO STREQUAL "USE")
            foreach(_type IN ITEMS SHARED MODULE EXE)
                set(CMAKE_${_type}_LINKER_FLAGS
                    "${CMAKE_${_type}_LINKER_FLAGS} /USEPROFILE:PGD=${_msvc_pgd_file}")
            endforeach()
            message(STATUS "  Compile flags: /GL")
            message(STATUS "  Link flags:    /USEPROFILE:PGD=${_msvc_pgd_file}")
        endif()

        unset(_msvc_pgd_file)

    # =================================================================
    # ICX (Intel LLVM)
    # =================================================================
    elseif(OV_COMPILER_IS_INTEL_LLVM)

        if(WIN32)
            # ICX on Windows — use Intel-specific flags
            if(ENABLE_PGO STREQUAL "GENERATE")
                ov_add_compiler_flags(-Qprof-gen)
                ov_add_compiler_flags(-Qprof-dir=${PGO_PROFILES_DIR})
                foreach(_type IN ITEMS SHARED MODULE EXE)
                    set(CMAKE_${_type}_LINKER_FLAGS
                        "${CMAKE_${_type}_LINKER_FLAGS} -Qprof-gen")
                endforeach()
                message(STATUS "  Compile flags: -Qprof-gen -Qprof-dir=${PGO_PROFILES_DIR}")
                message(STATUS "  Link flags:    -Qprof-gen")
                message(STATUS "")
                message(STATUS "  ── PGO GENERATE workflow ──")
                message(STATUS "  1. Build the project with this configuration")
                message(STATUS "  2. Run representative workloads with the instrumented binaries")
                message(STATUS "  3. Profile data (.dyn files) will be written to: ${PGO_PROFILES_DIR}")
                message(STATUS "  4. Merge profiles:")
                message(STATUS "       profmerge -prof_dir ${PGO_PROFILES_DIR}")
                message(STATUS "  5. Reconfigure with:")
                message(STATUS "       -DENABLE_PGO=USE -DPGO_PROFILES_DIR=${PGO_PROFILES_DIR}")

            elseif(ENABLE_PGO STREQUAL "USE")
                ov_add_compiler_flags(-Qprof-use)
                ov_add_compiler_flags(-Qprof-dir=${PGO_PROFILES_DIR})
                foreach(_type IN ITEMS SHARED MODULE EXE)
                    set(CMAKE_${_type}_LINKER_FLAGS
                        "${CMAKE_${_type}_LINKER_FLAGS} -Qprof-use")
                endforeach()
                message(STATUS "  Compile flags: -Qprof-use -Qprof-dir=${PGO_PROFILES_DIR}")
                message(STATUS "  Link flags:    -Qprof-use")
            endif()

        else()
            # ICX on Linux — use LLVM-compatible flags
            if(ENABLE_PGO STREQUAL "GENERATE")
                ov_add_compiler_flags(-fprofile-generate=${PGO_PROFILES_DIR})
                foreach(_type IN ITEMS SHARED MODULE EXE)
                    set(CMAKE_${_type}_LINKER_FLAGS
                        "${CMAKE_${_type}_LINKER_FLAGS} -fprofile-generate=${PGO_PROFILES_DIR}")
                endforeach()
                message(STATUS "  Compile flags: -fprofile-generate=${PGO_PROFILES_DIR}")
                message(STATUS "  Link flags:    -fprofile-generate=${PGO_PROFILES_DIR}")
                message(STATUS "")
                message(STATUS "  ── PGO GENERATE workflow ──")
                message(STATUS "  1. Build the project with this configuration")
                message(STATUS "  2. Run representative workloads with the instrumented binaries")
                message(STATUS "  3. Profile data (.profraw) will be written to: ${PGO_PROFILES_DIR}")
                message(STATUS "  4. Merge profiles:")
                message(STATUS "       llvm-profdata merge -output=${PGO_PROFILES_DIR}/default.profdata ${PGO_PROFILES_DIR}/*.profraw")
                message(STATUS "  5. Reconfigure with:")
                message(STATUS "       -DENABLE_PGO=USE -DPGO_PROFILES_DIR=${PGO_PROFILES_DIR}")

            elseif(ENABLE_PGO STREQUAL "USE")
                ov_add_compiler_flags(-fprofile-use=${PGO_PROFILES_DIR})
                foreach(_type IN ITEMS SHARED MODULE EXE)
                    set(CMAKE_${_type}_LINKER_FLAGS
                        "${CMAKE_${_type}_LINKER_FLAGS} -fprofile-use=${PGO_PROFILES_DIR}")
                endforeach()
                message(STATUS "  Compile flags: -fprofile-use=${PGO_PROFILES_DIR}")
                message(STATUS "  Link flags:    -fprofile-use=${PGO_PROFILES_DIR}")
            endif()
        endif()

    # =================================================================
    # GCC
    # =================================================================
    elseif(CMAKE_COMPILER_IS_GNUCXX)

        if(ENABLE_PGO STREQUAL "GENERATE")
            ov_add_compiler_flags(-fprofile-generate=${PGO_PROFILES_DIR})
            foreach(_type IN ITEMS SHARED MODULE EXE)
                set(CMAKE_${_type}_LINKER_FLAGS
                    "${CMAKE_${_type}_LINKER_FLAGS} -fprofile-generate=${PGO_PROFILES_DIR}")
            endforeach()
            message(STATUS "  Compile flags: -fprofile-generate=${PGO_PROFILES_DIR}")
            message(STATUS "  Link flags:    -fprofile-generate=${PGO_PROFILES_DIR}")
            message(STATUS "")
            message(STATUS "  ── PGO GENERATE workflow ──")
            message(STATUS "  1. Build the project with this configuration")
            message(STATUS "  2. Run representative workloads with the instrumented binaries")
            message(STATUS "  3. Profile data (.gcda files) will be written to: ${PGO_PROFILES_DIR}")
            message(STATUS "  4. Reconfigure with:")
            message(STATUS "       -DENABLE_PGO=USE -DPGO_PROFILES_DIR=${PGO_PROFILES_DIR}")

        elseif(ENABLE_PGO STREQUAL "USE")
            ov_add_compiler_flags(-fprofile-use=${PGO_PROFILES_DIR})
            ov_add_compiler_flags(-fprofile-correction)
            foreach(_type IN ITEMS SHARED MODULE EXE)
                set(CMAKE_${_type}_LINKER_FLAGS
                    "${CMAKE_${_type}_LINKER_FLAGS} -fprofile-use=${PGO_PROFILES_DIR}")
            endforeach()
            message(STATUS "  Compile flags: -fprofile-use=${PGO_PROFILES_DIR} -fprofile-correction")
            message(STATUS "  Link flags:    -fprofile-use=${PGO_PROFILES_DIR}")
        endif()

    # =================================================================
    # Clang
    # =================================================================
    elseif(OV_COMPILER_IS_CLANG)

        if(ENABLE_PGO STREQUAL "GENERATE")
            ov_add_compiler_flags(-fprofile-generate=${PGO_PROFILES_DIR})
            foreach(_type IN ITEMS SHARED MODULE EXE)
                set(CMAKE_${_type}_LINKER_FLAGS
                    "${CMAKE_${_type}_LINKER_FLAGS} -fprofile-generate=${PGO_PROFILES_DIR}")
            endforeach()
            message(STATUS "  Compile flags: -fprofile-generate=${PGO_PROFILES_DIR}")
            message(STATUS "  Link flags:    -fprofile-generate=${PGO_PROFILES_DIR}")
            message(STATUS "")
            message(STATUS "  ── PGO GENERATE workflow ──")
            message(STATUS "  1. Build the project with this configuration")
            message(STATUS "  2. Run representative workloads with the instrumented binaries")
            message(STATUS "  3. Profile data (.profraw) will be written to: ${PGO_PROFILES_DIR}")
            message(STATUS "  4. Merge profiles:")
            message(STATUS "       llvm-profdata merge -output=${PGO_PROFILES_DIR}/default.profdata ${PGO_PROFILES_DIR}/*.profraw")
            message(STATUS "  5. Reconfigure with:")
            message(STATUS "       -DENABLE_PGO=USE -DPGO_PROFILES_DIR=${PGO_PROFILES_DIR}")

        elseif(ENABLE_PGO STREQUAL "USE")
            ov_add_compiler_flags(-fprofile-use=${PGO_PROFILES_DIR})
            foreach(_type IN ITEMS SHARED MODULE EXE)
                set(CMAKE_${_type}_LINKER_FLAGS
                    "${CMAKE_${_type}_LINKER_FLAGS} -fprofile-use=${PGO_PROFILES_DIR}")
            endforeach()
            message(STATUS "  Compile flags: -fprofile-use=${PGO_PROFILES_DIR}")
            message(STATUS "  Link flags:    -fprofile-use=${PGO_PROFILES_DIR}")
        endif()

    else()
        message(FATAL_ERROR "PGO is not supported for compiler: ${CMAKE_CXX_COMPILER_ID}")
    endif()

    message(STATUS "")
endif()

# ============================================================================
# Hardware PGO  (ENABLE_HWPGO = GENERATE | USE, ICX only)
#
#   GENERATE: compile with -fprofile-sample-generate to produce binaries
#             with DWARF debug info for accurate hardware profile collection.
#             On Windows, -fprofile-sample-generate requires the lld linker
#             (not link.exe) to preserve DWARF info. The ICX driver auto-
#             selects lld when this flag is specified. When invoking the
#             linker directly, use: lld-link /profile-sample-generate
#
#   USE:      recompile with -fprofile-sample-use=<file> to optimize using
#             the collected hardware profile. Does NOT require lld; the
#             default linker (link.exe) works fine for the USE phase.
#
#   Profile collection tools:
#     Linux:   perf record -b -c 1000003 -e br_inst_retired.near_taken:uppp
#     Windows: sep (from Intel VTune)
#
#   Profile conversion:
#     Linux:   llvm-profgen --perfdata <file> --binary <bin> --output <out>
#     Windows: llvm-profgen --perfscript <file.script> --binary <bin> --output <out>
# ============================================================================

if(NOT ENABLE_HWPGO STREQUAL "OFF")

    if(NOT OV_COMPILER_IS_INTEL_LLVM)
        message(FATAL_ERROR
            "Hardware PGO (HWPGO) is only supported with Intel LLVM (ICX) compiler.\n"
            "  Current compiler: ${CMAKE_CXX_COMPILER_ID}")
    endif()

    message(STATUS "")
    message(STATUS "Hardware PGO (HWPGO) configuration:")
    message(STATUS "  Mode:     ${ENABLE_HWPGO}")
    message(STATUS "  Compiler: Intel LLVM (ICX)")

    # --- Recommend LTO ---
    if(NOT ENABLE_LTO)
        message(STATUS "  Note: LTO is not enabled. Combining LTO with HWPGO is recommended "
                       "for best optimization results (-DENABLE_LTO=ON).")
    endif()

    # =================================================================
    # GENERATE phase
    # =================================================================
    if(ENABLE_HWPGO STREQUAL "GENERATE")

        # -fprofile-sample-generate adds DWARF debug info and frame pointers
        # so that hardware profiling tools (SEP/VTune on Windows, perf on Linux)
        # can collect accurate sample-based profiles.
        #
        # On Windows, this flag also requires the lld linker to preserve DWARF
        # info in the binary. The ICX driver auto-selects lld when it sees
        # -fprofile-sample-generate, but we pass -fuse-ld=lld explicitly to
        # ensure correctness when CMake invokes the linker separately.
        ov_add_compiler_flags(-fprofile-sample-generate)

        if(WIN32)
            foreach(_type IN ITEMS SHARED MODULE EXE)
                set(CMAKE_${_type}_LINKER_FLAGS
                    "${CMAKE_${_type}_LINKER_FLAGS} -fprofile-sample-generate -fuse-ld=lld")
            endforeach()
            message(STATUS "  Linker:        lld (required by -fprofile-sample-generate on Windows)")
            message(STATUS "  Compile flags: -fprofile-sample-generate")
            message(STATUS "  Link flags:    -fprofile-sample-generate -fuse-ld=lld")
        else()
            foreach(_type IN ITEMS SHARED MODULE EXE)
                set(CMAKE_${_type}_LINKER_FLAGS
                    "${CMAKE_${_type}_LINKER_FLAGS} -fprofile-sample-generate")
            endforeach()
            message(STATUS "  Compile flags: -fprofile-sample-generate")
            message(STATUS "  Link flags:    -fprofile-sample-generate")
        endif()

        message(STATUS "")
        message(STATUS "  ── HWPGO GENERATE workflow ──")
        message(STATUS "  1. Build the project with this configuration")
        if(WIN32)
            message(STATUS "  2. Collect hardware profile using SEP (from Intel VTune):")
            message(STATUS "       sep -start -out app.tb7 \\")
            message(STATUS "         -ec BR_INST_RETIRED.NEAR_TAKEN:PRECISE=YES:SA=1000003:pdir:lbr:USR=YES \\")
            message(STATUS "         -lbr no_filter:usr -perf-script ip,brstack -app .\\your_workload.exe")
            message(STATUS "  3. Convert to LLVM profile (note: use --perfscript on Windows):")
            message(STATUS "       llvm-profgen --perfscript app.perf.data.script --binary your_workload.exe --output profile.prof")
        else()
            message(STATUS "  2. Collect hardware profile using perf:")
            message(STATUS "       perf record -o perf.data -b -c 1000003 -e br_inst_retired.near_taken:uppp -- ./your_workload")
            message(STATUS "  3. Convert to LLVM profile:")
            message(STATUS "       llvm-profgen --perfdata perf.data --binary your_workload --output profile.prof")
        endif()
        message(STATUS "  4. Reconfigure with:")
        message(STATUS "       -DENABLE_HWPGO=USE -DHWPGO_PROFILE_FILE=<path/to/profile.prof>")

    # =================================================================
    # USE phase
    # =================================================================
    elseif(ENABLE_HWPGO STREQUAL "USE")

        if(NOT HWPGO_PROFILE_FILE)
            message(FATAL_ERROR
                "ENABLE_HWPGO=USE requires HWPGO_PROFILE_FILE to be set.\n"
                "  Set it to the path of the profile collected during the GENERATE phase.")
        endif()

        if(NOT EXISTS "${HWPGO_PROFILE_FILE}")
            message(FATAL_ERROR
                "HWPGO profile file does not exist: '${HWPGO_PROFILE_FILE}'")
        endif()

        message(STATUS "  Profile file: ${HWPGO_PROFILE_FILE}")

        # -fprofile-sample-use tells the compiler to use the collected profile
        # for optimization decisions. Unlike GENERATE, the USE phase does NOT
        # require lld on Windows — the default linker (link.exe) works fine.
        # The profile is consumed at compile time; passing it to the linker
        # makes it available during link-time optimization (LTO) if enabled.
        ov_add_compiler_flags(-fprofile-sample-use=${HWPGO_PROFILE_FILE})
        foreach(_type IN ITEMS SHARED MODULE EXE)
            set(CMAKE_${_type}_LINKER_FLAGS
                "${CMAKE_${_type}_LINKER_FLAGS} -fprofile-sample-use=${HWPGO_PROFILE_FILE}")
        endforeach()

        message(STATUS "  Compile flags: -fprofile-sample-use=${HWPGO_PROFILE_FILE}")
        message(STATUS "  Link flags:    -fprofile-sample-use=${HWPGO_PROFILE_FILE}")
    endif()

    message(STATUS "")
endif()
