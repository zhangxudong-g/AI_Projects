from typing import Any
from ..tools.registry import ToolRegistry
from ..tools.base import ToolResult

class ToolExecutor:
    def __init__(self, registry: ToolRegistry):
        self.registry = registry

    async def execute(self, tool_name: str, args: dict[str, Any]) -> ToolResult:
        tool = self.registry.get(tool_name)
        if not tool:
            return ToolResult(
                success=False,
                content=None,
                error=f"Unknown tool: {tool_name}"
            )
        try:
            return await tool.execute(**args)
        except Exception as e:
            return ToolResult(
                success=False,
                content=None,
                error=str(e)
            )
