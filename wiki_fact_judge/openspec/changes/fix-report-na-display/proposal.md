## Why

当前报告详情页面会显示 'N/A' 给空值字段（如 plan_id、case_id、final_score），这导致：
1. 用户体验差 - N/A 不友好
2. 信息不清晰 - 用户不知道是数据缺失还是系统错误
3. 界面不美观

需要改进数据显示逻辑，隐藏空值字段或使用更友好的提示。

## What Changes

- 修改 ReportDetail 组件，不显示 'N/A'
- 对于可选字段（plan_id、case_id），如果为空则不显示该行
- 对于分数（final_score），如果为空显示"待计算"或隐藏
- 确保报告数据正确获取和显示

## Capabilities

### New Capabilities
- `report-data-display`: 改进报告数据显示逻辑，避免显示 N/A

### Modified Capabilities
- `report-management`: 报告详情展示优化

## Impact

- **前端组件**: 
  - `ReportDetail.tsx` - 修改数据显示逻辑
  - `ReportResultTable.tsx` - 可能需要类似修改
- **用户体验**: 更清晰、更友好的数据显示
