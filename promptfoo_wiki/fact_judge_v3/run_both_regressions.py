"""
独立的脚本，用于同时运行 positive 和 adversarial 回归测试
此脚本不修改任何业务代码，仅作为测试运行器
"""
import json
from pathlib import Path
from datetime import datetime
import subprocess
import os

POSITIVE_DATA_DIR = Path("stage2_positive_regression_full")
ADVERSARIAL_DATA_DIR = Path("stage2_adversarial_regression_full")


def load_case_spec(case_dir: Path):
    """
    支持两种格式：
    - case.yaml（推荐）
    - expected.json（兼容老格式）
    """
    yaml_path = case_dir / "case.yaml"
    json_path = case_dir / "expected.json"

    if yaml_path.exists():
        import yaml

        with open(yaml_path, "r", encoding="utf-8") as f:
            return yaml.safe_load(f)
    elif json_path.exists():
        with open(json_path, "r", encoding="utf-8") as f:
            return json.load(f)
    else:
        raise FileNotFoundError(f"No case.yaml or expected.json in {case_dir}")


def run_single_case_standalone(case_id: str, vars_cfg: dict, output_dir: str | Path):
    """
    独立运行单个测试案例的函数，模拟 run_single_case_pipeline 的功能
    但不修改原始业务代码
    """
    from stage0_pre_extractor import prepare_engineering_facts
    from stage3_score import final_score
    from utils import extract_llm_json

    output_dir = Path(output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"[CASE] {case_id}")
    
    stage1_out = (output_dir / "stage1.json").resolve()
    stage1_result_out = (output_dir / "stage1_result.json").resolve()
    stage1_5_out = (output_dir / "stage1_5.json").resolve()
    stage1_5_result_out = (output_dir / "stage1_5_result.json").resolve()
    stage2_out = (output_dir / "stage2.json").resolve()
    final_out = (output_dir / "final_score.json").resolve()
    
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

    # ======================
    # Stage 1: Structural Coverage Judge
    # ======================
    # 为 Stage 1 构建正确的命令行参数
    var_args = []
    for k, v in vars_cfg.items():
        if k in ['source_code', 'wiki_md']:
            # 文件路径使用 file:// 前缀
            var_args.append(f"--var {k}=file://{v}")
        elif k == 'language':
            # 语言参数特殊处理，不使用 file:// 前缀
            var_args.append(f"--var {k}={v}")
        else:
            # 其他参数直接传递
            var_args.append(f"--var {k}={v}")
    
    # 添加 engineering_anchors
    var_args.append(f"--var engineering_anchors=file://{engineering_facts_path}")

    # 运行 Stage 1
    cmd1 = f"promptfoo eval --no-cache --config stage1_fact_extractor.yaml {' '.join(var_args)} --output {stage1_out}"
    print(f"[RUN] {cmd1}")
    result1 = subprocess.run(cmd1, shell=True, capture_output=True, text=True, encoding='utf-8')
    if result1.returncode != 0:
        print(f"[ERROR] Stage 1 failed: {result1.stderr}")
        raise Exception(f"Stage 1 failed: {result1.stderr}")

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
        if k in ['source_code', 'wiki_md']:
            var_args_1_5.append(f"--var {k}=file://{v}")
        elif k == 'language':
            # 语言参数特殊处理，不使用 file:// 前缀
            var_args_1_5.append(f"--var {k}={v}")
        else:
            var_args_1_5.append(f"--var {k}={v}")
    var_args_1_5.append(f"--var artifact_type={artifact_type}")

    cmd1_5 = f"promptfoo eval --no-cache --config stage1_5_explanation_alignment.yaml {' '.join(var_args_1_5)} --output {stage1_5_out}"
    print(f"[RUN] {cmd1_5}")
    result1_5 = subprocess.run(cmd1_5, shell=True, capture_output=True, text=True, encoding='utf-8')
    if result1_5.returncode != 0:
        print(f"[ERROR] Stage 1.5 failed: {result1_5.stderr}")
        raise Exception(f"Stage 1.5 failed: {result1_5.stderr}")

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
        if k in ['source_code', 'wiki_md']:
            var_args_for_stage2.append(f"--var {k}=file://{v}")
        elif k == 'language':
            # 语言参数特殊处理，不使用 file:// 前缀
            var_args_for_stage2.append(f"--var {k}={v}")
        else:
            var_args_for_stage2.append(f"--var {k}={v}")
    var_args_for_stage2.append(f"--var artifact_type={artifact_type}")
    var_args_for_stage2.append(f"--var structural_coverage_results=file://./{output_dir}/stage1_result.json")
    var_args_for_stage2.append(f"--var explanation_alignment_results=file://./{output_dir}/stage1_5_result.json")

    cfg = "stage2_explanatory_judge_v3.yaml"  # Engineering Judge v3
    cmd2 = f"promptfoo eval --no-cache --config {cfg} {' '.join(var_args_for_stage2)} --output {stage2_out}"
    print(f"[RUN] {cmd2}")
    result2 = subprocess.run(cmd2, shell=True, capture_output=True, text=True, encoding='utf-8')
    if result2.returncode != 0:
        print(f"[ERROR] Stage 2 failed: {result2.stderr}")
        raise Exception(f"Stage 2 failed: {result2.stderr}")

    # ======================
    # Stage 3
    # ======================
    stage2_data = extract_llm_json(stage2_out)

    final = final_score(stage2_data)
    
    # 映射 engineering action
    from run_single_case_pipeline import map_engineering_action
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


def run_case(case_dir: Path, test_type: str):
    spec = load_case_spec(case_dir)

    files = spec.get("files", {})
    
    # 查找可用的源代码文件
    source_filename = files.get("source", "source.java")
    source_path = case_dir / source_filename
    
    # 如果指定的文件不存在，尝试常见的替代文件名
    if not source_path.exists():
        possible_names = ["source.java", "source_code.java", "source_code.sql", "source.sql", "source.py", "source_code.py"]
        for name in possible_names:
            alt_path = case_dir / name
            if alt_path.exists():
                source_filename = name
                source_path = alt_path
                break
    
    # 查找可用的wiki文件
    wiki_filename = files.get("wiki", "wiki.md")
    wiki_path = case_dir / wiki_filename
    
    # 如果指定的文件不存在，尝试常见替代文件名
    if not wiki_path.exists():
        possible_names = ["wiki.md", "wiki.txt", "documentation.md", "doc.md"]
        for name in possible_names:
            alt_path = case_dir / name
            if alt_path.exists():
                wiki_filename = name
                wiki_path = alt_path
                break

    vars_cfg = {
        "source_code": str(source_path),
        "wiki_md": str(wiki_path),
    }

    # 添加语言检测
    if source_path.exists():
        ext = source_path.suffix.lower()
        if ext in ['.sql', '.plsql']:
            vars_cfg["language"] = "sql"
        elif ext in ['.py', '.txt']:
            vars_cfg["language"] = "python"
        elif ext in ['.java', '.js', '.ts', '.jsx', '.tsx', '.c', '.cpp', '.cs', '.go', '.rs', '.rb', '.php']:
            vars_cfg["language"] = ext[1:]  # 去掉点号
        else:
            vars_cfg["language"] = "java"  # 默认值

    result = run_single_case_standalone(
        case_id=f"{test_type}_{case_dir.name}",
        vars_cfg=vars_cfg,
        output_dir=Path(f"output/{test_type}_regression") / case_dir.name,
    )

    details = result["details"]
    case_result = {
        "case_id": f"{test_type}_{case_dir.name}",
        "original_case_id": case_dir.name,
        "test_type": test_type,
        "passed": True,
        "final_score": result["final_score"],
        "result": result["result"],
        "details": details,
        "errors": []
    }

    # ===== MUST =====
    for key, allowed in spec.get("must", {}).items():
        if key in details and details[key] not in allowed:
            error_msg = f"{case_dir.name}: {key}={details[key]} not in {allowed}"
            case_result["errors"].append(error_msg)
            case_result["passed"] = False

    # ===== MUST NOT =====
    for key, forbidden in spec.get("must_not", {}).items():
        if key in details and details[key] in forbidden:
            error_msg = f"{case_dir.name}: {key}={details[key]} should not be in {forbidden}"
            case_result["errors"].append(error_msg)
            case_result["passed"] = False

    # ===== SCORE RANGE =====
    if "score_range" in spec:
        lo, hi = spec["score_range"]
        if not (lo <= result["final_score"] <= hi):
            error_msg = f"{case_dir.name}: score {result['final_score']} not in [{lo}, {hi}]"
            case_result["errors"].append(error_msg)
            case_result["passed"] = False

    return case_result


def run_regression_suite(data_dir: Path, test_type: str):
    results = []

    for case_dir in data_dir.iterdir():
        if not case_dir.is_dir():
            continue
        try:
            case_result = run_case(case_dir, test_type)
            results.append(case_result)
        except Exception as e:
            case_result = {
                "case_id": f"{test_type}_{case_dir.name}",
                "original_case_id": case_dir.name,
                "test_type": test_type,
                "passed": False,
                "error": str(e),
                "details": {},
                "final_score": None,
                "result": None
            }
            results.append(case_result)

    return results


def main():
    print("Running both Positive and Adversarial Regressions...")
    print("="*60)

    # 运行 Positive Regression
    print("Running POSITIVE regression tests...")
    positive_results = run_regression_suite(POSITIVE_DATA_DIR, "positive")
    
    # 运行 Adversarial Regression  
    print("Running ADVERSARIAL regression tests...")
    adversarial_results = run_regression_suite(ADVERSARIAL_DATA_DIR, "adversarial")

    # 合并结果
    all_results = positive_results + adversarial_results

    # 统计结果
    total_cases = len(all_results)
    passed_cases = sum(1 for r in all_results if r["passed"])
    failed_cases = total_cases - passed_cases

    # 按类型分别统计
    positive_total = len(positive_results)
    positive_passed = sum(1 for r in positive_results if r["passed"])
    positive_failed = positive_total - positive_passed

    adversarial_total = len(adversarial_results)
    adversarial_passed = sum(1 for r in adversarial_results if r["passed"])
    adversarial_failed = adversarial_total - adversarial_passed

    # 构建完整报告
    report = {
        "summary": {
            "total": total_cases,
            "passed": passed_cases,
            "failed": failed_cases,
            "timestamp": datetime.now().isoformat(),
            "breakdown": {
                "positive": {
                    "total": positive_total,
                    "passed": positive_passed,
                    "failed": positive_failed
                },
                "adversarial": {
                    "total": adversarial_total,
                    "passed": adversarial_passed,
                    "failed": adversarial_failed
                }
            }
        },
        "results": all_results
    }

    # 打印整体结果
    print("="*60)
    print("BOTH REGRESSION TEST SUITE RESULTS")
    print("="*60)
    print(f"Total cases: {report['summary']['total']}")
    print(f"Passed: {report['summary']['passed']}")
    print(f"Failed: {report['summary']['failed']}")
    print(f"Timestamp: {report['summary']['timestamp']}")
    print("-"*60)
    print("BREAKDOWN BY TYPE:")
    print(f"Positive: {positive_passed}/{positive_total} passed")
    print(f"Adversarial: {adversarial_passed}/{adversarial_total} passed")
    print("="*60)

    # 打印失败案例
    failed_results = [r for r in all_results if not r["passed"]]
    if failed_results:
        print("\nFAILED CASES:")
        print("-"*40)
        for result in failed_results:
            print(f"\nCase ID: {result['case_id']} (Type: {result['test_type']})")
            if "error" in result:
                print(f"  Error: {result['error']}")
            if "errors" in result:
                for error in result["errors"]:
                    print(f"  Error: {error}")
    else:
        print("\nALL TESTS PASSED!")

    # 打印通过案例
    passed_results = [r for r in all_results if r["passed"]]
    if passed_results:
        print(f"\nPASSED CASES:")
        print("-"*40)
        for result in passed_results:
            print(f"  [OK] {result['case_id']} (Type: {result['test_type']}) - Score: {result['final_score']} - Result: {result['result']}")

    # 将结果写入文件
    output_file = Path("output/both_regressions_report.json")
    output_file.parent.mkdir(parents=True, exist_ok=True)

    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print(f"\nDetailed results saved to: {output_file}")

    # 如果有失败的案例，则退出码为1
    if failed_cases > 0:
        print(f"\nX {failed_cases} test(s) failed")
        raise SystemExit(1)
    else:
        print(f"\nV All {passed_cases} tests passed!")


if __name__ == "__main__":
    main()