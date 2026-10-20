@echo off
title PCL 下载功能补丁
setlocal EnableDelayedExpansion
set "PS1=%~dp0Patcher.ps1"

echo ==============================================
echo   PCL 下载功能补丁  by 沐序
echo.
echo   把 Plain Craft Launcher 2.exe 拖到本窗口松手，
echo   或把 exe 拖到本 bat 图标上松手（先回答下面两问）。
echo ==============================================
echo.

:MENU1
echo 第一步：是否生成补丁前备份？
echo    [1] 生成备份（推荐，出问题可还原）
echo    [2] 不生成备份
set "BACKUP_ARG=-Backup"
set /p "CHOICE1=请输入 1 或 2 后回车（默认 1）： "
if "!CHOICE1!"=="2" set "BACKUP_ARG="
echo.

:MENU2
echo 第二步：启动器更新后，如何自动恢复补丁？
echo    [1] 不自动修复：每次更新后把新 exe 再拖一次
echo    [2] 启动壳检测：用补丁包里的「启动游戏.vbs」启动游戏，
echo        启动前自动修复（无后台；绕过它直接双击原 exe 则不修复）
echo    [3] 常驻守护（推荐）：开机自启后台守护（约 15MB，无窗口），
echo        打开启动器时检测，关闭后自动修复；快捷方式保持不变
set "AUTOFIX_ARG=-AutoFix watch"
set /p "CHOICE2=请输入 1 / 2 / 3 后回车（默认 3）： "
if "!CHOICE2!"=="1" set "AUTOFIX_ARG=-AutoFix none"
if "!CHOICE2!"=="2" set "AUTOFIX_ARG=-AutoFix shell"
echo.

:DROP
set "TARGET=%~1"
if "%~1"=="" set /p "TARGET=最后，把 exe 拖到本窗口松手后回车： "
if "!TARGET!"=="" goto MENU1
if not exist "!TARGET!" (
    echo 找不到文件：!TARGET!
    pause
    goto MENU1
)

where pwsh >nul 2>nul
if %errorlevel%==0 goto use_pwsh
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ExePath "!TARGET!" %BACKUP_ARG% %AUTOFIX_ARG%
goto end
:use_pwsh
pwsh -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ExePath "!TARGET!" %BACKUP_ARG% %AUTOFIX_ARG%
:end
echo.
pause
endlocal
