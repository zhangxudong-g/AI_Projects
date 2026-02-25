"""
数据库模型和通用操作函数
"""
from sqlalchemy import create_engine, Column, Integer, String, DateTime, Float, Text, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime
from typing import TypeVar, Type, List, Optional, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy.sql import asc, desc

# 创建基类
Base = declarative_base()

# 数据库 URL - 从环境变量获取，否则使用默认值
import os
from pathlib import Path

# 获取 backend 目录的绝对路径
backend_dir = Path(__file__).resolve().parent
# 使用绝对路径确保数据库文件位置正确
DEFAULT_DB_PATH = backend_dir / "judge.db"
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{DEFAULT_DB_PATH}")

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False} if DATABASE_URL.startswith("sqlite:") else {})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db():
    """获取数据库会话的依赖项"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def create_tables():
    """创建所有数据库表"""
    Base.metadata.create_all(bind=engine)


# 定义数据库模型
class TestCase(Base):
    __tablename__ = "test_cases"

    id = Column(Integer, primary_key=True, index=True)
    case_id = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, index=True, nullable=False)
    tag = Column(String, index=True, nullable=True)  # 用于区分不同版本的 case
    source_code_path = Column(String)
    wiki_path = Column(String)
    yaml_path = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # 关联的报告
    reports = relationship("TestReport", back_populates="test_case")


class TestPlan(Base):
    __tablename__ = "test_plans"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True, nullable=False)
    description = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # 关联的报告
    reports = relationship("TestReport", back_populates="test_plan")
    # 关联的案例
    plan_cases = relationship("PlanCase", back_populates="test_plan")


class PlanCase(Base):
    __tablename__ = "plan_cases"

    id = Column(Integer, primary_key=True, index=True)
    plan_id = Column(Integer, ForeignKey("test_plans.id"))
    case_id = Column(String, ForeignKey("test_cases.case_id"))

    # 关联关系
    test_plan = relationship("TestPlan", back_populates="plan_cases")
    test_case = relationship("TestCase")


class TestReport(Base):
    __tablename__ = "test_reports"

    id = Column(Integer, primary_key=True, index=True)
    report_name = Column(String, index=True, nullable=False)
    plan_id = Column(Integer, ForeignKey("test_plans.id"), nullable=True)
    case_id = Column(String, ForeignKey("test_cases.case_id"), nullable=True)
    status = Column(String, index=True)  # RUNNING / FINISHED / FAILED / PENDING
    final_score = Column(Float)
    result = Column(Text)  # JSON 格式的结果
    output_path = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # 关联关系
    test_plan = relationship("TestPlan", back_populates="reports")
    test_case = relationship("TestCase", back_populates="reports")


# 通用数据库操作函数
T = TypeVar('T', bound=Base)


def get_items(
    db: Session,
    model: Type[T],
    skip: int = 0,
    limit: int = 100,
    order_by: str = "created_at_desc",
    filters: Optional[Dict[str, Any]] = None
) -> List[T]:
    """
    通用的获取项目列表函数

    Args:
        db: 数据库会话
        model: SQLAlchemy 模型类
        skip: 跳过的记录数
        limit: 限制返回的记录数
        order_by: 排序方式
        filters: 过滤条件字典

    Returns:
        项目列表
    """
    query = db.query(model)

    # 应用过滤条件
    if filters:
        for key, value in filters.items():
            if hasattr(model, key):
                query = query.filter(getattr(model, key) == value)

    # 处理排序
    if order_by == "created_at_asc":
        query = query.order_by(asc(model.created_at))
    elif order_by == "created_at_desc":
        query = query.order_by(desc(model.created_at))
    elif order_by == "id_asc":
        query = query.order_by(asc(model.id))
    elif order_by == "id_desc":
        query = query.order_by(desc(model.id))
    elif order_by == "name_asc":
        query = query.order_by(asc(model.name))
    elif order_by == "name_desc":
        query = query.order_by(desc(model.name))

    return query.offset(skip).limit(limit).all()


def update_item(
    db: Session,
    model: Type[T],
    item_id: int,
    item_update: Dict[str, Any]
) -> Optional[T]:
    """
    通用的更新项目函数

    Args:
        db: 数据库会话
        model: SQLAlchemy 模型类
        item_id: 项目 ID
        item_update: 更新数据字典

    Returns:
        更新后的项目，如果不存在则返回 None
    """
    item = db.query(model).filter(model.id == item_id).first()
    if item:
        for key, value in item_update.items():
            if hasattr(item, key):
                setattr(item, key, value)
        db.commit()
        db.refresh(item)
    return item


def delete_item(
    db: Session,
    model: Type[T],
    item_id: int
) -> Optional[T]:
    """
    通用的删除项目函数

    Args:
        db: 数据库会话
        model: SQLAlchemy 模型类
        item_id: 项目 ID

    Returns:
        删除的项目，如果不存在则返回 None
    """
    item = db.query(model).filter(model.id == item_id).first()
    if item:
        db.delete(item)
        db.commit()
    return item


def bulk_delete_items(
    db: Session,
    model: Type[T],
    item_ids: List[int]
) -> List[T]:
    """
    通用的批量删除项目函数

    Args:
        db: 数据库会话
        model: SQLAlchemy 模型类
        item_ids: 项目 ID 列表

    Returns:
        实际删除的项目列表
    """
    items = db.query(model).filter(model.id.in_(item_ids)).all()
    for item in items:
        db.delete(item)
    db.commit()
    return items
