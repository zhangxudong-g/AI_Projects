from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session
from typing import List, Optional
from backend import schemas
from backend.database import get_db
from backend.services import report_service, export_service
import json


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
def read_reports(skip: int = 0, limit: int = 100, order_by: str = "created_at_desc", db: Session = Depends(get_db)):
    reports = report_service.get_reports(db, skip=skip, limit=limit, order_by=order_by)
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


@router.delete("/", response_model=List[schemas.TestReport])
def bulk_delete_reports(report_ids: List[int], db: Session = Depends(get_db)):
    db_reports = report_service.bulk_delete_reports(db, report_ids)
    # 即使没有找到报告也返回成功，但包含实际删除数量信息
    return db_reports


@router.get("/plan/{plan_id}/summary", response_model=dict)
def get_plan_summary(plan_id: int, db: Session = Depends(get_db)):
    """获取 Plan 的汇总信息（最大/最小/平均分，summary 等）"""
    summary = report_service.calculate_plan_summary(db, plan_id)
    if summary is None:
        raise HTTPException(status_code=404, detail="No reports found for this plan")
    return summary


# ==================== 导出功能端点 ====================

@router.get("/{report_id}/export/json")
def export_report_json(report_id: int, db: Session = Depends(get_db)):
    """
    导出单个报告为 JSON 格式
    """
    export_data = export_service.export_report_to_json(db, report_id)
    if export_data is None:
        raise HTTPException(status_code=404, detail="Report not found")

    return Response(
        content=json.dumps(export_data, ensure_ascii=False, indent=2),
        media_type="application/json",
        headers={
            "Content-Disposition": f"attachment; filename=report_{report_id}.json"
        }
    )


@router.get("/{report_id}/export/markdown")
def export_report_markdown(report_id: int, db: Session = Depends(get_db)):
    """
    导出单个报告为 Markdown 格式
    """
    md_content = export_service.export_report_to_markdown(db, report_id)
    if md_content is None:
        raise HTTPException(status_code=404, detail="Report not found")

    return Response(
        content=md_content,
        media_type="text/markdown",
        headers={
            "Content-Disposition": f"attachment; filename=report_{report_id}.md"
        }
    )


@router.get("/{report_id}/export/csv")
def export_report_csv(report_id: int, db: Session = Depends(get_db)):
    """
    导出单个报告为 CSV 格式
    """
    csv_content = export_service.export_reports_to_csv(db, report_ids=[report_id])
    if csv_content is None:
        raise HTTPException(status_code=404, detail="Report not found")

    return Response(
        content=csv_content,
        media_type="text/csv",
        headers={
            "Content-Disposition": f"attachment; filename=report_{report_id}.csv"
        }
    )


@router.get("/plan/{plan_id}/export/json")
def export_plan_json(plan_id: int, db: Session = Depends(get_db)):
    """
    导出整个 Plan 的所有报告为 JSON 格式
    """
    export_data = export_service.export_plan_reports_to_json(db, plan_id)
    if export_data is None:
        raise HTTPException(status_code=404, detail="Plan not found")

    return Response(
        content=json.dumps(export_data, ensure_ascii=False, indent=2),
        media_type="application/json",
        headers={
            "Content-Disposition": f"attachment; filename=plan_{plan_id}_reports.json"
        }
    )


@router.get("/plan/{plan_id}/export/markdown")
def export_plan_markdown(plan_id: int, db: Session = Depends(get_db)):
    """
    导出整个 Plan 的所有报告为 Markdown 格式
    """
    md_content = export_service.export_plan_reports_to_markdown(db, plan_id)
    if md_content is None:
        raise HTTPException(status_code=404, detail="Plan not found")

    return Response(
        content=md_content,
        media_type="text/markdown",
        headers={
            "Content-Disposition": f"attachment; filename=plan_{plan_id}_reports.md"
        }
    )


@router.get("/plan/{plan_id}/export/csv")
def export_plan_csv(plan_id: int, db: Session = Depends(get_db)):
    """
    导出整个 Plan 的所有报告为 CSV 格式
    """
    csv_content = export_service.export_reports_to_csv(db, plan_id=plan_id)
    if csv_content is None:
        raise HTTPException(status_code=404, detail="Plan not found or no reports available")

    return Response(
        content=csv_content,
        media_type="text/csv",
        headers={
            "Content-Disposition": f"attachment; filename=plan_{plan_id}_reports.csv"
        }
    )


@router.post("/export/csv")
def export_reports_csv_batch(
    report_ids: List[int],
    db: Session = Depends(get_db)
):
    """
    批量导出指定报告为 CSV 格式
    """
    csv_content = export_service.export_reports_to_csv(db, report_ids=report_ids)
    if csv_content is None:
        raise HTTPException(status_code=404, detail="No reports found")

    return Response(
        content=csv_content,
        media_type="text/csv",
        headers={
            "Content-Disposition": "attachment; filename=reports_export.csv"
        }
    )
