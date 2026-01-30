import subprocess
import json
from pathlib import Path


def run(cmd: str):
    print(f"[RUN] {cmd}")
    subprocess.run(cmd, shell=True, check=True)


# 确保输出目录存在
Path("output").mkdir(exist_ok=True)


# ======================
# Stage 1: Fact Extractor
# ======================
run("promptfoo eval --no-cache --config stage1_fact_extractor.yaml " "--output output/stage1.json")


# ======================
# Stage 2: Soft Judge
# ======================
run("promptfoo eval --no-cache --config stage2_soft_judge.yaml " "--output output/stage2.json")


# ======================
# Stage 3: Final Scoring
# ======================
from stage3_score import final_score
from extract import extract_llm_json

stage1_data = extract_llm_json("output/stage1.json")
stage2_data = extract_llm_json("output/stage2.json")
final = final_score(
    stage1_data,
    stage2_data,
)

Path("output/final_score.json").write_text(
    json.dumps(final, indent=2, ensure_ascii=False),
    encoding="utf-8",
)

print("[OK] Pipeline finished")
