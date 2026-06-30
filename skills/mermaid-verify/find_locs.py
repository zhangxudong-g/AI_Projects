#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Find line numbers of failing mermaid blocks in source MDs."""
import re
import json
from pathlib import Path

WIKI = Path(r"D:\code-wiki\projects\Aerr_1\wiki_cache")
SUMMARY = json.loads(Path(r"D:\code-wiki\docs\new\evidence\aerr1-mermaid-verify\summary.json").read_text(encoding="utf-8"))

# Each mermaid block: locate by ```mermaid open and ``` close
MD_OPEN  = re.compile(r"^```mermaid\s*$", re.MULTILINE)
MD_CLOSE = re.compile(r"^```\s*$", re.MULTILINE)

def find_block_lines(text: str, block_idx: int):
    """Return (start_line, end_line) of block_idx-th mermaid block (1-based)."""
    opens = [m.start() for m in MD_OPEN.finditer(text)]
    if block_idx - 1 >= len(opens):
        return None
    start_char = opens[block_idx - 1]
    # Find close after start_char
    close_m = MD_CLOSE.search(text, start_char + len("```mermaid\n"))
    if not close_m:
        return None
    end_char = close_m.end()
    # Convert char offset to 1-based line number
    start_line = text.count("\n", 0, start_char) + 1
    end_line   = text.count("\n", 0, end_char) + 1
    return (start_line, end_line)

out = []
for s in SUMMARY:
    if s["result"] != "FAIL":
        continue
    md_path = WIKI / (s["file"] + ".md")
    text = md_path.read_text(encoding="utf-8")
    for f in s["fails"]:
        loc = find_block_lines(text, f["block"])
        out.append({
            "file": s["file"],
            "block": f["block"],
            "line_range": loc,
            "error_excerpt": f["error"].splitlines()[1] if "\n" in f["error"] else f["error"],
        })

print(json.dumps(out, ensure_ascii=False, indent=2))
Path(r"D:\code-wiki\docs\new\evidence\aerr1-mermaid-verify\fail_locations.json").write_text(
    json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8"
)
