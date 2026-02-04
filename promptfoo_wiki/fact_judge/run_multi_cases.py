import datetime
import yaml
from pathlib import Path
from run_single_case_pipeline import run_single_case


def run_all_cases(cases_yaml: str, base_output: str = "output"):
    cfg = yaml.safe_load(open(cases_yaml, encoding="utf-8"))
    results = []

    for case in cfg["cases"]:
        case_id = case["id"]
        vars_cfg = case["vars"]
        print(f"\n🚀 Running {case_id}")

        result = run_single_case(
            case_id=case_id,
            vars_cfg=vars_cfg,
            output_dir=Path(base_output) / case_id,
        )

        results.append(
            {
                "case_id": case_id,
                "final_score": result["final_score"],
                "result": result["result"],
            }
        )
    for r in results:
        print(
            f"Case {r['case_id']}: Final Score = {r['final_score']} Result = {r['result']}"
        )
    # 保存最终结果到文件
    # 获取当前时间戳（格式：年月日_时分秒）
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    # 文件名加上时间戳以防覆盖
    filename = f"final_results-{timestamp}.yaml"
    final_results_path = Path(base_output) / filename
    with open(final_results_path, "w", encoding="utf-8") as f:
        yaml.dump({"results": results}, f, allow_unicode=True)

    return results


if __name__ == "__main__":
    # run_all_cases("cases.yaml")
    run_all_cases("cases copy.yaml")
