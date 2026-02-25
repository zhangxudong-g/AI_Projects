## Why

当前 Plan Markdown 导出的案例结果总结表格只包含 Engineering Action Level，但用户希望看到完整的 Recommendation 信息，以便快速了解每个案例的工程建议，无需滚动到详细信息部分。

## What Changes

- **修改总结表格**: 在现有表格基础上新增 **Recommendation** 列
- **显示内容**: 显示 engineering_action.recommended_action 的完整内容
- **位置**: 在 Engineering Action Level 列之后

## Capabilities

### Modified Capabilities
- `report-export`: 修改 `export_plan_reports_to_markdown` 函数，在总结表格中添加 Recommendation 列

## Impact

- **后端服务**: `backend/services/export_service.py` 需要修改
- **不影响**: 前端显示、数据库结构、其他导出格式
