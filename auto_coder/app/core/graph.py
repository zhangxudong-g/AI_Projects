"""Agent Graph 实现 - 管理多 Agent 协作流程"""

import logging
from typing import Any, Callable, Optional
from enum import Enum

from langchain_core.language_models import BaseLanguageModel
from langgraph.graph import StateGraph, END

from .deep_agent import DeepAgentState, ExecutionStatus

logger = logging.getLogger(__name__)


class GraphNode(str, Enum):
    """图节点枚举"""
    PLANNER = "planner"
    CODER = "coder"
    TESTER = "tester"
    FIXER = "fixer"


class AgentGraph:
    """Agent 图管理类
    
    封装 LangGraph 的状态图创建和执行逻辑
    """
    
    def __init__(
        self,
        llm: BaseLanguageModel,
        tools: list[Callable],
        max_iterations: int = 10,
    ):
        self.llm = llm
        self.tools = tools
        self.max_iterations = max_iterations
        self._graph: Optional[StateGraph] = None
        self._compiled_graph = None
    
    def build(self) -> StateGraph:
        """构建状态图"""
        workflow = StateGraph(DeepAgentState)
        
        # 添加节点
        self._add_nodes(workflow)
        
        # 添加边
        self._add_edges(workflow)
        
        # 设置入口
        workflow.set_entry_point(GraphNode.PLANNER)
        
        self._graph = workflow
        return workflow
    
    def compile(self):
        """编译图"""
        if self._graph is None:
            self.build()
        self._compiled_graph = self._graph.compile()
        return self._compiled_graph
    
    def _add_nodes(self, workflow: StateGraph) -> None:
        """添加所有节点"""
        from app.agents.planner import planner_node
        from app.agents.coder import coder_node
        from app.agents.tester import tester_node
        from app.agents.fixer import fixer_node
        
        workflow.add_node(
            GraphNode.PLANNER,
            lambda state: planner_node(state, self.llm, self.tools)
        )
        workflow.add_node(
            GraphNode.CODER,
            lambda state: coder_node(state, self.llm, self.tools)
        )
        workflow.add_node(
            GraphNode.TESTER,
            lambda state: tester_node(state, self.llm, self.tools)
        )
        workflow.add_node(
            GraphNode.FIXER,
            lambda state: fixer_node(state, self.llm, self.tools)
        )
    
    def _add_edges(self, workflow: StateGraph) -> None:
        """添加所有边"""
        # 基本流程
        workflow.add_edge(GraphNode.PLANNER, GraphNode.CODER)
        workflow.add_edge(GraphNode.CODER, GraphNode.TESTER)
        
        # 条件边：Tester -> Fixer 或 Planner
        workflow.add_conditional_edges(
            GraphNode.TESTER,
            self._tester_router,
            {
                GraphNode.FIXER: GraphNode.FIXER,
                GraphNode.PLANNER: GraphNode.PLANNER,
                END: END,
            }
        )
        
        # 条件边：Fixer -> Coder
        workflow.add_conditional_edges(
            GraphNode.FIXER,
            self._fixer_router,
            {
                GraphNode.CODER: GraphNode.CODER,
                END: END,
            }
        )
        
        # 循环检测边
        workflow.add_conditional_edges(
            GraphNode.PLANNER,
            self._planner_router,
            {
                GraphNode.CODER: GraphNode.CODER,
                END: END,
            }
        )
    
    def _tester_router(self, state: DeepAgentState) -> str:
        """Tester 路由逻辑"""
        if state.errors:
            return GraphNode.FIXER
        elif self._is_complete(state):
            return END
        else:
            return GraphNode.PLANNER
    
    def _fixer_router(self, state: DeepAgentState) -> str:
        """Fixer 路由逻辑"""
        if state.errors and state.iteration_count < self.max_iterations:
            return GraphNode.CODER
        elif state.iteration_count >= self.max_iterations:
            state.add_error("达到最大循环次数限制")
            return END
        else:
            return END
    
    def _planner_router(self, state: DeepAgentState) -> str:
        """Planner 路由逻辑"""
        if state.iteration_count >= self.max_iterations:
            state.add_error(f"达到最大循环次数限制：{self.max_iterations}")
            return END
        return GraphNode.CODER
    
    def _is_complete(self, state: DeepAgentState) -> bool:
        """判断任务是否完成"""
        # 所有步骤都已完成（处理字典和 TaskStep 两种情况）
        if state.plan:
            all_completed = True
            for step in state.plan:
                status = step.get("status") if isinstance(step, dict) else step.status
                if status != "completed":
                    all_completed = False
                    break
            if all_completed:
                return True

        # 没有错误且有最终输出
        if state.final_output and not state.errors:
            return True

        return False


def create_agent_graph(
    llm: BaseLanguageModel,
    tools: list[Callable],
    max_iterations: int = 10,
) -> Any:
    """创建并编译 Agent 图
    
    Args:
        llm: 语言模型
        tools: 工具列表
        max_iterations: 最大循环次数
    
    Returns:
        编译后的图
    """
    graph = AgentGraph(llm, tools, max_iterations)
    return graph.compile()
