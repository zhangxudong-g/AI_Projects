# src/opencli/agents/base.py
"""Base agent abstract class."""
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional
from opencli.agents.config import AgentConfig


@dataclass
class AgentResult:
    """Result from an agent execution."""

    summary: str
    key_findings: list[str] = None
    tools_used: list[str] = None
    duration: float = 0.0
    error: Optional[str] = None

    def __post_init__(self):
        if self.key_findings is None:
            self.key_findings = []
        if self.tools_used is None:
            self.tools_used = []


class BaseAgent(ABC):
    """Abstract base class for agents."""

    def __init__(self, config: AgentConfig):
        self.config = config

    @abstractmethod
    async def run(self, task: str) -> AgentResult:
        """Run the agent with the given task."""
        pass

    @property
    def name(self) -> str:
        return self.config.name

    @property
    def description(self) -> str:
        return self.config.description