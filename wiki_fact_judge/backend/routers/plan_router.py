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
    result = run_pipeline_plan(db, plan_id)

    # 更新已存在的计划报告，而不是创建新的
    from backend.services.report_service import get_reports_by_plan
    from sqlalchemy.orm import Session
    
    # 获取与该计划关联的最新报告（即Plan_Report_XXX）
    plan_reports = get_reports_by_plan(db, plan_id)
    
    if plan_reports:
        # 获取最新的报告进行更新
        latest_report = max(plan_reports, key=lambda r: r.created_at if r.created_at else r.id)
        
        # 更新报告信息
        latest_report.status = "FINISHED"
        latest_report.final_score = result.get("average_score")
        latest_report.result = json.dumps(result, ensure_ascii=False)
        
        # 提交更改
        db.commit()
        db.refresh(latest_report)
        
        return {
            "plan_id": plan_id,
            "result": result,
            "report_id": latest_report.id
        }
    else:
        # 如果没有找到现有报告，则创建一个
        from backend.services.report_service import create_report
        from backend.schemas import TestReportCreate

        report_data = TestReportCreate(
            report_name=f"Plan_Report_{plan_id}",
            plan_id=plan_id,
            status="FINISHED",
            final_score=result.get("average_score"),
            result=json.dumps(result, ensure_ascii=False),  # 序列化为JSON字符串
            output_path=None
        )

        report = create_report(db, report_data)

        return {
            "plan_id": plan_id,
            "result": result,
            "report_id": report.id
        }