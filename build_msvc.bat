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
REM    2. Run representative workloads (.pgc files generated automatically)
REM    3. build_msvc.bat pgo-use        (rebuild with collected profile)
REM ============================================================

setlocal enabledelayedexpansion

set MODE=%1
if "%MODE%"=="" set MODE=base

REM --- Common configuration ---
set ARCH=PANTHERLAKE
set PGO_DIR=C:\Users\gta\Desktop\openvino\msvc\pgo_profiles

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

cmake --build build_release_2025.4_msvc --config Release --verbose -j

cmake --install build_release_2025.4_msvc --config Release --prefix "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc"

echo.
echo  Building samples...
call "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc\setupvars.bat"
cd /d "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc\samples\cpp"
rmdir /s /q "C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc" 2>nul
call .\build_samples_msvc.bat -b "C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc"
cd /d "%~dp0"

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

cmake --build build_release_2025.4_msvc_ptl --config Release --verbose -j

cmake --install build_release_2025.4_msvc_ptl --config Release --prefix "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl"

echo.
echo  Building samples...
call "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl\setupvars.bat"
cd /d "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl\samples\cpp"
rmdir /s /q "C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl" 2>nul
call .\build_samples_msvc.bat -b "C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl"
cd /d "%~dp0"

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

cmake --build build_release_2025.4_msvc_ptl_lto --config Release --verbose -j

cmake --install build_release_2025.4_msvc_ptl_lto --config Release --prefix "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto"

echo.
echo  Building samples...
call "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto\setupvars.bat"
cd /d "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto\samples\cpp"
rmdir /s /q "C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl_lto" 2>nul
call .\build_samples_msvc.bat -b "C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl_lto"
cd /d "%~dp0"

echo.
echo ============================================================
echo  MSVC + %ARCH% + LTO build complete.
echo  Installed to: C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto
echo  Samples built to: C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl_lto
echo ============================================================
goto :done

REM ============================================================
REM  Mode 4: MSVC + Architecture Opt + LTO + PGO Generate
REM ============================================================
:mode_pgo_generate
echo.
echo ============================================================
echo  Building: MSVC + %ARCH% + LTO + PGO GENERATE
echo  Adds /GL (compile) + /GENPROFILE (link)
echo ============================================================
echo.

if not exist "%PGO_DIR%" mkdir "%PGO_DIR%"

rmdir /s /q build_release_2025.4_msvc_ptl_lto_pgo_gen 2>nul

cmake -B build_release_2025.4_msvc_ptl_lto_pgo_gen -G "Visual Studio 17 2022" -A x64 ^
    -DENABLE_INTEL_GPU=OFF ^
    -DENABLE_INTEL_NPU=OFF ^
    -DENABLE_PYTHON=ON ^
    -DENABLE_WHEEL=ON ^
    -DOV_TARGET_ARCH=%ARCH% ^
    -DENABLE_LTO=ON ^
    -DENABLE_PGO=GENERATE ^
    -DPGO_PROFILES_DIR="%PGO_DIR%"

cmake --build build_release_2025.4_msvc_ptl_lto_pgo_gen --config Release --verbose -j

cmake --install build_release_2025.4_msvc_ptl_lto_pgo_gen --config Release --prefix "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto_pgo_gen"

echo.
echo  Building samples...
call "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto_pgo_gen\setupvars.bat"
cd /d "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto_pgo_gen\samples\cpp"
rmdir /s /q "C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl_lto_pgo_gen" 2>nul
call .\build_samples_msvc.bat -b "C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl_lto_pgo_gen"
cd /d "%~dp0"

echo.
echo ============================================================
echo  PGO GENERATE build complete.
echo  Installed to: C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto_pgo_gen
echo  Samples built to: C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl_lto_pgo_gen
echo.
echo  Next steps:
echo    1. Run representative workloads with the installed binaries
echo       .pgc profile data will be generated alongside the .pgd at:
echo       %PGO_DIR%
echo    2. Run: build_msvc.bat pgo-use
echo ============================================================
goto :done

REM ============================================================
REM  Mode 5: MSVC + Architecture Opt + LTO + PGO Use
REM ============================================================
:mode_pgo_use
echo.
echo ============================================================
echo  Building: MSVC + %ARCH% + LTO + PGO USE
echo  Uses collected profile for optimization
echo ============================================================
echo.

REM --- Validate profile directory exists ---
if not exist "%PGO_DIR%" (
    echo ERROR: PGO profiles directory not found:
    echo   %PGO_DIR%
    echo.
    echo You must first:
    echo   1. Run: build_msvc.bat pgo-generate
    echo   2. Run representative workloads with the instrumented binaries
    exit /b 1
)

echo Using profiles from: %PGO_DIR%

rmdir /s /q build_release_2025.4_msvc_ptl_lto_pgo 2>nul

cmake -B build_release_2025.4_msvc_ptl_lto_pgo -G "Visual Studio 17 2022" -A x64 ^
    -DENABLE_INTEL_GPU=OFF ^
    -DENABLE_INTEL_NPU=OFF ^
    -DENABLE_PYTHON=ON ^
    -DENABLE_WHEEL=ON ^
    -DOV_TARGET_ARCH=%ARCH% ^
    -DENABLE_LTO=ON ^
    -DENABLE_PGO=USE ^
    -DPGO_PROFILES_DIR="%PGO_DIR%"

cmake --build build_release_2025.4_msvc_ptl_lto_pgo --config Release --verbose -j

cmake --install build_release_2025.4_msvc_ptl_lto_pgo --config Release --prefix "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto_pgo"

echo.
echo  Building samples...
call "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto_pgo\setupvars.bat"
cd /d "C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto_pgo\samples\cpp"
rmdir /s /q "C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl_lto_pgo" 2>nul
call .\build_samples_msvc.bat -b "C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl_lto_pgo"
cd /d "%~dp0"

echo.
echo ============================================================
echo  MSVC + %ARCH% + LTO + PGO build complete.
echo  Installed to: C:\Users\gta\Desktop\openvino\msvc\ov_2025.4_msvc_ptl_lto_pgo
echo  Samples built to: C:\Users\gta\Desktop\openvino\msvc\build_samples_msvc_ptl_lto_pgo
echo ============================================================
goto :done

:done
endlocal
