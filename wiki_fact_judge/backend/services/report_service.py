from sqlalchemy.orm import Session
from backend.database import TestReport, TestPlan, TestCase
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


def get_reports(db: Session, skip: int = 0, limit: int = 100):
    """获取测试报告列表"""
    return db.query(TestReport).offset(skip).limit(limit).all()


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