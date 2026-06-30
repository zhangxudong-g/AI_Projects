#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""把 sanitizer 跑在 3 个失败块上，看清洗后能不能过 mmdc。"""
import sys
from pathlib import Path

sys.path.insert(0, r"D:\code-wiki\src")

from shared.validators.mermaid_sanitizer import sanitize_mermaid_code  # noqa

cases = {
    "类型A_concat_no_space": (
        'flowchart TD\n'
        '    Start["開始 funcShikKbnGet"] --> Case{"CASE i_NIX"}\n'
        '    Case -->|"1"|"2""4""6""8""10"Assign["NwSHIK ← i_RKOJIN.SHIK_x"]\n'
        '    Case -->|"その他"| Null["NwSHIK ← NULL"]\n'
        '    Assign --> Return["戻り値 RETURN(NwSHIK)"]\n'
        '    Null --> Return\n'
    ),
    "类型A_concat_with_space": (
        'flowchart TD\n'
        '    Start["開始"] --> Case{"判定"}\n'
        '    Case -->|"1"|"2""4""6""8""10" Assign["Target"]\n'
        '    Case -->|"その他"| Null["Null"]\n'
    ),
    "类型B_empty_diamond": (
        'flowchart TD\n'
        '    A["A"] -->|"X?"|{?} -->|"YES"| B["B"]\n'
        '    A -->|"NO"| C["C"]\n'
    ),
    "类型C_dash_dash_arrow": (
        'flowchart TD\n'
        '    Start["開始 初期化"] --> CheckTable["テーブル存在チェック"]\n'
        '    CheckTable --> CountTmp{"TMP件数取得"}\n'
        '    CountTmp -->|"0件"|<| NoData["終了 戻り値0"]\n'
        '    CountTmp -->|"1件以上"| HasData["データあり"]\n'
    ),
}

for name, src in cases.items():
    print("="*70)
    print(f"## {name}")
    print("--- 原始 ---")
    print(src)
    sanitized = sanitize_mermaid_code(src)
    print("--- 清洗后 ---")
    print(sanitized)
    if sanitized == src:
        print(">>> ⚠️  sanitizer 没动这一行")
    else:
        print(">>> ✅  sanitizer 改了")
    print()
