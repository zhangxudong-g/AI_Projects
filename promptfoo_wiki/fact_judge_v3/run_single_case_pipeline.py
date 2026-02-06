import subprocess
import json
from pathlib import Path

from stage0_pre_extractor import prepare_engineering_facts
from stage3_score import final_score
from utils import extract_llm_json

ENGINEERING_ACTION_MAP = [
    {
        "min": 90,
        "max": 100,
        "label": "PRIMARY_REFERENCE",
        "description": "可作为主要参考文档",
        "action": "可直接用于理解、调试和修改代码",
    },
    {
        "min": 70,
        "max": 89,
        "label": "SAFE_WITH_CAUTION",
        "description": "可用于理解与修改，需关注风险点",
        "action": "修改前需重点核对标注的风险或 TODO",
    },
    {
        "min": 50,
        "max": 69,
        "label": "STRUCTURE_ONLY",
        "description": "仅供理解结构，修改需对照源码",
        "action": "不可仅依赖文档进行修改",
    },
    {
        "min": 40,
        "max": 49,
        "label": "READ_ONLY_WARNING",
        "description": "不建议用于修改",
        "action": "仅用于初步了解，不可指导工程决策",
    },
    {
        "min": 0,
        "max": 39,
        "label": "UNTRUSTWORTHY",
        "description": "不可信",
        "action": "不应作为任何工程依据",
    },
]


def map_engineering_action(score: int) -> dict:
    for rule in ENGINEERING_ACTION_MAP:
        if rule["min"] <= score <= rule["max"]:
            return rule
    # fallback（理论上不会触发）
    return ENGINEERING_ACTION_MAP[-1]


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
    - Stage1: promptfoo structural coverage judge
    - Stage1.5: promptfoo explanation alignment judge
    - Stage2: promptfoo engineering judge v3
    - Stage3: Python scoring v3

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
    stage1_5_out = (output_dir / "stage1_5.json").resolve()
    stage1_5_result_out = (output_dir / "stage1_5_result.json").resolve()
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

    # ======================
    # Stage 1: Structural Coverage Judge
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
    # Stage 1.5: Explanation Alignment Judge
    # ======================
    var_args_1_5 = []
    for k, v in vars_cfg.items():
        var_args_1_5.append(f"--var {k}=file://{v}")
    var_args_1_5.append(f"--var artifact_type={artifact_type}")

    run(
        f"promptfoo eval --no-cache "
        f"--config stage1_5_explanation_alignment.yaml "
        f"{" ".join(var_args_1_5)} "
        f"--output {stage1_5_out}",
    )
    # 将 Stage 1.5 结果保存为单独的文件，供 Stage 2 使用
    stage1_5_data = extract_llm_json(stage1_5_out)

    stage1_5_result_out.write_text(
        json.dumps(stage1_5_data, indent=4, ensure_ascii=False),
        encoding="utf-8",
    )

    # ======================
    # Stage 2: Engineering Judge v3
    # ======================
    # 为 Stage 2 创建新的参数列表，确保所有必要变量都传递
    var_args_for_stage2 = []
    for k, v in vars_cfg.items():
        var_args_for_stage2.append(f"--var {k}=file://{v}")
    var_args_for_stage2.append(f"--var artifact_type={artifact_type}")
    var_args_for_stage2.append(
        f"--var structural_coverage_results=file://{base_output}/{case_id}/stage1_result.json"
    )
    var_args_for_stage2.append(
        f"--var explanation_alignment_results=file://{base_output}/{case_id}/stage1_5_result.json"
    )

    # cfg = "stage2_explanatory_judge.yaml" # Engineering Judge v3
    cfg = "stage2_explanatory_judge_v3.yaml"  # Engineering Judge v3
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
    # 映射 engineering action
    action = map_engineering_action(final["final_score"])

    final["engineering_action"] = {
        "level": action["label"],
        "description": action["description"],
        "recommended_action": action["action"],
    }
    # 保存最终结果
    final_out.write_text(
        json.dumps(final, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    print(f"[OK] Case {case_id} finished → {final['final_score']} ({final['result']})")

    return final
