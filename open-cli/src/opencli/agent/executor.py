from typing import Any
from ..tools.registry import ToolRegistry
from ..tools.base import ToolResult

# Tool name aliases for compatibility
TOOL_ALIASES = {
    "cmd_execute": "run_command",
    "shell": "run_command",
    "exec": "run_command",
    "file_read": "read_file",
    "file_write": "write_file",
    "ls": "list_directory",
    "dir": "list_directory",
    "git": "git_status",
}

class ToolExecutor:
    def __init__(self, registry: ToolRegistry):
        self.registry = registry

    def _resolve_tool(self, tool_name: str) -> str:
        """Resolve tool name, checking aliases."""
        if self.registry.get(tool_name):
            return tool_name
        if tool_name in TOOL_ALIASES:
            resolved = TOOL_ALIASES[tool_name]
            if self.registry.get(resolved):
                return resolved
        return tool_name

    async def execute(self, tool_name: str, args: dict[str, Any]) -> ToolResult:
        resolved_name = self._resolve_tool(tool_name)
        tool = self.registry.get(resolved_name)
        if not tool:
            return ToolResult(
                success=False,
                content=None,
                error=f"Unknown tool: {tool_name} (tried: {resolved_name})"
            )
        try:
            return await tool.execute(**args)
        except Exception as e:
            return ToolResult(
                success=False,
                content=None,
                error=str(e)
            )
