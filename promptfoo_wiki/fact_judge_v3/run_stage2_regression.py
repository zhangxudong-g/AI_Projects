import json
from pathlib import Path
from datetime import datetime
from run_single_case_pipeline import run_single_case

DATA_DIR = Path("stage2_adversarial_regression_full")


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


def run_case(case_dir: Path):
    spec = load_case_spec(case_dir)

    files = spec.get("files", {})
    vars_cfg = {
        "source_code": str(case_dir / files.get("source", "source.java")),
        "wiki_md": str(case_dir / files.get("wiki", "wiki.md")),
    }

    result = run_single_case(
        case_id=case_dir.name,
        vars_cfg=vars_cfg,
        output_dir=Path("output/regression") / case_dir.name,
        base_output="output/regression",
    )

    details = result["details"]
    case_result = {
        "case_id": case_dir.name,
        "passed": True,
        "final_score": result["final_score"],
        "details": details,
        "errors": []
    }

    # ===== MUST =====
    for key, allowed in spec.get("must", {}).items():
        if details[key] not in allowed:
            error_msg = f"{case_dir.name}: {key}={details[key]} not in {allowed}"
            case_result["errors"].append(error_msg)
            case_result["passed"] = False

    # ===== MUST NOT =====
    for key, forbidden in spec.get("must_not", {}).items():
        if details[key] in forbidden:
            error_msg = f"{case_dir.name}: {key}={details[key]} should not be in {forbidden}"
            case_result["errors"].append(error_msg)
            case_result["passed"] = False

    # ===== SCORE RANGE =====
    lo, hi = spec["score_range"]
    if not (lo <= result["final_score"] <= hi):
        error_msg = f"{case_dir.name}: score {result['final_score']} not in [{lo}, {hi}]"
        case_result["errors"].append(error_msg)
        case_result["passed"] = False

    return case_result


def main():
    results = []
    
    for case_dir in DATA_DIR.iterdir():
        if not case_dir.is_dir():
            continue
        try:
            case_result = run_case(case_dir)
            results.append(case_result)
        except Exception as e:
            case_result = {
                "case_id": case_dir.name,
                "passed": False,
                "error": str(e),
                "details": {},
                "final_score": None
            }
            results.append(case_result)

    # 统计结果
    total_cases = len(results)
    passed_cases = sum(1 for r in results if r["passed"])
    failed_cases = total_cases - passed_cases
    
    # 构建完整报告
    report = {
        "summary": {
            "total": total_cases,
            "passed": passed_cases,
            "failed": failed_cases,
            "timestamp": datetime.now().isoformat(),
        },
        "results": results
    }
    
    # 打印整体结果
    print("="*60)
    print("REGRESSION TEST RESULTS")
    print("="*60)
    print(f"Total cases: {report['summary']['total']}")
    print(f"Passed: {report['summary']['passed']}")
    print(f"Failed: {report['summary']['failed']}")
    print(f"Timestamp: {report['summary']['timestamp']}")
    print("="*60)
    
    if failed_cases > 0:
        print("\nFAILED CASES:")
        print("-"*40)
        for result in results:
            if not result["passed"]:
                print(f"\nCase ID: {result['case_id']}")
                if "error" in result:
                    print(f"  Error: {result['error']}")
                if "errors" in result:
                    for error in result["errors"]:
                        print(f"  Error: {error}")
    
    print("\nPASSED CASES:")
    print("-"*40)
    for result in results:
        if result["passed"]:
            print(f"  [OK] {result['case_id']} - Score: {result['final_score']}")
    
    # 将结果写入文件
    output_file = Path("output/regression/regression_report.json")
    output_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    
    print(f"\nDetailed results saved to: {output_file}")
    
    # 如果有失败的案例，则退出码为1
    if failed_cases > 0:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
