import subprocess
import json
from pathlib import Path

from stage3_score import final_score
from extract import extract_llm_json


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

    var_str = " ".join(var_args)
    # ======================
    # Stage 1
    # ======================
    run(
        f"promptfoo eval --no-cache "
        f"--config stage1_fact_extractor.yaml "
        f"--grader ollama:gpt-oss:120b "
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
        f"--grader ollama:gpt-oss:120b "
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
