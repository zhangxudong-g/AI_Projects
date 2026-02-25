# Plan Edit Form - Tag 过滤功能测试指南

## 功能说明

在 Plan 编辑表单中，用户可以根据 tag 过滤 Case，并使用快捷操作选中或取消选中。

## 功能特性

### 1. Tag 过滤下拉框
- **位置**: Plan 编辑表单的 "Select Test Cases for this Plan" 区域
- **功能**: 
  - 显示所有已有的 tag 值（从当前加载的 case 中提取）
  - 默认选项："全部"（显示所有 case）
  - 选择特定 tag 后，只显示该 tag 的 case

### 2. Select All / Clear All 快捷按钮
- **Select All**: 选中当前过滤条件下的所有 case
- **Clear All**: 清空所有选中的 case
- **智能过滤**: 只选中当前 tag 过滤下的 case，不是全部 case

### 3. Case Tag 显示
- 每个 case 显示格式：`case_name (case_id) - Tag: tag_value`
- Tag 值为空时显示：`case_name (case_id)`

### 4. 空状态提示
- 当过滤后没有 case 时显示：`No cases found with tag "xxx"`

## 测试步骤

### 准备工作
1. 确保后端服务运行：`http://localhost:8000`
2. 确保前端服务运行：`http://localhost:3000`
3. 确保数据库中有带 tag 的 case 数据

### 测试 1: 基本过滤功能
1. 访问 `http://localhost:3000/plans`
2. 点击任意 Plan 的 "Edit" 按钮
3. 找到 "Select Test Cases for this Plan" 区域
4. 在 "Filter by Tag" 下拉框中选择 "default"
5. **预期**: 只显示 tag 为 "default" 的 case

### 测试 2: Select All 功能
1. 在过滤到 "default" tag 后
2. 点击 "Select All" 按钮
3. **预期**: 所有 tag 为 "default" 的 case 被选中
4. 切换到 "全部" 选项
5. **预期**: 只有 tag 为 "default" 的 case 是选中状态

### 测试 3: Clear All 功能
1. 选中一些 case 后
2. 点击 "Clear All" 按钮
3. **预期**: 所有选中的 case 都被取消选中

### 测试 4: 动态 Tag 列表
1. 如果数据库中有多个 tag 值（如 "default", "v1.0", "v2.0"）
2. 打开 Plan 编辑表单
3. **预期**: 下拉框中显示所有唯一的 tag 值（已排序）

## API 验证

### 获取所有 tag
```bash
curl http://localhost:8000/cases/tags
# 预期：["default"]
```

### 根据 tag 获取 case
```bash
curl http://localhost:8000/cases/tag/default
# 预期：返回所有 tag 为 "default" 的 case 列表
```

## 常见问题

### Q: Tag 下拉框为空？
A: 确保数据库中有带 tag 值的 case。可以使用以下命令检查：
```bash
curl http://localhost:8000/cases/ | python -c "import sys,json; data=json.load(sys.stdin); tags=set(c['tag'] for c in data if c.get('tag')); print('Tags:', tags)"
```

### Q: Select All 选中了所有 case 而不是过滤后的？
A: 检查 `handleSelectAllCases` 函数是否使用了 `filteredCases` 而不是 `allCases`。

### Q: 过滤后 UI 没有更新？
A: 确保 `filteredCases` 使用了 `useMemo` 并且依赖项正确：`[allCases, selectedTag]`

## 代码位置

- **组件**: `frontend/src/components/PlanEditForm.tsx`
- **样式**: `frontend/src/components/PlanEditForm.css`
- **API**: `frontend/src/api/index.ts` (caseApi.getAllTags, caseApi.getCasesByTag)

## 关键代码片段

### Tag 过滤逻辑
```typescript
const filteredCases = useMemo(() => {
  if (selectedTag === 'all') {
    return allCases;
  }
  return allCases.filter(c => c.tag === selectedTag);
}, [allCases, selectedTag]);
```

### Select All 逻辑
```typescript
const handleSelectAllCases = (selectAll: boolean) => {
  if (selectAll) {
    setSelectedCaseIds(filteredCases.map(c => c.case_id));
  } else {
    setSelectedCaseIds([]);
  }
};
```

### 获取所有 tag
```typescript
const allTags = useMemo(() => {
  const tags = new Set<string>();
  allCases.forEach(c => {
    if (c.tag) {
      tags.add(c.tag);
    }
  });
  return Array.from(tags).sort();
}, [allCases]);
```
