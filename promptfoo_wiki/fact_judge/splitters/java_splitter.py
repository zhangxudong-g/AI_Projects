import re
from typing import List, Dict


def split_java(source: str) -> List[Dict]:
    """
    粗粒度但稳定：
    - class 级
    - method 级
    """
    blocks = []
    lines = source.splitlines()

    class_pattern = re.compile(r"\b(class|interface|enum)\s+(\w+)")
    method_pattern = re.compile(
        r"(public|protected|private|\s)+[\w<>\[\]]+\s+(\w+)\s*\([^)]*\)\s*\{"
    )

    current_block = []
    current_name = "file"
    start_line = 1

    for idx, line in enumerate(lines, start=1):
        if class_pattern.search(line) or method_pattern.search(line):
            if current_block:
                blocks.append({
                    "name": current_name,
                    "start_line": start_line,
                    "end_line": idx - 1,
                    "code": "\n".join(current_block)
                })
            current_block = [line]
            start_line = idx
            current_name = line.strip()
        else:
            current_block.append(line)

    if current_block:
        blocks.append({
            "name": current_name,
            "start_line": start_line,
            "end_line": len(lines),
            "code": "\n".join(current_block)
        })

    return blocks
