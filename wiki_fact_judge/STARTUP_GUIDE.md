# Wiki Fact Judge 系统启动脚本

## 启动后端服务

```bash
cd backend
uvicorn main:app --reload --port 8000
```

## 启动前端服务

```bash
cd frontend
npm install
npm start
```

## 系统要求

- Python 3.8+
- Node.js 14+
- npm

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

### 全局依赖
```bash
npm install -g promptfoo
```