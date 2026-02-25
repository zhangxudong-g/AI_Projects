## Why

当前 Plan Markdown 导出功能中，"各案例详细结果" 部分内容不完整或缺失，用户无法在导出的 Markdown 文档中查看每个 case 的详细评估结果，包括 Engineering Action、Summary 等关键信息。

## What Changes

- **修复导出内容**: 确保 "各案例详细结果" 部分包含每个 case 的完整信息
- **显示内容**: Case Name、Score、Result、Engineering Action、Summary、Assessment Details
- **格式优化**: 使用清晰的 Markdown 格式，便于阅读

## Capabilities

### Modified Capabilities
- `report-export`: 修改 `export_plan_reports_to_markdown` 函数，增强案例详细结果的导出内容

## Impact

- **后端服务**: `backend/services/export_service.py` 需要修改
- **不影响**: 前端显示、数据库结构、其他导出格式
