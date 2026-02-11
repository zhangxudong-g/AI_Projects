
# Wiki Engineering Judge 系统重构设计文档

## 目标：CLI + Web UI 双入口架构

---

# 一、总体目标

在保留现有 CLI pipeline（`run_single_case_pipeline.py`）完全不变的前提下，新增：

1. Web UI（React）
2. Python API Server（FastAPI）
3. SQLite 数据库存储测试元数据
4. 本地文件存储测试资源
5. Test Case / Test Plan / Test Report 管理系统

---

# 二、总体架构设计

## 2.1 总体架构

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

---

# 三、核心原则

1. ❗ 不修改 `run_single_case_pipeline.py` 核心逻辑
2. ❗ 不改变 CLI 使用方式
3. Web 只是“封装 CLI 调用”
4. 文件全部保存在本地
5. 数据库存储元数据与索引
6. Web 调用通过 subprocess 执行 CLI

---

# 四、目录结构设计

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

---

# 五、数据库设计（SQLite）

## 5.1 Case 表

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

---

## 5.2 Test Plan 表

```sql
CREATE TABLE test_plans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    description TEXT,
    created_at DATETIME
);
```

---

## 5.3 Plan-Case 关联表

```sql
CREATE TABLE plan_cases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER,
    case_id INTEGER,
    FOREIGN KEY(plan_id) REFERENCES test_plans(id),
    FOREIGN KEY(case_id) REFERENCES test_cases(id)
);
```

---

## 5.4 Test Report 表

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

---

# 六、核心功能设计

---

# 1️⃣ Test Case 功能

## 支持：

* 单个 case 上传
* 批量上传
* 单独执行

---

## API 设计

### 创建 Case

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

---

### 批量上传

```
POST /cases/batch
```

支持 zip 包解析。

---

### 执行单个 Case

```
POST /cases/{case_id}/run
```

流程：

1. 查询数据库
2. 构造 vars_cfg
3. 调用 pipeline_service.run_case()
4. 保存结果
5. 生成 report

---

# 2️⃣ Test Plan 功能

## 创建 Plan

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

---

## 执行 Plan

```
POST /plans/{plan_id}/run
```

逻辑：

```
for case in plan:
    run_single_case(...)
    collect result
aggregate results
generate report
```

---

# 3️⃣ Test Report 管理

## 查询报告

```
GET /reports
GET /reports/{id}
```

返回：

```json
{
  "report_name": "regression_plan_v1",
  "results": [
    {
      "case_id": "case_001",
      "score": 88,
      "result": "PASS"
    }
  ]
}
```

---

# 七、Pipeline 调用设计（核心）

## pipeline_service.py

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

❗ 不修改 CLI
❗ Web 只负责“触发”

---

# 八、React 前端设计

---

## 页面结构

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

---

## 主要功能

### Case 页面

* 上传文件
* 显示 source / wiki 文件名
* 显示最近分数
* Run 按钮

---

### Plan 页面

* 多选 Case
* 创建 Plan
* 批量 Run

---

### Report 页面

* 显示分数
* 显示 PASS/FAIL
* 显示详细 breakdown
* 可下载 final_score.json

---

# 九、执行流程示意

## 单个 Case

```
User 点击 Run
    ↓
API /cases/{id}/run
    ↓
pipeline_service.run_case()
    ↓
CLI pipeline 执行
    ↓
生成 final_score.json
    ↓
数据库写入 report
    ↓
返回结果
```

---

## Plan 执行

```
User 点击 Run Plan
    ↓
for case in plan:
    run_case()
    collect score
aggregate:
    avg_score
    pass_rate
保存 plan_report
```

---

# 十、状态管理设计

Report.status:

* RUNNING
* FINISHED
* FAILED

后期可扩展：

* WebSocket 实时进度

当前版本：同步执行即可

---

# 十一、未来可扩展能力（本期不实现）

* 分布式执行
* 并发 worker
* Redis 队列
* SSE 实时流式日志
* 多用户权限系统

---

# 十二、CLI 保持不变的约束

必须满足：

* `run_single_case_pipeline.py` 不修改
* CLI 仍可：

```bash
python run_single_case_pipeline.py ...
```

* 所有 yaml config 保持现状

---

# 十三、阶段划分（给 Qwen Coder）

## Phase 1

* 建 SQLite
* 实现 Case CRUD
* 实现 run_case

## Phase 2

* 实现 Plan
* 实现 batch run

## Phase 3

* 实现 Report UI
* 显示 score breakdown

---

# 十四、验收标准

✅ CLI 仍可单独运行
✅ Web 可以执行单个 case
✅ Web 可以执行 plan
✅ Web 可以查看报告
✅ 所有文件保存到本地
✅ SQLite 正常存储数据

---

# 十五、最终目标

把当前：

> CLI 工具

升级为：

> 可视化工程评估平台

同时保留：

> CLI 作为核心引擎
