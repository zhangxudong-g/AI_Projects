## Context

当前 `export_plan_reports_to_markdown` 函数在生成"各案例详细结果"部分时，只显示了基本信息（报告名称、状态、得分），缺少关键的评估详情。

## Goals / Non-Goals

**Goals:**
- 在"各案例详细结果"部分显示每个 case 的完整评估信息
- 包括：Engineering Action、Summary、Assessment Details
- 保持 Markdown 格式清晰易读

**Non-Goals:**
- 不修改 JSON 导出格式
- 不修改单个 report 的导出
- 不影响 CSV 导出

## Decisions

### Decision 1: 从 result 字段提取详细信息

**Rationale:** 
- 修复后的 report 数据已经包含了完整的 assessment 信息
- 直接从 `result.results[].details` 和 `result.results[].engineering_action` 提取

### Decision 2: 使用折叠格式显示详情

**Rationale:**
- Markdown 不支持真正的折叠，使用标题和列表格式
- 保持文档结构清晰

## Risks / Trade-offs

**[Risk]** 导出文档可能变长  
→ **Benefit:** 信息完整，用户无需查看多个文件
