## MODIFIED Requirements

### Requirement: Plan Markdown Export Case Details

导出 Plan 的 Markdown 报告时，系统应在"各案例详细结果"部分包含完整的评估信息。

#### Scenario: 显示 Case 基本信息
- **WHEN** 导出 Plan Markdown 报告
- **THEN** 每个 case 显示 name、score、result

#### Scenario: 显示 Engineering Action
- **WHEN** case 有 engineering_action 数据
- **THEN** 显示 level、description、recommended_action

#### Scenario: 显示 Summary
- **WHEN** case 有 summary 数据
- **THEN** 显示完整的评估 summary

#### Scenario: 显示 Assessment Details
- **WHEN** case 有 details 数据
- **THEN** 显示 comprehension_support、engineering_usefulness 等评估维度

#### Scenario: 格式化输出
- **WHEN** 生成 Markdown 内容
- **THEN** 使用清晰的标题、列表和代码块格式
