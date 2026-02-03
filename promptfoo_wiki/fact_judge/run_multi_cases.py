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
    return results


if __name__ == "__main__":
    run_all_cases("cases.yaml")
