## ADDED Requirements

### Requirement: Plan MD Export Case Summary Table

导出 Plan 的 Markdown 报告时，系统应在"各案例详细结果"部分上方添加一个总结表格。

#### Scenario: 显示总结表格
- **WHEN** 导出 Plan Markdown 报告
- **THEN** 在"各案例详细结果"标题下方显示总结表格

#### Scenario: 表格列内容
- **WHEN** 生成总结表格
- **THEN** 包含 Case Name、Case ID、Result、Score、Engineering Action Level 列

#### Scenario: 表格排序
- **WHEN** 显示案例
- **THEN** 按照 results 数组中的顺序显示

#### Scenario: 表格格式
- **WHEN** 生成 Markdown 表格
- **THEN** 使用标准 Markdown 表格格式，包含表头分隔线
