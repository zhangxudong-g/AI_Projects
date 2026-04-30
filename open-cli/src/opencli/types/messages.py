from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, AsyncIterator, Optional


class AgentType(Enum):
    PLAN = "plan"
    BUILD = "build"
    GENERAL = "general"


@dataclass
class Message:
    id: str
    role: str
    content: str | list["ContentBlock"]
    timestamp: datetime = field(default_factory=datetime.now)


@dataclass
class ContentBlock:
    type: str
    text: Optional[str] = None
    tool_use: Optional[dict] = None
    tool_result: Optional[dict] = None


@dataclass
class ToolCall:
    id: str
    name: str
    arguments: dict


@dataclass
class Session:
    id: str
    agent_type: AgentType
    messages: list[Message] = field(default_factory=list)
    created_at: datetime = field(default_factory=datetime.now)
