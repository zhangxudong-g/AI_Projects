## Why

后端已经实现了报告导出 API（JSON/Markdown/CSV），但前端 UI 没有任何导出按钮，用户无法通过 Web 界面导出报告。这导致：
1. 用户只能通过 API 调用导出功能，使用不便
2. 前端功能不完整，用户体验差
3. 已实现的后端功能被浪费

需要在前端添加导出按钮，让用户可以方便地下载报告。

## What Changes

- 在报告列表页面添加导出按钮（每个报告行）
- 在报告详情页面添加导出按钮
- 添加 Plan 汇总页面的导出按钮（可选）
- 支持导出为 JSON/Markdown/CSV 三种格式

## Capabilities

### New Capabilities
- `report-export-ui`: 前端报告导出 UI 组件和交互

### Modified Capabilities
- `report-management`: 报告管理界面添加导出功能

## Impact

- **前端组件**: 
  - `ReportList.tsx` - 添加导出按钮列
  - `ReportDetail.tsx` - 添加导出按钮组
- **API 调用**: 需要添加导出相关的 API 函数
- **用户体验**: 用户可以方便地下载报告，无需手动调用 API
