from dataclasses import dataclass, field
from pathlib import Path
from enum import Enum

class Permission(Enum):
    READ = "read"
    WRITE = "write"
    EXECUTE = "execute"
    NETWORK = "network"

@dataclass
class TrustedFolder:
    path: Path
    permissions: set[Permission] = field(default_factory={Permission.READ})
    recursive: bool = True

class TrustedFolderManager:
    def __init__(self, folders: list[TrustedFolder] = None):
        self.folders = folders or []

    def check_access(self, path: Path, permission: Permission) -> bool:
        for folder in self.folders:
            if self._is_under(path, folder.path):
                if permission in folder.permissions:
                    return True
        return False

    def _is_under(self, path: Path, base: Path) -> bool:
        try:
            path.resolve().relative_to(base.resolve())
            return True
        except ValueError:
            return False