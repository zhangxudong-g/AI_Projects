import subprocess
import json
from pathlib import Path

from stage0_pre_extractor import prepare_engineering_facts
from stage3_score import final_score
from utils import extract_llm_json, map_engineering_action


def run_cmd(cmd: str):
    """
    统一的 shell 执行封装
    - shell=True：兼容 Windows
    - 添加超时处理以避免无限等待
    """
    import signal
    import sys
    
    print(f"[RUN] {cmd}")
    
    # 在 Windows 上使用 timeout 参数（如果可用）或使用其他方式处理长时间运行
    import os
    try:
        # 使用更安全的 subprocess 调用方式，带超时和当前环境
        result = subprocess.run(
            cmd, 
            shell=True, 
            check=True,
            timeout=1800,  # 30分钟超时，给 Ollama 更多时间
            env=os.environ.copy()  # 确保使用当前进程的环境变量
        )
        return result
    except subprocess.TimeoutExpired:
        print(f"[ERROR] 命令执行超时: {cmd}")
        raise
    except KeyboardInterrupt:
        print(f"[ERROR] 命令被用户中断: {cmd}")
        raise
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] 命令执行失败: {cmd}, 返回码: {e.returncode}")
        raise


def _build_var_args(vars_dict: dict) -> list[str]:
    """构建变量参数列表"""
    return [f"--var {k}=file://{v}" for k, v in vars_dict.items()]


def _detect_language(vars_cfg: dict) -> str:
    """根据文件扩展名自动确定语言"""
    source_code_path = Path(vars_cfg["source_code"])
    
    if "language" in vars_cfg:
        return vars_cfg["language"]
    
    ext = source_code_path.suffix.lower()
    language_mapping = {
        ".sql": "sql",
        ".plsql": "sql",
        ".py": "python",
        ".txt": "python",
        ".java": "java"
    }
    
    return language_mapping.get(ext, "java")


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

    print(f"[CASE] {case_id}")
    
    # 定义输出文件路径
    stage1_out = (output_dir / "stage1.json").resolve()
    stage1_result_out = (output_dir / "stage1_result.json").resolve()
    stage1_5_out = (output_dir / "stage1_5.json").resolve()
    stage1_5_result_out = (output_dir / "stage1_5_result.json").resolve()
    stage2_out = (output_dir / "stage2.json").resolve()
    final_out = (output_dir / "final_score.json").resolve()
    
    # 构建基础变量参数
    var_args = _build_var_args(vars_cfg)
    
    print(f"[INFO] source_code_path: {vars_cfg["source_code"]}")
    # ======================
    # Stage 0 前置提取事实（工程wiki级别的）
    # ======================
    source_code_path = Path(vars_cfg["source_code"])
    language = _detect_language(vars_cfg)
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
    run_cmd(
        f"promptfoo eval --no-cache "
        f"--config stage1_fact_extractor.yaml "
        f"{' '.join(var_args)} "
        f"--output {stage1_out}"
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
    var_args_1_5 = _build_var_args(vars_cfg)
    var_args_1_5.append(f"--var artifact_type={artifact_type}")

    run_cmd(
        f"promptfoo eval --no-cache "
        f"--config stage1_5_explanation_alignment.yaml "
        f"{' '.join(var_args_1_5)} "
        f"--output {stage1_5_out}"
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
    var_args_for_stage2 = _build_var_args(vars_cfg)
    var_args_for_stage2.append(f"--var artifact_type={artifact_type}")
    # 使用实际的输出目录路径，而不是 base_output/case_id
    var_args_for_stage2.append(
        f"--var structural_coverage_results=file://{output_dir}/stage1_result.json"
    )
    var_args_for_stage2.append(
        f"--var explanation_alignment_results=file://{output_dir}/stage1_5_result.json"
    )

    cfg = "stage2_explanatory_judge.yaml"  # Engineering Judge v3
    run_cmd(
        f"promptfoo eval --no-cache "
        f"--config {cfg} "
        f"{' '.join(var_args_for_stage2)} "
        f"--output {stage2_out}"
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
