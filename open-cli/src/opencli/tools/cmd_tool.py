import subprocess
from typing import Any
from .base import BaseTool, ToolDefinition, ToolResult

class CmdError(Exception):
    pass

class CmdTool(BaseTool):
    def __init__(self, trusted_commands: list[str] = None):
        self.trusted_commands = trusted_commands or []

    def get_definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="run_command",
            description="Execute a trusted command",
            input_schema={
                "type": "object",
                "properties": {
                    "command": {"type": "string"},
                    "require_confirmation": {"type": "boolean", "default": False}
                },
                "required": ["command"]
            }
        )

    async def execute(self, command: str, require_confirmation: bool = False, **kwargs) -> ToolResult:
        try:
            cmd_name = command.split()[0] if command else ""
            if not self.is_trusted(cmd_name):
                if require_confirmation:
                    return ToolResult(
                        success=False,
                        content=None,
                        error=f"Command '{cmd_name}' is not trusted. Requires confirmation."
                    )
                else:
                    return ToolResult(
                        success=False,
                        content=None,
                        error=f"Command '{cmd_name}' is not trusted. Add it to trusted_commands."
                    )

            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True
            )
            return ToolResult(
                success=result.returncode == 0,
                content={
                    "returncode": result.returncode,
                    "stdout": result.stdout,
                    "stderr": result.stderr
                }
            )
        except Exception as e:
            return ToolResult(success=False, content=None, error=str(e))

    def is_trusted(self, command: str) -> bool:
        return command in self.trusted_commands
