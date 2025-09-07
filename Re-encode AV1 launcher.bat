@echo off
REM Find the path to this script and PowerShell script
set "script=%~dp0Re-Encode AV1.ps1"

REM Build argument list (always quoted)
setlocal enabledelayedexpansion
set args=
set i=1
:next
set arg=%~1
if "%arg%"=="" goto done
set args=!args! "!arg!"
shift
goto next
:done

REM Prefer PowerShell 7 (pwsh), fallback to legacy PowerShell
where pwsh >nul 2>nul
if %errorlevel%==0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%script%" !args!
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%script%" !args!
)

pause
