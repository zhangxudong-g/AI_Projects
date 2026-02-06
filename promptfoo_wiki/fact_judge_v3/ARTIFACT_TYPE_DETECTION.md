# Artifact Type 检测机制说明

## 概述

Artifact Type 检测是 Engineering Judge v3 系统中的一个重要功能，用于自动识别代码文件的类型，以便在评估过程中应用适当的评估标准。

## 检测逻辑

### Java 代码
- 通过分析注解（annotations）来判断类型
- 支持以下类型：
  - `CONTROLLER`：带有 @Controller 或 @RestController 注解
  - `SERVICE`：带有 @Service 注解
  - `REPOSITORY`：带有 @Repository 注解
  - `DATA_STRUCTURE`：仅有字段而无方法的类
  - `UNKNOWN`：其他类型

### SQL 代码
- 统一归类为 `SQL_SCRIPT` 类型

### 其他语言（Python等）
- 默认归类为 `UNKNOWN` 类型

## 修复记录

在 v3 版本中，修复了 SQL 代码的 artifact type 检测问题：
- 问题：SQL 代码的 artifact_type 被设置为字符串而非列表，导致与其他语言处理方式不一致
- 修复：将 `anchors["artifact_type"] = "SQL_SCRIPT"` 修改为 `anchors["artifact_type"] = ["SQL_SCRIPT"]`
- 影响：确保了数据结构的一致性，使系统能正确处理各种类型的代码文件

## 在评估流程中的作用

1. **Stage 0**：`prepare_engineering_facts` 函数提取代码特征并确定 artifact type
2. **Stage 1.5**：在解释对齐判断中使用 artifact type 信息
3. **Stage 2**：在工程价值判断中参考 artifact type 进行评估