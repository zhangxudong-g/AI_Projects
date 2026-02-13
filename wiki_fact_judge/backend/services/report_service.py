from sqlalchemy.orm import Session
from backend.database import TestReport, TestPlan, TestCase, get_items, update_item, delete_item, bulk_delete_items
from backend.schemas import TestReportCreate, TestReportUpdate
from typing import List, Optional
import uuid
from datetime import datetime


def create_report(db: Session, report: TestReportCreate):
    """创建新的测试报告"""
    db_report = TestReport(
        report_name=report.report_name,
        plan_id=report.plan_id,
        case_id=report.case_id,
        status=report.status,
        final_score=report.final_score,
        result=report.result,
        output_path=report.output_path,
        created_at=datetime.utcnow()
    )
    db.add(db_report)
    db.commit()
    db.refresh(db_report)
    return db_report


def get_report(db: Session, report_id: int):
    """根据ID获取测试报告"""
    return db.query(TestReport).filter(TestReport.id == report_id).first()


def get_reports(db: Session, skip: int = 0, limit: int = 100, order_by: str = "created_at_desc"):
    """获取测试报告列表"""
    return get_items(db, TestReport, skip=skip, limit=limit, order_by=order_by)


def get_reports_by_case(db: Session, case_id: str):
    """根据案例ID获取测试报告"""
    return db.query(TestReport).filter(TestReport.case_id == case_id).all()


def get_reports_by_plan(db: Session, plan_id: int):
    """根据计划ID获取测试报告"""
    return db.query(TestReport).filter(TestReport.plan_id == plan_id).all()


def update_report(db: Session, report_id: int, report_update: TestReportUpdate):
    """更新测试报告"""
    db_report = db.query(TestReport).filter(TestReport.id == report_id).first()
    if db_report:
        for key, value in report_update.dict(exclude_unset=True).items():
            setattr(db_report, key, value)
        db.commit()
        db.refresh(db_report)
    return db_report


def delete_report(db: Session, report_id: int):
    """删除测试报告"""
    db_report = db.query(TestReport).filter(TestReport.id == report_id).first()
    if db_report:
        db.delete(db_report)
        db.commit()
    return db_report


def bulk_delete_reports(db: Session, report_ids: List[int]):
    """批量删除测试报告"""
    return bulk_delete_items(db, TestReport, report_ids)


def calculate_plan_summary(db: Session, plan_id: int):
    """计算Plan的汇总信息（最大/最小/平均分，summary等）"""
    # 获取属于该计划的所有报告
    plan_reports = get_reports_by_plan(db, plan_id)

    if not plan_reports:
        return None

    # 提取所有有效分数
    scores = [report.final_score for report in plan_reports if report.final_score is not None]

    if not scores:
        return {
            'plan_id': plan_id,
            'total_reports': len(plan_reports),
            'completed_reports': len([r for r in plan_reports if r.status == 'FINISHED']),
            'average_score': None,
            'max_score': None,
            'min_score': None,
            'summary': 'No scores available for this plan'
        }

    average_score = sum(scores) / len(scores)
    max_score = max(scores)
    min_score = min(scores)

    # 生成摘要信息
    completed_reports = [r for r in plan_reports if r.status == 'FINISHED']
    failed_reports = [r for r in plan_reports if r.status == 'FAILED']

    summary = f"Plan {plan_id} has {len(plan_reports)} total reports, " \
              f"{len(completed_reports)} completed, {len(failed_reports)} failed. " \
              f"Average score: {average_score:.2f}, Max: {max_score:.2f}, Min: {min_score:.2f}"

    return {
        'plan_id': plan_id,
        'total_reports': len(plan_reports),
        'completed_reports': len(completed_reports),
        'failed_reports': len(failed_reports),
        'average_score': average_score,
        'max_score': max_score,
        'min_score': min_score,
        'summary': summary
    }