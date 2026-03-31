@echo off
title AI Chat App - Run
setlocal

set "PUB_HOSTED_URL=https://pub.flutter-io.cn"
set "FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn"
set "PATH=C:\Users\admin\flutter\flutter\bin;%PATH%"

cd /d "%~dp0"

echo.
echo Starting AI Chat App...
echo.

flutter run -d chrome

pause
