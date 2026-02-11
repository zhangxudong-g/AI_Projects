from sqlalchemy.orm import Session
from backend.database import TestPlan, PlanCase, TestCase
from backend.schemas import TestPlanCreate, TestPlanUpdate, PlanCaseCreate
from typing import List, Optional
import uuid
from datetime import datetime


def create_plan(db: Session, plan: TestPlanCreate):
    """创建新的测试计划"""
    db_plan = TestPlan(
        name=plan.name,
        description=plan.description,
        created_at=datetime.utcnow()
    )
    db.add(db_plan)
    db.commit()
    db.refresh(db_plan)
    
    # 如果提供了 case_ids，则创建关联
    if plan.case_ids:
        for case_id in plan.case_ids:
            plan_case = PlanCase(
                plan_id=db_plan.id,
                case_id=case_id
            )
            db.add(plan_case)
        db.commit()
    
    return db_plan


def get_plan(db: Session, plan_id: int):
    """根据ID获取测试计划"""
    return db.query(TestPlan).filter(TestPlan.id == plan_id).first()


def get_plans(db: Session, skip: int = 0, limit: int = 100):
    """获取测试计划列表"""
    return db.query(TestPlan).offset(skip).limit(limit).all()


def update_plan(db: Session, plan_id: int, plan_update: TestPlanUpdate):
    """更新测试计划"""
    db_plan = db.query(TestPlan).filter(TestPlan.id == plan_id).first()
    if db_plan:
        for key, value in plan_update.dict(exclude_unset=True).items():
            if key != 'case_ids':  # case_ids 需要特殊处理
                setattr(db_plan, key, value)
        
        db.commit()
        db.refresh(db_plan)
        
        # 更新关联的测试案例
        if plan_update.case_ids is not None:
            # 删除现有的关联
            db.query(PlanCase).filter(PlanCase.plan_id == plan_id).delete()
            
            # 添加新的关联
            for case_id in plan_update.case_ids:
                plan_case = PlanCase(
                    plan_id=plan_id,
                    case_id=case_id
                )
                db.add(plan_case)
            db.commit()
    
    return db_plan


def delete_plan(db: Session, plan_id: int):
    """删除测试计划"""
    # 删除关联的 PlanCase 记录
    db.query(PlanCase).filter(PlanCase.plan_id == plan_id).delete()
    
    # 删除计划本身
    db_plan = db.query(TestPlan).filter(TestPlan.id == plan_id).first()
    if db_plan:
        db.delete(db_plan)
        db.commit()
    return db_plan


def get_plan_cases(db: Session, plan_id: int):
    """获取计划中的所有测试案例"""
    plan_cases = db.query(PlanCase).filter(PlanCase.plan_id == plan_id).all()
    case_ids = [pc.case_id for pc in plan_cases]
    cases = db.query(TestCase).filter(TestCase.case_id.in_(case_ids)).all()
    return cases