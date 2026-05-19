from typing import AsyncIterator
from .agent import Agent, AgentConfig
from ..messages.messages import Session, Message, AgentType
from ..providers.base import BaseProvider
from ..tools.registry import ToolRegistry

class AgentOrchestrator:
    def __init__(self, provider: BaseProvider, registry: ToolRegistry):
        self.provider = provider
        self.registry = registry
        self.agents: dict[AgentType, Agent] = {}

    def register_agent(self, agent_type: AgentType, agent: Agent):
        self.agents[agent_type] = agent

    async def run(
        self,
        agent_type: AgentType,
        prompt: str,
        session: Session
    ) -> AsyncIterator[str]:
        agent = self.agents.get(agent_type)
        if not agent:
            raise ValueError(f"No agent registered for type: {agent_type}")
        async for chunk in agent.run(prompt, session):
            yield chunk
