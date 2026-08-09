@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
wsl.exe --status >nul 2>nul
if errorlevel 1 (
    echo error: WSL is not available or is not installed.
    exit /b 1
)

wsl.exe --cd "%SCRIPT_DIR%" bash ./run-wsl.sh %*
exit /b %ERRORLEVEL%
