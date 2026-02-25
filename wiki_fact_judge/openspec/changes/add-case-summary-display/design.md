## Context

当前 ReportResultTable 组件中，summary 显示在 case card 的顶部，而 Engineering Action 和 Recommendation 在下方。用户希望按照以下顺序查看信息：
1. Case Name（标识）
2. 分数和 Pass/Fail（快速评估）
3. Engineering Action（工程建议）
4. Recommendation（推荐操作）
5. Summary（详细评估总结）

## Goals / Non-Goals

**Goals:**
- 将 summary 移动到 Recommendation 下方显示
- 保持其他显示逻辑不变
- 确保样式协调一致

**Non-Goals:**
- 不修改数据结构
- 不修改其他显示内容
- 不影响导出功能

## Decisions

### Decision 1: 调整显示顺序

**Rationale:** 
- 用户阅读习惯是从概括到详细
- Engineering Action 和 Recommendation 是决策关键，应该先看到
- Summary 提供详细背景，放在最后供需要时阅读

## Risks / Trade-offs

**[Risk]** 用户可能习惯之前的布局  
→ **Mitigation:** 改动较小，不影响功能，只是顺序调整
