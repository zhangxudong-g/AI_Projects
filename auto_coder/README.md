# AutoCoder - 自动写代码的 DeepAgents 系统

一个基于 LangChain + LangGraph + DeepAgents 架构的自动代码生成系统，能够根据用户需求自动生成完整的代码项目。

## 功能特性

### 核心功能

- **自动代码生成**: 根据自然语言描述自动生成完整代码项目
- **多文件创建**: 支持创建、修改、重构多个文件
- **自动错误修复**: 运行代码并自动修复错误
- **任务拆解**: Planner Agent 将复杂任务拆解为可执行步骤
- **多 Agent 协作**: Planner、Coder、Tester、Fixer 四个 Agent 协同工作

### 技术特性

- **后端框架**: FastAPI
- **Agent 框架**: LangChain + LangGraph
- **流式输出**: 支持 SSE (Server-Sent Events) 实时输出执行过程
- **模型可替换**: 支持 OpenAI / Ollama 模型切换
- **安全执行**: Shell 命令白名单机制，文件操作限制在工作空间
- **持久化存储**: 执行历史、生成项目、错误日志保存

## 项目结构

```
auto_coder/
├── app/
│   ├── main.py              # FastAPI 入口
│   ├── api/
│   │   └── agent.py         # API 接口
│   ├── agents/
│   │   ├── planner.py       # 任务规划 Agent
│   │   ├── coder.py         # 代码生成 Agent
│   │   ├── tester.py        # 测试执行 Agent
│   │   └── fixer.py         # 错误修复 Agent
│   ├── tools/
│   │   ├── file_tools.py    # 文件操作工具
│   │   ├── shell_tools.py   # Shell 命令工具
│   │   └── git_tools.py     # Git 操作工具
│   ├── core/
│   │   ├── deep_agent.py    # DeepAgent 核心
│   │   ├── graph.py         # Agent 图管理
│   │   └── config.py        # 配置管理
│   └── memory/
│       └── memory_store.py  # 记忆存储
├── workspace/               # 工作空间（生成的代码在此）
├── tests/                   # 测试用例
├── requirements.txt         # 依赖
└── README.md               # 说明文档
```

## 快速开始

### 1. 环境要求

- Python 3.11+
- pip 包管理器

### 2. 安装依赖

```bash
cd auto_coder
pip install -r requirements.txt
```

### 3. 配置环境变量

复制环境变量示例文件：

```bash
cp .env.example .env
```

编辑 `.env` 文件，配置已预设好（使用你的 Ollama 服务器）：

```bash
MODEL_PROVIDER=ollama
MODEL_MODEL_NAME=nemotron-3-super:120b
MODEL_BASE_URL=http://133.238.28.90:51434
```

### 4. 使用方式（三种）

#### 方式一：交互式 Python 脚本（最简单）

```bash
python run_interactive.py
```

然后直接输入你的代码需求即可！

#### 方式二：命令行工具

```bash
# 交互模式
python cli.py

# 单次生成
python cli.py "创建一个 Flask Hello World 应用"

# 指定模型
python cli.py "生成排序算法" --model qwen3:32b
```

#### 方式三：启动 API 服务

```bash
# Windows
start.bat

# 或直接运行
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8001
```

服务启动后访问：http://localhost:8001/docs

## 使用示例

### 示例 1: 生成 FastAPI CRUD 项目

**请求:**

```bash
curl -X POST "http://localhost:8000/api/generate_code" \
  -H "Content-Type: application/json" \
  -d '{
    "request": "创建一个 FastAPI CRUD 项目，包含用户模型的增删改查功能，使用 SQLAlchemy 操作 SQLite 数据库"
  }'
```

**响应:**

```json
{
  "success": true,
  "status": "completed",
  "files": [
    "app/main.py",
    "app/models.py",
    "app/schemas.py",
    "app/crud.py",
    "app/database.py",
    "requirements.txt"
  ],
  "output": "项目生成完成，所有测试通过"
}
```

### 示例 2: 流式输出

```bash
curl -X POST "http://localhost:8000/api/generate_code_stream" \
  -H "Content-Type: application/json" \
  -d '{
    "request": "创建一个 Python 爬虫，爬取网站标题并保存为 JSON"
  }'
```

### 示例 3: 使用 Ollama 模型

```bash
curl -X POST "http://localhost:8000/api/generate_code" \
  -H "Content-Type: application/json" \
  -d '{
    "request": "创建一个 Flask Hello World 应用",
    "model_provider": "ollama",
    "model_name": "qwen2.5-coder:7b"
  }'
```

## API 接口

### POST /api/generate_code

同步生成代码

**请求体:**

| 字段 | 类型 | 说明 |
|------|------|------|
| request | string | 用户需求描述 |
| model_provider | string | 模型提供商 (openai/ollama) |
| model_name | string | 模型名称 |
| max_iterations | int | 最大循环次数 |
| debug | boolean | 是否启用调试模式 |

### POST /api/generate_code_stream

流式生成代码（SSE）

### GET /api/execution/{execution_id}

获取执行状态

### GET /api/projects

获取项目列表

### GET /api/project/{project_id}

获取项目详情

### GET /api/workspace/files

列出工作空间文件

### GET /api/workspace/files/{path}

读取工作空间文件

## 多 Agent 架构

### Planner Agent

- 分析用户需求
- 拆解为可执行步骤
- 定义验收标准

### Coder Agent

- 根据规划编写代码
- 遵循最佳实践
- 创建项目结构

### Tester Agent

- 运行测试用例
- 检查语法错误
- 验证功能

### Fixer Agent

- 分析错误信息
- 定位问题根源
- 应用修复方案

## 执行流程

```
用户输入需求
    ↓
Planner 拆任务
    ↓
Coder 写代码
    ↓
Tester 运行测试
    ↓
有错误？───→ Fixer 修复 ───┐
    ↓                     │
   无                     │
    ↓                     │
完成 ←────────────────────┘
```

## 工具系统

### 文件工具

- `write_file(path, content)`: 写入文件
- `read_file(path)`: 读取文件
- `list_files(path)`: 列出文件
- `file_exists(path)`: 检查文件存在
- `delete_file(path)`: 删除文件
- `create_directory(path)`: 创建目录

### Shell 工具

- `run_command(cmd)`: 运行命令
- `check_command(cmd)`: 检查命令可用性
- `get_python_version()`: 获取 Python 版本

### Git 工具

- `git_init()`: 初始化仓库
- `git_add(files)`: 添加文件
- `git_commit(message)`: 提交变更
- `git_status()`: 查看状态
- `git_log()`: 查看历史

## 安全机制

### 命令安全

- 危险命令黑名单（rm -rf, format 等）
- 允许的命令白名单
- 工作空间限制

### 文件安全

- 路径穿越防护
- 工作空间隔离
- 编码验证

## 配置说明

### 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| MODEL_PROVIDER | openai | 模型提供商 |
| MODEL_MODEL_NAME | gpt-4o | 模型名称 |
| MODEL_API_KEY | - | API 密钥 |
| MODEL_BASE_URL | - | API 基础 URL |
| MODEL_TEMPERATURE | 0.7 | 温度参数 |
| EXEC_MAX_ITERATIONS | 10 | 最大循环次数 |
| EXEC_WORKSPACE_DIR | workspace | 工作目录 |
| LOG_LEVEL | INFO | 日志级别 |
| LOG_DEBUG_MODE | false | 调试模式 |

## 测试

运行测试：

```bash
cd auto_coder
pytest tests/ -v
```

运行覆盖率测试：

```bash
pytest tests/ -v --cov=app --cov-report=html
```

## 扩展开发

### 添加新工具

在 `app/tools/` 目录创建新工具文件：

```python
# app/tools/custom_tools.py

def custom_tool(param: str) -> dict:
    """工具描述"""
    return {"result": param}
```

在 `app/api/agent.py` 中注册：

```python
from app.tools.custom_tools import custom_tool

def get_all_tools() -> list:
    return [
        # ... 其他工具
        custom_tool,
    ]
```

### 添加新 Agent

在 `app/agents/` 目录创建新 Agent：

```python
# app/agents/custom_agent.py

class CustomAgent:
    def __init__(self, llm):
        self.llm = llm
    
    def execute(self, state):
        # 实现逻辑
        return state
```

在 `app/core/graph.py` 中添加节点。

## 常见问题

### Q: 如何切换模型？

A: 设置环境变量或在请求中指定 `model_provider` 和 `model_name`。

### Q: 生成的代码在哪里？

A: 在 `workspace/` 目录下。

### Q: 如何查看执行历史？

A: 调用 `GET /api/stats` 或查看 `.memory/history.jsonl`。

### Q: 执行超时怎么办？

A: 增加 `max_iterations` 参数或优化需求描述。

## License

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！
