from typing import AsyncIterator
from .agent import Agent, AgentConfig
from ..messages.messages import Message, Session, AgentType


class PlanAgent(Agent):
    """Plan模式的Agent - 只读分析模式"""
    
    async def run(self, prompt: str, session: Session) -> AsyncIterator[str]:
        """执行Plan Agent并yield响应块"""
        # Plan模式不允许修改文件
        system_prompt = self.get_system_prompt()
        full_prompt = f"{system_prompt}\n\n{prompt}"
        
        messages = [Message(id="0", role="user", content=full_prompt)]
        
        async for chunk in self.provider.chat(messages):
            yield chunk
