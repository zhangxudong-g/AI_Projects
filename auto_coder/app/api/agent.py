"""Agent API - 代码生成接口"""

import json
import logging
import asyncio
from typing import Optional, List, AsyncGenerator
from datetime import datetime

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from langchain_openai import ChatOpenAI
from langchain_ollama import ChatOllama

from app.core.config import get_settings
from app.core.deep_agent import DeepAgentExecutor, DeepAgentState, ExecutionStatus
from app.tools import (
    write_file, read_file, list_files,
    run_command,
    git_init, git_add, git_commit,
)
from app.memory.memory_store import get_memory_store

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["agent"])

# 全局执行器缓存
_executors: dict[str, DeepAgentExecutor] = {}


# ============ 数据模型 ============

class GenerateCodeRequest(BaseModel):
    """代码生成请求"""
    request: str = Field(..., description="用户需求描述")
    model_provider: Optional[str] = Field(default=None, description="模型提供商 (openai/ollama)")
    model_name: Optional[str] = Field(default=None, description="模型名称")
    max_iterations: Optional[int] = Field(default=None, description="最大循环次数")
    debug: bool = Field(default=False, description="是否启用调试模式")


class GenerateCodeResponse(BaseModel):
    """代码生成响应"""
    success: bool
    status: str
    files: List[str] = []
    output: Optional[str] = None
    errors: List[str] = []
    execution_id: Optional[str] = None


class ExecutionStatusResponse(BaseModel):
    """执行状态响应"""
    execution_id: str
    status: str
    progress: int  # 0-100
    current_step: Optional[str] = None
    files_generated: List[str] = []
    errors: List[str] = []


class ProjectInfo(BaseModel):
    """项目信息"""
    id: str
    name: str
    description: str
    files_count: int
    created_at: str


# ============ 工具函数 ============

def create_llm(
    model_provider: Optional[str] = None,
    model_name: Optional[str] = None,
    model_base_url: Optional[str] = None,
    model_api_key: Optional[str] = None,
    temperature: Optional[float] = None,
    max_tokens: Optional[int] = None,
) -> any:
    """创建语言模型实例"""
    settings = get_settings()
    
    # 使用传入参数或默认设置
    provider = model_provider or settings.model_provider
    name = model_name or settings.model_name
    base_url = model_base_url or settings.model_base_url
    api_key = model_api_key or settings.model_api_key
    temp = temperature or settings.model_temperature
    tokens = max_tokens or settings.model_max_tokens
    
    if provider == "ollama":
        return ChatOllama(
            model=name,
            base_url=base_url or "http://localhost:11434",
            temperature=temp,
        )
    else:  # openai
        return ChatOpenAI(
            model=name,
            base_url=base_url,
            api_key=api_key,
            temperature=temp,
            max_tokens=tokens,
        )


def get_all_tools() -> list:
    """获取所有工具"""
    return [
        write_file,
        read_file,
        list_files,
        run_command,
        git_init,
        git_add,
        git_commit,
    ]


def create_executor(
    model_provider: Optional[str] = None,
    model_name: Optional[str] = None,
    model_base_url: Optional[str] = None,
    model_api_key: Optional[str] = None,
    max_iterations: Optional[int] = None,
    debug: bool = False,
) -> DeepAgentExecutor:
    """创建执行器"""
    settings = get_settings()

    # 创建 LLM
    llm = create_llm(
        model_provider=model_provider,
        model_name=model_name,
        model_base_url=model_base_url,
        model_api_key=model_api_key,
    )

    # 获取工具
    tools = get_all_tools()

    # 创建执行器
    executor = DeepAgentExecutor(
        llm=llm,
        tools=tools,
        max_iterations=max_iterations,
        debug=debug,
    )
    
    return executor


# ============ SSE 事件流 ============

async def event_stream(
    executor: DeepAgentExecutor,
    request: str,
    execution_id: str,
) -> AsyncGenerator[str, None]:
    """SSE 事件流"""
    memory_store = get_memory_store()
    
    # 创建执行记录
    record = memory_store.add_execution(request)
    
    try:
        # 执行任务
        state = await executor.execute(
            request=request,
            sse_callback=lambda event: None,  # 同步回调，我们直接流式输出
        )
        
        # 流式输出状态
        yield f"data: {json.dumps({'type': 'start', 'execution_id': execution_id}, ensure_ascii=False)}\n\n"
        
        # 输出执行过程事件
        for record in state.execution_history:
            yield f"data: {json.dumps({'type': 'event', 'data': record}, ensure_ascii=False)}\n\n"
        
        # 输出最终状态
        result = {
            "type": "complete",
            "status": state.status.value,
            "files": state.generated_files,
            "output": state.final_output,
            "errors": state.errors,
            "execution_id": execution_id,
        }
        yield f"data: {json.dumps(result, ensure_ascii=False)}\n\n"
        
        # 更新记忆存储
        memory_store.update_execution(
            record_id=record.id,
            status=state.status.value,
            files=state.generated_files,
            errors=state.errors,
            iterations=state.iteration_count,
        )
        
    except Exception as e:
        logger.exception(f"执行失败：{e}")
        error_result = {
            "type": "error",
            "message": str(e),
            "execution_id": execution_id,
        }
        yield f"data: {json.dumps(error_result, ensure_ascii=False)}\n\n"
        
        # 更新记忆存储
        memory_store.update_execution(
            record_id=record.id,
            status="failed",
            files=[],
            errors=[str(e)],
            iterations=0,
        )


# ============ API 端点 ============

@router.post("/generate_code", response_model=GenerateCodeResponse)
async def generate_code(request: GenerateCodeRequest) -> GenerateCodeResponse:
    """生成代码（非流式）

    同步返回代码生成结果
    """
    logger.info(f"收到代码生成请求：{request.request[:100]}...")

    try:
        # 创建执行器
        executor = create_executor(
            model_provider=request.model_provider,
            model_name=request.model_name,
            max_iterations=request.max_iterations,
            debug=request.debug,
        )

        # 执行任务（传入字符串 request）
        state = await executor.execute(request=request.request)

        # 生成响应
        return GenerateCodeResponse(
            success=state.status == ExecutionStatus.COMPLETED,
            status=state.status.value,
            files=state.generated_files,
            output=state.final_output,
            errors=state.errors,
            execution_id=None,
        )

    except Exception as e:
        logger.exception(f"代码生成失败：{e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/generate_code_stream")
async def generate_code_stream(request: GenerateCodeRequest, req: Request):
    """生成代码（流式）

    使用 SSE 流式返回执行过程和结果
    """
    logger.info(f"收到流式代码生成请求：{request.request[:100]}...")

    # 生成执行 ID
    execution_id = f"exec_{datetime.now().strftime('%Y%m%d%H%M%S')}"

    # 创建执行器
    executor = create_executor(
        model_provider=request.model_provider,
        model_name=request.model_name,
        max_iterations=request.max_iterations,
        debug=request.debug,
    )

    # 返回 SSE 流
    return StreamingResponse(
        event_stream(executor, request.request, execution_id),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.get("/execution/{execution_id}", response_model=ExecutionStatusResponse)
async def get_execution_status(execution_id: str) -> ExecutionStatusResponse:
    """获取执行状态"""
    # 从记忆存储获取
    memory_store = get_memory_store()
    record = memory_store.get_execution(execution_id)
    
    if not record:
        raise HTTPException(status_code=404, detail="执行记录不存在")
    
    # 计算进度
    progress = 0
    if record.status == "completed":
        progress = 100
    elif record.status == "running":
        progress = min(50 + record.iteration_count * 10, 90)
    elif record.status == "failed":
        progress = max(record.iteration_count * 10, 10)
    
    return ExecutionStatusResponse(
        execution_id=execution_id,
        status=record.status,
        progress=progress,
        current_step=None,
        files_generated=record.files_generated,
        errors=record.errors,
    )


@router.get("/projects", response_model=List[ProjectInfo])
async def list_projects(limit: int = 10) -> List[ProjectInfo]:
    """获取项目列表"""
    memory_store = get_memory_store()
    projects = memory_store.get_projects(limit)
    
    return [
        ProjectInfo(
            id=p.id,
            name=p.name,
            description=p.description,
            files_count=len(p.files),
            created_at=p.created_at,
        )
        for p in projects
    ]


@router.get("/project/{project_id}")
async def get_project(project_id: str):
    """获取项目详情"""
    memory_store = get_memory_store()
    project = memory_store.get_project(project_id)
    
    if not project:
        raise HTTPException(status_code=404, detail="项目不存在")
    
    return {
        "id": project.id,
        "name": project.name,
        "description": project.description,
        "files": project.files,
        "created_at": project.created_at,
        "updated_at": project.updated_at,
    }


@router.get("/stats")
async def get_stats():
    """获取统计信息"""
    memory_store = get_memory_store()
    return memory_store.get_stats()


@router.post("/workspace/files/{path:path}")
async def read_workspace_file(path: str):
    """读取工作空间文件"""
    result = read_file(path)
    
    if not result["success"]:
        raise HTTPException(status_code=404, detail=result.get("error", "文件不存在"))
    
    return {
        "path": path,
        "content": result["content"],
        "size": result["size"],
    }


@router.get("/workspace/files")
async def list_workspace_files(recursive: bool = False):
    """列出工作空间文件"""
    result = list_files(".", recursive=recursive)
    
    if not result["success"]:
        raise HTTPException(status_code=500, detail=result.get("error", "无法列出文件"))
    
    return {
        "files": result["files"],
        "count": result["count"],
    }
