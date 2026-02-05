import subprocess
import json
from pathlib import Path

from stage0_pre_extractor import prepare_engineering_facts
from stage3_score import final_score
from extract import extract_llm_json


# 统一的 shell 执行封装
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
    base_output: str | Path = "output",
):
    """
    单 case 完整 pipeline：
    - Stage0: engineering facts pre-extractor
    - Stage1: promptfoo fact extractor
    - Stage2: promptfoo engineering explanation judge
    - Stage3: Python risk-aware scoring

    Args:
        case_id: 测试用例ID
        vars_cfg: 变量配置字典
        output_dir: 输出目录
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
    # ======================
    # Stage 0 前置提取事实（工程wiki级别的）
    # ======================
    source_code_path = Path(vars_cfg["source_code"])
    # 根据文件扩展名自动确定语言
    if "language" in vars_cfg:
        language = vars_cfg["language"]
    else:
        ext = source_code_path.suffix.lower()
        if ext in [".sql", ".plsql"]:
            language = "sql"
        elif ext in [".py", "txt"]:
            language = "python"
        elif ext in [".java"]:
            language = "java"
        else:
            language = "java"  # 默认值

    source_code = source_code_path.read_text(encoding="utf-8")

    engineering_facts = prepare_engineering_facts(
        source_code=source_code,
        language=language,
        output_dir=output_dir,
    )
    engineering_facts_path = engineering_facts["anchors_path"]
    artifact_type = engineering_facts["artifact_type"]
    print(f"[INFO] Artifact type detected: {artifact_type}")
    var_args.append(f"--var engineering_anchors=file://{engineering_facts_path}")
    var_str = " ".join(var_args)

    # ======================
    # Stage 1
    # ======================
    run(
        f"promptfoo eval --no-cache "
        f"--config stage1_fact_extractor.yaml "
        f"{" ".join(var_args)} "
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
    # 为 Stage 2 创建新的参数列表，确保所有必要变量都传递
    var_args_for_stage2 = []
    for k, v in vars_cfg.items():
        var_args_for_stage2.append(f"--var {k}=file://{v}")
    var_args_for_stage2.append(f"--var artifact_type={artifact_type}")
    var_args_for_stage2.append(f"--var facts=file://{base_output}/{case_id}/stage1_result.json")

    cfg = "stage2_explanatory_judge.yaml"
    # cfg = "stage2_soft_judge.yaml" # 严格打分
    run(
        f"promptfoo eval --no-cache "
        f"--config {cfg} "
        f"{" ".join(var_args_for_stage2)} "
        f"--output {stage2_out}",
    )

    # ======================
    # Stage 3
    # ======================
    stage2_data = extract_llm_json(stage2_out)

    final = final_score(stage2_data)

    # 保存最终结果
    final_out.write_text(
        json.dumps(final, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    print(f"[OK] Case {case_id} finished → {final['final_score']} ({final['result']})")

    return final
