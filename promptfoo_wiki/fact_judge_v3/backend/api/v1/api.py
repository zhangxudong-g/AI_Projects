from fastapi import APIRouter
from api.v1.endpoints import users, cases, executions, reports, dashboard

api_router = APIRouter()

# 用户相关路由
api_router.include_router(users.router, prefix="/users", tags=["users"])

# 案例相关路由
api_router.include_router(cases.router, prefix="/cases", tags=["cases"])

# 执行相关路由
api_router.include_router(executions.router, prefix="/executions", tags=["executions"])

# 报告相关路由
api_router.include_router(reports.router, prefix="/reports", tags=["reports"])

# 仪表盘相关路由
api_router.include_router(dashboard.router, prefix="/dashboard", tags=["dashboard"])