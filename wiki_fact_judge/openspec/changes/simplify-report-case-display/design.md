## Context

当前 ReportResultTable 组件在显示 plan report 时，每个 case 都会显示：
- Case name 和 ID
- 分数和 Pass/Fail 徽章
- Engineering Action（主要信息）
- Assessment Details（折叠）
- Stage Results（折叠）

用户反馈 Stage Results 内容冗长，且与 Assessment Details 有重复，导致页面需要大量滚动。

## Goals / Non-Goals

**Goals:**
- 简化 case 结果显示，只保留关键信息
- 移除 Stage Results 部分
- 保持 Engineering Action 和 Assessment Details 的显示
- 不影响数据导出功能
- 保持组件的可维护性和扩展性

**Non-Goals:**
- 不修改后端数据结构
- 不改变导出功能的内容
- 不修改单个 case report 的显示（只针对 plan report）

## Decisions

### Decision 1: 保留 Assessment Details，移除 Stage Results

**Rationale**: 
- Assessment Details 包含关键评估维度（comprehension_support, engineering_usefulness 等），用户需要快速查看
- Stage Results 内容冗长，且与 Assessment Details 有重复
- 保持折叠显示，用户仍可查看详细信息

**Alternatives Considered:**
- 全部移除：会导致信息缺失，不可取
- 都保留：无法解决信息过载问题

### Decision 2: 修改前端组件，不影响后端

**Rationale:**
- 后端数据结构保持不变，兼容性好
- 只修改 ReportResultTable 组件的渲染逻辑
- 导出功能使用原始数据，不受影响

**Alternatives Considered:**
- 修改后端数据结构：增加复杂度，影响现有功能

## Risks / Trade-offs

**[Risk]** 用户可能需要 Stage Results 信息进行深度分析  
→ **Mitigation**: Stage Results 仍可在原始数据中查看，导出功能不受影响

**[Risk]** 修改组件可能影响其他显示逻辑  
→ **Mitigation**: 只修改 plan report 的显示逻辑，单个 case report 保持不变

**[Trade-off]** 简化显示可能丢失部分信息  
→ **Benefit**: 提升用户体验，减少滚动，快速找到关键信息
