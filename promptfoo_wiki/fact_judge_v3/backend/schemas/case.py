from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

class CaseBase(BaseModel):
    name: str
    description: Optional[str] = None
    config_yaml: str

class CaseCreate(CaseBase):
    pass

class CaseUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    config_yaml: Optional[str] = None
    status: Optional[str] = None

class Case(CaseBase):
    id: str
    created_by: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    status: str = "active"

    class Config:
        from_attributes = True

class CaseWithExecutions(Case):
    executions: List['Execution'] = []

class ExecutionBase(BaseModel):
    case_id: str
    status: str = "queued"  # queued, running, completed, failed, stopped, paused, scheduled
    progress: int = 0

class ExecutionCreate(ExecutionBase):
    pass

class ExecutionUpdate(BaseModel):
    status: Optional[str] = None
    progress: Optional[int] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None

class Execution(ExecutionBase):
    id: str
    user_id: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True

class ReportBase(BaseModel):
    execution_id: str
    case_id: str
    final_score: Optional[int] = None
    result: Optional[str] = None
    details: Optional[dict] = None

class ReportCreate(ReportBase):
    pass

class ReportUpdate(BaseModel):
    final_score: Optional[int] = None
    result: Optional[str] = None
    details: Optional[dict] = None

class Report(ReportBase):
    id: str
    created_at: datetime

    class Config:
        from_attributes = True