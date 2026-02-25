# Report Unique Naming

## ADDED Requirements

### Requirement: 报告唯一命名生成
系统应为每次运行生成唯一的报告名称，确保不覆盖已有报告。

#### Scenario: 运行案例生成新报告
- **WHEN** 用户运行测试案例
- **THEN** 系统生成包含时间戳和随机数的唯一报告名称

#### Scenario: 运行计划生成新报告
- **WHEN** 用户运行测试计划
- **THEN** 系统为该计划下的每个案例生成唯一报告名称

#### Scenario: 同一案例多次运行
- **WHEN** 同一案例在短时间内被多次运行
- **THEN** 每次运行都生成独立的报告记录，互不覆盖

### Requirement: 报告名称格式
报告名称应包含案例/计划标识、时间戳和随机数，便于识别和追溯。

#### Scenario: 案例报告命名
- **WHEN** 为案例生成报告
- **THEN** 报告名称格式为 `report_{case_id}_{timestamp}_{random}`

#### Scenario: 计划报告命名
- **WHEN** 为计划生成报告
- **THEN** 报告名称格式为 `report_{plan_id}_{timestamp}_{random}`

#### Scenario: 时间戳精度
- **WHEN** 生成时间戳
- **THEN** 使用 ISO 8601 格式，精确到秒

#### Scenario: 随机数长度
- **WHEN** 生成随机数
- **THEN** 使用 6 位十六进制数，确保同一秒内的唯一性

### Requirement: 报告名称唯一性验证
系统应验证生成的报告名称在数据库中不存在，防止冲突。

#### Scenario: 名称冲突检测
- **WHEN** 生成的报告名称已存在
- **THEN** 系统重新生成随机数部分，直到名称唯一

#### Scenario: 最大重试次数
- **WHEN** 连续 10 次生成冲突名称
- **THEN** 系统抛出错误并记录日志
