import re
from typing import List, Dict


def split_sql(source: str) -> List[Dict]:
    """
    按 statement 切分（;）
    CTE 会自然落在同一块
    """
    blocks = []
    statements = re.split(r";\s*(?=SELECT|INSERT|UPDATE|DELETE|WITH)", source, flags=re.I)

    line_cursor = 1
    for idx, stmt in enumerate(statements):
        lines = stmt.strip().splitlines()
        if not lines:
            continue

        blocks.append({
            "name": f"statement_{idx+1}",
            "start_line": line_cursor,
            "end_line": line_cursor + len(lines) - 1,
            "code": stmt.strip()
        })

        line_cursor += len(lines)

    return blocks
