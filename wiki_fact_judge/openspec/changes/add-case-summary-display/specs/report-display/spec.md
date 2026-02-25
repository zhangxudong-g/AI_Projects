## MODIFIED Requirements

### Requirement: Case Summary Display Position

在 Report 详情页面的每个 case 卡片中，系统应按以下顺序显示信息：

#### Scenario: 显示 Case Name 在顶部
- **WHEN** 用户查看 case 卡片
- **THEN** case name 和 case ID 显示在卡片顶部

#### Scenario: 显示分数和结果
- **WHEN** 用户查看 case 卡片
- **THEN** final_score 和 Pass/Fail 徽章显示在顶部右侧

#### Scenario: 显示 Engineering Action
- **WHEN** case 有 engineering_action 数据
- **THEN** Engineering Action 显示在顶部下方，使用彩色边框突出

#### Scenario: 显示 Recommendation
- **WHEN** engineering_action 包含 recommended_action
- **THEN** Recommendation 显示在 Engineering Action 内部

#### Scenario: 显示 Summary 在 Recommendation 下方
- **WHEN** case 有 summary 数据
- **THEN** Summary 显示在 Recommendation 下方，使用独立段落

#### Scenario: Summary 样式
- **WHEN** 显示 summary
- **THEN** 使用较浅的背景色或边框与 Recommendation 区分
