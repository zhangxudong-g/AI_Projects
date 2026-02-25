from sqlalchemy.orm import Session
from backend.database import TestReport, TestPlan, TestCase, get_items, update_item, delete_item, bulk_delete_items
from backend.schemas import TestReportCreate, TestReportUpdate
from typing import List, Optional
import uuid
from datetime import datetime
import random


def generate_unique_report_name(case_id: Optional[str] = None, plan_id: Optional[int] = None, db: Optional[Session] = None) -> str:
    """
    生成唯一的报告名称
    
    Args:
        case_id: 案例 ID（如果为案例生成报告）
        plan_id: 计划 ID（如果为计划生成报告）
        db: 数据库会话（用于验证唯一性）
        
    Returns:
        唯一的报告名称，格式：report_{id}_{timestamp}_{random}
    """
    # 确定标识符
    if case_id:
        identifier = case_id
    elif plan_id:
        identifier = str(plan_id)
    else:
        identifier = "unknown"
    
    # 生成时间戳（精确到秒）
    timestamp = datetime.utcnow().strftime("%Y%m%d%H%M%S")
    
    # 生成 6 位随机数（十六进制）
    random_suffix = format(random.randint(0, 0xFFFFFF), '06x')
    
    report_name = f"report_{identifier}_{timestamp}_{random_suffix}"
    
    # 如果提供了数据库会话，验证唯一性
    if db:
        max_retries = 10
        retries = 0
        while db.query(TestReport).filter(TestReport.report_name == report_name).first():
            if retries >= max_retries:
                raise Exception(f"Failed to generate unique report name after {max_retries} retries")
            # 重新生成随机数
            random_suffix = format(random.randint(0, 0xFFFFFF), '06x')
            report_name = f"report_{identifier}_{timestamp}_{random_suffix}"
            retries += 1
    
    return report_name


def ensure_unique_report_name(report: TestReport, db: Session):
    """
    确保报告有唯一的名称，如果没有则自动生成
    
    Args:
        report: TestReport 对象（会被修改）
        db: 数据库会话
    """
    if not report.report_name:
        report.report_name = generate_unique_report_name(
            case_id=report.case_id,
            plan_id=report.plan_id,
            db=db
        )


def create_report(db: Session, report: TestReportCreate):
    """
    创建新的测试报告
    
    如果未提供 report_name，自动生成唯一的报告名称
    """
    # 如果没有提供报告名称，自动生成唯一名称
    report_name = report.report_name
    if not report_name:
        report_name = generate_unique_report_name(
            case_id=report.case_id,
            plan_id=report.plan_id,
            db=db
        )
    
    db_report = TestReport(
        report_name=report_name,
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