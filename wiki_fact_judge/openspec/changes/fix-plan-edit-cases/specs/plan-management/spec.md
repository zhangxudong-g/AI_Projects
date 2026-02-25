# Plan Management Delta

## MODIFIED Requirements

### Requirement: 编辑 Plan 时 Case 回显
编辑 Plan 时，表单应正确回显已关联的 Case，复选框选中状态与 plan.case_ids 一致。

#### Scenario: Plan 有关联的 Case
- **WHEN** 用户打开 Plan 编辑表单且 Plan 有已关联的 Case
- **THEN** 对应的 Case 复选框应该被选中

#### Scenario: Plan 没有关联的 Case
- **WHEN** 用户打开 Plan 编辑表单且 Plan 没有关联的 Case
- **THEN** 所有 Case 复选框都不选中

#### Scenario: 用户修改 Case 选择
- **WHEN** 用户在编辑表单中勾选或取消勾选 Case
- **THEN** 复选框状态正确更新
