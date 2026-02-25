# Proposal: optimize-report-display

## 概述

优化 Report 页面的显示效果，提升用户体验和信息可读性。

## 需求

### 1. 显示工程建议
- 将 Engineering Action 作为主要展示内容
- 突出显示推荐操作（recommended_action）
- 使用醒目的样式展示工程建议级别

### 2. 简化显示结构
- 去掉 Sub-Results 嵌套显示
- 直接展示每个 case 的结果
- 减少层级，提升可读性

### 3. 修复导出功能
- 检查并修复最高分/最低分显示问题
- 确保各种类型的 report 导出正确
- Markdown 导出要包含详细的案例信息

### 4. Markdown 导出优化
- 每个 case 的评估结果都要显示
- 包含 Engineering Action 信息
- 包含各阶段评估维度详情

## 技术方案

### 前端组件优化
- ReportResultTable.tsx: 重构显示逻辑
- 突出 Engineering Action
- 简化嵌套结构

### 导出功能优化
- 检查 export 相关 API
- 修复分数统计逻辑
- 增强 Markdown 导出内容

## 任务列表

1. 分析当前 report 显示逻辑
2. 显示工程建议作为主要内容
3. 去掉 Sub-Results 嵌套显示
4. 修复导出功能中最高分最低分问题
5. Markdown 导出显示详细案例信息
6. 确保所有优化不影响现有功能
7. 测试验证
