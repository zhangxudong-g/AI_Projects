# src/opencli/memory/loader.py
"""Memory loader for AGENTS.md and MEMORY.md files."""
import hashlib
import subprocess
from pathlib import Path
from typing import Optional


class MemoryLoader:
    """Loads memory files from various locations."""

    def __init__(
        self,
        user_home: Optional[Path] = None,
        project_path: Optional[Path] = None,
    ):
        self.user_home = user_home or self._get_default_user_home()
        self.project_path = project_path
        self._project_hash: Optional[str] = None

    def _get_default_user_home(self) -> Path:
        """Get default user home directory."""
        return Path.home() / ".opencli"

    def _get_project_hash(self) -> str:
        """Get unique hash for project based on git root."""
        if self._project_hash is not None:
            return self._project_hash

        if self.project_path:
            try:
                result = subprocess.run(
                    ["git", "rev-parse", "--show-toplevel"],
                    cwd=self.project_path,
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                if result.returncode == 0:
                    project_root = result.stdout.strip()
                    self._project_hash = hashlib.md5(project_root.encode()).hexdigest()[:8]
                    return self._project_hash
            except Exception:
                pass
        # Fallback to project path string hash
        if self.project_path:
            self._project_hash = hashlib.md5(str(self.project_path).encode()).hexdigest()[:8]
            return self._project_hash
        self._project_hash = "default"
        return self._project_hash

    # User-level memory
    def get_user_agents_path(self) -> Path:
        """Path to user-level AGENTS.md."""
        return self.user_home / "AGENTS.md"

    def get_user_memory_dir(self) -> Path:
        """Path to user auto-memory directory."""
        return self.user_home / "memory" / "default"

    def get_user_memory_path(self) -> Path:
        """Path to user MEMORY.md."""
        return self.get_user_memory_dir() / "MEMORY.md"

    def load_user_memory(self) -> str:
        """Load user-level AGENTS.md."""
        path = self.get_user_agents_path()
        if path.exists():
            return path.read_text(encoding="utf-8")
        return ""

    def load_user_auto_memory(self, max_lines: int = 200) -> str:
        """Load user auto-memory (first N lines)."""
        path = self.get_user_memory_path()
        if path.exists():
            content = path.read_text(encoding="utf-8")
            lines = content.split("\n")
            return "\n".join(lines[:max_lines])
        return ""

    # Project-level memory
    def get_project_agents_paths(self) -> list[Path]:
        """Get possible project AGENTS.md locations (priority order)."""
        if not self.project_path:
            return []
        return [
            self.project_path / "AGENTS.md",
            self.project_path / ".opencli" / "AGENTS.md",
        ]

    def get_project_memory_path(self) -> Path:
        """Path to project MEMORY.md."""
        project_id = self._get_project_hash()
        return self.user_home / "memory" / project_id / "MEMORY.md"

    def load_project_memory(self) -> str:
        """Load project-level AGENTS.md (first found)."""
        for path in self.get_project_agents_paths():
            if path.exists():
                return path.read_text(encoding="utf-8")
        return ""

    def load_project_auto_memory(self, max_lines: int = 200) -> str:
        """Load project auto-memory (first N lines)."""
        path = self.get_project_memory_path()
        if path.exists():
            content = path.read_text(encoding="utf-8")
            lines = content.split("\n")
            return "\n".join(lines[:max_lines])
        return ""

    # Combined loading
    def get_loading_priority(self) -> list[str]:
        """Return loading priority order."""
        return ["system", "user", "project", "project_auto", "user_auto"]

    def load_all_memory(self) -> dict[str, str]:
        """Load all memory sources in priority order."""
        return {
            "user": self.load_user_memory(),
            "project": self.load_project_memory(),
            "project_auto": self.load_project_auto_memory(),
            "user_auto": self.load_user_auto_memory(),
        }

    def build_context(self) -> str:
        """Build complete memory context for LLM."""
        memory = self.load_all_memory()

        context_parts = []

        # Project context
        if memory["project"]:
            context_parts.append("# Project Context\n" + memory["project"])

        # User preferences
        if memory["user"]:
            context_parts.append("# User Preferences\n" + memory["user"])

        # Auto-memory (project-specific learned patterns)
        if memory["project_auto"]:
            context_parts.append("# Project Memory\n" + memory["project_auto"])

        # Auto-memory (user-wide learned patterns)
        if memory["user_auto"]:
            context_parts.append("# Your Memory\n" + memory["user_auto"])

        if not context_parts:
            return ""

        return "\n\n".join(context_parts)