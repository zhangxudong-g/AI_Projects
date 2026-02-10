import json
import datetime
from pathlib import Path

from constants import ENGINEERING_ACTION_MAP

def extract_llm_json(promptfoo_output_path: str) -> dict:
    """
    从 promptfoo eval 的输出中，
    提取并 parse LLM 返回的 JSON
    """
    with open(promptfoo_output_path, encoding="utf-8") as f:
        raw = json.load(f)

    try:
        output_text = raw["results"]["results"][0]["response"]["output"]
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
    
def _get_case_filename(cases_config: dict, case_id: str) -> str:
    """根据case_id获取对应的文件名"""
    for case_config in cases_config["cases"]:
        if case_config["id"] == case_id:
            vars_cfg = case_config.get("vars", {})
            source_code_path = vars_cfg.get("source_code", "N/A")
            if source_code_path != "N/A":
                return Path(source_code_path).name
            return "N/A"
    return "N/A"


def _format_details(details_data: dict) -> str:
    """格式化详细信息为HTML详情标签"""
    try:
        # 提取summary和details中的值
        summary = details_data.get('summary', 'N/A')
        details_obj = details_data.get('details', {})

        # 从details中提取各个字段（新版本的评估维度 - Judge v3）
        comprehension_support = details_obj.get('comprehension_support', 'N/A')
        engineering_usefulness = details_obj.get('engineering_usefulness', 'N/A')
        explanation_reasonableness = details_obj.get('explanation_reasonableness', 'N/A')
        abstraction_quality = details_obj.get('abstraction_quality', 'N/A')
        fabrication_risk = details_obj.get('fabrication_risk', 'N/A')

        # 提取工程操作建议信息，作为主要展示点
        engineering_action = details_data.get('engineering_action', {})
        recommended_action = "N/A"
        action_level = "N/A"
        action_description = "N/A"
        
        if engineering_action:
            action_level = engineering_action.get('level', 'N/A')
            action_description = engineering_action.get('description', 'N/A')
            recommended_action = engineering_action.get('recommended_action', 'N/A')

        # 构建平铺显示的内容
        flat_details = (
            f"Action Level: {action_level}<br/>"
            f"Description: {action_description}<br/>"
            f"Summary: {summary}<br/>"
            f"Comprehension Support: {comprehension_support}<br/>"
            f"Engineering Usefulness: {engineering_usefulness}<br/>"
            f"Explanation Reasonableness: {explanation_reasonableness}<br/>"
            f"Abstraction Quality: {abstraction_quality}<br/>"
            f"Fabrication Risk: {fabrication_risk}"
        )

        # 使用简洁的摘要和详细的平铺信息，将推荐操作放在摘要中
        compact_info = f"{recommended_action[:50]}{'...' if len(str(recommended_action)) > 50 else ''}"
        return f'<details><summary>{compact_info}</summary><div>{flat_details}</div></details>'
    except Exception as e:
        return f'<details><summary>Error occurred</summary><div>Error reading details: {str(e)}</div></details>'


def format_results_to_html(case_results, cases_config, base_output: str = "output"):
    """
    使用LLM整理结果并输出为HTML表格格式
    表格包含：case id/文件名/结果/分数/详情（final_score.json内容，包括理解支持、工程实用性、解释合理性、抽象质量和伪造风险）
    """
    html_content = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Code wiki 测试结果</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
            border-bottom: 2px solid #4CAF50;
            padding-bottom: 10px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 12px;
            text-align: left;
        }
        th {
            background-color: #4CAF50;
            color: white;
            font-weight: bold;
        }
        tr:nth-child(even) {
            background-color: #f2f2f2;
        }
        tr:hover {
            background-color: #f0f0f0;
        }
        details {
            cursor: pointer;
        }
        summary {
            font-weight: bold;
            color: #2196F3;
        }
        .status-pass {
            color: green;
            font-weight: bold;
        }
        .status-fail {
            color: red;
            font-weight: bold;
        }
        .score {
            font-weight: bold;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Code wiki 测试结果</h1>
        <table>
            <thead>
                <tr>
                    <th>Case ID</th>
                    <th>文件名</th>
                    <th>结果</th>
                    <th>分数</th>
                    <th>详情</th>
                </tr>
            </thead>
            <tbody>
"""
    
    for result in case_results:
        case_id = result['case_id']
        result_status = result['result']
        final_score_value = result['final_score']

        # 获取对应的final_score.json内容作为详情
        final_score_path = Path(base_output) / case_id / "final_score.json"
        if final_score_path.exists():
            with open(final_score_path, 'r', encoding='utf-8') as f:
                details_data = json.load(f)
            details = _format_details(details_data)
        else:
            details = '{}'

        # 获取输入文件名
        input_file = _get_case_filename(cases_config, case_id)
        
        # 为结果添加CSS类
        status_class = "status-pass" if result_status.lower() == "pass" else "status-fail"
        score_class = "score"

        html_content += f"""                <tr>
                    <td>{case_id}</td>
                    <td>{input_file}</td>
                    <td class="{status_class}">{result_status}</td>
                    <td class="{score_class}">{final_score_value}</td>
                    <td>{details}</td>
                </tr>
"""

    html_content += """            </tbody>
        </table>
    </div>
</body>
</html>"""

    # 生成时间戳文件名
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"final_results_table-{timestamp}.html"
    final_results_path = Path(base_output) / filename

    with open(final_results_path, "w", encoding="utf-8") as f:
        f.write(html_content)

    print(f"SUCCESS: Engineering Judge v3 HTML结果表格已保存至: {final_results_path}")
    return final_results_path


def format_results_with_llm(case_results, cases_config, base_output: str = "output"):
    """
    使用LLM整理结果并输出为Markdown表格格式
    表格包含：case id/文件名/结果/分数/详情（final_score.json内容，包括理解支持、工程实用性、解释合理性、抽象质量和伪造风险）
    """
    md_content = "# Code wiki 测试结果\n\n"
    md_content += "| Case ID | 文件名 | 结果 | 分数 | 详情 |\n"
    md_content += "|--------|-------|------|------|------|\n"

    for result in case_results:
        case_id = result['case_id']
        result_status = result['result']
        final_score_value = result['final_score']

        # 获取对应的final_score.json内容作为详情
        final_score_path = Path(base_output) / case_id / "final_score.json"
        if final_score_path.exists():
            with open(final_score_path, 'r', encoding='utf-8') as f:
                details_data = json.load(f)
            details = _format_details(details_data)
        else:
            details = '{}'

        # 获取输入文件名
        input_file = _get_case_filename(cases_config, case_id)

        md_content += f"| {case_id} | {input_file} | {result_status} | {final_score_value} | {details} |\n"

    # 生成时间戳文件名
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"final_results_table-{timestamp}.md"
    final_results_path = Path(base_output) / filename

    with open(final_results_path, "w", encoding="utf-8") as f:
        f.write(md_content)

    print(f"SUCCESS: Engineering Judge v3 Markdown结果表格已保存至: {final_results_path}")
    return final_results_path



