from typing import TYPE_CHECKING
from ...tools.base import BaseTool, ToolDefinition, ToolResult

if TYPE_CHECKING:
    from mcp import ClientSession

class MCPTool(BaseTool):
    def __init__(self, server: str, name: str, description: str, input_schema: dict):
        self.server = server
        self.name = name
        self.description = description
        self.input_schema = input_schema

    def get_definition(self) -> ToolDefinition:
        return ToolDefinition(
            name=f"{self.server}/{self.name}",
            description=self.description,
            input_schema=self.input_schema
        )

    async def execute(self, session: "ClientSession" = None, **kwargs) -> ToolResult:
        if session is None:
            return ToolResult(success=False, content=None, error="No MCP session available")
        try:
            result = await session.call_tool(self.name, arguments=kwargs)
            content = result.content if hasattr(result, 'content') else result
            return ToolResult(success=True, content=content)
        except Exception as e:
            return ToolResult(success=False, content=None, error=str(e))