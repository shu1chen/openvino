@echo off
setlocal enabledelayedexpansion

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"

set "BUILD_DIR=%ROOT_DIR%\build"
set "INSTALL_DIR="
set "CMAKE_GENERATOR=Ninja"

:argParse
if "%~1" == "" goto checkSetup
if "%~1" == "-b" (
   set "BUILD_DIR=%~2"
   shift
   shift
   goto argParse
)
if "%~1" == "-i" (
   set "INSTALL_DIR=%~2"
   shift
   shift
   goto argParse
)
if "%~1" == "-h" (
   goto help
   shift
   goto argParse
)
goto argParse

:help
echo Usage: build_samples_icx.bat [-b BUILD_DIR] [-i INSTALL_DIR] [-h]
echo.
echo Options:
echo   -b BUILD_DIR    Specify the build directory. Default: %ROOT_DIR%\build
echo   -i INSTALL_DIR  Specify the install directory.
echo   -h              Show this help message.
exit /b 0

:checkSetup
if "%OpenVINO_DIR%"=="" (
    if exist "%ROOT_DIR%\..\..\setupvars.bat" (
        echo [INFO] OpenVINO_DIR not set. Trying to run setupvars.bat...
        call "%ROOT_DIR%\..\..\setupvars.bat"
    ) else (
        echo [WARNING] OpenVINO_DIR not set and setupvars.bat not found in standard location.
        echo           Build might fail if OpenVINO is not found.
    )
)

:build
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
cd /d "%BUILD_DIR%"

echo [INFO] Building with Intel LLVM (icx)...
echo [INFO] Build Dir: %BUILD_DIR%
echo [INFO] Source Dir: %ROOT_DIR%

cmake -G "%CMAKE_GENERATOR%" ^
      -DCMAKE_CXX_COMPILER=icx ^
      -DCMAKE_C_COMPILER=icx ^
      -DCMAKE_BUILD_TYPE=Release ^
      "%ROOT_DIR%"

if errorlevel 1 (
   echo [ERROR] CMake failed.
   exit /b 1
)

cmake --build . --config Release --parallel

if errorlevel 1 (
   echo [ERROR] Build failed.
   exit /b 1
)

echo [INFO] Build successful.
echo [INFO] Executables are in %BUILD_DIR%\intel64\Release

if defined INSTALL_DIR (
   echo [INFO] Installing to %INSTALL_DIR%...
   cmake -DCMAKE_INSTALL_PREFIX="%INSTALL_DIR%" -DCOMPONENT=samples_bin -P "%BUILD_DIR%\cmake_install.cmake"
   if errorlevel 1 (
      echo [ERROR] Installation failed.
      exit /b 1
   )
   echo [INFO] Installation successful.
)

endlocal
