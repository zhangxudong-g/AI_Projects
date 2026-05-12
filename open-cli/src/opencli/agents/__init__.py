# src/opencli/agents/__init__.py
"""Subagent system for open-cli."""
from .types import AgentType
from .config import AgentConfig
from .base import BaseAgent, AgentResult
from .factory import AgentFactory

__all__ = [
    "AgentType",
    "AgentConfig",
    "BaseAgent",
    "AgentResult",
    "AgentFactory",
]