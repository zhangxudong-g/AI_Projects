#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""直接调 _sanitize_line（含字符级扫描）看完整效果。"""
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
    print(f"  原始:    {line!r}")
    fixed = s._sanitize_line(line)
    print(f"  _sanitize_line: {fixed!r}")
    if fixed == line:
        print(f"  >>> ⚠️  未改")
    else:
        print(f"  >>> ✅ 改了")
    print()
