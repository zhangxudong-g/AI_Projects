## Why

编辑 Plan 时，已关联的 Case 复选框没有正确回显选中状态，导致用户不知道哪些 Case 已经关联到该 Plan。这是因为：
1. `selectedCaseIds` 在组件初始化时设置
2. 但 `allCases` 是异步加载的
3. 当 `allCases` 加载完成后，没有正确设置选中状态

需要修复数据加载时序问题，确保编辑 Plan 时能正确回显已关联的 Case。

## What Changes

- 修改 `PlanEditForm.tsx` 中的 `useEffect` 逻辑
- 在 `allCases` 加载完成后，根据 `plan.case_ids` 设置选中的 Case
- 添加 `plan.case_ids` 到依赖数组，确保数据变化时重新加载

## Capabilities

### Modified Capabilities
- `plan-management`: 修复 Plan 编辑表单的 Case 回显逻辑

## Impact

- **前端组件**: `PlanEditForm.tsx` - 修复 Case 复选框回显逻辑
- **用户体验**: 编辑 Plan 时可以正确看到已关联的 Case
