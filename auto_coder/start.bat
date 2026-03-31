@echo off
REM AutoCoder 启动脚本 (Windows)

echo ========================================
echo AutoCoder - 自动写代码的 DeepAgents 系统
echo ========================================
echo.

REM 检查 Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 Python，请先安装 Python 3.11+
    pause
    exit /b 1
)

echo [信息] 检查依赖...
pip show fastapi >nul 2>&1
if errorlevel 1 (
    echo [信息] 安装依赖...
    pip install -r requirements.txt
) else (
    echo [信息] 依赖已安装
)

echo.
echo [信息] 启动服务...
echo 访问 http://localhost:8000 查看 API 文档
echo.

python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

pause
