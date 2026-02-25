## Context

当前导出的 Markdown 文档结构：
1. 计划信息
2. 汇总统计
3. 报告列表
4. 各案例详细结果（直接列出详细信息）

用户需要在第 4 部分之前看到一个总结表格，快速了解所有案例的评估状态。

## Goals / Non-Goals

**Goals:**
- 在"各案例详细结果"标题下方添加总结表格
- 表格包含：Case Name、Case ID、Result、Score、Engineering Action Level
- 保持现有详细内容不变

**Non-Goals:**
- 不修改其他导出格式
- 不修改前端显示
- 不影响汇总统计部分

## Decisions

### Decision 1: 使用 Markdown 表格格式

**Rationale:** 
- Markdown 原生支持表格
- 易于阅读和解析
- 与其他部分格式一致

### Decision 2: 表格列设计

**Rationale:**
- Case Name: 识别案例
- Case ID: 唯一标识
- Result: Pass/Fail 状态
- Score: 量化评分
- Engineering Action Level: 工程建议级别

## Risks / Trade-offs

**[Risk]** 表格可能较长（20 个案例）  
→ **Mitigation:** 这是总结表格，比详细列表简洁得多
