@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%" >nul

if not defined SWIFT_EXE (
    where swift.exe >nul 2>&1
    if not errorlevel 1 (
        set "SWIFT_EXE=swift.exe"
    ) else (
        for /d %%D in ("%LocalAppData%\Programs\Swift\Toolchains\*") do (
            if exist "%%~fD\usr\bin\swift.exe" set "SWIFT_EXE=%%~fD\usr\bin\swift.exe"
        )
        if not defined SWIFT_EXE (
            echo Swift was not found. Install the Windows Swift toolchain and open a new terminal.
            echo See SETUP_WINDOWS.md for setup instructions.
            popd >nul
            exit /b 1
        )
    )
)

rem A newly installed Swift toolchain may not be visible to this process yet.
rem Add its matching runtime and bundled Python directories explicitly so the
rem compiler works without requiring a reboot or a fresh terminal. Wildcards
rem deliberately support both version changes and AMD64/ARM64 installations.
for /d %%D in ("%LocalAppData%\Programs\Swift\Runtimes\*") do if exist "%%~fD\usr\bin" set "PATH=%%~fD\usr\bin;!PATH!"
for /d %%D in ("%LocalAppData%\Programs\Swift\Python-*") do if exist "%%~fD\usr\bin" set "PATH=%%~fD\usr\bin;!PATH!"
if not defined SDKROOT for /d %%D in ("%LocalAppData%\Programs\Swift\Platforms\*") do (
    if exist "%%~fD\Windows.platform\Developer\SDKs\Windows.sdk" set "SDKROOT=%%~fD\Windows.platform\Developer\SDKs\Windows.sdk"
)

rem Swift delegates native linking to Visual Studio. Initialize that environment
rem automatically when this was launched from ordinary PowerShell/cmd. Keep the
rem target architecture native so the same script works on Windows ARM64.
where link.exe >nul 2>&1
if errorlevel 1 (
    set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
    if exist "!VSWHERE!" (
        for /f "usebackq delims=" %%I in (`"!VSWHERE!" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VS_PATH=%%I"
        if /I "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
            for /f "usebackq delims=" %%I in (`"!VSWHERE!" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.ARM64 -property installationPath`) do set "VS_PATH=%%I"
            set "VS_ARCH=arm64"
        ) else (
            set "VS_ARCH=amd64"
        )
        if defined VS_PATH if exist "!VS_PATH!\Common7\Tools\VsDevCmd.bat" call "!VS_PATH!\Common7\Tools\VsDevCmd.bat" -no_logo -arch=!VS_ARCH! -host_arch=!VS_ARCH!
    )
)

if not defined SDKROOT (
    echo Swift's Windows SDK was not found.
    echo Run windowsSwiftCheck.bat --install, then try again.
    popd >nul
    exit /b 1
)

where link.exe >nul 2>&1
if errorlevel 1 (
    echo Visual Studio's native linker was not found.
    echo Run windowsSwiftCheck.bat --install, then try again.
    popd >nul
    exit /b 1
)

rem Which app to build and run. The first argument may select it; anything else
rem (e.g. --dark, --classic, --page N) passes through to the app unchanged, so
rem `buildandrun.bat --dark` still runs the main demo as before.
rem   (default) / demo / winchocolate  -> WinChocolateDemo (the main demo)
rem   runloop / runloopdemo            -> RunLoopDemo (the run-loop demo)
rem   note / chocolatenote / notedemo  -> ChocolateNoteDemo (the document proof)
set "APP_NAME=WinChocolateDemo"
set "BUILD_ONLY=0"
if /I "%~1"=="--build" (
    set "BUILD_ONLY=1"
    shift
)
if /I "%~1"=="note"         goto sel_note
if /I "%~1"=="chocolatenote" goto sel_note
if /I "%~1"=="notedemo"     goto sel_note
if /I "%~1"=="runloop"      goto sel_runloop
if /I "%~1"=="runloopdemo"  goto sel_runloop
if /I "%~1"=="demo"         goto sel_demo
if /I "%~1"=="winchocolate" goto sel_demo
goto sel_done
:sel_note
set "APP_NAME=ChocolateNoteDemo"
shift
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

set "RUN_DIR=%SCRIPT_DIR%Run"

echo Building WinChocolate (selected app: %APP_NAME%)...
"%SWIFT_EXE%" build
if errorlevel 1 (
    echo.
    echo Build failed.
    popd >nul
    exit /b 1
)

for /f "usebackq delims=" %%I in (`"%SWIFT_EXE%" build --show-bin-path`) do set "BUILD_DIR=%%I"
if not defined BUILD_DIR (
    echo.
    echo Could not determine the SwiftPM binary directory.
    popd >nul
    exit /b 1
)
set "APP_EXE=%BUILD_DIR%\%APP_NAME%.exe"
set "CONTRACT_TEST_EXE=%BUILD_DIR%\WinChocolateContractTests.exe"

echo.
echo Running WinChocolate contract tests...
set "CONTRACT_TEST_LOG=%TEMP%\WinChocolateContractTests-%RANDOM%-%RANDOM%.log"
"%CONTRACT_TEST_EXE%" >"%CONTRACT_TEST_LOG%" 2>&1
set "CONTRACT_TEST_STATUS=%ERRORLEVEL%"
type "%CONTRACT_TEST_LOG%"
findstr /C:"WinChocolate contract tests passed." "%CONTRACT_TEST_LOG%" >nul
set "CONTRACT_TEST_MARKER=%ERRORLEVEL%"
del /q "%CONTRACT_TEST_LOG%" >nul 2>&1
if not "%CONTRACT_TEST_STATUS%"=="0" (
    echo.
    echo Contract tests failed with exit code %CONTRACT_TEST_STATUS%.
    popd >nul
    exit /b 1
)
if not "%CONTRACT_TEST_MARKER%"=="0" (
    echo.
    echo Contract tests terminated without printing their success marker.
    popd >nul
    exit /b 1
)

if "%BUILD_ONLY%"=="1" (
    echo.
    echo Build and contract tests completed successfully.
    popd >nul
    exit /b 0
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

rem The main demo loads artwork and DemoNibPanel.xib from a Resources folder
rem beside the exe; the run-loop demo has no resources, so this is main-demo only.
rem
rem Copy the WHOLE folder, not a list of extensions. This used to enumerate
rem *.bmp and *.png, and when the nib panel added a .xib the staging silently
rem stopped covering it — the build stayed clean and the panel failed with
rem "not found" at run time. LinChocolate's run-linux.sh has always copied
rem Resources/* wholesale, which is why Linux never hit this. Same rule here now,
rem so adding a resource type can never reintroduce it.
if /I "%APP_NAME%"=="WinChocolateDemo" (
    if not exist "%RUN_DIR%\Resources" mkdir "%RUN_DIR%\Resources"
    copy /y "%SCRIPT_DIR%Demo\DemoApplication\Resources\*" "%RUN_DIR%\Resources\" >nul
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
