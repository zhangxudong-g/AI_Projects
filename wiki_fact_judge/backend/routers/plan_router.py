import json
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from backend import schemas
from backend.database import get_db
from backend.services import plan_service
import uuid
from datetime import datetime


router = APIRouter(prefix="/plans", tags=["plans"])


@router.post("/", response_model=schemas.TestPlan)
def create_plan(plan: schemas.TestPlanCreate, db: Session = Depends(get_db)):
    db_plan = plan_service.create_plan(db, plan)
    return db_plan


@router.get("/{plan_id}", response_model=schemas.TestPlan)
def read_plan(plan_id: int, db: Session = Depends(get_db)):
    db_plan = plan_service.get_plan(db, plan_id)
    if db_plan is None:
        raise HTTPException(status_code=404, detail="Plan not found")
    return db_plan


@router.get("/", response_model=List[schemas.TestPlan])
def read_plans(skip: int = 0, limit: int = 100, order_by: str = "created_at_desc", db: Session = Depends(get_db)):
    plans = plan_service.get_plans(db, skip=skip, limit=limit, order_by=order_by)
    return plans


@router.put("/{plan_id}", response_model=schemas.TestPlan)
def update_plan(plan_id: int, plan: schemas.TestPlanUpdate, db: Session = Depends(get_db)):
    db_plan = plan_service.update_plan(db, plan_id, plan)
    if db_plan is None:
        raise HTTPException(status_code=404, detail="Plan not found")
    return db_plan


@router.delete("/{plan_id}", response_model=schemas.TestPlan)
def delete_plan(plan_id: int, db: Session = Depends(get_db)):
    db_plan = plan_service.delete_plan(db, plan_id)
    if db_plan is None:
        raise HTTPException(status_code=404, detail="Plan not found")
    return db_plan


@router.delete("/", response_model=List[schemas.TestPlan])
def bulk_delete_plans(plan_ids: List[int], db: Session = Depends(get_db)):
    db_plans = plan_service.bulk_delete_plans(db, plan_ids)
    # 即使没有找到计划也返回成功，但包含实际删除数量信息
    return db_plans


@router.post("/{plan_id}/run")
def run_plan(plan_id: int, db: Session = Depends(get_db)):
    from backend.services.pipeline_service import run_plan as run_pipeline_plan

    # 在这里调用 pipeline_service.run_plan
    # pipeline_service 内部会创建/更新 Plan_Report_{plan_id} 用于进度跟踪和结果汇总
    result = run_pipeline_plan(db, plan_id)

    # 获取 pipeline_service 创建的报告 ID
    from backend.database import TestReport
    plan_report = (
        db.query(TestReport)
        .filter(TestReport.plan_id == plan_id)
        .order_by(TestReport.created_at.desc())
        .first()
    )

    return {
        "plan_id": plan_id,
        "result": result,
        "report_id": plan_report.id if plan_report else None
    }
