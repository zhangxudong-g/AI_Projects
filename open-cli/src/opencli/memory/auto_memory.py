# src/opencli/memory/auto_memory.py
"""Auto-memory system that learns from user corrections and discoveries."""
import re
from pathlib import Path
from typing import Optional

class AutoMemory:
    """Manages auto-generated memory that learns from session."""

    SECTION_HEADER = "# Auto-Generated Memory\n"

    def __init__(
        self,
        project_path: Optional[Path] = None,
        user_home: Optional[Path] = None,
    ):
        self.project_path = project_path
        self.user_home = user_home or Path.home() / ".opencli"
        self.pending_entries: list[str] = []
        self._memory_path: Optional[Path] = None

    def _get_project_hash(self) -> str:
        """Get unique hash for project."""
        if self.project_path:
            import hashlib
            return hashlib.md5(str(self.project_path).encode()).hexdigest()[:8]
        return "default"

    def get_memory_path(self) -> Path:
        """Get path to MEMORY.md file."""
        if self._memory_path:
            return self._memory_path

        project_id = self._get_project_hash()
        memory_dir = self.user_home / "memory" / project_id
        memory_dir.mkdir(parents=True, exist_ok=True)
        self._memory_path = memory_dir / "MEMORY.md"
        return self._memory_path

    def has_pending(self) -> bool:
        """Check if there are pending entries to save."""
        return len(self.pending_entries) > 0

    def add_correction(self, correction: str) -> None:
        """Add a user correction to memory."""
        normalized = correction
        patterns_to_remove = [
            r"^remember\s+that\s+",
            r"^remember\s+",
            r"^note:\s*",
            r"^note\s+that\s+",
        ]
        for pattern in patterns_to_remove:
            normalized = re.sub(pattern, "", normalized, flags=re.IGNORECASE).strip()

        if normalized:
            self.pending_entries.append(f"- {normalized}")

    def add_discovery(self, discovery: str) -> None:
        """Add an AI discovery to memory."""
        self.pending_entries.append(f"- {discovery}")

    def add_preference(self, preference: str) -> None:
        """Add a user preference."""
        self.pending_entries.append(f"- {preference}")

    def flush(self) -> None:
        """Write pending entries to MEMORY.md."""
        if not self.pending_entries:
            return

        memory_path = self.get_memory_path()
        existing_content = ""

        if memory_path.exists():
            existing_content = memory_path.read_text(encoding="utf-8")

        lines = existing_content.split("\n")

        insert_idx = 0
        if lines and "# Auto-Generated Memory" in lines[0]:
            for i, line in enumerate(lines[1:], 1):
                if line.strip() and not line.startswith("#"):
                    insert_idx = i
                    break
            else:
                insert_idx = len(lines)

        new_entries = ["\n".join(self.pending_entries), ""]
        new_content = lines[:insert_idx] + new_entries + lines[insert_idx:]

        memory_path.write_text("\n".join(new_content), encoding="utf-8")
        self.pending_entries.clear()

    def get_context(self, max_lines: int = 200) -> str:
        """Get memory content for context (first N lines)."""
        memory_path = self.get_memory_path()
        if not memory_path.exists():
            return ""

        content = memory_path.read_text(encoding="utf-8")
        lines = content.split("\n")

        result_lines = []
        skip_header = True
        for line in lines:
            if skip_header and "# Auto-Generated Memory" in line:
                skip_header = False
                continue
            result_lines.append(line)
            if len(result_lines) >= max_lines:
                break

        return "\n".join(result_lines).strip()

    @classmethod
    def from_loader(cls, loader) -> "AutoMemory":
        """Create AutoMemory from existing MemoryLoader."""
        return cls(
            project_path=loader.project_path,
            user_home=loader.user_home,
        )
