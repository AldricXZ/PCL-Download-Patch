@echo off
title PCL 下载功能补丁
setlocal EnableDelayedExpansion
set "PS1=%~dp0Patcher.ps1"

echo ==============================================
echo   PCL 下载功能补丁  by 沐序
echo.
echo   建议先手动备份：把 Plain Craft Launcher 2.exe
echo   复制一份改名保存，出问题复制回来即可还原。
echo.
echo   把 exe 拖到本窗口松手，或拖到本 bat 图标上
echo   松手（先回答下面一问）。
echo ==============================================
echo.

:MENU
echo 启动器更新后，如何自动恢复补丁？
echo    [1] 启动壳检测：用补丁包里的「启动游戏.vbs」启动游戏，
echo        启动前自动修复（无后台；绕过它直接双击原 exe 则不修复）
echo    [2] 常驻守护（推荐）：开机自启后台守护（约 15MB，无窗口），
echo        打开启动器时检测，关闭后自动修复；快捷方式保持不变
set "AUTOFIX_ARG=-AutoFix watch"
set /p "CHOICE=请输入 1 / 2 后回车（默认 2）： "
if "!CHOICE!"=="1" set "AUTOFIX_ARG=-AutoFix shell"
echo.

:DROP
set "TARGET=%~1"
if "%~1"=="" set /p "TARGET=最后，把 exe 拖到本窗口松手后回车： "
if "!TARGET!"=="" goto MENU
if not exist "!TARGET!" (
    echo 找不到文件：!TARGET!
    pause
    goto MENU
)

where pwsh >nul 2>nul
if %errorlevel%==0 goto use_pwsh
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ExePath "!TARGET!" %AUTOFIX_ARG%
goto end
:use_pwsh
pwsh -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ExePath "!TARGET!" %AUTOFIX_ARG%
:end
echo.
pause
endlocal
