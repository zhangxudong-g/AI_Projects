import datetime
import json
import yaml
from pathlib import Path
from run_single_case_pipeline import run_single_case


def format_results_with_llm(case_results, cases_config, base_output: str = "output"):
    """
    使用LLM整理结果并输出为Markdown表格格式
    表格包含：case id/文件名/结果/分数/详情（final_score.json内容）
    """
    # 创建Markdown表格
    md_content = "# Fact Judge 测试结果汇总\n\n"
    md_content += "| Case ID | 文件名 | 结果 | 分数 | 详情 |\n"
    md_content += "|--------|-------|------|------|------|\n"

    for idx, result in enumerate(case_results):
        case_id = result['case_id']
        result_status = result['result']
        final_score = result['final_score']

        # 获取对应的final_score.json内容作为详情
        final_score_path = Path(base_output) / case_id / "final_score.json"
        details = "{}"
        if final_score_path.exists():
            try:
                with open(final_score_path, 'r', encoding='utf-8') as f:
                    details_data = json.load(f)

                    # 提取summary和details中的值
                    summary = details_data.get('summary', 'N/A')
                    details_obj = details_data.get('details', {})

                    # 从details中提取各个字段
                    coverage_level = details_obj.get('coverage_level', 'N/A')
                    usefulness_level = details_obj.get('usefulness_level', 'N/A')
                    correctness_level = details_obj.get('correctness_level', 'N/A')
                    hallucination_level = details_obj.get('hallucination_level', 'N/A')
                    coverage_rate = details_obj.get('coverage_rate', 'N/A')

                    # 构建平铺显示的内容
                    flat_details = f"Summary: {summary}<br/>Coverage: {coverage_level}<br/>Usefulness: {usefulness_level}<br/>Correctness: {correctness_level}<br/>Hallucination: {hallucination_level}<br/>Coverage Rate: {coverage_rate}"

                    # 使用简洁的摘要和详细的平铺信息
                    compact_info = f"Score: {details_data.get('final_score', 'N/A')}, Result: {details_data.get('result', 'N/A')}"
                    details = f'<details><summary>{compact_info}</summary><div>{flat_details}</div></details>'
            except Exception as e:
                details = f'<details><summary>Error occurred</summary><div>Error reading details: {str(e)}</div></details>'

        # 获取输入文件名（从原始cases配置中获取source_code字段）
        input_file = "N/A"
        if idx < len(cases_config["cases"]):
            case_config = cases_config["cases"][idx]
            vars_cfg = case_config.get("vars", {})
            input_file = vars_cfg.get("source_code", "N/A")
            # 提取文件名部分
            if input_file != "N/A":
                input_file = Path(input_file).name

        md_content += f"| {case_id} | {input_file} | {result_status} | {final_score} | {details} |\n"

    # 生成时间戳文件名
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"final_results_table-{timestamp}.md"
    final_results_path = Path(base_output) / filename

    with open(final_results_path, "w", encoding="utf-8") as f:
        f.write(md_content)

    print(f"SUCCESS: Markdown结果表格已保存至: {final_results_path}")
    return final_results_path


def run_all_cases(cases_yaml: str, base_output: str = "output"):
    cfg = yaml.safe_load(open(cases_yaml, encoding="utf-8"))
    results = []

    for case in cfg["cases"]:
        case_id = case["id"]
        vars_cfg = case["vars"]
        print(f"\n[START] Running {case_id}")

        result = run_single_case(
            case_id=case_id,
            vars_cfg=vars_cfg,
            output_dir=Path(base_output) / case_id,
            base_output=base_output,
        )

        results.append(
            {
                "case_id": case_id,
                "final_score": result["final_score"],
                "result": result["result"],
            }
        )


    # 处理最终结果
    for r in results:
        print(
            f"Case {r['case_id']}: Final Score = {r['final_score']} Result = {r['result']}"
        )

    # 使用LLM整理结果并输出为Markdown表格
    format_results_with_llm(results, cfg, base_output)

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
    import sys
    import argparse

    parser = argparse.ArgumentParser(description='Run fact judge test cases')
    parser.add_argument('--cases-yaml', type=str, default='cases_all.yaml', help='Cases YAML file path')
    parser.add_argument('--base-output', type=str, default='results_output', help='Base output directory')

    args = parser.parse_args()

    # run_all_cases("cases.yaml")
    run_all_cases(args.cases_yaml, args.base_output)
