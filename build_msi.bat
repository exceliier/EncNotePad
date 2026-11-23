@echo off
setlocal
cd /d "%~dp0"

echo Starting EncNotePad MSI Build Script...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_msi.ps1" %*

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Build failed with exit code %ERRORLEVEL%.
    pause
    exit /b %ERRORLEVEL%
)

pause
