from sqlalchemy.orm import Session
from backend.database import TestCase as TestCaseModel, get_items, update_item, delete_item, bulk_delete_items
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


def get_cases(db: Session, skip: int = 0, limit: int = 100, order_by: str = "created_at_desc"):
    """获取测试案例列表"""
    # 使用通用的get_items函数，但需要处理case_id字段的特殊情况
    # 因为TestCase使用case_id而不是id作为主要标识符
    valid_orders = ["created_at_asc", "created_at_desc", "id_asc", "id_desc", "name_asc", "name_desc"]
    if order_by not in valid_orders:
        raise ValueError(f"Invalid order_by value. Must be one of {valid_orders}")

    query = db.query(TestCaseModel)

    # 根据order_by参数决定排序方式
    if order_by == "created_at_asc":
        query = query.order_by(TestCaseModel.created_at.asc())
    elif order_by == "created_at_desc":
        query = query.order_by(TestCaseModel.created_at.desc())
    elif order_by == "id_asc":
        query = query.order_by(TestCaseModel.id.asc())
    elif order_by == "id_desc":
        query = query.order_by(TestCaseModel.id.desc())
    elif order_by == "name_asc":
        query = query.order_by(TestCaseModel.name.asc())
    elif order_by == "name_desc":
        query = query.order_by(TestCaseModel.name.desc())

    return query.offset(skip).limit(limit).all()


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


def bulk_delete_cases(db: Session, case_ids: List[str]):
    """批量删除测试案例"""
    # 获取所有要删除的案例
    db_cases = db.query(TestCaseModel).filter(TestCaseModel.case_id.in_(case_ids)).all()

    # 删除存在的案例
    for db_case in db_cases:
        db.delete(db_case)
    db.commit()

    # 返回实际删除的案例
    return db_cases