@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%" >nul

if not defined SWIFT_EXE (
    set "SWIFT_EXE=C:\Users\bobby\AppData\Local\Programs\Swift\Toolchains\0.0.0+Asserts\usr\bin\swift.exe"
)
set "DEMO_EXE=%SCRIPT_DIR%.build\aarch64-unknown-windows-msvc\debug\WinChocolateDemo.exe"
set "CONTRACT_TEST_EXE=%SCRIPT_DIR%.build\aarch64-unknown-windows-msvc\debug\WinChocolateContractTests.exe"

echo Building WinChocolate...
"%SWIFT_EXE%" build
if errorlevel 1 (
    echo.
    echo Build failed.
    popd >nul
    exit /b 1
)

echo.
echo Running WinChocolate contract tests...
"%CONTRACT_TEST_EXE%"
if errorlevel 1 (
    echo.
    echo Contract tests failed.
    popd >nul
    exit /b 1
)

echo.
echo Checking native demo window creation...
"%DEMO_EXE%" --diagnose
if errorlevel 1 (
    echo.
    echo Demo native window creation failed.
    popd >nul
    exit /b 1
)

echo.
echo Launching WinChocolate demo window...
start "" "%DEMO_EXE%"
if errorlevel 1 (
    echo.
    echo Demo launch failed.
    popd >nul
    exit /b 1
)

echo.
echo Build and contract tests completed successfully. Demo window launched.
popd >nul
exit /b 0
