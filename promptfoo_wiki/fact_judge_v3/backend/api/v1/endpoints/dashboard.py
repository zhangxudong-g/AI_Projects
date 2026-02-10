from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import Dict, Any

from database.session import get_db
from core.security import get_current_user
from models.user import User as UserModel
from models.user import Case as CaseModel
from models.user import Execution as ExecutionModel
from models.user import Report as ReportModel

router = APIRouter()

@router.get("/stats")
def get_dashboard_stats(
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    获取仪表盘统计信息
    """
    total_executions = db.query(ExecutionModel).count()
    total_cases = db.query(CaseModel).count()
    total_reports = db.query(ReportModel).count()
    
    # 计算成功率 (这里简化处理，实际应根据报告结果计算)
    completed_executions = db.query(ExecutionModel).filter(ExecutionModel.status == "completed").count()
    success_rate = (completed_executions / total_executions * 100) if total_executions > 0 else 0
    
    # 获取平均分数 (如果有报告数据的话)
    avg_score = 0
    if total_reports > 0:
        # 这里需要根据实际的报告数据计算平均分
        pass
    
    recent_failures = db.query(ExecutionModel).filter(ExecutionModel.status == "failed").count()
    
    return {
        "totalExecutions": total_executions,
        "totalCases": total_cases,
        "totalReports": total_reports,
        "successRate": round(success_rate, 2),
        "averageScore": avg_score,
        "recentFailures": recent_failures
    }


@router.get("/trends")
def get_trend_data(
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    获取趋势数据
    """
    # 这里应该根据时间范围获取执行和分数的趋势数据
    # 为了演示，返回模拟数据
    return {
        "data": [
            {"date": "2026-02-01", "executions": 12, "avgScore": 75},
            {"date": "2026-02-02", "executions": 8, "avgScore": 78},
            {"date": "2026-02-03", "executions": 15, "avgScore": 72},
            {"date": "2026-02-04", "executions": 10, "avgScore": 82},
            {"date": "2026-02-05", "executions": 18, "avgScore": 76},
            {"date": "2026-02-06", "executions": 7, "avgScore": 69},
            {"date": "2026-02-07", "executions": 11, "avgScore": 74}
        ]
    }


@router.get("/recent")
def get_recent_activity(
    skip: int = 0,
    limit: int = 10,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    获取最近活动
    """
    recent_executions = db.query(ExecutionModel).order_by(ExecutionModel.created_at.desc()).offset(skip).limit(limit).all()
    
    activities = []
    for exec_item in recent_executions:
        case_info = db.query(CaseModel).filter(CaseModel.id == exec_item.case_id).first()
        activities.append({
            "id": exec_item.id,
            "case": case_info.name if case_info else "Unknown Case",
            "status": exec_item.status,
            "date": exec_item.created_at.isoformat() if exec_item.created_at else None
        })
    
    return {"activities": activities}