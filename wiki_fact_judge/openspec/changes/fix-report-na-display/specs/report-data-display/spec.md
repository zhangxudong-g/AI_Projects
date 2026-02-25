# Report Data Display

## ADDED Requirements

### Requirement: 空值字段隐藏
报告详情中可选字段为空时应隐藏整行，不显示 'N/A'。

#### Scenario: plan_id 为空时隐藏
- **WHEN** 报告的 plan_id 为 null
- **THEN** 不显示 Plan ID 字段行

#### Scenario: case_id 为空时隐藏
- **WHEN** 报告的 case_id 为 null
- **THEN** 不显示 Case ID 字段行

#### Scenario: output_path 为空时隐藏
- **WHEN** 报告的 output_path 为 null 或空字符串
- **THEN** 不显示 Output Path 字段行

### Requirement: 分数显示优化
最终分数应根据报告状态智能显示。

#### Scenario: 报告未完成时分数显示
- **WHEN** 报告状态为 PENDING 或 RUNNING
- **THEN** 分数显示为"待计算"而不是 N/A

#### Scenario: 报告完成但无分数
- **WHEN** 报告状态为 FINISHED 但 final_score 为 null
- **THEN** 分数显示为"-"或隐藏

#### Scenario: 报告有分数
- **WHEN** final_score 有有效值
- **THEN** 显示分数，保留两位小数
