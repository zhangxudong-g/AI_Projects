from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from database.session import get_db
from core.security import get_current_user
from schemas.user import User, UserCreate, UserUpdate
from models.user import User as UserModel

router = APIRouter()

@router.get("/", response_model=List[User])
def read_users(
    skip: int = 0, 
    limit: int = 100, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    获取用户列表
    """
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    users = db.query(UserModel).offset(skip).limit(limit).all()
    return users


@router.get("/{user_id}", response_model=User)
def read_user(
    user_id: str, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    获取特定用户信息
    """
    user = db.query(UserModel).filter(UserModel.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.post("/", response_model=User)
def create_user(
    user: UserCreate, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    创建新用户
    """
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    # 检查用户名或邮箱是否已存在
    existing_user = db.query(UserModel).filter(
        (UserModel.username == user.username) | (UserModel.email == user.email)
    ).first()
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username or email already registered"
        )
    
    from core.security import get_password_hash
    db_user = UserModel(
        username=user.username,
        email=user.email,
        hashed_password=get_password_hash(user.password),
        role=user.role
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


@router.put("/{user_id}", response_model=User)
def update_user(
    user_id: str, 
    user_update: UserUpdate, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    更新用户信息
    """
    db_user = db.query(UserModel).filter(UserModel.id == user_id).first()
    if db_user is None:
        raise HTTPException(status_code=404, detail="User not found")
    
    # 检查权限
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    update_data = user_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_user, field, value)
    
    db.commit()
    db.refresh(db_user)
    return db_user


@router.delete("/{user_id}")
def delete_user(
    user_id: str, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    删除用户
    """
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )
    
    db_user = db.query(UserModel).filter(UserModel.id == user_id).first()
    if db_user is None:
        raise HTTPException(status_code=404, detail="User not found")
    
    db.delete(db_user)
    db.commit()
    return {"message": "User deleted successfully"}


@router.get("/profile", response_model=User)
def read_profile(
    current_user: UserModel = Depends(get_current_user)
):
    """
    获取当前用户个人资料
    """
    return current_user


@router.put("/profile", response_model=User)
def update_profile(
    user_update: UserUpdate, 
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    更新当前用户个人资料
    """
    update_data = user_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(current_user, field, value)
    
    db.commit()
    db.refresh(current_user)
    return current_user


@router.get("/activity-log")
def get_activity_log(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    获取用户活动日志
    """
    # 这里应该实现活动日志查询逻辑
    # 为了演示，返回模拟数据
    activity_logs = [
        {"id": "log-001", "action": "login", "timestamp": "2026-02-10T10:30:00", "details": "Successful login"},
        {"id": "log-002", "action": "create_case", "timestamp": "2026-02-10T09:45:00", "details": "Created new test case"},
        {"id": "log-003", "action": "run_execution", "timestamp": "2026-02-10T08:30:00", "details": "Started execution for case-001"},
        {"id": "log-004", "action": "logout", "timestamp": "2026-02-09T18:15:00", "details": "User logged out"},
    ]
    
    return {"logs": activity_logs[skip:skip+limit], "total": len(activity_logs)}