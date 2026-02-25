## Why

当前 report 详情页面显示内容过于冗长，每个 case 的 Stage Results 占据了大量篇幅，导致用户难以快速找到关键信息（case name、summary、engineering action）。用户反馈信息过载，需要滚动很多次才能看完所有 case。

## What Changes

- **简化显示**: 每个 case 只显示 name、summary 和 engineering action
- **移除 Stage Results**: 去掉 stage result 折叠面板，减少视觉干扰
- **优化布局**: 突出显示关键评估信息，提升可读性
- **保持功能**: 不影响导出功能和其他已有功能

## Capabilities

### New Capabilities
- `report-case-display`: 简化后的 case 结果显示组件，只显示 name、summary 和 engineering action

### Modified Capabilities
- `report-display`: 修改 ReportResultTable 组件的显示逻辑，移除 stage results 显示

## Impact

- **前端组件**: `frontend/src/components/ReportResultTable.tsx` 需要修改
- **样式文件**: `frontend/src/components/ReportResultTable.css` 需要调整
- **不影响**: 后端 API、数据导出功能、数据库结构
- **用户体验**: 页面加载更快，信息更清晰，滚动距离减少
