## MODIFIED Requirements

### Requirement: Plan MD Export Summary Table Recommendation Column

导出 Plan 的 Markdown 报告时，系统应在案例结果总结表格中包含 Recommendation 列。

#### Scenario: 显示 Recommendation 列
- **WHEN** 生成案例结果总结表格
- **THEN** 表格包含 Recommendation 列

#### Scenario: Recommendation 列位置
- **WHEN** 显示表格列
- **THEN** Recommendation 列在 Engineering Action Level 列之后

#### Scenario: 显示完整 Recommendation 内容
- **WHEN** 显示 Recommendation
- **THEN** 显示 engineering_action.recommended_action 的完整内容

#### Scenario: 处理缺失的 Recommendation
- **WHEN** case 没有 engineering_action 或 recommended_action
- **THEN** 显示 "N/A"
