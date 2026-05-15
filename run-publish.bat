@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish.ps1"
echo.
echo ====================================================
echo Script finished. This window stays open so you can
echo read the output above. Close it when done.
echo ====================================================
pause
