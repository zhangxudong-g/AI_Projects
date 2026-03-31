@echo off
echo 正在配置 Android SDK 环境变量...
echo.

:: 设置环境变量
setx ANDROID_HOME "C:\Users\admin\AppData\Local\Android\sdk"
setx ANDROID_SDK_ROOT "C:\Users\admin\AppData\Local\Android\sdk"

echo.
echo ✓ 环境变量已设置！
echo.
echo 请重启命令行窗口后运行以下命令：
echo   flutter doctor --android-licenses
echo.
echo 然后输入 y 接受所有许可证
pause
