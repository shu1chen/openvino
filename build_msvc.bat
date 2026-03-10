@echo off
set http_proxy=http://proxy-dmz.intel.com:911
set https_proxy=http://proxy-dmz.intel.com:912
REM ============================================================
REM  OpenVINO build script: MSVC with progressive optimizations
REM
REM  Usage:
REM    build_msvc.bat base              Baseline MSVC build
REM    build_msvc.bat arch              + PantherLake arch opt (/arch:AVX2)
REM    build_msvc.bat arch-lto          + LTO (/GL + /LTCG)
REM    build_msvc.bat pgo-generate      + PGO generate (/GENPROFILE)
REM    build_msvc.bat pgo-use           + PGO use (/USEPROFILE)
REM
REM  Optimization levels (progressive):
REM    base          :  MSVC Release
REM    arch          :  MSVC Release + /arch:AVX2 (PANTHERLAKE mapping)
REM    arch-lto      :  MSVC Release + /arch:AVX2 + /GL + /LTCG
REM    pgo-generate  :  MSVC Release + /arch:AVX2 + /GL + /GENPROFILE
REM    pgo-use       :  MSVC Release + /arch:AVX2 + /GL + /USEPROFILE
REM
REM  PGO workflow:
REM    1. build_msvc.bat pgo-generate   (build instrumented binaries)
REM    2. Run representative workloads with the INSTALLED binaries
REM    3. build_msvc.bat pgo-use        (reconfigure same build dir with /USEPROFILE)
REM
REM  How MSVC PGO profile data works:
REM    - OpenVINO cmake sets CMAKE_RUNTIME_OUTPUT_DIRECTORY to
REM      <source_dir>\bin\intel64\<config>, so ALL binaries (DLLs, EXEs)
REM      go to openvino\bin\intel64\Release\ (not inside the build tree).
REM    - The GENERATE link creates a .pgd file next to each binary
REM      (e.g. openvino\bin\intel64\Release\openvino.pgd)
REM    - The absolute .pgd path is BAKED INTO the instrumented binary
REM    - At runtime, the PGO runtime writes .pgc files next to the .pgd,
REM      regardless of where the binary is executed from
REM    - The USE link finds <target>.pgd + <target>!N.pgc in the output dir
REM
REM  Optional: set VCPROFILE_PATH=<dir> before running workloads to redirect
REM            .pgc output to a different directory.
REM
REM  IMPORTANT: Do NOT delete the build directory or bin\intel64\ between phases.
REM ============================================================

setlocal enabledelayedexpansion

set MODE=%1
if "%MODE%"=="" set MODE=base

REM --- Common configuration ---
set ARCH=PANTHERLAKE

REM --- Setup TBB environment ---
call "C:\Program Files (x86)\Intel\oneAPI\setvars.bat"

REM --- Dispatch ---
if /i "%MODE%"=="base" goto :mode_base
if /i "%MODE%"=="arch" goto :mode_arch
if /i "%MODE%"=="arch-lto" goto :mode_arch_lto
if /i "%MODE%"=="pgo-generate" goto :mode_pgo_generate
if /i "%MODE%"=="pgo-use" goto :mode_pgo_use

echo ERROR: Unknown mode "%MODE%"
echo Usage: build_msvc.bat [base ^| arch ^| arch-lto ^| pgo-generate ^| pgo-use]
exit /b 1

REM ============================================================
REM  Mode 1: Baseline MSVC
REM ============================================================
:mode_base
echo.
echo ============================================================
echo  Building: MSVC baseline (Release)
echo ============================================================
echo.

rmdir /s /q build_release_2025.4_msvc 2>nul

cmake -B build_release_2025.4_msvc -G "Visual Studio 17 2022" -A x64 ^
    -DENABLE_INTEL_GPU=OFF ^
    -DENABLE_INTEL_NPU=OFF ^
    -DENABLE_PYTHON=ON ^
    -DENABLE_WHEEL=ON

cmake --build build_release_2025.4_msvc --config Release --verbose -j -- /p:StopOnFirstFailure=true
if errorlevel 1 exit /b 1

cmake --install build_release_2025.4_msvc --config Release --prefix "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc"

echo.
echo  Building samples...
call "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc\setupvars.bat"
set "SAMPLES_SRC=C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc\samples\cpp"
set "SAMPLES_BLD=C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc"
rmdir /s /q "%SAMPLES_BLD%" 2>nul
cmake -B "%SAMPLES_BLD%" -S "%SAMPLES_SRC%" -G "Visual Studio 17 2022" -A x64
cmake --build "%SAMPLES_BLD%" --config Release --parallel

echo.
echo ============================================================
echo  MSVC baseline build complete.
echo  Installed to: C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc
echo  Samples built to: C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc
echo ============================================================
goto :done

REM ============================================================
REM  Mode 2: MSVC + Architecture Opt
REM ============================================================
:mode_arch
echo.
echo ============================================================
echo  Building: MSVC + %ARCH% arch opt
echo ============================================================
echo.

rmdir /s /q build_release_2025.4_msvc_ptl 2>nul

cmake -B build_release_2025.4_msvc_ptl -G "Visual Studio 17 2022" -A x64 ^
    -DENABLE_INTEL_GPU=OFF ^
    -DENABLE_INTEL_NPU=OFF ^
    -DENABLE_PYTHON=ON ^
    -DENABLE_WHEEL=ON ^
    -DOV_TARGET_ARCH=%ARCH%

cmake --build build_release_2025.4_msvc_ptl --config Release --verbose -j -- /p:StopOnFirstFailure=true
if errorlevel 1 exit /b 1

cmake --install build_release_2025.4_msvc_ptl --config Release --prefix "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl"

echo.
echo  Building samples...
call "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl\setupvars.bat"
set "SAMPLES_SRC=C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl\samples\cpp"
set "SAMPLES_BLD=C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl"
rmdir /s /q "%SAMPLES_BLD%" 2>nul
cmake -B "%SAMPLES_BLD%" -S "%SAMPLES_SRC%" -G "Visual Studio 17 2022" -A x64
cmake --build "%SAMPLES_BLD%" --config Release --parallel

echo.
echo ============================================================
echo  MSVC + %ARCH% build complete.
echo  Installed to: C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl
echo  Samples built to: C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl
echo ============================================================
goto :done

REM ============================================================
REM  Mode 3: MSVC + Architecture Opt + LTO
REM ============================================================
:mode_arch_lto
echo.
echo ============================================================
echo  Building: MSVC + %ARCH% + LTO
echo ============================================================
echo.

rmdir /s /q build_release_2025.4_msvc_ptl_lto 2>nul

cmake -B build_release_2025.4_msvc_ptl_lto -G "Visual Studio 17 2022" -A x64 ^
    -DENABLE_INTEL_GPU=OFF ^
    -DENABLE_INTEL_NPU=OFF ^
    -DENABLE_PYTHON=ON ^
    -DENABLE_WHEEL=ON ^
    -DOV_TARGET_ARCH=%ARCH% ^
    -DENABLE_LTO=ON

cmake --build build_release_2025.4_msvc_ptl_lto --config Release --verbose -j -- /p:StopOnFirstFailure=true
if errorlevel 1 exit /b 1

cmake --install build_release_2025.4_msvc_ptl_lto --config Release --prefix "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto"

echo.
echo  Building samples...
call "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto\setupvars.bat"
set "SAMPLES_SRC=C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto\samples\cpp"
set "SAMPLES_BLD=C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl_lto"
rmdir /s /q "%SAMPLES_BLD%" 2>nul
cmake -B "%SAMPLES_BLD%" -S "%SAMPLES_SRC%" -G "Visual Studio 17 2022" -A x64
cmake --build "%SAMPLES_BLD%" --config Release --parallel

echo.
echo ============================================================
echo  MSVC + %ARCH% + LTO build complete.
echo  Installed to: C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto
echo  Samples built to: C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl_lto
echo ============================================================
goto :done

REM ============================================================
REM  Mode 4: MSVC + Architecture Opt + LTO + PGO Generate
REM
REM  IMPORTANT: pgo-generate and pgo-use share the same build
REM  directory (build_release_2025.4_msvc_ptl_lto_pgo). Each
REM  target creates its own .pgd file next to its binary. The
REM  .pgc files from profiling runs land beside them. The USE
REM  phase reconfigures the SAME directory so MSVC can find the
REM  per-target .pgd/.pgc files.
REM ============================================================
:mode_pgo_generate
echo.
echo ============================================================
echo  Building: MSVC + %ARCH% + LTO + PGO GENERATE
echo  Adds /GL (compile) + /LTCG /GENPROFILE (link)
echo  Per-target .pgd files created next to each binary
echo ============================================================
echo.

rmdir /s /q build_release_2025.4_msvc_ptl_lto_pgo 2>nul

cmake -B build_release_2025.4_msvc_ptl_lto_pgo -G "Visual Studio 17 2022" -A x64 ^
    -DENABLE_INTEL_GPU=OFF ^
    -DENABLE_INTEL_NPU=OFF ^
    -DENABLE_PYTHON=ON ^
    -DENABLE_WHEEL=ON ^
    -DOV_TARGET_ARCH=%ARCH% ^
    -DENABLE_LTO=ON ^
    -DENABLE_PGO=GENERATE

cmake --build build_release_2025.4_msvc_ptl_lto_pgo --config Release --verbose -j -- /p:StopOnFirstFailure=true
if errorlevel 1 exit /b 1

cmake --install build_release_2025.4_msvc_ptl_lto_pgo --config Release --prefix "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto_pgo_gen"

echo.
echo  Building samples...
call "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto_pgo_gen\setupvars.bat"
set "SAMPLES_SRC=C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto_pgo_gen\samples\cpp"
set "SAMPLES_BLD=C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl_lto_pgo_gen"
rmdir /s /q "%SAMPLES_BLD%" 2>nul
cmake -B "%SAMPLES_BLD%" -S "%SAMPLES_SRC%" -G "Visual Studio 17 2022" -A x64
cmake --build "%SAMPLES_BLD%" --config Release --parallel

echo.
echo ============================================================
echo  PGO GENERATE build complete.
echo  Installed to: C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto_pgo_gen
echo  Samples built to: C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl_lto_pgo_gen
echo.
echo  .pgd files created next to each binary in the build tree.
echo  The absolute .pgd path is baked into each instrumented binary.
echo.
echo  Next steps:
echo    1. Run representative workloads with the INSTALLED binaries
echo       (the .pgc profile data will be written back to the BUILD TREE,
echo        next to each .pgd file, NOT next to the installed binary)
echo.
echo       Optional: set VCPROFILE_PATH=^<dir^> before running workloads
echo       to redirect .pgc output to a custom directory.
echo.
echo    2. Run: build_msvc.bat pgo-use
echo       (do NOT manually delete build_release_2025.4_msvc_ptl_lto_pgo)
echo ============================================================
goto :done

REM ============================================================
REM  Mode 5: MSVC + Architecture Opt + LTO + PGO Use
REM
REM  Re-uses the SAME build directory from pgo-generate so the
REM  linker can find each target's .pgd + .pgc files.
REM ============================================================
:mode_pgo_use
echo.
echo ============================================================
echo  Building: MSVC + %ARCH% + LTO + PGO USE
echo  Reconfigures the GENERATE build dir with /USEPROFILE
echo ============================================================
echo.

REM --- Validate the generate build directory exists ---
if not exist "build_release_2025.4_msvc_ptl_lto_pgo" (
    echo ERROR: PGO GENERATE build directory not found:
    echo   build_release_2025.4_msvc_ptl_lto_pgo
    echo.
    echo You must first:
    echo   1. Run: build_msvc.bat pgo-generate
    echo   2. Run representative workloads with the instrumented binaries
    exit /b 1
)

REM --- Reconfigure the SAME build dir with USE (do NOT rmdir) ---
cmake -B build_release_2025.4_msvc_ptl_lto_pgo -G "Visual Studio 17 2022" -A x64 ^
    -DENABLE_INTEL_GPU=OFF ^
    -DENABLE_INTEL_NPU=OFF ^
    -DENABLE_PYTHON=ON ^
    -DENABLE_WHEEL=ON ^
    -DOV_TARGET_ARCH=%ARCH% ^
    -DENABLE_LTO=ON ^
    -DENABLE_PGO=USE

cmake --build build_release_2025.4_msvc_ptl_lto_pgo --config Release --verbose -j -- /p:StopOnFirstFailure=true
if errorlevel 1 exit /b 1

cmake --install build_release_2025.4_msvc_ptl_lto_pgo --config Release --prefix "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto_pgo"

echo.
echo  Building samples...
call "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto_pgo\setupvars.bat"
set "SAMPLES_SRC=C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto_pgo\samples\cpp"
set "SAMPLES_BLD=C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl_lto_pgo"
rmdir /s /q "%SAMPLES_BLD%" 2>nul
cmake -B "%SAMPLES_BLD%" -S "%SAMPLES_SRC%" -G "Visual Studio 17 2022" -A x64
cmake --build "%SAMPLES_BLD%" --config Release --parallel

echo.
echo ============================================================
echo  MSVC + %ARCH% + LTO + PGO build complete.
echo  Installed to: C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto_pgo
echo  Samples built to: C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl_lto_pgo
echo ============================================================
goto :done

:done
endlocal
