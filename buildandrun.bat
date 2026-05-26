@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%" >nul

if not defined SWIFT_EXE (
    set "SWIFT_EXE=C:\Users\bobby\AppData\Local\Programs\Swift\Toolchains\0.0.0+Asserts\usr\bin\swift.exe"
)

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
".build\aarch64-unknown-windows-msvc\debug\WinChocolateContractTests.exe"
if errorlevel 1 (
    echo.
    echo Contract tests failed.
    popd >nul
    exit /b 1
)

echo.
echo Running WinChocolate demo smoke test...
".build\aarch64-unknown-windows-msvc\debug\WinChocolateDemo.exe"
if errorlevel 1 (
    echo.
    echo Demo smoke test failed.
    popd >nul
    exit /b 1
)

echo.
echo Build, contract tests, and demo smoke test completed successfully.
popd >nul
exit /b 0
