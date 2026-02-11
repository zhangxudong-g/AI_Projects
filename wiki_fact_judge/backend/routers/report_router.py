from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from backend import schemas
from backend.database import get_db
from backend.services import report_service


router = APIRouter(prefix="/reports", tags=["reports"])


@router.post("/", response_model=schemas.TestReport)
def create_report(report: schemas.TestReportCreate, db: Session = Depends(get_db)):
    db_report = report_service.create_report(db, report)
    return db_report


@router.get("/{report_id}", response_model=schemas.TestReport)
def read_report(report_id: int, db: Session = Depends(get_db)):
    db_report = report_service.get_report(db, report_id)
    if db_report is None:
        raise HTTPException(status_code=404, detail="Report not found")
    return db_report


@router.get("/", response_model=List[schemas.TestReport])
def read_reports(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    reports = report_service.get_reports(db, skip=skip, limit=limit)
    return reports


@router.put("/{report_id}", response_model=schemas.TestReport)
def update_report(report_id: int, report: schemas.TestReportUpdate, db: Session = Depends(get_db)):
    db_report = report_service.update_report(db, report_id, report)
    if db_report is None:
        raise HTTPException(status_code=404, detail="Report not found")
    return db_report


@router.delete("/{report_id}", response_model=schemas.TestReport)
def delete_report(report_id: int, db: Session = Depends(get_db)):
    db_report = report_service.delete_report(db, report_id)
    if db_report is None:
        raise HTTPException(status_code=404, detail="Report not found")
    return db_report