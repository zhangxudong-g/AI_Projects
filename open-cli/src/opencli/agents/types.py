# src/opencli/agents/types.py
"""Agent type definitions."""
from enum import Enum


class AgentType(Enum):
    """Built-in agent types."""

    EXPLORE = "explore"
    PLAN = "plan"
    BUILD = "build"
    GENERAL = "general"

    @classmethod
    def from_string(cls, value: str) -> "AgentType":
        """Create AgentType from string value."""
        value = value.lower().strip()
        for agent_type in cls:
            if agent_type.value == value:
                return agent_type
        return cls.GENERAL

    def __str__(self) -> str:
        return self.value