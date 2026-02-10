from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from database.session import get_db
from core.security import get_current_user
from schemas.case import Report, ReportCreate, ReportUpdate
from models.user import User as UserModel
from models.user import Report as ReportModel
from models.user import Execution as ExecutionModel
from models.user import Case as CaseModel

router = APIRouter()

@router.get("/", response_model=List[Report])
def read_reports(
    skip: int = 0, 
    limit: int = 100, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    获取报告列表
    """
    reports = db.query(ReportModel).offset(skip).limit(limit).all()
    return reports


@router.get("/{report_id}", response_model=Report)
def read_report(
    report_id: str, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    获取特定报告信息
    """
    report = db.query(ReportModel).filter(ReportModel.id == report_id).first()
    if report is None:
        raise HTTPException(status_code=404, detail="Report not found")
    return report


@router.post("/", response_model=Report)
def create_report(
    report: ReportCreate, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    创建新报告
    """
    # 检查执行和案例是否存在
    execution = db.query(ExecutionModel).filter(ExecutionModel.id == report.execution_id).first()
    case = db.query(CaseModel).filter(CaseModel.id == report.case_id).first()
    
    if not execution:
        raise HTTPException(status_code=404, detail="Execution not found")
    if not case:
        raise HTTPException(status_code=404, detail="Case not found")
    
    # 检查是否已有该执行的报告
    existing_report = db.query(ReportModel).filter(ReportModel.execution_id == report.execution_id).first()
    if existing_report:
        raise HTTPException(status_code=400, detail="Report already exists for this execution")
    
    db_report = ReportModel(
        execution_id=report.execution_id,
        case_id=report.case_id,
        final_score=report.final_score,
        result=report.result,
        details=str(report.details)  # 将字典转换为字符串存储
    )
    db.add(db_report)
    db.commit()
    db.refresh(db_report)
    return db_report


@router.put("/{report_id}", response_model=Report)
def update_report(
    report_id: str, 
    report_update: ReportUpdate, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    更新报告信息
    """
    db_report = db.query(ReportModel).filter(ReportModel.id == report_id).first()
    if db_report is None:
        raise HTTPException(status_code=404, detail="Report not found")
    
    # 检查权限 - 通常只有系统可以更新报告
    if current_user.role != "admin":
        raise HTTPException(
            status_code=403,
            detail="Only admin can update reports"
        )
    
    update_data = report_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        if field == "details" and isinstance(value, dict):
            setattr(db_report, field, str(value))  # 将字典转换为字符串存储
        else:
            setattr(db_report, field, value)
    
    db.commit()
    db.refresh(db_report)
    return db_report


@router.get("/export/{report_id}")
def export_report(
    report_id: str, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    导出报告
    """
    report = db.query(ReportModel).filter(ReportModel.id == report_id).first()
    if report is None:
        raise HTTPException(status_code=404, detail="Report not found")
    
    # 这里应该实现报告导出逻辑
    # 为了演示，返回报告数据
    return {
        "id": report.id,
        "execution_id": report.execution_id,
        "case_id": report.case_id,
        "final_score": report.final_score,
        "result": report.result,
        "details": report.details,
        "created_at": report.created_at
    }


@router.get("/charts")
def get_chart_data(
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    获取图表数据
    """
    # 获取分数分布数据
    reports = db.query(ReportModel).all()
    
    score_distribution = {}
    for report in reports:
        if report.final_score is not None:
            range_key = f"{(report.final_score // 10) * 10}-{((report.final_score // 10) + 1) * 10}"
            score_distribution[range_key] = score_distribution.get(range_key, 0) + 1
    
    # 获取成功率数据
    total_reports = len(reports)
    passed_reports = len([r for r in reports if r.result == "PASS"]) if reports else 0
    success_rate = (passed_reports / total_reports * 100) if total_reports > 0 else 0
    
    return {
        "scoreDistribution": score_distribution,
        "successRate": success_rate,
        "totalReports": total_reports
    }