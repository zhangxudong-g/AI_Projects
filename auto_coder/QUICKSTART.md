# AutoCoder 快速开始指南

## 1. 安装依赖

```bash
cd auto_coder
pip install -r requirements.txt
```

## 2. 配置环境

复制环境变量示例文件：

```bash
cp .env.example .env
```

编辑 `.env` 文件，填入你的 API 密钥：

```bash
MODEL_API_KEY=your-actual-api-key
```

如果使用 Ollama（本地模型），则不需要 API 密钥：

```bash
MODEL_PROVIDER=ollama
MODEL_MODEL_NAME=qwen2.5-coder:7b
```

## 3. 启动服务

### Windows

双击运行 `start.bat` 或命令行运行：

```bash
start.bat
```

### Linux/Mac

```bash
chmod +x start.sh
./start.sh
```

### 或直接运行

```bash
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## 4. 访问 API 文档

浏览器打开：http://localhost:8000/docs

## 5. 测试 API

### 使用 curl 测试

```bash
curl -X POST "http://localhost:8000/api/generate_code" \
  -H "Content-Type: application/json" \
  -d '{
    "request": "创建一个 Flask Hello World 应用"
  }'
```

### 使用 Python 测试

```python
import requests

response = requests.post(
    "http://localhost:8000/api/generate_code",
    json={
        "request": "创建一个 Python 计算器程序"
    }
)

print(response.json())
```

## 6. 查看生成的代码

生成的代码保存在 `workspace/` 目录。

## 7. 运行测试

```bash
pytest tests/ -v
```

## 常见问题

### Q: 提示找不到模块？

A: 确保已安装依赖：`pip install -r requirements.txt`

### Q: API 启动失败？

A: 检查端口 8000 是否被占用，可以更换端口：
```bash
python -m uvicorn app.main:app --reload --port 8001
```

### Q: 使用 Ollama 模型？

A: 确保 Ollama 已启动并下载了模型：
```bash
ollama pull qwen2.5-coder:7b
ollama serve
```

### Q: 生成的代码在哪里？

A: 在 `workspace/` 目录下。

## 下一步

- 阅读完整文档：README.md
- 查看示例测试：tests/test_example_generation.py
- 自定义 Agent：修改 app/agents/ 下的文件
