## Context

当前 `export_plan_reports_to_markdown` 函数在导出 Plan 报告时，案例结果按照数据库中存储的顺序显示（通常是创建时间顺序）。当 Plan 包含多个不同类型的案例（如 Java、SQL、Python 等）时，用户难以快速找到特定类型的文件。

## Goals / Non-Goals

**Goals:**
- 在 Markdown 导出的"案例结果总结"表格中按文件类型排序
- 在"各案例详细结果"部分按相同顺序显示
- 支持常见文件类型识别：java、sql、py、js、ts 等
- 保持排序的稳定性和可预测性

**Non-Goals:**
- 不改变 JSON 和 CSV 导出格式的顺序
- 不改变数据库存储顺序
- 不支持自定义排序规则（如用户指定优先级）
- 不修改前端显示逻辑

## Decisions

### 1. 文件类型提取方式

**决策**：从 case name 中提取文件扩展名

**方案对比**：
- **方案 A**：从 case name 提取（如 `Controller.java` → `java`）
  - ✅ 简单直接，无需额外查询
  - ✅ case name 通常包含完整文件名
  - ⚠️ 如果 case name 不含扩展名则无法识别
  
- **方案 B**：从 source_code_path 提取
  - ✅ 更准确，反映实际文件类型
  - ❌ 需要额外解析路径
  
- **方案 C**：从 TestCase 的 language 字段（如果有）
  - ✅ 最准确
  - ❌ 当前 schema 没有此字段

**选择**：方案 A，因为 case name 通常包含完整文件名（如 `Controller_xxx.java`），且实现简单。

### 2. 排序规则

**决策**：按文件类型分组 → 组内按 name 字母排序

**排序逻辑**：
1. 提取每个 case 的文件类型（扩展名）
2. 按类型分组
3. 类型之间按类型名字母排序（java < sql）
4. 同类型内按 case name 字母排序
5. 无扩展名的 case 排在最后

### 3. 实现位置

**决策**：在 `export_plan_reports_to_markdown` 函数内部排序

**理由**：
- 排序仅影响 Markdown 导出显示
- 不影响其他导出格式（JSON/CSV）
- 不改变数据库查询逻辑
- 便于维护和测试

## Risks / Trade-offs

### Risk 1: Case name 不含扩展名

**风险**：如果 case name 不包含文件扩展名，无法正确识别类型

**缓解**：
- 无扩展名的 case 统一排在最后
- 不影响功能，只是排序效果不佳

### Risk 2: 大小写不一致

**风险**：扩展名可能大小写混用（`.JAVA` vs `.java`）

**缓解**：
- 提取扩展名时统一转为小写
- 使用 `.lower()` 处理

### Risk 3: 多扩展名文件

**风险**：如 `test.java.md` 可能被识别为 `md` 而非 `java`

**缓解**：
- 使用最后一个扩展名（`split('.')[-1]`）
- 这符合预期，因为 `.md` 是实际文件类型

## Migration Plan

无需迁移：
- 仅修改导出逻辑，不改变数据结构
- 不影响现有报告
- 无需数据库迁移

## Open Questions

无
