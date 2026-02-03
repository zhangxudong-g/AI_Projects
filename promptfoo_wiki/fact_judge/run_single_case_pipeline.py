import subprocess
import json
from pathlib import Path

from stage3_score import final_score
from extract import extract_llm_json

import re
from collections import defaultdict
from typing import Dict, List


def _uniq(seq: List[str]) -> List[str]:
    return sorted(set(seq))


def extract_anchors(*, source_code: str, language: str) -> Dict[str, List[str]]:
    """
    Extract engineering-level anchors from source code.
    Supports:
      - Python
      - Java
      - SQL / PL/SQL (tables, operations, procedures, packages, triggers)
    Returns dict of lists for each anchor type.
    """

    lang = language.lower()
    anchors = defaultdict(list)

    # =========================
    # Python
    # =========================
    if lang == "python":
        anchors["classes"] += re.findall(r"\bclass\s+([A-Z_a-z][\w]*)\b", source_code)
        anchors["functions"] += re.findall(r"\bdef\s+([a-zA-Z_]\w*)\s*\(", source_code)
        anchors["async_functions"] += re.findall(
            r"\basync\s+def\s+([a-zA-Z_]\w*)\s*\(", source_code
        )
        anchors["decorators"] += re.findall(r"@([a-zA-Z_][\w\.]*)", source_code)
        anchors["imports"] += re.findall(
            r"^\s*(?:from|import)\s+([a-zA-Z_][\w\.]*)", source_code, re.MULTILINE
        )

    # =========================
    # Java
    # =========================
    elif lang == "java":
        # classes / interfaces / enums
        anchors["classes"] += [
            c[1]
            for c in re.findall(r"\b(class|interface|enum)\s+([A-Z][\w]*)", source_code)
        ]
        # methods
        anchors["methods"] += [
            m[1]
            for m in re.findall(
                r"\b(public|protected)\s+[\w\<\>\[\]]+\s+([a-zA-Z_]\w*)\s*\(",
                source_code,
            )
        ]
        # annotations
        anchors["annotations"] += re.findall(r"@([A-Z][A-Za-z0-9_]*)", source_code)
        # imports
        anchors["imports"] += re.findall(r"\bimport\s+([\w\.]+);", source_code)

    # =========================
    # SQL / PL/SQL
    # =========================
    elif lang in {"sql", "plsql", "oracle"}:
        # Remove comments to avoid matching version numbers in comments
        # Remove single-line comments (-- ...)
        source_code_no_comments = re.sub(r'--.*$', '', source_code, flags=re.MULTILINE)
        # Remove multi-line comments (/* ... */)
        source_code_no_comments = re.sub(r'/\*.*?\*/', '', source_code_no_comments, flags=re.DOTALL)

        # Simple and effective pattern for database tables/views
        # Focus on typical database table naming patterns with known prefixes
        # Common prefixes in this system: JIBT (住基テーブル), GABT (ガバナンステーブル), etc.
        table_pattern = r'\b(from|join|into|update)\s+([A-Z][A-Z0-9_]+)(?=\s|,|\)|$|\.|\(|where\b|and\b|or\b|set\b|on\b)'
        matches = re.findall(table_pattern, source_code_no_comments, re.I)

        # Process matches and filter for likely database table names
        for match in matches:
            table_name = match[1].upper()

            # Filter for likely database table names based on naming conventions
            # Real tables typically have known prefixes and/or contain underscores
            if (re.match(r'^(JIBT|GABT|JIBW|GACT|KK[A-Z]|GAB_|JIB|GAB)[A-Z0-9_]+$', table_name)  # Known prefixes
                and '_' in table_name):  # Real tables typically have underscores
                anchors["tables"].append(table_name)

        # Also look for schema.table patterns
        schema_table_pattern = r'\b(from|join|into|update)\s+([A-Z][A-Z0-9_]*\.[A-Z][A-Z0-9_]{4,})\b'
        schema_matches = re.findall(schema_table_pattern, source_code_no_comments, re.I)
        anchors["tables"] += [match[1].upper() for match in schema_matches]

        # Operations
        anchors["operations"] += [
            op.lower()
            for op in re.findall(
                r"\b(select|insert|update|delete|merge|truncate)\b", source_code_no_comments, re.I
            )
        ]

        # Clauses
        anchors["clauses"] += [
            c.lower()
            for c in re.findall(
                r"\b(where|group\s+by|order\s+by|having|limit|with|connect\s+by|start\s+with)\b",
                source_code_no_comments,
                re.I,
            )
        ]

        # Stored Procedures / Functions
        # re.findall with groups returns tuples, so we need to extract the second group ([a-zA-Z0-9_]+)
        procedure_matches = re.findall(
            r"\bcreate\s+(or\s+replace\s+)?procedure\s+([a-zA-Z0-9_]+)",
            source_code_no_comments,
            re.I,
        )
        anchors["procedures"] += [match[1].upper() for match in procedure_matches if len(match) > 1]

        function_matches = re.findall(
            r"\bcreate\s+(or\s+replace\s+)?function\s+([a-zA-Z0-9_]+)",
            source_code_no_comments,
            re.I,
        )
        anchors["functions"] += [match[1].upper() for match in function_matches if len(match) > 1]

        # Packages
        package_matches = re.findall(
            r"\bcreate\s+(or\s+replace\s+)?package\s+([a-zA-Z0-9_]+)",
            source_code_no_comments,
            re.I,
        )
        anchors["packages"] += [match[1].upper() for match in package_matches if len(match) > 1]

        package_body_matches = re.findall(
            r"\bcreate\s+(or\s+replace\s+)?package\s+body\s+([a-zA-Z0-9_]+)",
            source_code_no_comments,
            re.I,
        )
        anchors["package_bodies"] += [match[1].upper() for match in package_body_matches if len(match) > 1]

        # Triggers
        trigger_matches = re.findall(
            r"\bcreate\s+(or\s+replace\s+)?trigger\s+([a-zA-Z0-9_]+)",
            source_code_no_comments,
            re.I,
        )
        anchors["triggers"] += [match[1].upper() for match in trigger_matches if len(match) > 1]

        # CTEs / WITH queries (engineering signal)
        anchors["with_queries"] += re.findall(
            r"\bwith\s+([a-zA-Z0-9_]+)\s+as\s*\(", source_code_no_comments, re.I
        )

    else:
        raise ValueError(f"Unsupported language: {language}")

    # =========================
    # normalize / deduplicate
    # =========================
    return {k: _uniq(v) for k, v in anchors.items()}


def generate_engineering_facts(*, anchors: dict, source_code: str) -> list:
    """
    使用 LLM 将 anchors 组合为工程级事实（engineering facts）
    """
    import ollama

    prompt = f"""
You are a senior software engineer.

Given the following extracted anchors from source code:

{json.dumps(anchors, indent=2)}

And the source code itself (for context only):

{source_code[:100000]}  # (truncated for brevity)

Task:
- Group anchors into ENGINEERING-LEVEL FACTS.
- Each fact should describe a responsibility, mechanism, or workflow.
- List which anchors support each fact.

Rules:
- Do NOT describe APIs.
- Do NOT invent functionality not implied by anchors.
- Focus on engineering responsibilities.

Output JSON ONLY:
[
  {{
    "id": "...",
    "description": "...",
    "anchors": ["..."]
  }}
]
"""
    base_url = "http://163.44.52.247:11434"

    def run_sync_ollama():
        client = ollama.Client(host=base_url)
        return client.generate(
            model="gpt-oss:120b",
            prompt=prompt,
            options={"temperature": 0},
        )

    response = run_sync_ollama()
    return json.loads(response["response"])


def prepare_engineering_facts(
    *,
    source_code: str,
    language: str,
    output_dir: Path,
) -> Path:
    anchors = extract_anchors(
        source_code=source_code,
        language=language,
    )
    

    facts = generate_engineering_facts(
        anchors=anchors,
        source_code=source_code,
    )

    facts_path = output_dir / "engineering_facts.json"
    anchors_path = output_dir / "anchors.json"
    facts_path.write_text(
        json.dumps(facts, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    anchors_path.write_text(
        json.dumps(anchors, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    return facts_path


def run(cmd: str, cwd: Path | None = None):
    """
    统一的 shell 执行封装
    - shell=True：兼容 Windows
    - cwd：解决 promptfoo 相对路径问题（核心）
    """
    print(f"[RUN] {cmd}")
    subprocess.run(
        cmd,
        shell=True,
        check=True,
        # cwd=str(cwd.resolve()) if cwd else None,  # 去掉绝对路径
    )


def run_single_case(
    *,
    case_id: str,
    vars_cfg: dict,
    output_dir: str | Path,
):
    """
    单 case 完整 pipeline：
    - Stage1: promptfoo fact extractor
    - Stage2: promptfoo soft judge
    - Stage3: Python final scoring
    """

    output_dir = Path(output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    # case 根目录 = yaml 所在目录
    # case_root = output_dir.parents[1]
    # print(f"[CWD ] {case_root}  {vars_cfg}")

    print(f"[CASE] {case_id}")
    # print(f"[CWD ] {case_root}")
    stage1_out = (output_dir / "stage1.json").resolve()
    stage1_result_out = (output_dir / "stage1_result.json").resolve()
    stage2_out = (output_dir / "stage2.json").resolve()
    final_out = (output_dir / "final_score.json").resolve()
    # 拼 --var 参数
    var_args = []
    for k, v in vars_cfg.items():
        # file:// + 绝对路径（最稳）
        # abs_path = (case_root / v).resolve()
        var_args.append(f"--var {k}=file://{v}")

    # 前置提取事实（工程wiki级别的）
    source_code_path = Path(vars_cfg["source_code"])
    # 根据文件扩展名自动确定语言
    if "language" in vars_cfg:
        language = vars_cfg["language"]
    else:
        ext = source_code_path.suffix.lower()
        if ext in ['.sql', '.plsql']:
            language = 'sql'
        elif ext in ['.py','txt']:
            language = 'python'
        elif ext in ['.java']:
            language = 'java'
        else:
            language = 'java'  # 默认值

    source_code = source_code_path.read_text(encoding="utf-8")

    engineering_facts_path = prepare_engineering_facts(
        source_code=source_code,
        language=language,
        output_dir=output_dir,
    )
    var_args.append(f"--var engineering_facts=file://{engineering_facts_path}")
    var_str = " ".join(var_args)

    # ======================
    # Stage 1
    # ======================
    run(
        f"promptfoo eval --no-cache "
        f"--config stage1_fact_extractor.yaml "
        # f"--grader ollama:gpt-oss:120b "
        f"{var_str} "
        f"--output {stage1_out}",
    )
    # 将 Stage 1 结果保存为单独的文件，供 Stage 2 使用
    stage1_data = extract_llm_json(stage1_out)

    stage1_result_out.write_text(
        json.dumps(stage1_data, indent=4, ensure_ascii=False),
        encoding="utf-8",
    )
    # ======================
    # Stage 2
    # ======================
    run(
        f"promptfoo eval --no-cache "
        f"--config stage2_soft_judge.yaml "
        # f"--grader ollama:gpt-oss:120b "
        f"--var facts=file://output/{case_id}/stage1_result.json "
        f"--output {stage2_out}",
    )

    # ======================
    # Stage 3
    # ======================
    stage2_data = extract_llm_json(stage2_out)

    final = final_score(stage1_data, stage2_data)

    # 保存最终结果
    final_out.write_text(
        json.dumps(final, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    print(f"[OK] Case {case_id} finished → {final['final_score']} ({final['result']})")

    return final
