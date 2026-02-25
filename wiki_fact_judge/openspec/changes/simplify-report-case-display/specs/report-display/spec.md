## MODIFIED Requirements

### Requirement: Plan Report Case Display

在 Plan Report 详情页面显示每个 case 的评估结果时，系统应只显示关键信息，避免信息过载。

#### Scenario: 显示 Case Name
- **WHEN** 用户查看 Plan Report 详情
- **THEN** 每个 case 显示完整的 case name 和 case ID

#### Scenario: 显示 Summary
- **WHEN** 用户查看 case 结果
- **THEN** 显示评估 summary（前 100 个字符，超出部分用省略号）

#### Scenario: 显示 Engineering Action
- **WHEN** case 有 engineering_action 数据
- **THEN** 突出显示 engineering action 的 level、description 和 recommended_action

#### Scenario: 显示 Assessment Details
- **WHEN** case 有 details 数据
- **THEN** 提供折叠面板显示评估维度详情（comprehension_support, engineering_usefulness 等）

#### Scenario: 隐藏 Stage Results
- **WHEN** 用户查看 Plan Report 详情
- **THEN** 不显示 stage results 部分，减少页面长度

#### Scenario: 显示分数和结果
- **WHEN** 用户查看 case 结果
- **THEN** 显示 final_score（带颜色标识）和 Pass/Fail 徽章

#### Scenario: 分数颜色标识
- **WHEN** final_score >= 80
- **THEN** 使用绿色显示分数

#### Scenario: 中等分数颜色
- **WHEN** final_score >= 40 且 < 80
- **THEN** 使用黄色显示分数

#### Scenario: 低分颜色
- **WHEN** final_score < 40
- **THEN** 使用红色显示分数
