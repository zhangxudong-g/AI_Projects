from pathlib import Path

class SecurityError(Exception):
    pass

class SecurityBoundary:
    def __init__(self, workspace_root: Path):
        self.workspace_root = Path(workspace_root).resolve()

    def normalize_path(self, path: Path) -> Path:
        return Path(path).resolve()

    def is_path_allowed(self, path: Path) -> bool:
        try:
            resolved = self.normalize_path(path)
            return resolved.is_relative_to(self.workspace_root)
        except (ValueError, OSError):
            return False

    def validate_path(self, path: Path) -> Path:
        if not self.is_path_allowed(path):
            raise SecurityError(f"Path '{path}' is outside workspace '{self.workspace_root}'")
        return path