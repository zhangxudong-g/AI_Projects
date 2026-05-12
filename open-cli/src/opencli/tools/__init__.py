from .base import BaseTool, ToolDefinition, ToolResult
from .registry import ToolRegistry
from .file_tool import ReadFileTool, WriteFileTool, EditFileTool, ListDirectoryTool
from .git_tool import GitTool
from .cmd_tool import CmdTool, CmdError

_registry = ToolRegistry()

def get_registry() -> ToolRegistry:
    return _registry

def register_default_tools():
    _registry.register(ReadFileTool())
    _registry.register(WriteFileTool())
    _registry.register(EditFileTool())
    _registry.register(ListDirectoryTool())
    _registry.register(GitTool())
    _registry.register(CmdTool(trusted_commands=[
        "git", "python", "pip", "npm", "node", "pytest",
        "dir", "ls", "pwd", "mkdir", "rm", "cp", "mv", "cat", "type"
    ]))

register_default_tools()

__all__ = [
    "BaseTool", "ToolDefinition", "ToolResult", "ToolRegistry",
    "ReadFileTool", "WriteFileTool", "EditFileTool", "ListDirectoryTool",
    "GitTool", "CmdTool", "CmdError", "get_registry",
]