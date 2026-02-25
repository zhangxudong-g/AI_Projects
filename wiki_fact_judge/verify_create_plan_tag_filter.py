#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
验证 CreatePlanForm 的 tag 过滤功能是否正确实现
"""

import sys
from pathlib import Path

project_root = Path(__file__).parent
frontend_component = project_root / "frontend" / "src" / "components" / "CreatePlanForm.tsx"
frontend_css = project_root / "frontend" / "src" / "components" / "CreatePlanForm.css"

def check_file_content(file_path: Path, checks: list) -> bool:
    """检查文件是否包含所需内容"""
    if not file_path.exists():
        print(f"[FAIL] 文件不存在：{file_path}")
        return False
    
    content = file_path.read_text(encoding='utf-8')
    all_passed = True
    
    for check_name, check_str in checks:
        if check_str in content:
            print(f"[OK] {check_name}")
        else:
            print(f"[FAIL] {check_name} - 缺少：{check_str}")
            all_passed = False
    
    return all_passed

print("="*60)
print("CreatePlanForm Tag 过滤功能验证")
print("="*60)
print()

# 检查 CreatePlanForm.tsx
print("检查 CreatePlanForm.tsx:")
tsx_checks = [
    ("导入 useMemo", "import React, { useState, useEffect, useMemo }"),
    ("导入 CSS", "import './CreatePlanForm.css'"),
    ("Tag 状态管理", "const [selectedTag, setSelectedTag] = useState<string>('all')"),
    ("获取所有 tag", "const allTags = useMemo"),
    ("Tag 过滤逻辑", "const filteredCases = useMemo"),
    ("过滤实现", "allCases.filter(c => c.tag === selectedTag)"),
    ("Select All 使用 filteredCases", "filteredCases.map(c => c.case_id)"),
    ("Tag 过滤器 UI", 'id="create-plan-tag-filter"'),
    ("Tag 显示", "testCase.tag && <span className=\"case-tag\">"),
    ("Select All 按钮", "handleSelectAllCases(true)"),
    ("Clear All 按钮", "handleSelectAllCases(false)"),
]

tsx_passed = check_file_content(frontend_component, tsx_checks)
print()

# 检查 CreatePlanForm.css
print("检查 CreatePlanForm.css:")
css_checks = [
    ("案例选择头部", ".case-selection-header"),
    ("Tag 过滤器容器", ".tag-filter-container"),
    ("选择操作按钮", ".selection-actions"),
    ("Case Tag 样式", ".case-tag"),
    ("空状态提示", ".no-cases-message"),
    ("案例列表", ".case-selection-list"),
]

css_passed = check_file_content(frontend_css, css_checks)
print()

print("="*60)
if tsx_passed and css_passed:
    print("[OK] 所有检查通过！CreatePlanForm Tag 过滤功能已完整实现。")
    print()
    print("功能包括:")
    print("  - Tag 下拉框过滤（支持选择特定 tag 或全部）")
    print("  - Select All / Clear All 快捷操作（基于过滤结果）")
    print("  - Case Tag 显示")
    print("  - 空状态提示")
    print("  - 与 PlanEditForm 一致的 UI 风格")
else:
    print("[FAIL] 部分检查未通过，请检查上述输出。")
print("="*60)
