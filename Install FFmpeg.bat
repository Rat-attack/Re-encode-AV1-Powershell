@echo off
echo Installing FFmpeg for Re-Encode AV1 scripts...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0Install-FFmpeg.ps1"
echo.
pause