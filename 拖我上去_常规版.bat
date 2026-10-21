@echo off
title PCL Download Patch (plain)
rem 常规款：把启动器 exe 拖到本文件图标上松手，直接打补丁，
rem 不安装任何自动修复；界面会自动开始，完成后可关闭。
setlocal
set "TARGET=%~1"
if "%~1"=="" set /p "TARGET=把 Plain Craft Launcher 2.exe 拖到本窗口松手后回车： "
if "%TARGET%"=="" goto end
if not exist "%TARGET%" (
    echo 找不到文件：%TARGET%
    pause
    goto end
)
set "GUI=%~dp0PCL补丁界面.exe"
if not exist "%GUI%" (
    echo 未找到 PCL补丁界面.exe，请保持它和本文件在同一文件夹。
    pause
    goto end
)
start "" "%GUI%" "%TARGET%" none
:end
endlocal