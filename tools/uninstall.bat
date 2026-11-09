@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo.
echo Uninstalling PuffIME...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall-package.ps1" %*
if errorlevel 1 (
    echo.
    echo Uninstallation failed. Read the messages above.
) else (
    echo.
    echo Done. You can close this window.
)
echo.
pause >nul
