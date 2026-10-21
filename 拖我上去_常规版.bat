@echo off
title PCL Download Patch (plain)
set "PS1=%~dp0Patcher.ps1"

echo ==============================================
echo   PCL 下载功能补丁（常规款：只打补丁，不装自动修复）
echo   by 沐序
echo.
echo   建议先手动备份：把 Plain Craft Launcher 2.exe
echo   复制一份改名保存，出问题复制回来即可还原。
echo ==============================================
echo.

set "TARGET=%~1"
if "%~1"=="" set /p "TARGET=把 exe 拖到本窗口松手后回车： "
if "%TARGET%"=="" goto end
if not exist "%TARGET%" (
    echo 找不到文件：%TARGET%
    pause
    goto end
)

where pwsh >nul 2>nul
if %errorlevel%==0 goto use_pwsh
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ExePath "%TARGET%" -AutoFix none
goto end
:use_pwsh
pwsh -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ExePath "%TARGET%" -AutoFix none
:end
echo.
pause
