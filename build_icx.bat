@echo off
set http_proxy=http://proxy-dmz.intel.com:911
set https_proxy=http://proxy-dmz.intel.com:912
REM ============================================================
REM  OpenVINO build script: ICX with progressive optimizations
REM
REM  Usage:
REM    build_icx.bat base              Baseline ICX build
REM    build_icx.bat arch              + PantherLake arch opt (/QxPANTHERLAKE)
REM    build_icx.bat arch-lto          + LTO
REM    build_icx.bat hwpgo-generate    + HWPGO generate (instrument for profiling)
REM    build_icx.bat hwpgo-use         + HWPGO use (rebuild with collected profile)
REM
REM  Optimization levels (progressive):
REM    base            :  ICX Release
REM    arch            :  ICX Release + /QxPANTHERLAKE
REM    arch-lto        :  ICX Release + /QxPANTHERLAKE + LTO
REM    hwpgo-generate  :  ICX Release + /QxPANTHERLAKE + LTO + HWPGO gen
REM    hwpgo-use       :  ICX Release + /QxPANTHERLAKE + LTO + HWPGO use
REM
REM  HWPGO workflow:
REM    1. build_icx.bat hwpgo-generate  (build with DWARF debug info)
REM    2. Collect profile using SEP (from Intel VTune):
REM       sep -start -out app.tb7 -ec BR_INST_RETIRED.NEAR_TAKEN:PRECISE=YES:SA=1000003:pdir:lbr:USR=YES
REM         -lbr no_filter:usr -perf-script ip,brstack -app .\your_workload.exe
REM    3. Convert profile:
REM       llvm-profgen --perfscript app.perf.data.script --binary your_workload.exe --output profile.prof
REM    4. Place profile at: C:\Users\gta\Desktop\openvino\icx\pgo_profiles\profile.prof
REM    5. build_icx.bat hwpgo-use       (rebuild with profile)
REM ============================================================

setlocal enabledelayedexpansion

set MODE=%1
if "%MODE%"=="" set MODE=base

REM --- Common configuration ---
set ARCH=PANTHERLAKE
set PROFILE_DIR=C:\Users\gta\Desktop\openvino\icx\pgo_profiles
set PROFILE_FILE=%PROFILE_DIR%\profile.prof

REM --- Setup oneAPI environment ---
call "C:\Program Files (x86)\Intel\oneAPI\setvars.bat"

REM --- Dispatch ---
if /i "%MODE%"=="base" goto :mode_base
if /i "%MODE%"=="arch" goto :mode_arch
if /i "%MODE%"=="arch-lto" goto :mode_arch_lto
if /i "%MODE%"=="hwpgo-generate" goto :mode_hwpgo_generate
if /i "%MODE%"=="hwpgo-use" goto :mode_hwpgo_use

echo ERROR: Unknown mode "%MODE%"
echo Usage: build_icx.bat [base ^| arch ^| arch-lto ^| hwpgo-generate ^| hwpgo-use]
exit /b 1

REM ============================================================
REM  Mode 1: Baseline ICX
REM ============================================================
:mode_base
echo.
echo ============================================================
echo  Building: ICX baseline (Release)
echo ============================================================
echo.

rmdir /s /q build_release_2025.4_icx 2>nul

cmake -B build_release_2025.4_icx -G "Ninja" ^
    -DCMAKE_C_COMPILER=icx ^
    -DCMAKE_CXX_COMPILER=icx ^
    -DENABLE_INTEL_GPU=OFF ^
    -DENABLE_INTEL_NPU=OFF ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DENABLE_PYTHON=ON ^
    -DENABLE_WHEEL=ON

cmake --build build_release_2025.4_icx --config Release --verbose -j
if errorlevel 1 exit /b 1

cmake --install build_release_2025.4_icx --prefix "C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx"

echo.
echo  Building samples...
call "C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx\setupvars.bat"
set "SAMPLES_SRC=C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx\samples\cpp"
set "SAMPLES_BLD=C:\Users\gta\Desktop\openvino\icx\build_samples_icx"
rmdir /s /q "%SAMPLES_BLD%" 2>nul
cmake -B "%SAMPLES_BLD%" -S "%SAMPLES_SRC%" -G "Ninja" -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icx -DCMAKE_BUILD_TYPE=Release
cmake --build "%SAMPLES_BLD%" --config Release --parallel

echo.
echo ============================================================
echo  ICX baseline build complete.
echo  Installed to: C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx
echo  Samples built to: C:\Users\gta\Desktop\openvino\icx\build_samples_icx
echo ============================================================
goto :done

REM ============================================================
REM  Mode 2: ICX + Architecture Opt
REM ============================================================
:mode_arch
echo.
echo ============================================================
echo  Building: ICX + %ARCH% arch opt
echo ============================================================
echo.

rmdir /s /q build_release_2025.4_icx_ptl 2>nul

cmake -B build_release_2025.4_icx_ptl -G "Ninja" ^
    -DCMAKE_C_COMPILER=icx ^
    -DCMAKE_CXX_COMPILER=icx ^
    -DENABLE_INTEL_GPU=OFF ^
    -DENABLE_INTEL_NPU=OFF ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DENABLE_PYTHON=ON ^
    -DENABLE_WHEEL=ON ^
    -DOV_TARGET_ARCH=%ARCH%

cmake --build build_release_2025.4_icx_ptl --config Release --verbose -j
if errorlevel 1 exit /b 1

cmake --install build_release_2025.4_icx_ptl --prefix "C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx_ptl"

echo.
echo  Building samples...
call "C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx_ptl\setupvars.bat"
set "SAMPLES_SRC=C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx_ptl\samples\cpp"
set "SAMPLES_BLD=C:\Users\gta\Desktop\openvino\icx\build_samples_icx_ptl"
rmdir /s /q "%SAMPLES_BLD%" 2>nul
cmake -B "%SAMPLES_BLD%" -S "%SAMPLES_SRC%" -G "Ninja" -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icx -DCMAKE_BUILD_TYPE=Release
cmake --build "%SAMPLES_BLD%" --config Release --parallel

echo.
echo ============================================================
echo  ICX + %ARCH% build complete.
echo  Installed to: C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx_ptl
echo  Samples built to: C:\Users\gta\Desktop\openvino\icx\build_samples_icx_ptl
echo ============================================================
goto :done

REM ============================================================
REM  Mode 3: ICX + Architecture Opt + LTO
REM ============================================================
:mode_arch_lto
echo.
echo ============================================================
echo  Building: ICX + %ARCH% + LTO
echo ============================================================
echo.

rmdir /s /q build_release_2025.4_icx_ptl_lto 2>nul

cmake -B build_release_2025.4_icx_ptl_lto -G "Ninja" ^
    -DCMAKE_C_COMPILER=icx ^
    -DCMAKE_CXX_COMPILER=icx ^
    -DENABLE_INTEL_GPU=OFF ^
    -DENABLE_INTEL_NPU=OFF ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DENABLE_PYTHON=ON ^
    -DENABLE_WHEEL=ON ^
    -DOV_TARGET_ARCH=%ARCH% ^
    -DENABLE_LTO=ON

cmake --build build_release_2025.4_icx_ptl_lto --config Release --verbose -j
if errorlevel 1 exit /b 1

cmake --install build_release_2025.4_icx_ptl_lto --prefix "C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx_ptl_lto"

echo.
echo  Building samples...
call "C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx_ptl_lto\setupvars.bat"
set "SAMPLES_SRC=C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx_ptl_lto\samples\cpp"
set "SAMPLES_BLD=C:\Users\gta\Desktop\openvino\icx\build_samples_icx_ptl_lto"
rmdir /s /q "%SAMPLES_BLD%" 2>nul
cmake -B "%SAMPLES_BLD%" -S "%SAMPLES_SRC%" -G "Ninja" -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icx -DCMAKE_BUILD_TYPE=Release
cmake --build "%SAMPLES_BLD%" --config Release --parallel

echo.
echo ============================================================
echo  ICX + %ARCH% + LTO build complete.
echo  Installed to: C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx_ptl_lto
echo  Samples built to: C:\Users\gta\Desktop\openvino\icx\build_samples_icx_ptl_lto
echo ============================================================
goto :done

REM ============================================================
REM  Mode 4: ICX + Architecture Opt + LTO + HWPGO Generate
REM ============================================================
:mode_hwpgo_generate
echo.
echo ============================================================
echo  Building: ICX + %ARCH% + LTO + HWPGO GENERATE
echo  Adds -fprofile-sample-generate for hardware profile collection
echo ============================================================
echo.

rmdir /s /q build_release_2025.4_icx_ptl_lto_hwpgo_gen 2>nul

cmake -B build_release_2025.4_icx_ptl_lto_hwpgo_gen -G "Ninja" ^
    -DCMAKE_C_COMPILER=icx ^
    -DCMAKE_CXX_COMPILER=icx ^
    -DENABLE_INTEL_GPU=OFF ^
    -DENABLE_INTEL_NPU=OFF ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DENABLE_PYTHON=ON ^
    -DENABLE_WHEEL=ON ^
    -DOV_TARGET_ARCH=%ARCH% ^
    -DENABLE_LTO=ON ^
    -DENABLE_HWPGO=GENERATE

cmake --build build_release_2025.4_icx_ptl_lto_hwpgo_gen --config Release --verbose -j
if errorlevel 1 exit /b 1

cmake --install build_release_2025.4_icx_ptl_lto_hwpgo_gen --prefix "C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx_ptl_lto_hwpgo_gen"

echo.
echo  Building samples...
call "C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx_ptl_lto_hwpgo_gen\setupvars.bat"
set "SAMPLES_SRC=C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx_ptl_lto_hwpgo_gen\samples\cpp"
set "SAMPLES_BLD=C:\Users\gta\Desktop\openvino\icx\build_samples_icx_ptl_lto_hwpgo_gen"
rmdir /s /q "%SAMPLES_BLD%" 2>nul
cmake -B "%SAMPLES_BLD%" -S "%SAMPLES_SRC%" -G "Ninja" -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icx -DCMAKE_BUILD_TYPE=Release
cmake --build "%SAMPLES_BLD%" --config Release --parallel

echo.
echo ============================================================
echo  HWPGO GENERATE build complete.
echo  Installed to: C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx_ptl_lto_hwpgo_gen
echo  Samples built to: C:\Users\gta\Desktop\openvino\icx\build_samples_icx_ptl_lto_hwpgo_gen
echo.
echo  Next steps:
echo    1. Collect profile using SEP (from Intel VTune):
echo       sep -start -out app.tb7 ^
echo         -ec BR_INST_RETIRED.NEAR_TAKEN:PRECISE=YES:SA=1000003:pdir:lbr:USR=YES ^
echo         -lbr no_filter:usr -perf-script ip,brstack -app .\your_workload.exe
echo    2. Convert to LLVM profile (note: use --perfscript on Windows):
echo       llvm-profgen --perfscript app.perf.data.script --binary your_workload.exe --output profile.prof
echo    3. Place profile at: %PROFILE_FILE%
echo    4. Run: build_icx.bat hwpgo-use
echo ============================================================
goto :done

REM ============================================================
REM  Mode 5: ICX + Architecture Opt + LTO + HWPGO Use
REM ============================================================
:mode_hwpgo_use
echo.
echo ============================================================
echo  Building: ICX + %ARCH% + LTO + HWPGO USE
echo  Uses collected profile for optimization
echo ============================================================
echo.

REM --- Validate profile file exists ---
if exist "%PROFILE_FILE%" goto :hwpgo_profile_found
echo ERROR: HWPGO profile file not found:
echo   %PROFILE_FILE%
echo.
echo You must first:
echo   1. Run: build_icx.bat hwpgo-generate
echo   2. Profile the built binaries using SEP (from Intel VTune)
echo   3. Convert with: llvm-profgen --perfscript ^<file^> --binary ^<exe^> --output profile.prof
echo   4. Place profile.prof at the path above
exit /b 1
:hwpgo_profile_found
echo Using profile: %PROFILE_FILE%

rmdir /s /q build_release_2025.4_icx_ptl_lto_hwpgo 2>nul

cmake -B build_release_2025.4_icx_ptl_lto_hwpgo -G "Ninja" ^
    -DCMAKE_C_COMPILER=icx ^
    -DCMAKE_CXX_COMPILER=icx ^
    -DENABLE_INTEL_GPU=OFF ^
    -DENABLE_INTEL_NPU=OFF ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DENABLE_PYTHON=ON ^
    -DENABLE_WHEEL=ON ^
    -DOV_TARGET_ARCH=%ARCH% ^
    -DENABLE_LTO=ON ^
    -DENABLE_HWPGO=USE ^
    -DHWPGO_PROFILE_FILE="%PROFILE_FILE%"

cmake --build build_release_2025.4_icx_ptl_lto_hwpgo --config Release --verbose -j
if errorlevel 1 exit /b 1

cmake --install build_release_2025.4_icx_ptl_lto_hwpgo --prefix "C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx_ptl_lto_hwpgo"

echo.
echo  Building samples...
call "C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx_ptl_lto_hwpgo\setupvars.bat"
set "SAMPLES_SRC=C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx_ptl_lto_hwpgo\samples\cpp"
set "SAMPLES_BLD=C:\Users\gta\Desktop\openvino\icx\build_samples_icx_ptl_lto_hwpgo"
rmdir /s /q "%SAMPLES_BLD%" 2>nul
cmake -B "%SAMPLES_BLD%" -S "%SAMPLES_SRC%" -G "Ninja" -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icx -DCMAKE_BUILD_TYPE=Release
cmake --build "%SAMPLES_BLD%" --config Release --parallel

echo.
echo ============================================================
echo  ICX + %ARCH% + LTO + HWPGO build complete.
echo  Installed to: C:\Users\gta\Desktop\openvino\icx\ov_2025.4_icx_ptl_lto_hwpgo
echo  Samples built to: C:\Users\gta\Desktop\openvino\icx\build_samples_icx_ptl_lto_hwpgo
echo ============================================================
goto :done

:done
endlocal
