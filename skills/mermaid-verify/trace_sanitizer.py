#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""逐步调用 sanitizer 的方法看哪一步应该修但没修。"""
import sys
sys.path.insert(0, r"D:\code-wiki\src")
from shared.validators.mermaid_sanitizer import MermaidSanitizer

s = MermaidSanitizer()

cases = {
    "类型A_no_space":  '    Case -->|"1"|"2""4""6""8""10"Assign["X"]',
    "类型A_with_space":'    Case -->|"1"|"2""4""6""8""10" Assign["X"]',
    "类型B_diamond":   '    A["A"] -->|"X?"|{?} -->|"YES"| B["B"]',
    "类型C_langle":    '    CountTmp -->|"0件"|<| NoData["X"]',
}

for name, line in cases.items():
    print(f"## {name}")
    print(f"  原始:     {line}")

    # 顺序调用 _sanitize_line 里挂的各步骤
    methods = [
        s._fix_concatenated_quoted_labels,
        s._fix_multiple_edge_labels,
        s._remove_br_from_edge_label,
        s._fix_dash_dash_arrow,
    ]
    for m in methods:
        new = m(line)
        if new != line:
            print(f"  [{m.__name__}] 改了:")
            print(f"    → {new}")
            line = new
        # else: 未改，不打印
    print(f"  最终:     {line}")
    print()
