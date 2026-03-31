# Wiki Fact Judge 系统启动指南

## 快速启动（推荐）

### Windows 系统

**双击运行**
```bat
start.bat
```

**或使用 PowerShell**
```powershell
.\start.ps1
```

### Linux/macOS

```bash
python start.py
```

### 命令行选项

| 选项 | 说明 |
|------|------|
| `--backend` | 只启动后端服务 |
| `--frontend` | 只启动前端服务 |
| `--backend-port PORT` | 指定后端端口 (默认：8765) |
| `--frontend-port PORT` | 指定前端端口 (默认：3456) |
| `--help` | 显示帮助信息 |

**示例：**
```bash
# 只启动后端
python start.py --backend

# 只启动前端
python start.py --frontend

# 自定义端口
python start.py --backend-port 9000 --frontend-port 4000
```

### 默认端口

| 服务 | 端口 | 地址 |
|------|------|------|
| 后端 API | 8765 | http://localhost:8765 |
| 后端文档 | 8765 | http://localhost:8765/docs |
| 前端界面 | 3456 | http://localhost:3456 |

---

## 手动启动

### 1. 启动后端服务

```bash
cd backend
python -m uvicorn main:app --reload --port 8765 --host 0.0.0.0
```

访问后端 API 文档：http://localhost:8765/docs

### 2. 启动前端服务

打开新的终端窗口：

```bash
cd frontend
npm install
PORT=3456 npm start
```

访问前端界面：http://localhost:3456

---

## 系统要求

| 组件 | 版本要求 | 用途 |
|------|---------|------|
| Python | 3.8+ | 后端运行 |
| Node.js | 14+ | 前端运行 |
| npm | 最新 | 前端依赖管理 |

---

## 安装依赖

### 后端依赖
```bash
pip install -r requirements.txt
```

### 前端依赖
```bash
cd frontend
npm install
```

### 全局依赖（可选）
```bash
npm install -g promptfoo
```

---

## 服务地址

| 服务 | 地址 | 说明 |
|------|------|------|
| 后端 API | http://localhost:8765 | REST API |
| API 文档 | http://localhost:8765/docs | Swagger UI |
| 前端界面 | http://localhost:3456 | React 应用 |

---

## 常见问题

### 1. 端口被占用

如果端口 8765 或 3456 被占用，可以修改：

**后端端口：**
```bash
uvicorn main:app --reload --port 8766
```

**前端端口：**
```bash
PORT=3457 npm start
```

或在启动脚本中修改默认端口值。

### 2. 依赖安装失败

**Python 依赖：**
```bash
pip install --upgrade pip
pip install -r requirements.txt --no-cache-dir
```

**Node.js 依赖：**
```bash
cd frontend
rm -rf node_modules package-lock.json
npm install
```

### 3. 数据库初始化

系统会在首次启动时自动创建数据库表，数据库文件位于：
```
backend/judge.db
```

---

## 项目结构

```
wiki_fact_judge/
├── backend/           # 后端服务 (FastAPI + SQLAlchemy)
│   ├── main.py       # 应用入口
│   ├── database.py   # 数据库配置
│   ├── models.py     # 数据模型
│   ├── schemas.py    # 数据验证
│   └── routers/      # API 路由
├── frontend/          # 前端服务 (React + TypeScript)
│   ├── src/          # 源代码
│   └── package.json  # 依赖配置
├── cli/              # 命令行工具
├── data/             # 数据目录
│   └── cases/        # 测试用例
├── test/             # 测试数据
├── start.bat         # Windows 启动脚本
└── start.ps1         # PowerShell 启动脚本
```