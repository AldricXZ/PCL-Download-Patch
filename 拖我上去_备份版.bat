@echo off
title PCL Download Patch (with backup)
set "PS1=%~dp0Patcher.ps1"
if "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Backup
    goto end
)
where pwsh >nul 2>nul
if %errorlevel%==0 goto use_pwsh
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ExePath "%~1" -Backup
goto end
:use_pwsh
pwsh -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ExePath "%~1" -Backup
:end
echo.
pause
