from sqlalchemy.orm import Session
from backend.database import TestCase as TestCaseModel
from backend.schemas import TestCaseCreate, TestCaseUpdate
from typing import List, Optional
import uuid
from datetime import datetime


def create_case(db: Session, case: TestCaseCreate):
    """创建新的测试案例"""
    db_case = TestCaseModel(
        case_id=case.case_id or f"case_{uuid.uuid4().hex[:8]}",
        name=case.name,
        source_code_path=case.source_code_path,
        wiki_path=case.wiki_path,
        yaml_path=case.yaml_path,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow()
    )
    db.add(db_case)
    db.commit()
    db.refresh(db_case)
    return db_case


def get_case(db: Session, case_id: str):
    """根据ID获取测试案例"""
    return db.query(TestCaseModel).filter(TestCaseModel.case_id == case_id).first()


def get_cases(db: Session, skip: int = 0, limit: int = 100):
    """获取测试案例列表"""
    return db.query(TestCaseModel).offset(skip).limit(limit).all()


def update_case(db: Session, case_id: str, case_update: TestCaseUpdate):
    """更新测试案例"""
    db_case = db.query(TestCaseModel).filter(TestCaseModel.case_id == case_id).first()
    if db_case:
        for key, value in case_update.dict(exclude_unset=True).items():
            setattr(db_case, key, value)
        db_case.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(db_case)
    return db_case


def delete_case(db: Session, case_id: str):
    """删除测试案例"""
    db_case = db.query(TestCaseModel).filter(TestCaseModel.case_id == case_id).first()
    if db_case:
        db.delete(db_case)
        db.commit()
    return db_case