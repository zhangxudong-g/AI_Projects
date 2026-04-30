from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import AsyncIterator, Optional, TYPE_CHECKING
from ..types.messages import Message, AgentType

if TYPE_CHECKING:
    from ..types.messages import Session

@dataclass
class AgentConfig:
    agent_type: AgentType
    model: Optional[str] = None
    temperature: float = 0.7
    max_tokens: int = 4096
    system_prompt: Optional[str] = None

class Agent(ABC):
    def __init__(self, config: AgentConfig, registry, provider):
        self.config = config
        self.registry = registry
        self.provider = provider

    @abstractmethod
    async def run(self, prompt: str, session: "Session") -> AsyncIterator[str]:
        """Execute agent and yield response chunks"""
        pass

    def get_system_prompt(self) -> str:
        base = "You are a helpful AI coding assistant."
        if self.config.agent_type == AgentType.PLAN:
            base += "\n\n[PLAN MODE] You can read files and analyze code, but CANNOT modify anything."
        return base
