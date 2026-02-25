from sqlalchemy.orm import Session
from backend.database import TestCase as TestCaseModel, get_items, update_item, delete_item, bulk_delete_items
from backend.schemas import TestCaseCreate, TestCaseUpdate
from typing import List, Optional
import uuid
from datetime import datetime
import os
import logging
from pathlib import Path

# 配置：删除案例时是否同步删除文件
DELETE_CASE_FILES_SYNC = os.getenv("DELETE_CASE_FILES_SYNC", "false").lower() == "true"

# 日志配置
logger = logging.getLogger(__name__)

# 项目根目录（用于构建绝对路径）
PROJECT_ROOT = Path(__file__).parent.parent.parent


def _validate_case_file_path(file_path: str) -> bool:
    """
    验证案例文件路径是否在安全目录内
    
    Args:
        file_path: 文件路径（相对路径或绝对路径）
        
    Returns:
        bool: 路径是否安全
    """
    if not file_path:
        return False
    
    # 转换为绝对路径
    abs_path = Path(file_path) if Path(file_path).is_absolute() else PROJECT_ROOT / file_path
    
    # 解析路径（解决 .. 等问题）
    try:
        resolved_path = abs_path.resolve()
    except (OSError, ValueError):
        return False
    
    # 检查路径是否在 data/cases/ 目录下
    cases_dir = (PROJECT_ROOT / "data" / "cases").resolve()
    
    try:
        resolved_path.relative_to(cases_dir)
        return True
    except ValueError:
        logger.warning(f"文件路径 {file_path} 不在 data/cases/ 目录下，跳过删除")
        return False


def _delete_case_files(db_case: TestCaseModel):
    """
    删除案例关联的所有文件
    
    Args:
        db_case: 数据库案例对象
        
    Note:
        文件删除失败不会影响数据库操作，仅记录日志
    """
    if not db_case:
        return
    
    file_paths = [db_case.source_code_path, db_case.wiki_path, db_case.yaml_path]
    
    for file_path in file_paths:
        if not file_path:
            continue
        
        # 验证路径安全性
        if not _validate_case_file_path(file_path):
            continue
        
        # 转换为绝对路径
        abs_path = PROJECT_ROOT / file_path if not Path(file_path).is_absolute() else Path(file_path)
        
        try:
            if abs_path.exists():
                abs_path.unlink()
                logger.info(f"成功删除文件：{file_path}")
            else:
                logger.warning(f"文件不存在，跳过：{file_path}")
        except PermissionError as e:
            logger.error(f"权限不足，无法删除文件：{file_path} - {str(e)}")
        except OSError as e:
            logger.error(f"删除文件失败：{file_path} - {str(e)}")
        except Exception as e:
            logger.error(f"删除文件时发生未知错误：{file_path} - {str(e)}")


def create_case(db: Session, case: TestCaseCreate):
    """创建新的测试案例"""
    db_case = TestCaseModel(
        case_id=case.case_id or f"case_{uuid.uuid4().hex[:8]}",
        name=case.name,
        tag=case.tag,  # 添加 tag 字段
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
        # 如果配置启用，先删除文件
        if DELETE_CASE_FILES_SYNC:
            _delete_case_files(db_case)
        
        # 删除数据库记录
        db.delete(db_case)
        db.commit()
        logger.info(f"删除案例：{case_id} (文件同步删除：{DELETE_CASE_FILES_SYNC})")
    return db_case


def bulk_delete_cases(db: Session, case_ids: List[str]):
    """批量删除测试案例"""
    # 获取所有要删除的案例
    db_cases = db.query(TestCaseModel).filter(TestCaseModel.case_id.in_(case_ids)).all()

    # 如果配置启用，先删除所有文件
    if DELETE_CASE_FILES_SYNC:
        for db_case in db_cases:
            _delete_case_files(db_case)
        logger.info(f"批量删除 {len(db_cases)} 个案例的文件 (文件同步删除：{DELETE_CASE_FILES_SYNC})")

    # 删除数据库记录
    for db_case in db_cases:
        db.delete(db_case)
    db.commit()

    logger.info(f"批量删除 {len(db_cases)} 个案例记录")

    # 返回实际删除的案例
    return db_cases


def get_all_tags(db: Session):
    """
    获取所有唯一的 tag 值
    
    Args:
        db: 数据库会话
        
    Returns:
        List[str]: 所有唯一的 tag 列表
    """
    results = db.query(TestCaseModel.tag).filter(TestCaseModel.tag.isnot(None)).distinct().all()
    return [tag for (tag,) in results]


def get_cases_by_tag(db: Session, tag: str, skip: int = 0, limit: int = 100, order_by: str = "created_at_desc"):
    """
    根据 tag 获取测试案例列表
    
    Args:
        db: 数据库会话
        tag: tag 值
        skip: 跳过的记录数
        limit: 限制返回的记录数
        order_by: 排序方式
        
    Returns:
        List[TestCaseModel]: 测试案例列表
    """
    query = db.query(TestCaseModel).filter(TestCaseModel.tag == tag)
    
    # 根据 order_by 参数决定排序方式
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