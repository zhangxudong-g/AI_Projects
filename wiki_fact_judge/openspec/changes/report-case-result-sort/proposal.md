## Why

在导出 Plan Markdown 报告时，案例结果表格和详细结果的显示顺序是随机的（按 case_id 或数据库顺序），用户难以快速定位特定类型的文件（如所有 Java 文件或所有 SQL 文件）。当 Plan 包含多个案例时，按文件类型排序可以提高报告的可读性和查找效率。

## What Changes

- **修改 `export_plan_reports_to_markdown` 函数**：在生成"案例结果总结"表格和"各案例详细结果"部分时，按文件类型对案例进行排序
- **文件类型识别**：从 case name 中提取文件扩展名（如 `.java`, `.sql`, `.py` 等），按类型分组排序
- **排序规则**：
  1. 首先按文件类型分组（java、sql、py 等）
  2. 同一类型内按 case name 字母顺序排序
  3. 无扩展名的案例排在最后

## Capabilities

### New Capabilities

- `case-result-sort`: 支持按文件类型对案例结果进行排序显示

### Modified Capabilities

- `report-export`: 导出功能中的 Markdown 导出逻辑需要支持排序

## Impact

- **修改文件**：`backend/services/export_service.py` 中的 `export_plan_reports_to_markdown` 函数
- **影响范围**：Plan Markdown 导出功能，不影响 JSON 和 CSV 导出
- **向后兼容**：完全兼容，只是改变显示顺序，不改变数据结构
- **依赖**：需要从 `TestCase` 中获取 case name 来识别文件类型
