from typing import Optional
from .base import BaseTool, ToolDefinition

class ToolRegistry:
    def __init__(self):
        self._tools: dict[str, BaseTool] = {}

    def register(self, tool: BaseTool):
        self._tools[tool.get_definition().name] = tool

    def get(self, name: str) -> Optional[BaseTool]:
        return self._tools.get(name)

    def list_all(self) -> list[ToolDefinition]:
        return [t.get_definition() for t in self._tools.values()]
