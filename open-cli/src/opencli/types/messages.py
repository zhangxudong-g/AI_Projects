from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, AsyncIterator, Optional


class AgentType(Enum):
    PLAN = "plan"
    BUILD = "build"
    GENERAL = "general"


class MessageType(Enum):
    THINKING = "thinking"
    PLAN = "plan"
    TOOL_CALL = "tool_call"
    TOOL_RESULT = "tool_result"
    ERROR = "error"
    DONE = "done"


@dataclass
class AgentMessage:
    type: MessageType
    content: str
    tool_name: Optional[str] = None
    tool_args: Optional[dict] = None
    success: Optional[bool] = None
    timestamp: datetime = field(default_factory=datetime.now)

    def to_dict(self) -> dict:
        result = {
            "type": self.type.value,
            "content": self.content,
        }
        if self.tool_name:
            result["tool_name"] = self.tool_name
        if self.tool_args:
            result["tool_args"] = self.tool_args
        if self.success is not None:
            result["success"] = self.success
        return result


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
