"""Planner Agent - 任务拆解和规划"""

import logging
import json
import re
from typing import Any, Callable
from uuid import uuid4

from langchain_core.language_models import BaseLanguageModel
from langchain_core.messages import HumanMessage, SystemMessage, AIMessage

from app.core.deep_agent import DeepAgentState, TaskStep, ExecutionStatus
from app.core.config import get_settings

logger = logging.getLogger(__name__)


# Planner 系统提示词
PLANNER_SYSTEM_PROMPT = """你是一个专业的软件架构师和任务规划专家。

你的职责是：
1. 分析用户的需求，理解其核心目标
2. 将复杂任务拆解为可执行的小步骤
3. 为每个步骤定义清晰的验收标准
4. 确定步骤之间的依赖关系

请按照以下 JSON 格式输出任务规划：
{
    "plan": [
        {
            "id": "step_1",
            "description": "步骤描述",
            "type": "code|test|config|docs",
            "files": ["相关文件路径"],
            "acceptance_criteria": "验收标准"
        }
    ],
    "summary": "整体规划概述"
}

步骤类型说明：
- code: 编写代码
- test: 编写测试
- config: 配置文件
- docs: 文档

注意：
1. 步骤应该尽可能原子化
2. 每个步骤应该是可独立验证的
3. 考虑步骤之间的依赖关系
4. 优先创建项目结构和配置文件
5. 然后实现核心功能
6. 最后编写测试和文档
"""


class PlannerAgent:
    """Planner Agent 类
    
    负责分析需求并拆解任务
    """
    
    def __init__(self, llm: BaseLanguageModel):
        self.llm = llm
        self.settings = get_settings()
    
    def plan(self, request: str) -> dict[str, Any]:
        """分析需求并生成任务规划
        
        Args:
            request: 用户需求
        
        Returns:
            任务规划结果
        """
        messages = [
            SystemMessage(content=PLANNER_SYSTEM_PROMPT),
            HumanMessage(content=f"请分析以下需求并生成任务规划：\n\n{request}"),
        ]
        
        response = self.llm.invoke(messages)
        
        # 解析 JSON 响应
        content = response.content
        plan_data = self._parse_json_response(content)
        
        return plan_data
    
    def _parse_json_response(self, content: str) -> dict[str, Any]:
        """解析 JSON 响应"""
        # 尝试直接解析
        try:
            return json.loads(content)
        except json.JSONDecodeError:
            pass
        
        # 尝试提取 JSON 块
        json_pattern = r"```json\s*(.*?)\s*```"
        match = re.search(json_pattern, content, re.DOTALL)
        if match:
            try:
                return json.loads(match.group(1))
            except json.JSONDecodeError:
                pass
        
        # 尝试查找 { 和 }
        start = content.find("{")
        end = content.rfind("}") + 1
        if start >= 0 and end > start:
            try:
                return json.loads(content[start:end])
            except json.JSONDecodeError:
                pass
        
        # 返回默认结构
        logger.warning(f"无法解析 JSON 响应：{content[:200]}")
        return {
            "plan": [],
            "summary": content[:500],
        }


def planner_node(
    state: DeepAgentState,
    llm: BaseLanguageModel,
    tools: list[Callable],
) -> dict[str, Any]:
    """Planner 节点函数
    
    Args:
        state: 当前状态
        llm: 语言模型
        tools: 工具列表
    
    Returns:
        状态更新
    """
    logger.info("=== Planner 节点执行 ===")
    
    # 检查是否已有规划
    if state.plan:
        logger.info("已有任务规划，跳过规划阶段")
        return {"plan": state.plan}
    
    try:
        # 创建 Planner
        planner = PlannerAgent(llm)
        
        # 生成规划
        plan_data = planner.plan(state.user_request)
        
        # 转换为 TaskStep 列表
        steps = []
        for i, step_data in enumerate(plan_data.get("plan", [])):
            # 确保 step_data 是字典
            if isinstance(step_data, dict):
                step = TaskStep(
                    id=step_data.get("id", f"step_{i}"),
                    description=step_data.get("description", ""),
                    status="pending",
                )
            else:
                # 如果已经是 TaskStep 或其他对象，尝试提取属性
                step = TaskStep(
                    id=getattr(step_data, "id", f"step_{i}"),
                    description=getattr(step_data, "description", str(step_data)),
                    status="pending",
                )
            steps.append(step)
        
        # 如果没有解析出步骤，创建一个默认步骤
        if not steps:
            steps = [
                TaskStep(
                    id="step_1",
                    description=f"实现需求：{state.user_request[:100]}",
                    status="pending",
                )
            ]
        
        # 记录执行历史
        state.add_execution_record({
            "node": "planner",
            "action": "create_plan",
            "steps_count": len(steps),
            "summary": plan_data.get("summary", ""),
        })
        
        # 发送事件
        state._emit_event("plan_created", {
            "plan": [
                {"id": s.id, "description": s.description}
                for s in steps
            ],
            "summary": plan_data.get("summary", ""),
        })
        
        logger.info(f"任务规划完成，共 {len(steps)} 个步骤")

        # 将 TaskStep 转换为字典（LangGraph 需要可序列化的数据）
        plan_dict = [
            {
                "id": step.id,
                "description": step.description,
                "status": step.status,
                "result": step.result,
                "error": step.error,
            }
            for step in steps
        ]

        return {
            "plan": plan_dict,
            "messages": state.messages + [
                AIMessage(content=f"任务规划完成：{len(steps)} 个步骤")
            ],
        }
    
    except Exception as e:
        logger.exception(f"Planner 执行失败：{e}")
        state.add_error(f"Planner 执行失败：{e}")

        # 创建降级计划
        fallback_steps = [
            TaskStep(
                id="fallback_step",
                description=f"实现需求：{state.user_request[:100]}",
                status="pending",
            )
        ]

        # 转换为字典
        plan_dict = [
            {
                "id": step.id,
                "description": step.description,
                "status": step.status,
                "result": step.result,
                "error": step.error,
            }
            for step in fallback_steps
        ]

        return {
            "plan": plan_dict,
            "errors": state.errors,
        }
