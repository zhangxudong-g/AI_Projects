from typing import AsyncIterator
from .agent import Agent, AgentConfig
from ..messages.messages import Message, Session, AgentType, ToolCall
from ..tools.base import ToolResult

class BuildAgent(Agent):
    """Build模式的Agent实现 - 完整操作权限"""

    async def run(self, prompt: str, session: Session) -> AsyncIterator[str]:
        """执行Agent并yield响应块"""
        from ..tools import get_registry

        # 构建消息
        messages = [Message(id="0", role="user", content=prompt)]

        # 调用LLM
        async for chunk in self.provider.chat(messages):
            yield chunk

        # 处理工具调用
        # 获取registry中的工具
        registry = get_registry()

        # 根据设计文档实现完整逻辑
        # 1. 解析AI响应中的tool_use
        # 2. 调用对应工具
        # 3. 将工具结果返回给AI
        # 4. 继续生成响应
