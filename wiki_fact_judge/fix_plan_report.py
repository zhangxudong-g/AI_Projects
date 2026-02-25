#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
修复 Plan Report 数据
根据 output 目录下实际生成的结果来修复 report 数据
"""

import sys
import json
from pathlib import Path

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from backend.database import SessionLocal, TestReport, TestCase
from backend.services import report_service

def fix_plan_report(report_id: int):
    """修复 plan report 数据"""
    db = SessionLocal()
    
    try:
        # 获取 report
        report = db.query(TestReport).filter(TestReport.id == report_id).first()
        if not report:
            print(f"Report {report_id} not found")
            return
        
        print(f"修复 Report: {report.report_name}")
        print(f"  Plan ID: {report.plan_id}")
        print(f"  当前状态：{report.status}")
        
        # 获取 output 目录
        output_dir = project_root / "data" / "output"
        
        # 收集所有 case 的结果
        results = []
        total_cases = 0
        completed_cases = 0
        failed_cases = 0
        total_score = 0
        
        # 遍历 output 目录下的所有 case
        for case_dir in output_dir.iterdir():
            if not case_dir.is_dir() or not case_dir.name.startswith('case_'):
                continue
            
            total_cases += 1
            case_id = case_dir.name
            
            # 读取 final_score.json
            final_score_path = case_dir / "final_score.json"
            if final_score_path.exists():
                try:
                    with open(final_score_path, 'r', encoding='utf-8') as f:
                        case_result = json.load(f)
                    
                    # 获取 case 信息
                    case = db.query(TestCase).filter(TestCase.case_id == case_id).first()
                    case_name = case.name if case else "Unknown"
                    
                    # 构建 stage_results
                    stage_results = {}
                    stage_files = {
                        'stage1': case_dir / 'stage1_result.json',
                        'stage1_5': case_dir / 'stage1_5_result.json',
                        'stage2': case_dir / 'stage2_result.json',
                        'stage3': case_dir / 'stage3_result.json'
                    }
                    for stage_name, stage_path in stage_files.items():
                        if stage_path.exists():
                            try:
                                with open(stage_path, 'r', encoding='utf-8') as f:
                                    stage_data = json.load(f)
                                stage_results[stage_name] = stage_data
                            except:
                                pass
                    
                    # 构建完整的结果记录，包含所有评估信息
                    results.append({
                        "case_id": case_id,
                        "case_name": case_name,
                        "success": True,
                        "result": case_result.get("result", "UNKNOWN"),
                        "final_score": case_result.get("final_score", 0),
                        "summary": case_result.get("summary", "")[:100] + "..." if len(case_result.get("summary", "")) > 100 else case_result.get("summary", ""),
                        # 包含完整的评估信息
                        "details": case_result.get("details", {}),
                        "engineering_action": case_result.get("engineering_action", {}),
                        "stage_results": stage_results
                    })
                    
                    completed_cases += 1
                    total_score += case_result.get("final_score", 0)
                    
                except Exception as e:
                    print(f"  读取 {case_id} 失败：{e}")
                    failed_cases += 1
                    results.append({
                        "case_id": case_id,
                        "case_name": case_name if 'case_name' in locals() else "Unknown",
                        "success": False,
                        "error": str(e)
                    })
            else:
                print(f"  Case {case_id} 没有 final_score.json")
                failed_cases += 1
                results.append({
                    "case_id": case_id,
                    "success": False,
                    "error": "final_score.json not found"
                })
        
        # 计算平均分
        average_score = total_score / completed_cases if completed_cases > 0 else 0
        
        # 构建修复后的结果
        fixed_result = {
            "status": "FINISHED" if completed_cases > 0 else "FAILED",
            "message": f"Plan completed with {completed_cases}/{total_cases} cases successful",
            "total_cases": total_cases,
            "completed_cases": completed_cases,
            "failed_cases": failed_cases,
            "average_score": round(average_score, 2),
            "results": results
        }
        
        # 更新 report
        report.status = fixed_result["status"]
        report.result = json.dumps(fixed_result, ensure_ascii=False)
        report.final_score = average_score
        db.commit()
        
        print(f"\n修复完成！")
        print(f"  总案例数：{total_cases}")
        print(f"  成功：{completed_cases}")
        print(f"  失败：{failed_cases}")
        print(f"  平均分：{average_score:.2f}")
        print(f"  状态：{report.status}")
        
    except Exception as e:
        db.rollback()
        print(f"修复失败：{e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='修复 Plan Report 数据')
    parser.add_argument('--report-id', type=int, required=True, help='要修复的 report ID')
    
    args = parser.parse_args()
    fix_plan_report(args.report_id)
