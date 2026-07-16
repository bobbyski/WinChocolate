@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%" >nul

if not defined SWIFT_EXE (
    set "SWIFT_EXE=C:\Users\bobby\AppData\Local\Programs\Swift\Toolchains\0.0.0+Asserts\usr\bin\swift.exe"
)

rem Which app to build and run. The first argument may select it; anything else
rem (e.g. --dark, --classic, --page N) passes through to the app unchanged, so
rem `buildandrun.bat --dark` still runs the main demo as before.
rem   (default) / demo / winchocolate  -> WinChocolateDemo (the main demo)
rem   runloop / runloopdemo            -> RunLoopDemo (the run-loop demo)
set "APP_NAME=WinChocolateDemo"
if /I "%~1"=="runloop"      goto sel_runloop
if /I "%~1"=="runloopdemo"  goto sel_runloop
if /I "%~1"=="demo"         goto sel_demo
if /I "%~1"=="winchocolate" goto sel_demo
goto sel_done
:sel_runloop
set "APP_NAME=RunLoopDemo"
shift
goto sel_done
:sel_demo
set "APP_NAME=WinChocolateDemo"
shift
goto sel_done
:sel_done

rem Collect the remaining arguments for pass-through to the app (`shift` does
rem not update %*, so rebuild the list by hand).
set "APP_ARGS="
:collect_args
if "%~1"=="" goto collected_args
set "APP_ARGS=%APP_ARGS% %1"
shift
goto collect_args
:collected_args

set "BUILD_DIR=%SCRIPT_DIR%.build\aarch64-unknown-windows-msvc\debug"
set "APP_EXE=%BUILD_DIR%\%APP_NAME%.exe"
set "CONTRACT_TEST_EXE=%BUILD_DIR%\WinChocolateContractTests.exe"
set "RUN_DIR=%SCRIPT_DIR%Run"

echo Building WinChocolate (selected app: %APP_NAME%)...
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

rem The main demo supports a --diagnose self-check that creates its windows and
rem exits; the run-loop demo has no such mode, so this step is main-demo only.
if /I "%APP_NAME%"=="WinChocolateDemo" (
    echo.
    echo Checking native demo window creation...
    "%APP_EXE%" --diagnose %APP_ARGS%
    if errorlevel 1 (
        echo.
        echo Demo native window creation failed.
        popd >nul
        exit /b 1
    )
)

echo.
echo Launching %APP_NAME%...
if not exist "%RUN_DIR%" mkdir "%RUN_DIR%"
rem Remove stale staged copies from earlier runs so an old build can't be
rem launched by mistake (copies still running are skipped silently).
del /q "%RUN_DIR%\%APP_NAME%-*.exe" >nul 2>&1
set "RUN_APP_EXE=%RUN_DIR%\%APP_NAME%-%RANDOM%-%RANDOM%.exe"
copy /y "%APP_EXE%" "%RUN_APP_EXE%" >nul
if errorlevel 1 (
    echo.
    echo App staging failed.
    popd >nul
    exit /b 1
)

rem The main demo loads bitmaps/icons from a Resources folder beside the exe;
rem the run-loop demo has no resources, so this staging is main-demo only.
if /I "%APP_NAME%"=="WinChocolateDemo" (
    if not exist "%RUN_DIR%\Resources" mkdir "%RUN_DIR%\Resources"
    copy /y "%SCRIPT_DIR%Demo\DemoApplication\Resources\*.bmp" "%RUN_DIR%\Resources\" >nul
    if errorlevel 1 (
        echo.
        echo Demo resource staging failed.
        popd >nul
        exit /b 1
    )
    copy /y "%SCRIPT_DIR%Demo\DemoApplication\Resources\*.png" "%RUN_DIR%\Resources\" >nul
    if errorlevel 1 (
        echo.
        echo Demo resource staging failed.
        popd >nul
        exit /b 1
    )
)

start "" "%RUN_APP_EXE%" %APP_ARGS%
if errorlevel 1 (
    echo.
    echo App launch failed.
    popd >nul
    exit /b 1
)

echo.
echo Build and contract tests completed successfully. %APP_NAME% window launched.
popd >nul
exit /b 0
