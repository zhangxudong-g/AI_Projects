from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import uvicorn
from pathlib import Path

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from api.v1.api import api_router
from core.config import settings
from core.security import get_current_user

# 创建应用实例
app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# 设置 CORS 中间件
if settings.BACKEND_CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[str(origin) for origin in settings.BACKEND_CORS_ORIGINS],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

@app.get("/")
async def root():
    return {"message": "Engineering Judge v3 API"}

@app.get("/api/v1/health")
async def health_check():
    return {"status": "healthy"}

# 包含 API 路由
app.include_router(api_router, prefix=settings.API_V1_STR)

# 挂载静态文件目录（用于前端构建文件）- 注意顺序，必须在API路由之后
static_dir = Path(__file__).parent / "static"
if static_dir.exists():
    app.mount("/static", StaticFiles(directory=static_dir, html=True), name="static")
else:
    # 如果静态目录不存在，创建一个空的
    static_dir.mkdir(exist_ok=True)
    app.mount("/static", StaticFiles(directory=static_dir, html=True), name="static")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)