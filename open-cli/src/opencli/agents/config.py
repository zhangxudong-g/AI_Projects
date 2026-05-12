# src/opencli/agents/config.py
"""Agent configuration dataclass."""
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class AgentConfig:
    """Configuration for an agent instance."""

    name: str
    description: str
    allowed_tools: list[str] = field(default_factory=list)
    denied_tools: list[str] = field(default_factory=list)
    model: Optional[str] = None  # None = use default
    memory_enabled: bool = True
    max_turns: int = 10
    timeout: int = 300  # seconds