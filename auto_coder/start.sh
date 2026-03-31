#!/bin/bash
# AutoCoder 启动脚本 (Linux/Mac)

echo "========================================"
echo "AutoCoder - 自动写代码的 DeepAgents 系统"
echo "========================================"
echo

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "[错误] 未找到 Python3，请先安装 Python 3.11+"
    exit 1
fi

echo "[信息] Python 版本："
python3 --version

echo "[信息] 检查依赖..."
if ! python3 -c "import fastapi" 2>/dev/null; then
    echo "[信息] 安装依赖..."
    pip3 install -r requirements.txt
else
    echo "[信息] 依赖已安装"
fi

echo
echo "[信息] 启动服务..."
echo "访问 http://localhost:8000 查看 API 文档"
echo

python3 -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
