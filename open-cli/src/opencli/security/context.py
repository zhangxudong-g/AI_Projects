from dataclasses import dataclass
from pathlib import Path
from typing import Optional
from enum import Enum

class SecurityLevel(Enum):
    NONE = "none"
    STANDARD = "standard"
    STRICT = "strict"

@dataclass
class SecurityContext:
    level: SecurityLevel = SecurityLevel.STANDARD
    workspace_root: Optional[Path] = None
    trusted_folders: Optional[list[Path]] = None

    def is_path_allowed(self, path: Path) -> bool:
        if self.workspace_root is None:
            return True
        try:
            resolved = path.resolve()
            resolved_root = self.workspace_root.resolve()
            resolved.relative_to(resolved_root)
            return True
        except ValueError:
            return False

class SecurityBoundary:
    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root

    def is_path_allowed(self, path: Path) -> bool:
        try:
            resolved = path.resolve()
            resolved_root = self.workspace_root.resolve()
            resolved.relative_to(resolved_root)
            return True
        except ValueError:
            return False

    def normalize_path(self, path: Path) -> Path:
        return path.resolve()