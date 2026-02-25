# Proposal: add-case-tag-filter

## 概述

为 Case 表添加 tag 属性，用于区分不同版本的 case，并在页面中支持 tag 过滤功能。

## 需求

1. **Case Tag 管理**
   - 为 test_cases 表添加 tag 字段
   - tag 是用户自定义的字符串
   - 支持在创建/编辑 Case 时设置 tag

2. **Tag 过滤功能**
   - Case 列表页面支持按 tag 过滤
   - 显示所有已有的 tag 值供用户选择

3. **Plan 关联 Case 时的 Tag 过滤**
   - Plan 编辑表单中，选择 Case 时支持按 tag 过滤
   - 显示所有已有的 tag 值

## 技术方案

### 数据库变更
- 为 `test_cases` 表添加 `tag` 字段（VARCHAR，可空）

### 后端变更
- 更新 `schemas.py`：TestCase 模型添加 tag 字段
- 更新 `case_service.py`：添加获取所有 tag 的方法
- 更新 `case_router.py`：添加获取所有 tag 的 API

### 前端变更
- 更新 `api.ts`：添加获取 tag 列表的 API
- 更新 `CaseList.tsx`：添加 tag 过滤 UI
- 更新 `PlanEditForm.tsx`：添加 tag 过滤功能

## 任务列表

1. 数据库：为 test_cases 表添加 tag 字段
2. 后端 Schema：更新 TestCase 相关模型
3. 后端 Service：支持 tag 的 CRUD 和查询
4. 后端 API：添加 tag 相关接口
5. 前端 API：添加 tag 相关方法
6. 前端组件：CaseList 添加 tag 过滤
7. 前端组件：PlanEditForm 添加 tag 过滤
8. 测试验证
