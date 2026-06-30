#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Extract content of failing mermaid blocks and categorize."""
import re
import json
from pathlib import Path

WIKI = Path(r"D:\code-wiki\projects\Aerr_1\wiki_cache")
LOCS = json.loads(Path(r"D:\code-wiki\docs\new\evidence\aerr1-mermaid-verify\fail_locations.json").read_text(encoding="utf-8"))

def extract_block(path: Path, start: int, end: int) -> str:
    lines = path.read_text(encoding="utf-8").splitlines()
    return "\n".join(lines[start-1:end])

def categorize(error: str, content: str) -> str:
    e = error.lower()
    if "got 'str'" in e or "got 'STR'" in error:
        return "未闭合字符串 / 边标签拼接 (multiple \"X\" with no separator)"
    if "got 'DIAMOND_START'" in e:
        return "节点标签含 ? 或 { (diamond 节点解析失败)"
    if "got 'TAGSTART'" in e:
        return "边标签内出现裸 < 字符 (Mermaid 解析为 HTML tag 起始)"
    return "其它"

print("="*70)
for item in LOCS:
    p = WIKI / (item["file"] + ".md")
    content = extract_block(p, *item["line_range"])
    cat = categorize(item["error_excerpt"], content)
    print(f"\n[{item['file']}.md 块 {item['block']}]  行 {item['line_range'][0]}-{item['line_range'][1]}")
    print(f"类别: {cat}")
    print("--- 内容 ---")
    for ln in content.splitlines():
        print(f"  {ln}")
    print("--- 错误 ---")
    for ln in item["error_excerpt"].splitlines():
        print(f"  {ln}")
    print("="*70)
