import subprocess
import json
import tempfile
from pathlib import Path


def run_stage1_chunk(source_code: str, wiki_md: str) -> dict:
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        output_path = f.name

    cmd = [
        "promptfoo",
        "eval",
        "--config",
        "prompts/stage1_fact_extractor.yaml",
        "--output",
        output_path,
    ]

    env = {
        "SOURCE_CODE": source_code,
        "WIKI_MD": wiki_md,
    }

    subprocess.run(cmd, check=True, env={**env, **dict(**env)})

    raw = json.loads(Path(output_path).read_text(encoding="utf-8"))

    # ⚠️ 只取第一个 test 的输出（promptfoo 固定结构）
    return raw["results"]["results"][0]["response"]["output"]
