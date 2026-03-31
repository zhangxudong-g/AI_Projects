"""AutoCoder 主应用 - FastAPI 入口"""

import logging
import sys
from pathlib import Path
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from rich.logging import RichHandler

from app.core.config import get_settings
from app.api.agent import router as agent_router

# 配置日志
def setup_logging():
    """配置日志系统"""
    settings = get_settings()

    # 使用 Rich 进行美化输出
    logging.basicConfig(
        level=getattr(logging, settings.log_level),
        format="%(message)s",
        handlers=[
            RichHandler(
                rich_tracebacks=True,
                show_time=settings.log_debug_mode,
                show_path=settings.log_debug_mode,
            )
        ],
    )

    logger = logging.getLogger("auto_coder")
    logger.info("AutoCoder 启动...")

    return logger


# 生命周期管理
@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期"""
    # 启动时
    settings = get_settings()
    logger = logging.getLogger("auto_coder")

    logger.info(f"工作空间：{settings.workspace_dir}")
    logger.info(f"模型提供商：{settings.model_provider}")
    logger.info(f"模型名称：{settings.model_name}")

    # 确保工作空间存在
    Path(settings.workspace_dir).mkdir(parents=True, exist_ok=True)

    yield

    # 关闭时
    logger.info("AutoCoder 关闭...")


# 创建 FastAPI 应用
def create_app() -> FastAPI:
    """创建 FastAPI 应用实例"""
    settings = get_settings()
    
    app = FastAPI(
        title="AutoCoder",
        description="自动写代码的 DeepAgents 系统",
        version="1.0.0",
        lifespan=lifespan,
    )
    
    # 配置 CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    # 注册路由
    app.include_router(agent_router)
    
    # 健康检查
    @app.get("/health")
    async def health_check():
        return {
            "status": "healthy",
            "version": "1.0.0",
        }
    
    # 根路径
    @app.get("/")
    async def root():
        return {
            "name": "AutoCoder",
            "description": "自动写代码的 DeepAgents 系统",
            "docs": "/docs",
            "health": "/health",
        }
    
    # 全局异常处理
    @app.exception_handler(Exception)
    async def global_exception_handler(request, exc):
        logger = logging.getLogger("auto_coder")
        logger.exception(f"未处理异常：{exc}")
        
        return JSONResponse(
            status_code=500,
            content={
                "error": "Internal Server Error",
                "detail": str(exc) if settings.log_debug_mode else "服务器内部错误",
            },
        )

    return app


# 设置日志
logger = setup_logging()

# 创建应用
app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=get_settings().log_debug_mode,
        log_level=get_settings().log_level.lower(),
    )
