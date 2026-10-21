@echo off
title PCL 下载功能补丁
rem 把启动器 exe 拖到本文件图标上松手：会打开图形界面并自动填好路径，
rem 在界面里选择自动修复方式后点「开始打补丁」即可。
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
start "" "%GUI%" "%TARGET%"
:end
endlocal