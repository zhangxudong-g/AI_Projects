import sys
import os
from pathlib import Path

# Add the project root directory to Python path if needed
if __name__ == "__main__" or "backend.main" not in sys.modules:
    project_root = Path(__file__).parent.parent
    sys.path.insert(0, str(project_root))

from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from backend.database import engine, create_tables, get_db
from backend.routers import case_router, plan_router, report_router
from fastapi.middleware.cors import CORSMiddleware


# 创建数据库表
create_tables()

# 创建 FastAPI 应用实例
app = FastAPI(
    title="Wiki Fact Judge System",
    description="一个用于评估维基百科事实准确性的系统，支持CLI和Web UI双入口",
    version="1.0.0"
)

# 添加 CORS 中间件（允许前端访问）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 在生产环境中应限制为特定域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 包含路由
app.include_router(case_router)
app.include_router(plan_router)
app.include_router(report_router)


@app.get("/")
def read_root():
    return {
        "message": "Welcome to Wiki Fact Judge System API",
        "version": "1.0.0",
        "endpoints": [
            "/cases - Test Case Management",
            "/plans - Test Plan Management", 
            "/reports - Test Report Management"
        ]
    }


@app.get("/health")
def health_check():
    return {"status": "healthy", "message": "API is running"}


@app.on_event('startup')
def startup_event():
    print("启动事件：初始化数据库连接...")


@app.on_event('shutdown')
def shutdown_event():
    print("关闭事件：清理资源...")