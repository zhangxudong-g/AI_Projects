@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

echo ========================================
echo   AI Chat App - 快速启动脚本
echo ========================================
echo.

:: 设置 Flutter 路径
set "FLUTTER_ROOT=%USERPROFILE%\flutter"
if exist "%FLUTTER_ROOT%\flutter\bin\flutter.exe" (
    set "PATH=%FLUTTER_ROOT%\flutter\bin;%PATH%"
)

:: 设置国内镜像
set "PUB_HOSTED_URL=https://pub.flutter-io.cn"
set "FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn"

cd /d "%~dp0"

:: 检查设备
echo 检查可用设备...
flutter devices
echo.

:: 运行应用
echo 启动应用...
flutter run

pause
