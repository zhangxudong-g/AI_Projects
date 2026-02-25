from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


# Test Case 相关模型
class TestCaseBase(BaseModel):
    case_id: str
    name: str
    tag: Optional[str] = None  # 用于区分不同版本的 case
    source_code_path: Optional[str] = None
    wiki_path: Optional[str] = None
    yaml_path: Optional[str] = None


class TestCaseCreate(TestCaseBase):
    pass


class TestCaseUpdate(TestCaseBase):
    pass


class TestCase(TestCaseBase):
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# Test Plan 相关模型
class TestPlanBase(BaseModel):
    name: str
    description: Optional[str] = None


class TestPlanCreate(TestPlanBase):
    case_ids: Optional[List[str]] = []


class TestPlanUpdate(TestPlanBase):
    case_ids: Optional[List[str]] = []


class TestPlan(TestPlanBase):
    id: int
    case_ids: Optional[List[str]] = []  # 添加 case_ids 字段
    created_at: datetime

    class Config:
        from_attributes = True


# Plan-Case 关联模型
class PlanCaseBase(BaseModel):
    plan_id: int
    case_id: str


class PlanCaseCreate(PlanCaseBase):
    pass


class PlanCase(PlanCaseBase):
    id: int

    class Config:
        from_attributes = True


# Test Report 相关模型
class TestReportBase(BaseModel):
    report_name: str
    plan_id: Optional[int] = None
    case_id: Optional[str] = None
    status: str = "PENDING"  # RUNNING / FINISHED / FAILED / PENDING
    final_score: Optional[float] = None
    result: Optional[str] = None
    output_path: Optional[str] = None


class TestReportCreate(TestReportBase):
    pass


class TestReportUpdate(TestReportBase):
    pass


class TestReport(TestReportBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


# 响应模型
class ApiResponse(BaseModel):
    success: bool
    message: str
    data: Optional[dict] = None