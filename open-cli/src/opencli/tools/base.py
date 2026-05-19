from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any, Optional

@dataclass
class ToolDefinition:
    name: str
    description: str
    input_schema: dict

@dataclass
class ToolResult:
    success: bool
    content: Any
    error: Optional[str] = None

class BaseTool(ABC):
    @abstractmethod
    def get_definition(self) -> ToolDefinition:
        pass

    @abstractmethod
    async def execute(self, **kwargs) -> ToolResult:
        pass
