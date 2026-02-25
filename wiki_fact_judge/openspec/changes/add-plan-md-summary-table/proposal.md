## Why

当前 Plan Markdown 导出中，"各案例详细结果"部分直接列出所有案例的详细信息，用户无法快速概览所有案例的评估结果。需要在详细信息之前添加一个总结表格，方便用户快速浏览所有案例的关键信息。

## What Changes

- **新增总结表格**: 在"各案例详细结果"标题下方添加一个 Markdown 表格
- **表格内容**: Case Name、Case ID、Result、Score、Engineering Action Level
- **位置**: 在"各案例详细结果"标题之后，详细案例列表之前

## Capabilities

### Modified Capabilities
- `report-export`: 修改 `export_plan_reports_to_markdown` 函数，添加案例结果总结表格

## Impact

- **后端服务**: `backend/services/export_service.py` 需要修改
- **不影响**: 前端显示、数据库结构、其他导出格式
