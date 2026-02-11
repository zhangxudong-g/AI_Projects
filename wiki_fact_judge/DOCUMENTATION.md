# Wiki Fact Judge 系统重构项目文档

## 项目概述

Wiki Fact Judge 是一个用于评估维基百科事实准确性的系统，支持 CLI 和 Web UI 双入口架构。该项目重构旨在保留现有 CLI pipeline 完全不变的前提下，新增 Web UI 功能，提供可视化工程评估平台。

## 系统架构

```
                   ┌──────────────────────────┐
                   │        React Web UI      │
                   └────────────┬─────────────┘
                                │ REST API
                                ▼
                   ┌──────────────────────────┐
                   │      FastAPI Backend     │
                   │                          │
                   │  - Case Management       │
                   │  - Plan Management       │
                   │  - Report Management     │
                   │  - Trigger Pipeline      │
                   └────────────┬─────────────┘
                                │
                                ▼
                   ┌──────────────────────────┐
                   │   Existing CLI Pipeline  │
                   │ run_single_case_pipeline │
                   └────────────┬─────────────┘
                                │
                                ▼
                        本地文件输出 (output/)
                                │
                                ▼
                             SQLite
```

## 核心原则

1. ❗ 不修改 `run_single_case_pipeline.py` 核心逻辑
2. ❗ 不改变 CLI 使用方式
3. Web 只是"封装 CLI 调用"
4. 文件全部保存在本地
5. 数据库存储元数据与索引
6. Web 调用通过 subprocess 执行 CLI

## 目录结构

```
project_root/
│
├── cli/                            # 现有 CLI 保持不动
│   ├── run_single_case_pipeline.py
│   ├── stage1_fact_extractor.yaml
│   ├── stage1_5_explanation_alignment.yaml
│   ├── stage2_explanatory_judge.yaml
│   ├── stage3_score.py
│   └── ...
│
├── backend/
│   ├── main.py                     # FastAPI 入口
│   ├── database.py
│   ├── models.py
│   ├── schemas.py
│   ├── services/
│   │     ├── case_service.py
│   │     ├── plan_service.py
│   │     ├── report_service.py
│   │     └── pipeline_service.py   # 调用 CLI
│   └── routers/
│         ├── case_router.py
│         ├── plan_router.py
│         └── report_router.py
│
├── frontend/
│   ├── src/
│   │    ├── pages/
│   │    ├── components/
│   │    ├── api/
│   │    └── App.tsx
│
├── data/
│   ├── cases/
│   ├── plans/
│   ├── reports/
│   └── output/
│
└── judge.db
```

## 数据库设计

### 1. Case 表
```sql
CREATE TABLE test_cases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    case_id TEXT UNIQUE,
    name TEXT,
    source_code_path TEXT,
    wiki_path TEXT,
    yaml_path TEXT,
    created_at DATETIME,
    updated_at DATETIME
);
```

### 2. Test Plan 表
```sql
CREATE TABLE test_plans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    description TEXT,
    created_at DATETIME
);
```

### 3. Plan-Case 关联表
```sql
CREATE TABLE plan_cases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER,
    case_id INTEGER,
    FOREIGN KEY(plan_id) REFERENCES test_plans(id),
    FOREIGN KEY(case_id) REFERENCES test_cases(id)
);
```

### 4. Test Report 表
```sql
CREATE TABLE test_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_name TEXT,
    plan_id INTEGER NULL,
    case_id INTEGER NULL,
    status TEXT,           -- RUNNING / FINISHED / FAILED
    final_score REAL,
    result TEXT,
    output_path TEXT,
    created_at DATETIME
);
```

## API 接口设计

### 1. Test Case 接口

#### 创建 Case
```
POST /cases
```

form-data:
* source_code
* wiki
* yaml

返回：
```json
{
  "case_id": "case_001",
  "status": "created"
}
```

#### 执行单个 Case
```
POST /cases/{case_id}/run
```

### 2. Test Plan 接口

#### 创建 Plan
```
POST /plans
```

body:
```json
{
  "name": "regression_plan_v1",
  "case_ids": ["case_001", "case_002"]
}
```

#### 执行 Plan
```
POST /plans/{plan_id}/run
```

### 3. Test Report 接口

#### 查询报告
```
GET /reports
GET /reports/{id}
```

## 前端页面结构

```
Dashboard
 ├── Cases
 │     ├── CaseList
 │     ├── UploadCase
 │     └── CaseDetail
 │
 ├── Plans
 │     ├── PlanList
 │     ├── CreatePlan
 │     └── PlanDetail
 │
 └── Reports
       ├── ReportList
       └── ReportDetail
```

## 后端服务实现

### 1. Pipeline 调用设计

```python
import subprocess
import json
from pathlib import Path

def run_case(case):
    output_dir = Path("data/output") / case.case_id
    output_dir.mkdir(parents=True, exist_ok=True)

    cmd = [
        "python",
        "cli/run_single_case_pipeline.py",
        "--case-id", case.case_id
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        raise Exception(result.stderr)

    final_json = output_dir / "final_score.json"
    return json.loads(final_json.read_text())
```

### 2. 服务层实现

- `case_service.py`: 处理测试案例的 CRUD 操作
- `plan_service.py`: 处理测试计划的 CRUD 操作
- `report_service.py`: 处理测试报告的 CRUD 操作
- `pipeline_service.py`: 调用 CLI 执行测试

## 前端实现

### 1. 技术栈
- React 18
- TypeScript
- React Router
- Axios
- CSS Modules

### 2. 主要组件
- `CasesPage`: 案例管理页面
- `PlansPage`: 计划管理页面
- `ReportsPage`: 报告管理页面
- 各种子组件（列表、详情、表单等）

## 部署指南

### 1. 后端部署
```bash
# 安装依赖
pip install -r requirements.txt

# 启动服务
cd backend
uvicorn main:app --host 0.0.0.0 --port 8000
```

### 2. 前端部署
```bash
# 安装依赖
cd frontend
npm install

# 构建生产版本
npm run build

# 或者开发模式启动
npm start
```

## 环境变量

- `REACT_APP_API_URL`: 前端 API 地址（默认: http://localhost:8000）

## 开发指南

### 1. 后端开发
- 使用 FastAPI 提供 RESTful API
- 使用 SQLAlchemy 进行数据库操作
- 所有业务逻辑放在 services 目录中

### 2. 前端开发
- 使用 TypeScript 编写类型安全的代码
- 使用 React Hooks 进行状态管理
- API 调用统一在 api 目录中管理

## 测试策略

### 1. 单元测试
- 后端：使用 pytest 测试服务层和路由
- 前端：使用 Jest 和 React Testing Library 测试组件

### 2. 集成测试
- 测试 API 端点
- 测试前后端集成

## 未来扩展

1. 分布式执行
2. 并发 worker
3. Redis 队列
4. SSE 实时流式日志
5. 多用户权限系统

## 验收标准

✅ CLI 仍可单独运行
✅ Web 可以执行单个 case
✅ Web 可以执行 plan
✅ Web 可以查看报告
✅ 所有文件保存到本地
✅ SQLite 正常存储数据

## 总结

本项目成功将原有的 CLI 工具升级为可视化工程评估平台，同时保留了 CLI 作为核心引擎。通过双入口架构，用户可以选择使用命令行或 Web 界面来执行测试，提高了系统的可用性和易用性。