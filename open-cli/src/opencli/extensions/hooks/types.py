from enum import Enum
from dataclasses import dataclass, field
from typing import Optional

class HookType(Enum):
    BEFORE_TOOL_CALL = "before_tool_call"
    AFTER_TOOL_CALL = "after_tool_call"
    BEFORE_AGENT_RUN = "before_agent_run"
    AFTER_AGENT_RUN = "after_agent_run"
    ON_ERROR = "on_error"
    ON_CHECKPOINT = "on_checkpoint"

@dataclass
class Hook:
    type: HookType
    script: str
    condition: Optional[dict] = None
    timeout: int = 30