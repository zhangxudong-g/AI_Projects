## Context

当前总结表格包含 5 列：Case Name、Case ID、Result、Score、Engineering Action Level。用户希望在表格中直接看到 Recommendation，方便快速浏览所有案例的工程建议。

## Goals / Non-Goals

**Goals:**
- 在总结表格中添加 Recommendation 列
- 显示完整的 recommended_action 内容
- 保持表格格式清晰

**Non-Goals:**
- 不修改其他列
- 不影响详细案例列表
- 不修改其他导出格式

## Decisions

### Decision 1: 在 Engineering Action Level 后添加 Recommendation 列

**Rationale:** 
- Recommendation 是 Engineering Action 的一部分
- 逻辑上应该紧跟在 Level 之后
- 保持表格的可读性

### Decision 2: 显示完整内容

**Rationale:**
- Recommendation 内容通常较短（10-30 字）
- 完整显示更有信息量
- Markdown 表格支持自动换行

## Risks / Trade-offs

**[Risk]** 表格可能变宽  
→ **Mitigation:** Markdown 表格支持滚动，且 Recommendation 内容通常不长
