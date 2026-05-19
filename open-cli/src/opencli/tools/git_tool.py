import subprocess
from pathlib import Path
from typing import Any
from .base import BaseTool, ToolDefinition, ToolResult

class GitTool(BaseTool):
    def __init__(self, repo_root: Path = None):
        self.repo_root = repo_root or Path.cwd()

    def get_definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="git_status",
            description="Get git repository status",
            input_schema={
                "type": "object",
                "properties": {},
                "required": []
            }
        )

    async def execute(self, command: str = "status", **kwargs) -> ToolResult:
        try:
            if command == "status":
                result = self._git_status()
            elif command == "log":
                result = self._git_log()
            elif command == "diff":
                result = self._git_diff()
            elif command == "commit":
                message = kwargs.get("message", "")
                result = self._git_commit(message)
            else:
                return ToolResult(success=False, content=None, error=f"Unknown command: {command}")
            return ToolResult(success=True, content=result)
        except Exception as e:
            return ToolResult(success=False, content=None, error=str(e))

    def _git_status(self) -> dict:
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=self.repo_root,
            capture_output=True,
            text=True
        )
        lines = result.stdout.strip().split("\n") if result.stdout.strip() else []
        files = []
        for line in lines:
            if line:
                files.append(line)
        branch_result = subprocess.run(
            ["git", "branch", "--show-current"],
            cwd=self.repo_root,
            capture_output=True,
            text=True
        )
        branch = branch_result.stdout.strip()
        return {"branch": branch, "files": files}

    def _git_log(self) -> str:
        result = subprocess.run(
            ["git", "log", "--oneline", "-10"],
            cwd=self.repo_root,
            capture_output=True,
            text=True
        )
        return result.stdout.strip() or "No commits yet."

    def _git_diff(self) -> str:
        result = subprocess.run(
            ["git", "diff"],
            cwd=self.repo_root,
            capture_output=True,
            text=True
        )
        return result.stdout.strip() or "No changes."

    def _git_commit(self, message: str) -> dict:
        result = subprocess.run(
            ["git", "commit", "-m", message],
            cwd=self.repo_root,
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return {"success": True, "message": result.stdout}
        else:
            return {"success": False, "error": result.stderr}
