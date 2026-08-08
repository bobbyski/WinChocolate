@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "INSTALL_MODE=0"
if /I "%~1"=="--install" set "INSTALL_MODE=1"
if not "%~1"=="" if /I not "%~1"=="--install" goto :usage
if not "%~2"=="" goto :usage

set "MISSING=0"
set "NEED_SWIFT=0"
set "NEED_GIT=0"
set "NEED_PYTHON=0"
set "NEED_VS=0"
set "NEED_DEVMODE=0"

echo WinChocolate Windows prerequisite check
echo =======================================
echo.

where swift.exe >nul 2>&1
if errorlevel 1 (
    call :missing "Swift toolchain"
    set "NEED_SWIFT=1"
) else (
    for /f "delims=" %%I in ('swift --version 2^>^&1') do if not defined SWIFT_VERSION set "SWIFT_VERSION=%%I"
    call :ok "Swift: !SWIFT_VERSION!"
)

where git.exe >nul 2>&1
if errorlevel 1 (
    call :missing "Git for Windows"
    set "NEED_GIT=1"
) else (
    for /f "delims=" %%I in ('git --version 2^>^&1') do set "GIT_VERSION=%%I"
    call :ok "!GIT_VERSION!"
)

where python.exe >nul 2>&1
if errorlevel 1 (
    call :missing "Python 3.10"
    set "NEED_PYTHON=1"
) else (
    for /f "delims=" %%I in ('python --version 2^>^&1') do set "PYTHON_VERSION=%%I"
    echo !PYTHON_VERSION! | findstr /B /C:"Python 3.10." >nul
    if errorlevel 1 (
        call :missing "Python 3.10 (found !PYTHON_VERSION!)"
        set "NEED_PYTHON=1"
    ) else (
        call :ok "!PYTHON_VERSION!"
    )
)

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VC_COMPONENT=Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
if /I "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "VC_COMPONENT=Microsoft.VisualStudio.Component.VC.Tools.ARM64"
if exist "%VSWHERE%" (
    for /f "usebackq delims=" %%I in (`"%VSWHERE%" -latest -products * -requires !VC_COMPONENT! -property installationPath`) do set "VS_PATH=%%I"
)
if not defined VS_PATH (
    call :missing "Visual Studio 2022 C++ build tools (!VC_COMPONENT!)"
    set "NEED_VS=1"
) else (
    call :ok "Visual Studio C++ tools: !VS_PATH!"
)

set "SDK_ROOT="
for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows Kits\Installed Roots" /v KitsRoot10 2^>nul ^| findstr /I "KitsRoot10"') do set "SDK_ROOT=%%B"
if not defined SDK_ROOT (
    call :missing "Windows 10/11 SDK"
    set "NEED_VS=1"
) else (
    set "SDK_VERSION="
    for /f "delims=" %%I in ('dir /b /ad "!SDK_ROOT!Include\10.*" 2^>nul') do set "SDK_VERSION=%%I"
    if not defined SDK_VERSION (
        call :missing "Windows SDK headers"
        set "NEED_VS=1"
    ) else (
        call :ok "Windows SDK: !SDK_VERSION!"
    )
)

set "DEVMODE="
for /f "tokens=3" %%I in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense 2^>nul ^| findstr /I "AllowDevelopmentWithoutDevLicense"') do set "DEVMODE=%%I"
if /I not "!DEVMODE!"=="0x1" (
    call :missing "Windows Developer Mode"
    set "NEED_DEVMODE=1"
) else (
    call :ok "Windows Developer Mode"
)

echo.
if "!MISSING!"=="0" (
    echo All prerequisites were found.
    echo Run buildandrun.bat to build, test, and launch WinChocolate.
    exit /b 0
)

if "!INSTALL_MODE!"=="0" (
    echo One or more prerequisites are missing.
    echo Run windowsSwiftCheck.bat --install from an Administrator terminal to install them.
    exit /b 1
)

net session >nul 2>&1
if errorlevel 1 (
    echo Requesting administrator access...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '--install' -Verb RunAs -Wait"
    exit /b !errorlevel!
)

call :find_winget
if not defined WINGET_EXE (
    echo.
    echo Windows Package Manager was not found; bootstrapping it from Microsoft's
    echo official PowerShell Gallery module...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Install-PackageProvider -Name NuGet -Force -Scope AllUsers; Install-Module -Name Microsoft.WinGet.Client -Repository PSGallery -Force -Scope AllUsers; Repair-WinGetPackageManager -AllUsers"
    if errorlevel 1 (
        echo [ERROR] Could not bootstrap Windows Package Manager.
        echo Check the network connection and try again. Manual fallback: https://aka.ms/getwinget
        exit /b 2
    )
    call :find_winget
    if not defined WINGET_EXE (
        echo [ERROR] Windows Package Manager was installed but winget.exe could not be located.
        echo Open a new Administrator terminal and rerun windowsSwiftCheck.bat --install.
        exit /b 2
    )
)

echo.
echo Installing missing prerequisites. This can take a while...
if "!NEED_VS!"=="1" (
    set "VS_COMPONENTS=--add Microsoft.VisualStudio.Component.Windows11SDK.22621 --add !VC_COMPONENT!"
    call :winget Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive !VS_COMPONENTS!"
    if errorlevel 1 exit /b 3
)
if "!NEED_GIT!"=="1" (
    call :winget Git.Git
    if errorlevel 1 exit /b 3
)
if "!NEED_PYTHON!"=="1" (
    call :winget Python.Python.3.10
    if errorlevel 1 exit /b 3
)
if "!NEED_SWIFT!"=="1" (
    call :winget Swift.Toolchain
    if errorlevel 1 exit /b 3
)
if "!NEED_DEVMODE!"=="1" (
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense /t REG_DWORD /d 1 /f >nul
    if errorlevel 1 (
        echo [ERROR] Could not enable Windows Developer Mode.
        exit /b 3
    )
    call :ok "Enabled Windows Developer Mode"
)

echo.
echo Installation commands completed. Open a new terminal so PATH changes take effect,
echo then run windowsSwiftCheck.bat again.
exit /b 0

:winget
set "PACKAGE_ID=%~1"
shift
echo Installing %PACKAGE_ID%...
"%WINGET_EXE%" install --id "%PACKAGE_ID%" --exact --source winget --accept-package-agreements --accept-source-agreements %*
exit /b %errorlevel%

:find_winget
set "WINGET_EXE="
for /f "delims=" %%I in ('where winget.exe 2^>nul') do if not defined WINGET_EXE set "WINGET_EXE=%%I"
if not defined WINGET_EXE if exist "%LocalAppData%\Microsoft\WindowsApps\winget.exe" set "WINGET_EXE=%LocalAppData%\Microsoft\WindowsApps\winget.exe"
if not defined WINGET_EXE for /f "usebackq delims=" %%I in (`powershell.exe -NoProfile -Command "$p=(Get-AppxPackage -AllUsers Microsoft.DesktopAppInstaller ^| Select-Object -First 1 -ExpandProperty InstallLocation); if ($p) { Join-Path $p 'winget.exe' }"`) do if exist "%%I" set "WINGET_EXE=%%I"
exit /b 0

:ok
echo [ OK ] %~1
exit /b 0

:missing
echo [MISS] %~1
set /a MISSING+=1
exit /b 0

:usage
echo Usage: windowsSwiftCheck.bat [--install]
exit /b 64
