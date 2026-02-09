import json
import datetime
from pathlib import Path

from constants import ENGINEERING_ACTION_MAP

def extract_llm_json(promptfoo_output_path: str) -> dict:
    """
    从 promptfoo eval 的输出中，
    提取并 parse LLM 返回的 JSON
    """
    raw = json.loads(open(promptfoo_output_path, encoding="utf-8").read())

    try:
        output_text = raw["results"]["results"][0]["response"]["output"]
        # print(f"[LLM OUTPUT] {output_text}")
    except (KeyError, IndexError):
        raise RuntimeError("Invalid promptfoo output structure")

    try:
        return json.loads(output_text)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"LLM output is not valid JSON:\n{output_text}") from e




def map_engineering_action(score: int) -> dict:
    for rule in ENGINEERING_ACTION_MAP:
        if rule["min"] <= score <= rule["max"]:
            return rule
    # fallback（理论上不会触发）
    return ENGINEERING_ACTION_MAP[-1]    
    
def format_results_with_llm(case_results, cases_config, base_output: str = "output"):
    """
    使用LLM整理结果并输出为Markdown表格格式
    表格包含：case id/文件名/结果/分数/详情（final_score.json内容，包括理解支持、工程实用性、解释合理性、抽象质量和伪造风险）
    """
    # 创建Markdown表格
    # md_content = "# Engineering Judge v3 测试结果汇总\n\n"
    md_content = "# Code wiki 测试结果\n\n"
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

                    # 从details中提取各个字段（新版本的评估维度 - Judge v3）
                    comprehension_support = details_obj.get('comprehension_support', 'N/A')
                    engineering_usefulness = details_obj.get('engineering_usefulness', 'N/A')
                    explanation_reasonableness = details_obj.get('explanation_reasonableness', 'N/A')
                    abstraction_quality = details_obj.get('abstraction_quality', 'N/A')
                    fabrication_risk = details_obj.get('fabrication_risk', 'N/A')

                    # 构建平铺显示的内容
                    flat_details = f"Summary: {summary}<br/>Comprehension Support: {comprehension_support}<br/>Engineering Usefulness: {engineering_usefulness}<br/>Explanation Reasonableness: {explanation_reasonableness}<br/>Abstraction Quality: {abstraction_quality}<br/>Fabrication Risk: {fabrication_risk}"

                    # 添加工程操作建议信息
                    engineering_action = details_data.get('engineering_action', {})
                    if engineering_action:
                        level = engineering_action.get('level', 'N/A')
                        description = engineering_action.get('description', 'N/A')
                        recommended_action = engineering_action.get('recommended_action', 'N/A')
                        engineering_info = f"<br/>Engineering Action Level: {level}<br/>Description: {description}<br/>Recommended Action: {recommended_action}"
                        flat_details += engineering_info

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

    print(f"SUCCESS: Engineering Judge v3 Markdown结果表格已保存至: {final_results_path}")
    return final_results_path



