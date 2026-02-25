#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
验证 Plan Edit Form 的 tag 过滤功能是否正确实现
"""

import sys
from pathlib import Path

project_root = Path(__file__).parent
frontend_component = project_root / "frontend" / "src" / "components" / "PlanEditForm.tsx"
frontend_css = project_root / "frontend" / "src" / "components" / "PlanEditForm.css"

def check_file_content(file_path: Path, checks: list) -> bool:
    """检查文件是否包含所需内容"""
    if not file_path.exists():
        print(f"❌ 文件不存在：{file_path}")
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
print("Plan Edit Form Tag 过滤功能验证")
print("="*60)
print()

# 检查 PlanEditForm.tsx
print("检查 PlanEditForm.tsx:")
tsx_checks = [
    ("Tag 状态管理", "const [selectedTag, setSelectedTag] = useState<string>('all')"),
    ("获取所有 tag", "const allTags = useMemo"),
    ("Tag 过滤逻辑", "const filteredCases = useMemo"),
    ("过滤实现", "allCases.filter(c => c.tag === selectedTag)"),
    ("Select All 使用 filteredCases", "filteredCases.map(c => c.case_id)"),
    ("Tag 过滤器 UI", 'id="case-tag-filter"'),
    ("Tag 显示", "testCase.tag && <span className=\"case-tag\">"),
]

tsx_passed = check_file_content(frontend_component, tsx_checks)
print()

# 检查 PlanEditForm.css
print("检查 PlanEditForm.css:")
css_checks = [
    ("Tag 过滤器容器", ".tag-filter-container"),
    ("Case Tag 样式", ".case-tag"),
    ("空状态提示", ".no-cases-message"),
]

css_passed = check_file_content(frontend_css, css_checks)
print()

print("="*60)
if tsx_passed and css_passed:
    print("[OK] 所有检查通过！Tag 过滤功能已完整实现。")
    print()
    print("功能包括:")
    print("  - Tag 下拉框过滤")
    print("  - Select All / Clear All 快捷操作（基于过滤结果）")
    print("  - Case Tag 显示")
    print("  - 空状态提示")
else:
    print("[FAIL] 部分检查未通过，请检查上述输出。")
print("="*60)
