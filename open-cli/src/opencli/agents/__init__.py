# src/opencli/agents/__init__.py
"""Subagent system for open-cli."""
from .types import AgentType
from .config import AgentConfig

__all__ = [
    "AgentType",
    "AgentConfig",
]