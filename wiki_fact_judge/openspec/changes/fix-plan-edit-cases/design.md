## Context

PlanEditForm 组件在编辑 Plan 时无法正确回显已关联的 Case。

## Goals / Non-Goals

**Goals:**
- 编辑 Plan 时正确显示已关联的 Case
- 复选框选中状态与 plan.case_ids 一致

**Non-Goals:**
- 不修改 Plan 数据结构
- 不修改 API 接口

## Decisions

### 数据加载时序
**决策**: 在 allCases 加载完成后再设置 selectedCaseIds

**理由**:
- 确保所有 Case 数据可用
- 避免竞态条件

## Risks / Trade-offs

无显著风险。
