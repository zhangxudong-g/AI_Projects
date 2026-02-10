from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from database.session import get_db
from core.security import get_current_user
from schemas.case import Execution, ExecutionCreate, ExecutionUpdate
from models.user import User as UserModel
from models.user import Execution as ExecutionModel
from models.user import Case as CaseModel

router = APIRouter()

@router.get("/", response_model=List[Execution])
def read_executions(
    skip: int = 0, 
    limit: int = 100, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    获取执行列表
    """
    executions = db.query(ExecutionModel).offset(skip).limit(limit).all()
    return executions


@router.get("/{execution_id}", response_model=Execution)
def read_execution(
    execution_id: str, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    获取特定执行信息
    """
    execution = db.query(ExecutionModel).filter(ExecutionModel.id == execution_id).first()
    if execution is None:
        raise HTTPException(status_code=404, detail="Execution not found")
    return execution


@router.post("/", response_model=Execution)
def create_execution(
    execution: ExecutionCreate, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    创建新执行
    """
    # 检查案例是否存在
    case = db.query(CaseModel).filter(CaseModel.id == execution.case_id).first()
    if not case:
        raise HTTPException(status_code=404, detail="Case not found")
    
    db_execution = ExecutionModel(
        case_id=execution.case_id,
        user_id=current_user.id,
        status=execution.status,
        progress=execution.progress
    )
    db.add(db_execution)
    db.commit()
    db.refresh(db_execution)
    return db_execution


@router.put("/{execution_id}", response_model=Execution)
def update_execution(
    execution_id: str, 
    execution_update: ExecutionUpdate, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    更新执行信息
    """
    db_execution = db.query(ExecutionModel).filter(ExecutionModel.id == execution_id).first()
    if db_execution is None:
        raise HTTPException(status_code=404, detail="Execution not found")
    
    # 检查权限 - 只有执行者或管理员可以更新
    if current_user.role != "admin" and db_execution.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    update_data = execution_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_execution, field, value)
    
    db.commit()
    db.refresh(db_execution)
    return db_execution


@router.put("/{execution_id}/stop")
def stop_execution(
    execution_id: str, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    停止执行
    """
    db_execution = db.query(ExecutionModel).filter(ExecutionModel.id == execution_id).first()
    if db_execution is None:
        raise HTTPException(status_code=404, detail="Execution not found")
    
    # 检查权限
    if current_user.role != "admin" and db_execution.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    db_execution.status = "stopped"
    db.commit()
    return {"message": "Execution stopped successfully"}


@router.put("/{execution_id}/pause")
def pause_execution(
    execution_id: str, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    暂停执行
    """
    db_execution = db.query(ExecutionModel).filter(ExecutionModel.id == execution_id).first()
    if db_execution is None:
        raise HTTPException(status_code=404, detail="Execution not found")
    
    # 检查权限
    if current_user.role != "admin" and db_execution.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    db_execution.status = "paused"
    db.commit()
    return {"message": "Execution paused successfully"}