# Report Management Delta

## MODIFIED Requirements

### Requirement: 创建报告
创建报告时，系统应自动生成唯一的报告名称，不覆盖已有报告。

#### Scenario: 成功创建唯一报告
- **WHEN** 调用 `POST /reports/` 创建报告
- **THEN** 系统自动生成包含时间戳和随机数的唯一报告名称

#### Scenario: 案例报告创建
- **WHEN** 为案例创建报告且未提供 report_name
- **THEN** 系统使用格式 `report_{case_id}_{timestamp}_{random}` 生成名称

#### Scenario: 计划报告创建
- **WHEN** 为计划创建报告且未提供 report_name
- **THEN** 系统使用格式 `report_{plan_id}_{timestamp}_{random}` 生成名称

#### Scenario: 手动指定报告名称
- **WHEN** 调用 API 时提供了 report_name 参数
- **THEN** 系统使用提供的名称，但追加时间戳确保唯一性

#### Scenario: 报告名称唯一性保证
- **WHEN** 生成的报告名称与现有报告冲突
- **THEN** 系统自动重新生成随机数部分，直到名称唯一
