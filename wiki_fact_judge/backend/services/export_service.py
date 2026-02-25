"""
Report Export Service - 支持多种格式导出
- JSON: 完整原始数据
- Markdown: 可读性好的报告文档
- CSV: 用于数据分析
"""
import json
import csv
import io
from datetime import datetime
from typing import Dict, Any, List, Optional, Tuple
from sqlalchemy.orm import Session
from backend.database import TestReport, TestPlan, TestCase


def extract_file_type(case_name: str) -> str:
    """
    从 case name 中提取文件类型（扩展名）
    
    Args:
        case_name: 案例名称（如：Controller_xxx.java）
    
    Returns:
        文件类型（小写扩展名，如 'java'），如果没有扩展名则返回 'unknown'
    """
    if not case_name:
        return 'unknown'
    
    # 去掉 .md 后缀（如果是 wiki 文档）
    name = case_name[:-3] if case_name.endswith('.md') else case_name
    
    # 提取最后一个 . 之后的部分作为扩展名
    parts = name.split('.')
    if len(parts) > 1:
        ext = parts[-1].lower()
        return ext
    
    return 'unknown'


def sort_cases_by_file_type(case_results: List[Tuple[str, str, Dict]]) -> List[Tuple[str, str, Dict]]:
    """
    按文件类型对案例结果进行排序
    
    排序规则：
    1. 按文件类型分组（java、sql、py 等）
    2. 类型间按类型名字母顺序排序
    3. 同类型内按 case name 字母顺序排序
    4. 无扩展名的 case 排在最后
    
    Args:
        case_results: 列表，每个元素为 (case_id, case_name, case_result_data) 元组
    
    Returns:
        排序后的列表
    """
    def sort_key(item: Tuple[str, str, Dict]) -> Tuple[int, str, str]:
        case_id, case_name, _ = item
        file_type = extract_file_type(case_name)
        
        # unknown 类型排在最后
        if file_type == 'unknown':
            return (1, '', case_name.lower())
        
        # 其他类型按类型名排序，类型内按 name 排序
        return (0, file_type.lower(), case_name.lower())
    
    return sorted(case_results, key=sort_key)


def export_report_to_json(db: Session, report_id: int) -> Dict[str, Any]:
    """
    导出单个报告为 JSON 格式
    """
    report = db.query(TestReport).filter(TestReport.id == report_id).first()
    if not report:
        return None

    result_data = {}
    if report.result:
        try:
            result_data = json.loads(report.result)
        except json.JSONDecodeError:
            result_data = {"raw_result": report.result}

    export_data = {
        "report": {
            "id": report.id,
            "report_name": report.report_name,
            "status": report.status,
            "final_score": report.final_score,
            "created_at": report.created_at.isoformat() if report.created_at else None,
            "updated_at": report.updated_at.isoformat() if report.updated_at else None,
            "output_path": report.output_path,
        },
        "result": result_data,
    }

    # 添加关联的计划信息
    if report.plan_id:
        plan = db.query(TestPlan).filter(TestPlan.id == report.plan_id).first()
        if plan:
            export_data["plan"] = {
                "id": plan.id,
                "name": plan.name,
                "description": plan.description,
            }

    # 添加关联的案例信息
    if report.case_id:
        case = db.query(TestCase).filter(TestCase.case_id == report.case_id).first()
        if case:
            export_data["case"] = {
                "case_id": case.case_id,
                "name": case.name,
                "source_code_path": case.source_code_path,
                "wiki_path": case.wiki_path,
                "yaml_path": case.yaml_path,
            }

    return export_data


def export_plan_reports_to_json(db: Session, plan_id: int) -> Dict[str, Any]:
    """
    导出整个 Plan 的所有报告为 JSON 格式
    """
    plan = db.query(TestPlan).filter(TestPlan.id == plan_id).first()
    if not plan:
        return None

    reports = db.query(TestReport).filter(TestReport.plan_id == plan_id).all()

    export_data = {
        "plan": {
            "id": plan.id,
            "name": plan.name,
            "description": plan.description,
            "created_at": plan.created_at.isoformat() if plan.created_at else None,
            "updated_at": plan.updated_at.isoformat() if plan.updated_at else None,
        },
        "summary": {
            "total_reports": len(reports),
            "completed": len([r for r in reports if r.status == "FINISHED"]),
            "failed": len([r for r in reports if r.status == "FAILED"]),
            "running": len([r for r in reports if r.status == "RUNNING"]),
        },
        "reports": [],
    }

    scores = []
    for report in reports:
        report_data = {
            "id": report.id,
            "report_name": report.report_name,
            "status": report.status,
            "final_score": report.final_score,
            "created_at": report.created_at.isoformat() if report.created_at else None,
        }
        if report.case_id:
            case = db.query(TestCase).filter(TestCase.case_id == report.case_id).first()
            if case:
                report_data["case_name"] = case.name
        
        # 如果是 plan report（包含 results 数组），从 result 字段提取实际的 case 分数
        if report.result:
            try:
                result_obj = json.loads(report.result)
                if result_obj and isinstance(result_obj, dict) and "results" in result_obj:
                    # 从 results 数组中提取每个 case 的分数
                    for result_item in result_obj["results"]:
                        if "final_score" in result_item and result_item["final_score"] is not None:
                            scores.append(result_item["final_score"])
                        elif "result" in result_item and isinstance(result_item["result"], dict):
                            if "final_score" in result_item["result"] and result_item["result"]["final_score"] is not None:
                                scores.append(result_item["result"]["final_score"])
                elif "final_score" in result_obj and result_obj["final_score"] is not None:
                    # 如果是单个 case 的结果
                    scores.append(result_obj["final_score"])
            except (json.JSONDecodeError, KeyError, TypeError):
                # 如果解析失败，使用 report 的 final_score
                if report.final_score is not None:
                    scores.append(report.final_score)
        elif report.final_score is not None:
            scores.append(report.final_score)
            
        export_data["reports"].append(report_data)

    if scores:
        export_data["summary"]["average_score"] = sum(scores) / len(scores)
        export_data["summary"]["max_score"] = max(scores)
        export_data["summary"]["min_score"] = min(scores)

    return export_data


def export_report_to_markdown(db: Session, report_id: int) -> str:
    """
    导出单个报告为 Markdown 格式
    """
    report = db.query(TestReport).filter(TestReport.id == report_id).first()
    if not report:
        return None

    result_data = {}
    if report.result:
        try:
            result_data = json.loads(report.result)
        except json.JSONDecodeError:
            result_data = {"raw_result": report.result}

    # 获取关联信息
    plan_name = None
    case_name = None
    case_info = None

    if report.plan_id:
        plan = db.query(TestPlan).filter(TestPlan.id == report.plan_id).first()
        if plan:
            plan_name = plan.name

    if report.case_id:
        case = db.query(TestCase).filter(TestCase.case_id == report.case_id).first()
        if case:
            case_name = case.name
            case_info = {
                "source_code_path": case.source_code_path,
                "wiki_path": case.wiki_path,
                "yaml_path": case.yaml_path,
            }

    # 构建 Markdown
    md_lines = [
        f"# {report.report_name}",
        "",
        "## 基本信息",
        "",
        f"- **报告 ID**: {report.id}",
        f"- **状态**: {report.status}",
        f"- **最终得分**: {report.final_score if report.final_score is not None else 'N/A'}",
        f"- **创建时间**: {report.created_at.strftime('%Y-%m-%d %H:%M:%S') if report.created_at else 'N/A'}",
        f"- **更新时间**: {report.updated_at.strftime('%Y-%m-%d %H:%M:%S') if report.updated_at else 'N/A'}",
        "",
    ]

    if plan_name:
        md_lines.extend([
            f"- **测试计划**: {plan_name}",
            "",
        ])

    if case_name:
        md_lines.extend([
            f"- **测试案例**: {case_name}",
            "",
        ])

    # 添加案例详细信息
    if case_info:
        md_lines.extend([
            "## 案例文件",
            "",
        ])
        if case_info.get("source_code_path"):
            md_lines.append(f"- 源代码：`{case_info['source_code_path']}`")
        if case_info.get("wiki_path"):
            md_lines.append(f"- Wiki 文档：`{case_info['wiki_path']}`")
        if case_info.get("yaml_path"):
            md_lines.append(f"- 配置文件：`{case_info['yaml_path']}`")
        md_lines.append("")

    # 添加评估结果详情
    if result_data:
        md_lines.extend([
            "## 评估结果详情",
            "",
        ])

        # 处理五阶段评估结果
        if "result" in result_data and isinstance(result_data["result"], dict):
            stage_results = result_data["result"]

            # Stage 1: Structural Coverage Judge
            if "stage1_structural_coverage" in stage_results:
                s1 = stage_results["stage1_structural_coverage"]
                md_lines.extend([
                    "### Stage 1: 结构覆盖度评估",
                    "",
                    f"- **判断**: {s1.get('judgement', 'N/A')}",
                    f"- **置信度**: {s1.get('confidence', 'N/A')}",
                    "",
                ])
                if s1.get("reasoning"):
                    md_lines.extend([
                        "**评估理由**:",
                        "",
                        f"{s1['reasoning']}",
                        "",
                    ])

            # Stage 1.5: Explanation Alignment Judge
            if "stage1_5_explanation_alignment" in stage_results:
                s15 = stage_results["stage1_5_explanation_alignment"]
                md_lines.extend([
                    "### Stage 1.5: 解释对齐评估",
                    "",
                    f"- **判断**: {s15.get('judgement', 'N/A')}",
                    f"- **置信度**: {s15.get('confidence', 'N/A')}",
                    "",
                ])
                if s15.get("reasoning"):
                    md_lines.extend([
                        "**评估理由**:",
                        "",
                        f"{s15['reasoning']}",
                        "",
                    ])

            # Stage 2: Engineering Judge v3
            if "stage2_engineering_judge" in stage_results:
                s2 = stage_results["stage2_engineering_judge"]
                md_lines.extend([
                    "### Stage 2: 工程价值评估",
                    "",
                    f"- **判断**: {s2.get('judgement', 'N/A')}",
                    f"- **置信度**: {s2.get('confidence', 'N/A')}",
                    "",
                ])
                if s2.get("reasoning"):
                    md_lines.extend([
                        "**评估理由**:",
                        "",
                        f"{s2['reasoning']}",
                        "",
                    ])

            # Stage 3: Risk-aware Scoring
            if "stage3_risk_scoring" in stage_results:
                s3 = stage_results["stage3_risk_scoring"]
                md_lines.extend([
                    "### Stage 3: 风险评分",
                    "",
                    f"- **基础分数**: {s3.get('base_score', 'N/A')}",
                    f"- **风险扣分**: {s3.get('risk_deduction', 'N/A')}",
                    f"- **最终得分**: {s3.get('final_score', report.final_score)}",
                    "",
                ])
                if s3.get("risk_analysis"):
                    md_lines.extend([
                        "**风险分析**:",
                        "",
                        f"{s3['risk_analysis']}",
                        "",
                    ])

        # 添加原始 JSON 数据（折叠）
        md_lines.extend([
            "## 原始数据",
            "",
            "```json",
            json.dumps(result_data, ensure_ascii=False, indent=2),
            "```",
            "",
        ])

    # 添加导出时间
    md_lines.extend([
        "---",
        "",
        f"*报告导出时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*",
    ])

    return "\n".join(md_lines)


def export_plan_reports_to_markdown(db: Session, plan_id: int) -> str:
    """
    导出整个 Plan 的所有报告为 Markdown 格式
    """
    plan = db.query(TestPlan).filter(TestPlan.id == plan_id).first()
    if not plan:
        return None

    reports = db.query(TestReport).filter(TestReport.plan_id == plan_id).all()

    # 计算统计信息 - 从 result 字段提取实际的 case 分数
    scores = []
    for report in reports:
        if report.result:
            try:
                result_obj = json.loads(report.result)
                if result_obj and isinstance(result_obj, dict) and "results" in result_obj:
                    # 从 results 数组中提取每个 case 的分数
                    for result_item in result_obj["results"]:
                        if "final_score" in result_item and result_item["final_score"] is not None:
                            scores.append(result_item["final_score"])
                        elif "result" in result_item and isinstance(result_item["result"], dict):
                            if "final_score" in result_item["result"] and result_item["result"]["final_score"] is not None:
                                scores.append(result_item["result"]["final_score"])
                elif "final_score" in result_obj and result_obj["final_score"] is not None:
                    scores.append(result_obj["final_score"])
            except (json.JSONDecodeError, KeyError, TypeError):
                if report.final_score is not None:
                    scores.append(report.final_score)
        elif report.final_score is not None:
            scores.append(report.final_score)
    
    completed = len([r for r in reports if r.status == "FINISHED"])
    failed = len([r for r in reports if r.status == "FAILED"])
    running = len([r for r in reports if r.status == "RUNNING"])

    # 构建 Markdown
    md_lines = [
        f"# Plan {plan.id}: {plan.name} - 测试报告汇总",
        "",
        "## 计划信息",
        "",
        f"- **计划 ID**: {plan.id}",
        f"- **计划名称**: {plan.name}",
        f"- **描述**: {plan.description or 'N/A'}",
        f"- **创建时间**: {plan.created_at.strftime('%Y-%m-%d %H:%M:%S') if plan.created_at else 'N/A'}",
        "",
        "## 汇总统计",
        "",
        f"- **总报告数**: {len(reports)}",
        f"- **已完成**: {completed}",
        f"- **失败**: {failed}",
        f"- **进行中**: {running}",
        "",
    ]

    if scores:
        avg_score = sum(scores) / len(scores)
        max_score = max(scores)
        min_score = min(scores)
        md_lines.extend([
            f"- **平均分**: {avg_score:.2f}",
            f"- **最高分**: {max_score:.2f}",
            f"- **最低分**: {min_score:.2f}",
            "",
        ])

    # 添加报告列表
    md_lines.extend([
        "## 报告列表",
        "",
        "| ID | 报告名称 | 案例 | 状态 | 得分 | 创建时间 |",
        "|----|---------|------|------|------|---------|",
    ])

    for report in reports:
        case_name = "N/A"
        if report.case_id:
            case = db.query(TestCase).filter(TestCase.case_id == report.case_id).first()
            if case:
                case_name = case.name

        score_str = f"{report.final_score:.2f}" if report.final_score is not None else "N/A"
        created_str = report.created_at.strftime('%Y-%m-%d %H:%M') if report.created_at else "N/A"

        md_lines.append(
            f"| {report.id} | {report.report_name} | {case_name} | {report.status} | {score_str} | {created_str} |"
        )

    md_lines.append("")

    # 添加单个报告的详细摘要
    md_lines.extend([
        "## 各案例详细结果",
        "",
    ])

    # 收集并排序所有案例数据（用于表格和详细结果）
    sorted_case_data = None
    
    # 添加案例结果总结表格 - 按文件类型排序
    for i, report in enumerate(reports, 1):
        if report.result:
            try:
                result_data = json.loads(report.result)
                if result_data and isinstance(result_data, dict) and "results" in result_data:
                    # 收集所有案例数据用于排序
                    case_data_list = []

                    for case_result in result_data["results"]:
                        case_id = case_result.get("case_id", "Unknown")
                        # 从数据库查询 case_name
                        case_name = "Unknown"
                        if case_id and case_id != "Unknown":
                            case = db.query(TestCase).filter(TestCase.case_id == case_id).first()
                            if case:
                                case_name = case.name

                        # 从嵌套的 result 结构中获取数据
                        inner_result = case_result.get("result", {})
                        if isinstance(inner_result, dict):
                            score = inner_result.get("final_score", "N/A")
                            # result 字段在内层是判断结果（PASS/FAIL），不是 status
                            result_status = inner_result.get("result", "N/A")
                            ea = inner_result.get("engineering_action", {})
                            summary = inner_result.get("summary", "")
                        else:
                            score = case_result.get("final_score", "N/A")
                            result_status = case_result.get("result", "N/A")
                            ea = case_result.get("engineering_action", {})
                            summary = case_result.get("summary", "")

                        ea_level = ea.get("level", "N/A") if ea else "N/A"
                        recommendation = ea.get("recommended_action", "N/A") if ea else "N/A"

                        score_str = f"{score:.2f}" if isinstance(score, (int, float)) and score != "N/A" else str(score)

                        # 收集数据用于排序
                        case_data_list.append((
                            case_id,
                            case_name,
                            {
                                "result_status": result_status,
                                "score_str": score_str,
                                "ea_level": ea_level,
                                "recommendation": recommendation,
                                "ea": ea,
                                "summary": summary,
                            }
                        ))

                    # 按文件类型排序
                    sorted_case_data = sort_cases_by_file_type(case_data_list)

                    md_lines.extend([
                        "### 案例结果总结",
                        "",
                        "| Case Name | Case ID | Result | Score | Engineering Action Level | Recommendation |",
                        "|-----------|---------|--------|-------|-------------------------|----------------|",
                    ])

                    # 使用排序后的数据生成表格
                    for case_id, case_name, data in sorted_case_data:
                        md_lines.append(f"| {case_name} | {case_id} | {data['result_status']} | {data['score_str']} | {data['ea_level']} | {data['recommendation']} |")

                    md_lines.append("")
                    md_lines.append("---")
                    md_lines.append("")
                    break  # 只处理第一个 report
            except json.JSONDecodeError:
                pass

    # 各案例详细结果 - 使用排序后的顺序
    if sorted_case_data:
        # 获取第一个 plan report 用于获取 details
        plan_report = None
        for report in reports:
            if report.result:
                try:
                    result_data = json.loads(report.result)
                    if result_data and isinstance(result_data, dict) and "results" in result_data:
                        plan_report = result_data
                        break
                except json.JSONDecodeError:
                    pass
        
        # 使用排序后的案例数据生成详细结果
        for case_id, case_name, data in sorted_case_data:
            # 从原始 result_data 中获取完整的 details
            details = {}
            if plan_report:
                for cr in plan_report["results"]:
                    if cr.get("case_id") == case_id:
                        inner_result = cr.get("result", {})
                        if isinstance(inner_result, dict):
                            details = inner_result.get("details", {})
                        else:
                            details = cr.get("details", {})
                        break

            md_lines.extend([
                f"### {case_name} ({case_id})",
                "",
                f"- **状态**: {data['result_status']}",
                f"- **得分**: {data['score_str']}",
                "",
            ])

            # 显示 Engineering Action
            if data['ea']:
                md_lines.extend([
                    "**Engineering Action**:",
                    "",
                    f"- **Level**: {data['ea_level']}",
                    f"- **Description**: {data['ea'].get('description', 'N/A')}",
                    f"- **Recommendation**: {data['ea'].get('recommended_action', 'N/A')}",
                    "",
                ])

            # 显示 Summary
            if data['summary']:
                md_lines.extend([
                    "**Summary**:",
                    "",
                    f"{data['summary']}",
                    "",
                ])

            # 显示 Assessment Details
            if details:
                md_lines.extend([
                    "**Assessment Details**:",
                    "",
                ])
                for key, value in details.items():
                    label = key.replace("_", " ").title()
                    md_lines.append(f"- **{label}**: {value}")
                md_lines.append("")

            md_lines.append("---")
            md_lines.append("")
    else:
        # 如果没有排序数据（旧格式），使用原有逻辑
        for i, report in enumerate(reports, 1):
            if report.result:
                try:
                    result_data = json.loads(report.result)
                    # 单个 case 的 report（旧格式兼容）
                    if report.case_id:
                        case = db.query(TestCase).filter(TestCase.case_id == report.case_id).first()
                        if case:
                            md_lines.extend([
                                f"### {i}. {case.name}",
                                "",
                                f"- **报告名称**: {report.report_name}",
                                f"- **状态**: {report.status}",
                                f"- **得分**: {report.final_score if report.final_score is not None else 'N/A'}",
                                "",
                            ])

                            # 解析并添加关键评估结果
                            if "result" in result_data and isinstance(result_data["result"], dict):
                                stage_results = result_data["result"]
                                stages_info = []
                                if "stage1_structural_coverage" in stage_results:
                                    s1 = stage_results["stage1_structural_coverage"]
                                    stages_info.append(f"Stage1: {s1.get('judgement', 'N/A')}")
                                if "stage1_5_explanation_alignment" in stage_results:
                                    s15 = stage_results["stage1_5_explanation_alignment"]
                                    stages_info.append(f"Stage1.5: {s15.get('judgement', 'N/A')}")
                                if "stage2_engineering_judge" in stage_results:
                                    s2 = stage_results["stage2_engineering_judge"]
                                    stages_info.append(f"Stage2: {s2.get('judgement', 'N/A')}")

                                if stages_info:
                                    md_lines.extend([
                                        "**关键评估**:",
                                        "",
                                        "- " + " | ".join(stages_info),
                                        "",
                                    ])
                except json.JSONDecodeError:
                    md_lines.append(f"// 解析报告 {i} 失败")
                    md_lines.append("")

    md_lines.extend([
        "---",
        "",
        f"*报告导出时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*",
    ])

    return "\n".join(md_lines)


def export_reports_to_csv(db: Session, report_ids: Optional[List[int]] = None, plan_id: Optional[int] = None) -> str:
    """
    导出报告为 CSV 格式

    Args:
        db: 数据库会话
        report_ids: 指定报告 ID 列表
        plan_id: 指定 Plan ID（导出该 Plan 的所有报告）

    Returns:
        CSV 格式的字符串
    """
    query = db.query(TestReport)

    if report_ids:
        query = query.filter(TestReport.id.in_(report_ids))
    elif plan_id:
        query = query.filter(TestReport.plan_id == plan_id)

    reports = query.all()

    if not reports:
        return None

    # 创建 CSV
    output = io.StringIO()
    fieldnames = [
        "report_id",
        "report_name",
        "plan_id",
        "plan_name",
        "case_id",
        "case_name",
        "status",
        "final_score",
        "created_at",
        "stage1_judgement",
        "stage1_5_judgement",
        "stage2_judgement",
        "stage3_base_score",
        "stage3_risk_deduction",
    ]

    writer = csv.DictWriter(output, fieldnames=fieldnames)
    writer.writeheader()

    for report in reports:
        # 获取关联信息
        plan_name = None
        case_name = None

        if report.plan_id:
            plan = db.query(TestPlan).filter(TestPlan.id == report.plan_id).first()
            if plan:
                plan_name = plan.name

        if report.case_id:
            case = db.query(TestCase).filter(TestCase.case_id == report.case_id).first()
            if case:
                case_name = case.name

        # 解析评估结果
        stage1_judgement = None
        stage1_5_judgement = None
        stage2_judgement = None
        stage3_base_score = None
        stage3_risk_deduction = None

        if report.result:
            try:
                result_data = json.loads(report.result)
                if "result" in result_data and isinstance(result_data["result"], dict):
                    stage_results = result_data["result"]
                    if "stage1_structural_coverage" in stage_results:
                        stage1_judgement = stage_results["stage1_structural_coverage"].get("judgement")
                    if "stage1_5_explanation_alignment" in stage_results:
                        stage1_5_judgement = stage_results["stage1_5_explanation_alignment"].get("judgement")
                    if "stage2_engineering_judge" in stage_results:
                        stage2_judgement = stage_results["stage2_engineering_judge"].get("judgement")
                    if "stage3_risk_scoring" in stage_results:
                        stage3_base_score = stage_results["stage3_risk_scoring"].get("base_score")
                        stage3_risk_deduction = stage_results["stage3_risk_scoring"].get("risk_deduction")
            except json.JSONDecodeError:
                pass

        row = {
            "report_id": report.id,
            "report_name": report.report_name,
            "plan_id": report.plan_id or "",
            "plan_name": plan_name or "",
            "case_id": report.case_id or "",
            "case_name": case_name or "",
            "status": report.status,
            "final_score": report.final_score if report.final_score is not None else "",
            "created_at": report.created_at.strftime('%Y-%m-%d %H:%M:%S') if report.created_at else "",
            "stage1_judgement": stage1_judgement or "",
            "stage1_5_judgement": stage1_5_judgement or "",
            "stage2_judgement": stage2_judgement or "",
            "stage3_base_score": stage3_base_score if stage3_base_score is not None else "",
            "stage3_risk_deduction": stage3_risk_deduction if stage3_risk_deduction is not None else "",
        }
        writer.writerow(row)

    return output.getvalue()
