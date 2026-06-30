#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Parse mermaid-verify logs into a structured report."""
import re
import sys
import json
from pathlib import Path

LOG_DIR = Path(r"D:\code-wiki\docs\new\evidence\aerr1-mermaid-verify")

# Block result line: "第 N 个图表验证通过/失败" (with full-width 第)
BLOCK_PASS = re.compile(r"第\s*(\d+)\s*个图表验证通过")
BLOCK_FAIL = re.compile(r"第\s*(\d+)\s*个图表验证失败")
ERR_HDR    = re.compile(r"Error:\s*Parse error on line\s*(\d+):")
ERR_TAIL   = re.compile(r"Parser\.parseError")
FOUND_HDR  = re.compile(r"找到\s*(\d+)\s*个\s*Mermaid\s*图表")
END_OK     = re.compile(r"所有 Mermaid 图表语法均正确")
END_FAIL   = re.compile(r"存在语法错误")

def read_text_auto(p: Path) -> str:
    raw = p.read_bytes()
    if raw[:2] == b"\xff\xfe":
        return raw.decode("utf-16-le", errors="replace")
    if raw[:3] == b"\xef\xbb\xbf":
        return raw.decode("utf-8-sig", errors="replace")
    return raw.decode("utf-8", errors="replace")

def parse_one(log: Path):
    raw = read_text_auto(log)
    lines = raw.splitlines()

    total = None
    passes = []  # block indices that passed
    fails  = []  # list of {block_index, error_text}

    current_fail_idx = None
    current_err = []
    in_error = False

    for line in lines:
        m = FOUND_HDR.search(line)
        if m:
            total = int(m.group(1))
            continue

        m = BLOCK_PASS.search(line)
        if m:
            passes.append(int(m.group(1)))
            continue

        m = BLOCK_FAIL.search(line)
        if m:
            current_fail_idx = int(m.group(1))
            current_err = []
            in_error = True
            continue

        if in_error:
            if ERR_TAIL.search(line):
                # End of error block
                fails.append({
                    "block": current_fail_idx,
                    "error": "\n".join(current_err).strip(),
                })
                in_error = False
                current_fail_idx = None
                current_err = []
            else:
                current_err.append(line)
            continue

    # Derive total if not seen
    if total is None and (passes or fails):
        seen = set(passes) | {f["block"] for f in fails}
        total = max(seen) if seen else 0

    # Verify: passes + fails = total (fail indices are distinct from pass indices)
    fail_set = {f["block"] for f in fails}
    # The script's stdout marks each block once, so passes and fails should be disjoint
    # but a fail overwrites the pass for that block — should be no overlap
    overlap = set(passes) & fail_set
    if overlap:
        print(f"WARN: {log.name} has overlap {overlap}", file=sys.stderr)

    return {
        "file": log.name.replace(".log", ""),
        "total": total,
        "passed": len(passes),
        "failed": len(fails),
        "fails": fails,
        "result": "PASS" if not fails else "FAIL",
    }

def main():
    logs = sorted(LOG_DIR.glob("*.log"))
    summary = []
    for log in logs:
        summary.append(parse_one(log))

    total_charts = sum(s["total"] or 0 for s in summary)
    total_pass   = sum(s["passed"] for s in summary)
    total_fail   = sum(s["failed"] for s in summary)
    files_pass   = sum(1 for s in summary if s["result"] == "PASS")
    files_fail   = sum(1 for s in summary if s["result"] == "FAIL")

    print(f"Files: {len(summary)} (pass={files_pass}, fail={files_fail})")
    print(f"Charts: total={total_charts}, pass={total_pass}, fail={total_fail}")
    print()
    for s in summary:
        print(f"[{s['result']}] {s['file']}  total={s['total']}  pass={s['passed']}  fail={s['failed']}")
        for f in s["fails"]:
            print(f"    -> 块 {f['block']}:")
            for ln in f["error"].splitlines():
                if ln.strip():
                    print(f"       {ln}")
        print()

    # JSON dump for the report
    out_json = LOG_DIR / "summary.json"
    out_json.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"JSON: {out_json}")

if __name__ == "__main__":
    main()
