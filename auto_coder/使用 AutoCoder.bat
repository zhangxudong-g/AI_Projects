@echo off
chcp 65001 >nul
cls
echo ============================================================
echo   AutoCoder - 自动代码生成工具
echo ============================================================
echo.

REM 检查 Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 Python，请先安装 Python 3.11+
    pause
    exit /b 1
)

echo 正在启动交互式代码生成器...
echo.

REM 运行交互式脚本
python run_interactive.py

pause
