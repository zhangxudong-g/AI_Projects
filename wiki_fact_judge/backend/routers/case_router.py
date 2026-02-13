import json
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from typing import List
import os
from backend import schemas
from backend.database import get_db
from backend.services import case_service
import uuid
from pathlib import Path
from backend.utils import save_uploaded_file, ALLOWED_EXTENSIONS, MAX_FILE_SIZE

router = APIRouter(prefix="/cases", tags=["cases"])


@router.post("/", response_model=schemas.TestCase)
def create_case(
    name: str = Form(...),
    source_code: UploadFile = File(None),
    wiki: UploadFile = File(None),
    yaml_file: UploadFile = File(None),
    db: Session = Depends(get_db)
):
    # 生成唯一 case_id
    case_id = f"case_{uuid.uuid4().hex[:8]}"

    # 准备文件存储路径 - 使用绝对路径
    project_root = Path(__file__).parent.parent.parent  # 获取项目根目录 (backend 的父目录)
    case_dir = project_root / "data" / "cases" / case_id
    case_dir.mkdir(parents=True, exist_ok=True)

    source_code_path = None
    wiki_path = None
    yaml_path = None

    # 保存上传的文件，带安全验证
    if source_code:
        source_code_path = save_uploaded_file(source_code, str(case_dir))

    if wiki:
        wiki_path = save_uploaded_file(wiki, str(case_dir))

    if yaml_file:
        yaml_path = save_uploaded_file(yaml_file, str(case_dir))

    # 存储相对于项目根目录的路径（这样可以在任何地方正确访问）
    if source_code_path:
        source_code_path = str(Path(source_code_path).relative_to(project_root))
    if wiki_path:
        wiki_path = str(Path(wiki_path).relative_to(project_root))
    if yaml_path:
        yaml_path = str(Path(yaml_path).relative_to(project_root))

    # 创建数据库记录
    case_data = schemas.TestCaseCreate(
        case_id=case_id,
        name=name,
        source_code_path=source_code_path,
        wiki_path=wiki_path,
        yaml_path=yaml_path
    )

    db_case = case_service.create_case(db, case_data)
    return db_case


@router.post("/batch")
def upload_batch_cases(files: List[UploadFile] = File(...), db: Session = Depends(get_db)):
    # 这里实现批量上传逻辑
    # 暂时只返回成功消息
    return {"message": f"成功上传 {len(files)} 个文件", "filenames": [f.filename for f in files]}


@router.get("/{case_id}", response_model=schemas.TestCase)
def read_case(case_id: str, db: Session = Depends(get_db)):
    db_case = case_service.get_case(db, case_id)
    if db_case is None:
        raise HTTPException(status_code=404, detail="Case not found")
    return db_case


@router.get("/", response_model=List[schemas.TestCase])
def read_cases(skip: int = 0, limit: int = 100, order_by: str = "created_at_desc", db: Session = Depends(get_db)):
    cases = case_service.get_cases(db, skip=skip, limit=limit, order_by=order_by)
    return cases


@router.put("/{case_id}", response_model=schemas.TestCase)
def update_case(case_id: str, case: schemas.TestCaseUpdate, db: Session = Depends(get_db)):
    db_case = case_service.update_case(db, case_id, case)
    if db_case is None:
        raise HTTPException(status_code=404, detail="Case not found")
    return db_case


# 添加新的文件上传更新路由
@router.post("/{case_id}/update_files", response_model=schemas.TestCase)
async def update_case_files(
    case_id: str,
    name: str = Form(None),
    source_code: UploadFile = File(None),
    wiki: UploadFile = File(None),
    yaml_file: UploadFile = File(None),
    db: Session = Depends(get_db)
):
    # 获取现有案例
    db_case = case_service.get_case(db, case_id)
    if db_case is None:
        raise HTTPException(status_code=404, detail="Case not found")

    # 准备文件存储路径
    project_root = Path(__file__).parent.parent.parent  # 获取项目根目录 (backend 的父目录)
    case_dir = project_root / "data" / "cases" / case_id
    case_dir.mkdir(parents=True, exist_ok=True)

    # 更新文件路径
    source_code_path = db_case.source_code_path
    wiki_path = db_case.wiki_path
    yaml_path = db_case.yaml_path

    # 更新文件，带安全验证
    if source_code:
        source_code_path = save_uploaded_file(source_code, str(case_dir))

    if wiki:
        wiki_path = save_uploaded_file(wiki, str(case_dir))

    if yaml_file:
        yaml_path = save_uploaded_file(yaml_file, str(case_dir))

    # 更新数据库记录
    update_data = {
        "case_id": case_id,
        "name": name or db_case.name,
        "source_code_path": source_code_path,
        "wiki_path": wiki_path,
        "yaml_path": yaml_path
    }

    case_update = schemas.TestCaseUpdate(**update_data)
    db_case = case_service.update_case(db, case_id, case_update)
    return db_case


@router.delete("/{case_id}", response_model=schemas.TestCase)
def delete_case(case_id: str, db: Session = Depends(get_db)):
    db_case = case_service.delete_case(db, case_id)
    if db_case is None:
        raise HTTPException(status_code=404, detail="Case not found")
    return db_case


@router.delete("/", response_model=List[schemas.TestCase])
def bulk_delete_cases(case_ids: List[str], db: Session = Depends(get_db)):
    db_cases = case_service.bulk_delete_cases(db, case_ids)
    # 即使没有找到案例也返回成功，但包含实际删除数量信息
    return db_cases


@router.post("/{case_id}/run")
def run_case(case_id: str, db: Session = Depends(get_db)):
    from backend.services.pipeline_service import run_case as run_pipeline_case

    # 在这里调用 pipeline_service.run_case
    result = run_pipeline_case(db, case_id)

    # 创建报告记录
    from backend.services.report_service import create_report
    from backend.schemas import TestReportCreate

    report_data = TestReportCreate(
        report_name=f"Report for {case_id}",
        case_id=case_id,
        status="FINISHED" if result.get("success") else "FAILED",
        final_score=result.get("result", {}).get("final_score"),
        result=json.dumps(result, ensure_ascii=False),  # 序列化为JSON字符串
        output_path=result.get("output_path")
    )

    report = create_report(db, report_data)

    return {
        "case_id": case_id,
        "result": result,
        "report_id": report.id
    }