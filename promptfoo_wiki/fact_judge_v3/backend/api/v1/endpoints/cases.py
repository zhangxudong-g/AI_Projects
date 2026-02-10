from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile
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


@router.post("/import")
def import_cases(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    批量导入案例
    """
    import json
    import yaml
    
    try:
        # 读取上传的文件
        content = file.file.read().decode("utf-8")
        
        # 根据文件扩展名解析内容
        if file.filename.endswith('.json'):
            cases_data = json.loads(content)
        elif file.filename.endswith('.yaml') or file.filename.endswith('.yml'):
            cases_data = yaml.safe_load(content)
        else:
            raise HTTPException(
                status_code=400,
                detail="Unsupported file format. Please upload JSON or YAML file."
            )
        
        imported_count = 0
        for case_data in cases_data:
            # 创建新案例
            db_case = CaseModel(
                name=case_data.get("name"),
                description=case_data.get("description", ""),
                config_yaml=yaml.dump(case_data.get("config", {})),
                created_by=current_user.id
            )
            db.add(db_case)
            imported_count += 1
        
        db.commit()
        return {"message": f"Successfully imported {imported_count} cases", "imported_count": imported_count}
    
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail=f"Error importing cases: {str(e)}"
        )


@router.get("/templates")
def get_case_templates(
    db: Session = Depends(get_db),
    current_user: UserModel = Depends(get_current_user)
):
    """
    获取案例模板列表
    """
    # 这里可以返回预定义的案例模板
    templates = [
        {
            "id": "template-001",
            "name": "Java Controller Template",
            "description": "Template for evaluating Java controllers",
            "configYaml": "type: java-controller\ntechnology: spring-boot\nfeatures:\n  - rest-api\n  - validation\n"
        },
        {
            "id": "template-002",
            "name": "SQL Procedure Template",
            "description": "Template for evaluating SQL procedures",
            "configYaml": "type: sql-procedure\ndatabase: oracle\nfeatures:\n  - transaction\n  - error-handling\n"
        }
    ]
    return {"templates": templates}