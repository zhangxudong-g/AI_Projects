import asyncio
from pathlib import Path
from typing import Any, Optional
from .base import BaseTool, ToolDefinition, ToolResult


def _write_file(path: Path, content: str, mode: str) -> None:
    """Synchronous helper to write file content."""
    with open(path, mode, encoding='utf-8') as f:
        f.write(content)


class ReadFileTool(BaseTool):
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
            path = Path(file_path)
            if not path.exists():
                return ToolResult(success=False, content=None, error=f"File not found: {file_path}")
            if path.is_dir():
                return ToolResult(success=False, content=None, error=f"Path is a directory, not a file: {file_path}. Use list_directory instead.")
            content = await asyncio.to_thread(path.read_text, encoding='utf-8')
            return ToolResult(success=True, content=content)
        except PermissionError:
            return ToolResult(success=False, content=None, error=f"Permission denied: {file_path}")
        except Exception as e:
            return ToolResult(success=False, content=None, error=str(e))

class WriteFileTool(BaseTool):
    def get_definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="write_file",
            description="Write content to a file (creates or overwrites)",
            input_schema={
                "type": "object",
                "properties": {
                    "file_path": {"type": "string"},
                    "content": {"type": "string"},
                    "append": {"type": "boolean", "default": False}
                },
                "required": ["file_path", "content"]
            }
        )

    async def execute(self, file_path: str, content: str, append: bool = False, **kwargs) -> ToolResult:
        try:
            path = Path(file_path)
            path.parent.mkdir(parents=True, exist_ok=True)

            mode = 'a' if append else 'w'
            await asyncio.to_thread(_write_file, path, content, mode)

            return ToolResult(success=True, content=f"File {'appended to' if append else 'written'}: {file_path}")
        except Exception as e:
            return ToolResult(success=False, content=None, error=str(e))

class EditFileTool(BaseTool):
    """使用diff/patch方式编辑文件"""
    def get_definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="edit_file",
            description="Edit file using find/replace",
            input_schema={
                "type": "object",
                "properties": {
                    "file_path": {"type": "string"},
                    "find": {"type": "string", "description": "Text to find"},
                    "replace": {"type": "string", "description": "Replacement text"}
                },
                "required": ["file_path", "find", "replace"]
            }
        )

    async def execute(self, file_path: str, find: str, replace: str, **kwargs) -> ToolResult:
        try:
            path = Path(file_path)
            if not path.exists():
                return ToolResult(success=False, content=None, error=f"File not found: {file_path}")

            content = await asyncio.to_thread(path.read_text, encoding='utf-8')
            if find not in content:
                return ToolResult(success=False, content=None, error=f"Text '{find}' not found in file")

            new_content = content.replace(find, replace)
            await asyncio.to_thread(path.write_text, new_content, encoding='utf-8')

            return ToolResult(success=True, content=f"Edited: {file_path}")
        except Exception as e:
            return ToolResult(success=False, content=None, error=str(e))

class ListDirectoryTool(BaseTool):
    def get_definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="list_directory",
            description="List directory contents",
            input_schema={
                "type": "object",
                "properties": {
                    "path": {"type": "string", "default": "."},
                    "recursive": {"type": "boolean", "default": False}
                }
            }
        )

    async def execute(self, path: str = ".", recursive: bool = False, **kwargs) -> ToolResult:
        try:
            import os
            entries = []
            if recursive:
                for root, dirs, files in os.walk(path):
                    for d in dirs:
                        entries.append(f"{root}/{d}/")
                    for f in files:
                        entries.append(f"{root}/{f}")
            else:
                for item in os.listdir(path):
                    entries.append(item)
            
            return ToolResult(success=True, content="\n".join(entries))
        except Exception as e:
            return ToolResult(success=False, content=None, error=str(e))