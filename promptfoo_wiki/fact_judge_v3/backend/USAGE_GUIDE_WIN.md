# Engineering Judge v3 后端使用手册 (Windows)

## 目录
1. [系统要求](#系统要求)
2. [环境准备](#环境准备)
3. [安装步骤](#安装步骤)
4. [配置说明](#配置说明)
5. [启动服务](#启动服务)
6. [API 使用](#api-使用)
7. [常见问题](#常见问题)

## 系统要求

- **操作系统**: Windows 7 SP1 或更高版本 (推荐 Windows 10/11)
- **Python**: 3.9 或更高版本
- **内存**: 至少 4GB RAM (推荐 8GB)
- **硬盘**: 至少 2GB 可用空间
- **网络**: 稳定的互联网连接 (用于下载依赖包)

## 环境准备

### 1. 安装 Python
1. 访问 [Python 官网](https://www.python.org/downloads/)
2. 下载 Python 3.9+ 版本
3. 安装时勾选 "Add Python to PATH"
4. 验证安装：打开命令提示符，输入 `python --version`

### 2. 安装 Git (可选)
- 下载并安装 [Git for Windows](https://git-scm.com/download/win)
- 验证安装：打开命令提示符，输入 `git --version`

## 安装步骤

### 1. 克取项目代码
```cmd
git clone <repository-url>
cd promptfoo_wiki\fact_judge_v3\backend
```

### 2. 创建虚拟环境
```cmd
python -m venv venv
```

### 3. 激活虚拟环境
```cmd
# Windows 命令提示符
venv\Scripts\activate

# 或使用 PowerShell
venv\Scripts\Activate.ps1
```

### 4. 安装依赖包
```cmd
pip install -r requirements.txt
```

如果 requirements.txt 不存在，可以手动安装：
```cmd
pip install fastapi uvicorn sqlalchemy pydantic-settings passlib[bcrypt] python-jose[cryptography] python-multipart
```

## 配置说明

### 1. 环境变量配置
创建 `.env` 文件（位于 backend 目录下）：

```env
# 项目配置
PROJECT_NAME=Engineering Judge v3 API
VERSION=1.0.0
API_V1_STR=/api/v1

# 数据库配置
DATABASE_URL=sqlite:///./engineering_judge_v3.db

# 安全配置
SECRET_KEY=your-secret-key-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# CORS 配置
BACKEND_CORS_ORIGINS=["*"]

# 任务队列配置 (Windows 环境下禁用 Redis)
USE_REDIS=False
REDIS_URL=redis://localhost:6379/0

# 日志配置
LOG_LEVEL=INFO
```

### 2. 数据库初始化
首次运行前需要初始化数据库：

```cmd
# 激活虚拟环境后
python -c "
from database.base import engine
from models.user import User, Case, Execution, Report, SystemConfig
import os
os.makedirs('static', exist_ok=True)
User.metadata.create_all(bind=engine)
Case.metadata.create_all(bind=engine)
Execution.metadata.create_all(bind=engine)
Report.metadata.create_all(bind=engine)
SystemConfig.metadata.create_all(bind=engine)
print('Database initialized successfully!')
"
```

## 启动服务

### 1. 开发模式启动
```cmd
# 激活虚拟环境后
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 2. 生产模式启动
```cmd
# 激活虚拟环境后
uvicorn main:app --host 0.0.0.0 --port 8000
```

### 3. 使用 Windows 服务启动 (可选)
1. 安装 NSSM (Non-Sucking Service Manager)
2. 创建服务：
   ```cmd
   nssm install EngineeringJudgeV3 "C:\path\to\your\venv\Scripts\python.exe"
   nssm set EngineeringJudgeV3 AppDirectory "C:\path\to\your\project\backend"
   nssm set EngineeringJudgeV3 AppParameters "-m uvicorn main:app --host 0.0.0.0 --port 8000"
   ```

## API 使用

### 1. 基础 API 端点
- **根路径**: `GET http://localhost:8000/`
- **健康检查**: `GET http://localhost:8000/api/v1/health`
- **API 文档**: `GET http://localhost:8000/docs` (Swagger UI)
- **API 文档**: `GET http://localhost:8000/redoc` (ReDoc)

### 2. 用户认证
大多数 API 需要 JWT 认证：
```cmd
curl -X POST "http://localhost:8000/api/v1/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=password"
```

### 3. 示例 API 调用
获取用户列表：
```cmd
curl -X GET "http://localhost:8000/api/v1/users/" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## 常见问题

### 1. 端口被占用
如果 8000 端口被占用，可以更换端口：
```cmd
uvicorn main:app --host 0.0.0.0 --port 8001
```

### 2. 权限错误
确保以管理员身份运行命令提示符，特别是在安装服务时。

### 3. 依赖包安装失败
尝试使用国内镜像源：
```cmd
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
```

### 4. SQLite 数据库锁定
如果遇到数据库锁定问题，检查是否有其他进程正在使用数据库文件。

### 5. 虚拟环境激活失败
确保路径正确，或尝试：
```cmd
.\venv\Scripts\activate.bat
```

## 维护和监控

### 1. 日志查看
日志文件位于项目根目录下的 `logs` 文件夹中。

### 2. 数据库备份
定期备份 SQLite 数据库文件：
```cmd
copy engineering_judge_v3.db engineering_judge_v3_backup_YYYYMMDD.db
```

### 3. 服务重启
如果以后台服务方式运行，可以通过 Windows 服务管理器重启服务。

## 更新和升级

### 1. 代码更新
```cmd
git pull origin main
pip install -r requirements.txt --upgrade
```

### 2. 数据库迁移
如有数据库结构变更，按照迁移脚本进行操作。

---
**文档版本**: 1.0  
**最后更新**: 2026年2月10日