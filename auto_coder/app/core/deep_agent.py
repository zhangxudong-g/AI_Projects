"""DeepAgent 核心实现 - 支持长任务执行和多轮循环"""

import asyncio
import logging
from typing import Any, Optional, Callable, AsyncIterator, List, Dict
from dataclasses import dataclass, field
from enum import Enum
from typing_extensions import TypedDict, Annotated
from langgraph.graph import add_messages

from langchain_core.messages import BaseMessage, HumanMessage, AIMessage, SystemMessage
from langchain_core.language_models import BaseLanguageModel
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.memory import MemorySaver

from .config import get_settings

logger = logging.getLogger(__name__)


class AgentRole(str, Enum):
    """Agent 角色枚举"""
    PLANNER = "planner"
    CODER = "coder"
    TESTER = "tester"
    FIXER = "fixer"


class ExecutionStatus(str, Enum):
    """执行状态"""
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    INTERRUPTED = "interrupted"


class TaskStepDict(TypedDict):
    """任务步骤字典"""
    id: str
    description: str
    status: str
    result: Optional[str]
    error: Optional[str]


class DeepAgentStateDict(TypedDict):
    """DeepAgent 状态字典（用于 LangGraph）"""
    user_request: str
    status: str
    plan: List[TaskStepDict]
    current_step_index: int
    messages: Annotated[List[BaseMessage], add_messages]
    generated_files: List[str]
    errors: List[str]
    execution_history: List[Dict[str, Any]]
    iteration_count: int
    final_output: Optional[str]
    interrupt_requested: bool


@dataclass
class TaskStep:
    """任务步骤（数据类，用于内部处理）"""
    id: str
    description: str
    status: str = "pending"
    result: Optional[str] = None
    error: Optional[str] = None


def _task_step_to_dict(step: TaskStep) -> TaskStepDict:
    """将 TaskStep 转换为字典"""
    return {
        "id": step.id,
        "description": step.description,
        "status": step.status,
        "result": step.result,
        "error": step.error,
    }


def _task_step_from_dict(data: TaskStepDict) -> TaskStep:
    """将字典转换为 TaskStep"""
    return TaskStep(
        id=data["id"],
        description=data["description"],
        status=data["status"],
        result=data.get("result"),
        error=data.get("error")
    )


@dataclass
class DeepAgentState:
    """DeepAgent 状态类（用于内部处理）

    用于在 LangGraph 中传递和保存状态
    """
    # 用户原始需求
    user_request: str = ""

    # 当前执行状态
    status: ExecutionStatus = ExecutionStatus.PENDING

    # 任务规划
    plan: list[TaskStep] = field(default_factory=list)
    current_step_index: int = 0

    # 消息历史
    messages: list[BaseMessage] = field(default_factory=list)

    # 生成的文件
    generated_files: list[str] = field(default_factory=list)

    # 错误日志
    errors: list[str] = field(default_factory=list)

    # 执行历史
    execution_history: list[dict[str, Any]] = field(default_factory=list)

    # 循环计数
    iteration_count: int = 0

    # 最终输出
    final_output: Optional[str] = None

    # 是否可中断
    interrupt_requested: bool = False

    # SSE 事件回调
    sse_callback: Optional[Callable[[str], None]] = None

    def to_dict(self) -> DeepAgentStateDict:
        """转换为字典格式（用于 LangGraph）"""
        return {
            "user_request": self.user_request,
            "status": self.status.value,
            "plan": [_task_step_to_dict(step) for step in self.plan],
            "current_step_index": self.current_step_index,
            "messages": self.messages,
            "generated_files": self.generated_files,
            "errors": self.errors,
            "execution_history": self.execution_history,
            "iteration_count": self.iteration_count,
            "final_output": self.final_output,
            "interrupt_requested": self.interrupt_requested,
        }

    @classmethod
    def from_dict(cls, data: DeepAgentStateDict) -> "DeepAgentState":
        """从字典创建状态"""
        state = cls()
        state.user_request = data.get("user_request", "")
        state.status = ExecutionStatus(data.get("status", "pending"))
        state.plan = [_task_step_from_dict(step) for step in data.get("plan", [])]
        state.current_step_index = data.get("current_step_index", 0)
        state.messages = data.get("messages", [])
        state.generated_files = data.get("generated_files", [])
        state.errors = data.get("errors", [])
        state.execution_history = data.get("execution_history", [])
        state.iteration_count = data.get("iteration_count", 0)
        state.final_output = data.get("final_output")
        state.interrupt_requested = data.get("interrupt_requested", False)
        return state
    
    def add_message(self, message: BaseMessage) -> None:
        """添加消息"""
        self.messages.append(message)
        self._emit_event("message", {"role": message.type, "content": message.content})
    
    def add_error(self, error: str) -> None:
        """添加错误日志"""
        self.errors.append(error)
        logger.error(error)
        self._emit_event("error", {"message": error})
    
    def add_file(self, file_path: str) -> None:
        """添加生成的文件"""
        if file_path not in self.generated_files:
            self.generated_files.append(file_path)
            self._emit_event("file_created", {"path": file_path})
    
    def add_execution_record(self, record: dict[str, Any]) -> None:
        """添加执行记录"""
        self.execution_history.append(record)
        self._emit_event("execution", record)
    
    def update_step_status(
        self,
        step_id: str,
        status: str,
        result: Optional[str] = None,
        error: Optional[str] = None
    ) -> None:
        """更新任务步骤状态"""
        for i, step in enumerate(self.plan):
            # 处理字典和 TaskStep 两种情况
            if isinstance(step, dict):
                if step.get("id") == step_id:
                    self.plan[i]["status"] = status
                    self.plan[i]["result"] = result
                    self.plan[i]["error"] = error
                    break
            else:
                if step.id == step_id:
                    step.status = status
                    step.result = result
                    step.error = error
                    break
        
        self._emit_event("step_update", {
            "step_id": step_id,
            "status": status,
            "result": result,
            "error": error,
        })
    
    def _emit_event(self, event_type: str, data: Any) -> None:
        """发送 SSE 事件"""
        if self.sse_callback:
            import json
            event = json.dumps({"type": event_type, "data": data}, ensure_ascii=False)
            self.sse_callback(event)


def create_deep_agent(
    llm: BaseLanguageModel,
    tools: list[Callable],
    max_iterations: Optional[int] = None,
    debug: bool = False,
) -> StateGraph:
    """创建 DeepAgent 图
    
    Args:
        llm: 语言模型
        tools: 工具列表
        max_iterations: 最大循环次数
        debug: 是否启用调试模式
    
    Returns:
        编译后的 StateGraph
    """
    settings = get_settings()
    if max_iterations is None:
        max_iterations = settings.max_iterations
    
    # 创建状态图
    workflow = StateGraph(DeepAgentState)
    
    # 添加节点
    workflow.add_node("planner", create_planner_node(llm, tools))
    workflow.add_node("coder", create_coder_node(llm, tools))
    workflow.add_node("tester", create_tester_node(llm, tools))
    workflow.add_node("fixer", create_fixer_node(llm, tools))
    
    # 设置入口
    workflow.set_entry_point("planner")

    # 添加边 - 简化流程，添加停止条件
    workflow.add_edge("planner", "coder")
    workflow.add_edge("coder", "tester")
    
    # Tester 根据结果决定下一步
    workflow.add_conditional_edges(
        "tester",
        lambda state: "fixer" if state.errors else "end",
        {
            "fixer": "fixer",
            "end": END,
        }
    )
    
    # Fixer 修复后回到 Coder
    workflow.add_edge("fixer", "coder")

    # 编译图
    app = workflow.compile(
        checkpointer=None,  # 不使用检查点
    )

    return app


def _check_iteration_limit(state: DeepAgentState, max_iterations: int) -> str:
    """检查是否达到循环限制"""
    if state.iteration_count >= max_iterations:
        state.add_error(f"达到最大循环次数限制：{max_iterations}")
        return "end"
    state.iteration_count += 1
    return "continue"


# 以下是节点创建函数的占位实现，实际实现由各 Agent 模块提供
def create_planner_node(
    llm: BaseLanguageModel,
    tools: list[Callable]
) -> Callable:
    """创建 Planner 节点"""
    from app.agents.planner import planner_node
    return lambda state: planner_node(state, llm, tools)


def create_coder_node(
    llm: BaseLanguageModel,
    tools: list[Callable]
) -> Callable:
    """创建 Coder 节点"""
    from app.agents.coder import coder_node
    return lambda state: coder_node(state, llm, tools)


def create_tester_node(
    llm: BaseLanguageModel,
    tools: list[Callable]
) -> Callable:
    """创建 Tester 节点"""
    from app.agents.tester import tester_node
    return lambda state: tester_node(state, llm, tools)


def create_fixer_node(
    llm: BaseLanguageModel,
    tools: list[Callable]
) -> Callable:
    """创建 Fixer 节点"""
    from app.agents.fixer import fixer_node
    return lambda state: fixer_node(state, llm, tools)


class DeepAgentExecutor:
    """DeepAgent 执行器
    
    提供高级执行接口，支持流式输出和中断
    """
    
    def __init__(
        self,
        llm: BaseLanguageModel,
        tools: list[Callable],
        max_iterations: Optional[int] = None,
        debug: bool = False,
    ):
        self.llm = llm
        self.tools = tools
        self.max_iterations = max_iterations or get_settings().max_iterations
        self.debug = debug
        self.graph = create_deep_agent(llm, tools, max_iterations, debug)
    
    async def execute(
        self,
        request: str,
        sse_callback: Optional[Callable[[str], None]] = None,
    ) -> DeepAgentState:
        """执行任务
        
        Args:
            request: 用户需求
            sse_callback: SSE 回调函数
        
        Returns:
            最终状态
        """
        initial_state = DeepAgentState(
            user_request=request,
            sse_callback=sse_callback,
        )
        
        # 添加系统消息
        initial_state.add_message(
            SystemMessage(content=f"用户需求：{request}")
        )
        
        # 执行图
        config = {"recursion_limit": max(200, self.max_iterations * 10)}

        try:
            async for event in self.graph.astream(
                initial_state.to_dict(),
                config=config,
                stream_mode="values",
            ):
                state = DeepAgentState.from_dict(event)
                if self.debug:
                    logger.debug(f"当前状态：{state.status}")
                
                # 检查中断
                if state.interrupt_requested:
                    state.status = ExecutionStatus.INTERRUPTED
                    break
            
            return state
        except Exception as e:
            logger.exception(f"执行失败：{e}")
            initial_state.status = ExecutionStatus.FAILED
            initial_state.add_error(str(e))
            return initial_state
    
    async def execute_stream(
        self,
        request: str,
    ) -> AsyncIterator[str]:
        """流式执行任务
        
        Args:
            request: 用户需求
        
        Yields:
            SSE 事件字符串
        """
        event_queue = asyncio.Queue[str]()
        
        def sse_callback(event: str) -> None:
            asyncio.create_task(event_queue.put(event))
        
        # 在后台执行任务
        async def run_task():
            state = await self.execute(request, sse_callback)
            # 发送完成事件
            final_event = {
                "type": "complete",
                "data": {
                    "status": state.status.value,
                    "files": state.generated_files,
                    "output": state.final_output,
                    "errors": state.errors,
                }
            }
            import json
            await event_queue.put(json.dumps(final_event, ensure_ascii=False))
            await event_queue.put(None)  # 结束标记
        
        task = asyncio.create_task(run_task())
        
        # 流式输出事件
        while True:
            event = await event_queue.get()
            if event is None:
                break
            yield event
        
        await task
