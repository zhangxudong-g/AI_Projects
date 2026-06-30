#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""逐步按 sanitizer 真实顺序跑，看哪一步破坏了什么。"""
import sys
sys.path.insert(0, r"D:\code-wiki\src")
from shared.validators.mermaid_sanitizer import MermaidSanitizer

s = MermaidSanitizer()

# 真实失败块（类型 C）
src_C = (
    'flowchart TD\n'
    '    Start["開始 初期化"] --> CheckTable["テーブル存在チェック"]\n'
    '    CheckTable --> CountTmp{"TMP件数取得"}\n'
    '    CountTmp -->|"0件"|<| NoData["終了 戻り値0"]\n'
    '    CountTmp -->|"1件以上"| HasData["データあり"]\n'
)

# 真实失败块（类型 A 无空格）
src_A = (
    'flowchart TD\n'
    '    Start["開始 funcShikKbnGet"] --> Case{"CASE i_NIX"}\n'
    '    Case -->|"1"|"2""4""6""8""10"Assign["NwSHIK ← X"]\n'
    '    Case -->|"その他"| Null["NwSHIK ← NULL"]\n'
)

# 真实失败块（类型 B 空 diamond）
src_B = (
    'flowchart TD\n'
    '    InitMwGenmen -->|"X?"|{?} -->|"YES"| SetMwGenmen["OK"]\n'
    '    InitMwGenmen -->|"NO"| Skip["NO"]\n'
)

def trace(name, src):
    print(f"========== {name} ==========")
    # 按 _sanitize_line 的真实顺序
    methods = [
        s._fix_braces_inside_square_brackets,
        s._fix_missing_closing_bracket,
        s._fix_edge_label_inside_unclosed_node,
        s._fix_empty_labels,
        s._remove_html_entities,
        s._fix_incomplete_arrow_edge,
        s._fix_incomplete_edges,
        s._fix_double_pipe_labels,
        s._fix_unclosed_edge_label_before_br,
        s._fix_concatenated_quoted_labels,
        s._remove_br_from_edge_label,
        s._fix_multiple_edge_labels,
        s._fix_edge_label_node_no_space,
        s._fix_bare_text_after_edge,
        s._fix_ampersand_label,
        s._fix_ampersand_no_quotes,
        s._fix_double_arrow,
        s._fix_equality_arrow,
        s._fix_dash_dash_arrow,
        s._fix_braces_on_edge,
        s._fix_curly_braces_with_quotes,
        s._fix_arrow_no_space_before_node,
        s._fix_orphan_edge_label,
    ]
    lines = src.split("\n")
    for i, line in enumerate(lines):
        if "-->" not in line and "{" not in line:
            continue
        if "|<|" not in line and "Assign" not in line and "{?}" not in line and "0件" not in line and "1" not in line and "X?" not in line:
            continue
        # 简化: 只盯关键行
        if not any(t in line for t in ['|<|', 'Assign', '{?}']):
            continue
        for m in methods:
            new = m(line)
            if new != line:
                print(f"  行{i+1} | [{m.__name__}]")
                print(f"    IN:  {line!r}")
                print(f"    OUT: {new!r}")
                line = new
        if "|<|" in line or 'Assign["' in line and '"Y"' in line or "{?}" in line:
            print(f"  行{i+1} | 最终未修: {line!r}")
        else:
            print(f"  行{i+1} | ✅ 最终: {line!r}")
    print()

trace("类型C", src_C)
trace("类型A", src_A)
trace("类型B", src_B)
