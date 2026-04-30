import os
from pathlib import Path
from typing import List, Dict, Any
from core.security import SecurityBoundary, SecurityError

class FileTool:
    def __init__(self, security: SecurityBoundary):
        self.security = security

    def read_file(self, file_path: str) -> str:
        path = self.security.validate_path(Path(file_path))
        if not path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")
        if not path.is_file():
            raise ValueError(f"Not a file: {file_path}")
        return path.read_text(encoding="utf-8")

    def write_file(self, file_path: str, content: str) -> Dict[str, Any]:
        path = self.security.validate_path(Path(file_path))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return {"success": True, "path": str(path), "bytes": len(content)}

    def list_directory(self, dir_path: str) -> List[str]:
        path = self.security.validate_path(Path(dir_path))
        if not path.exists():
            raise FileNotFoundError(f"Directory not found: {dir_path}")
        if not path.is_dir():
            raise ValueError(f"Not a directory: {dir_path}")

        entries = []
        for item in sorted(path.iterdir()):
            name = item.name
            if item.is_dir():
                name += "/"
            entries.append(name)
        return entries

    def create_directory(self, dir_path: str) -> Dict[str, Any]:
        path = self.security.validate_path(Path(dir_path))
        path.mkdir(parents=True, exist_ok=True)
        return {"success": True, "path": str(path)}

    def delete_file(self, file_path: str) -> Dict[str, Any]:
        path = self.security.validate_path(Path(file_path))
        if not path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")
        path.unlink()
        return {"success": True, "path": str(path)}