@echo off
title AI Chat - Run App
setlocal

REM 设置 Flutter 路径
set "PATH=C:\Users\admin\flutter\flutter\bin;%PATH%"

REM 设置国内镜像加速
set "PUB_HOSTED_URL=https://pub.flutter-io.cn"
set "FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn"

cd /d "%~dp0"

echo.
echo ========================================
echo   AI Chat App
echo ========================================
echo.
echo 启动应用...
echo.

flutter run

pause
