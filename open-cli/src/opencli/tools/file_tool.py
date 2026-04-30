from pathlib import Path
from typing import Any
from .base import BaseTool, ToolDefinition, ToolResult

class FileTool(BaseTool):
    def get_definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="read_file",
            description="Read file contents",
            input_schema={
                "type": "object",
                "properties": {"file_path": {"type": "string"}},
                "required": ["file_path"]
            }
        )

    async def execute(self, file_path: str, **kwargs) -> ToolResult:
        try:
            content = Path(file_path).read_text()
            return ToolResult(success=True, content=content)
        except Exception as e:
            return ToolResult(success=False, content=None, error=str(e))
