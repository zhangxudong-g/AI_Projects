## Why

当前 Report 详情页面显示了 case name，但 summary 显示在顶部且不够醒目。用户反馈希望在 Recommendation 下面直接看到最终的 summary，这样可以快速了解评估结论，无需滚动查找。

## What Changes

- **显示位置调整**: 将 summary 移动到 Recommendation 下面显示
- **保持 Case Name**: 继续在顶部显示 case name 和 ID
- **优化布局**: Engineering Action → Recommendation → Summary 的顺序展示

## Capabilities

### Modified Capabilities
- `report-case-display`: 修改 summary 显示位置，移动到 Recommendation 下方

## Impact

- **前端组件**: `frontend/src/components/ReportResultTable.tsx` 需要调整显示顺序
- **样式文件**: 可能需要微调 CSS 样式
- **不影响**: 数据结构、后端 API、导出功能
