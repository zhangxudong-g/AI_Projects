from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from database.session import get_db
from core.security import get_current_user
from schemas.case import Case, CaseCreate, CaseUpdate, CaseWithExecutions
from models.user import User as UserModel
from models.user import Case as CaseModel

router = APIRouter()

@router.get("/", response_model=List[Case])
def read_cases(
    skip: int = 0, 
    limit: int = 100, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    获取案例列表
    """
    cases = db.query(CaseModel).offset(skip).limit(limit).all()
    return cases


@router.get("/{case_id}", response_model=CaseWithExecutions)
def read_case(
    case_id: str, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    获取特定案例信息
    """
    case = db.query(CaseModel).filter(CaseModel.id == case_id).first()
    if case is None:
        raise HTTPException(status_code=404, detail="Case not found")
    return case


@router.post("/", response_model=Case)
def create_case(
    case: CaseCreate, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    创建新案例
    """
    db_case = CaseModel(
        name=case.name,
        description=case.description,
        config_yaml=case.config_yaml,
        created_by=current_user.id
    )
    db.add(db_case)
    db.commit()
    db.refresh(db_case)
    return db_case


@router.put("/{case_id}", response_model=Case)
def update_case(
    case_id: str, 
    case_update: CaseUpdate, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    更新案例信息
    """
    db_case = db.query(CaseModel).filter(CaseModel.id == case_id).first()
    if db_case is None:
        raise HTTPException(status_code=404, detail="Case not found")
    
    # 检查权限 - 只有创建者或管理员可以更新
    if current_user.role != "admin" and db_case.created_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    update_data = case_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_case, field, value)
    
    db.commit()
    db.refresh(db_case)
    return db_case


@router.delete("/{case_id}")
def delete_case(
    case_id: str, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    删除案例
    """
    db_case = db.query(CaseModel).filter(CaseModel.id == case_id).first()
    if db_case is None:
        raise HTTPException(status_code=404, detail="Case not found")
    
    # 检查权限 - 只有创建者或管理员可以删除
    if current_user.role != "admin" and db_case.created_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    db.delete(db_case)
    db.commit()
    return {"message": "Case deleted successfully"}