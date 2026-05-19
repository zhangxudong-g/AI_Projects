# open-cli Memory System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement AGENTS.md and MEMORY.md memory system for open-cli

**Architecture:** Two-tier memory system: human-written AGENTS.md (project context) + AI-written MEMORY.md (learned patterns). Files loaded at session start, merged into LLM context.

**Tech Stack:** Python 3.11+, existing open-cli architecture (AgentEngine, ToolExecutor)

---

## File Structure

```
src/opencli/
├── memory/                      # NEW: Memory system
│   ├── __init__.py
│   ├── loader.py               # MemoryLoader class
│   └── auto_memory.py          # AutoMemory class
├── agent/
│   └── engine.py               # MODIFY: Integrate memory loading
└── cli.py                      # MODIFY: Add /memory, /init commands

~/.opencli/                     # User-level (auto-created)
├── AGENTS.md                   # User preferences
└── memory/
    └── default/
        └── MEMORY.md           # Auto-learned across projects

project/
├── AGENTS.md                   # Project-level (user creates)
└── .opencli/
    └── AGENTS.md               # Alternative location
```

---

## Task 1: Create Memory Loader

**Files:**
- Create: `src/opencli/memory/__init__.py`
- Create: `src/opencli/memory/loader.py`
- Create: `tests/test_memory_loader.py`

- [ ] **Step 1: Write failing test for MemoryLoader**

```python
# tests/test_memory_loader.py
import pytest
from pathlib import Path
from opencli.memory.loader import MemoryLoader

def test_load_user_agents_md():
    """Test loading user-level AGENTS.md"""
    loader = MemoryLoader(user_home=Path("/tmp/test_user"))
    # Should return empty string if no file exists
    assert loader.load_user_memory() == ""

def test_load_project_agents_md_found():
    """Test loading project AGENTS.md when it exists"""
    loader = MemoryLoader(project_path=Path("/tmp/test_project"))
    content = loader.load_project_memory()
    # Should return content or empty string
    assert isinstance(content, str)

def test_memory_priority():
    """Test that project memory takes priority over user memory"""
    loader = MemoryLoader(
        user_home=Path("/tmp/user"),
        project_path=Path("/tmp/project")
    )
    priority_order = loader.get_loading_priority()
    # Project should load after user
    assert priority_order.index("project") > priority_order.index("user")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_memory_loader.py -v`
Expected: ERROR - module not found

- [ ] **Step 3: Create memory/__init__.py**

```python
# src/opencli/memory/__init__.py
"""Memory system for open-cli."""
from .loader import MemoryLoader
from .auto_memory import AutoMemory

__all__ = ["MemoryLoader", "AutoMemory"]
```

- [ ] **Step 4: Write MemoryLoader implementation**

```python
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

    def _get_default_user_home(self) -> Path:
        """Get default user home directory."""
        return Path.home() / ".opencli"

    def _get_project_hash(self) -> str:
        """Get unique hash for project based on git root."""
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
                    return hashlib.md5(project_root.encode()).hexdigest()[:8]
            except Exception:
                pass
        # Fallback to project path string hash
        if self.project_path:
            return hashlib.md5(str(self.project_path).encode()).hexdigest()[:8]
        return "default"

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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `pytest tests/test_memory_loader.py -v`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add src/opencli/memory/__init__.py src/opencli/memory/loader.py tests/test_memory_loader.py
git commit -m "feat: add MemoryLoader for AGENTS.md and MEMORY.md loading"
```

---

## Task 2: Create AutoMemory Writer

**Files:**
- Create: `src/opencli/memory/auto_memory.py`
- Modify: `tests/test_memory_loader.py` (add auto-memory tests)
- Create: `tests/test_auto_memory.py`

- [ ] **Step 1: Write failing test for AutoMemory**

```python
# tests/test_auto_memory.py
import pytest
from pathlib import Path
from opencli.memory.auto_memory import AutoMemory

def test_add_correction():
    """Test adding a correction to auto-memory."""
    auto_mem = AutoMemory(project_path=Path("/tmp/test_project"))
    auto_mem.add_correction("remember that my name is Alice")
    assert auto_mem.has_pending()

def test_add_discovery():
    """Test adding a discovery."""
    auto_mem = AutoMemory(project_path=Path("/tmp/test_project"))
    auto_mem.add_discovery("build command: npm run build")
    assert auto_mem.has_pending()

def test_flush_writes_file():
    """Test that flush writes to MEMORY.md."""
    auto_mem = AutoMemory(project_path=Path("/tmp/test_project"))
    auto_mem.add_discovery("test command: pytest")
    auto_mem.flush()

    memory_path = auto_mem.get_memory_path()
    assert memory_path.exists()
    content = memory_path.read_text()
    assert "pytest" in content
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_auto_memory.py -v`
Expected: ERROR - module not found

- [ ] **Step 3: Write AutoMemory implementation**

```python
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
        """Add a user correction to memory.

        Args:
            correction: What the user wants remembered (e.g., "remember that my name is Alice")
        """
        # Normalize: remove "remember that" prefix if present
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
        """Add an AI discovery to memory.

        Args:
            discovery: What the AI learned (e.g., "build command: npm run build")
        """
        self.pending_entries.append(f"- {discovery}")

    def add_preference(self, preference: str) -> None:
        """Add a user preference.

        Args:
            preference: User's preference (e.g., "Prefers short explanations")
        """
        self.pending_entries.append(f"- {preference}")

    def flush(self) -> None:
        """Write pending entries to MEMORY.md."""
        if not self.pending_entries:
            return

        memory_path = self.get_memory_path()
        existing_content = ""

        if memory_path.exists():
            existing_content = memory_path.read_text(encoding="utf-8")

        # Parse existing content to preserve structure
        lines = existing_content.split("\n")

        # Find insertion point (after header if present)
        insert_idx = 0
        if lines and "# Auto-Generated Memory" in lines[0]:
            # Find first non-empty, non-header line
            for i, line in enumerate(lines[1:], 1):
                if line.strip() and not line.startswith("#"):
                    insert_idx = i
                    break
            else:
                insert_idx = len(lines)

        # Build new content
        new_entries = ["\n".join(self.pending_entries), ""]
        new_content = lines[:insert_idx] + new_entries + lines[insert_idx:]

        # Write
        memory_path.write_text("\n".join(new_content), encoding="utf-8")

        # Clear pending
        self.pending_entries.clear()

    def get_context(self, max_lines: int = 200) -> str:
        """Get memory content for context (first N lines)."""
        memory_path = self.get_memory_path()
        if not memory_path.exists():
            return ""

        content = memory_path.read_text(encoding="utf-8")
        lines = content.split("\n")

        # Skip header for context
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
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `pytest tests/test_auto_memory.py -v`
Expected: PASS (3 tests)

- [ ] **Step 4: Commit**

```bash
git add src/opencli/memory/auto_memory.py tests/test_auto_memory.py
git commit -m "feat: add AutoMemory for learned patterns"
```

---

## Task 3: Integrate Memory into AgentEngine

**Files:**
- Modify: `src/opencli/agent/engine.py`

- [ ] **Step 1: Read current engine.py implementation**

Run: `Get-Content src/opencli/agent/engine.py` (PowerShell)

- [ ] **Step 2: Add memory loading to AgentEngine**

In the `run()` method, after initializing but before `_generate_plan()`:

```python
# In __init__ or run(), add:
self.memory_loader = MemoryLoader(project_path=self.workspace_root)

# In run() method, before building prompt:
memory_context = self.memory_loader.build_context()
```

- [ ] **Step 3: Update prompt building to include memory**

```python
# Where prompt is built, prepend memory context:
if memory_context:
    full_context = f"{memory_context}\n\n## Your Task\n{task}"
else:
    full_context = f"## Your Task\n{task}"
```

- [ ] **Step 4: Add auto-memory tracking**

```python
# After each user correction or when user says "remember":
auto_memory = AutoMemory.from_loader(self.memory_loader)
auto_memory.add_correction(user_input)
auto_memory.flush()
```

- [ ] **Step 5: Commit**

```bash
git add src/opencli/agent/engine.py
git commit -m "feat: integrate memory system into AgentEngine"
```

---

## Task 4: Add CLI Commands (/memory, /init)

**Files:**
- Modify: `src/opencli/cli.py`

- [ ] **Step 1: Read current cli.py implementation**

Run: `Get-Content src/opencli/cli.py` (PowerShell)

- [ ] **Step 2: Add /memory command**

```python
# Add to cli.py
import typer
from pathlib import Path

memory_app = typer.Typer(help="Memory management commands")

@memory_app.command("view")
def memory_view():
    """View current memory contents."""
    loader = MemoryLoader()
    context = loader.build_context()
    if context:
        console.print(context)
    else:
        console.print("[dim]No memory loaded.[/dim]")

@memory_app.command("edit")
def memory_edit():
    """Edit AGENTS.md file."""
    # Open in user's editor
    loader = MemoryLoader()
    agents_path = loader.get_user_agents_path()
    if not agents_path.exists():
        agents_path.parent.mkdir(parents=True, exist_ok=True)
        agents_path.write_text("# Project Context\n\n", encoding="utf-8")
    # Use default editor
    import os
    os.environ["EDITOR"] = os.environ.get("EDITOR", "notepad")
    typer.launch(str(agents_path))

@memory_app.command("clear")
def memory_clear():
    """Clear auto-memory."""
    loader = MemoryLoader()
    auto_memory = AutoMemory.from_loader(loader)
    memory_path = auto_memory.get_memory_path()
    if memory_path.exists():
        memory_path.unlink()
    console.print("[green]Auto-memory cleared.[/green]")

# Add to main app
app.add_typer(memory_app, name="memory")
```

- [ ] **Step 3: Add /init command**

```python
# Add to cli.py
init_app = typer.Typer(help="Initialize project for open-cli")

@init_app.command("default")
def init_project():
    """Analyze project and create AGENTS.md."""
    project_path = Path.cwd()

    # Detect tech stack
    tech_stack = detect_tech_stack(project_path)

    # Generate AGENTS.md content
    content = f"""# Project Context

## Tech Stack
{tech_stack}

## Project Structure
- (Describe your project structure here)

## Build Commands
- (Add build commands here)

## Coding Standards
- (Add coding standards here)
"""

    agents_path = project_path / "AGENTS.md"
    if agents_path.exists():
        console.print("[yellow]AGENTS.md already exists. Not overwriting.[/yellow]")
    else:
        agents_path.write_text(content, encoding="utf-8")
        console.print(f"[green]Created {agents_path}[/green]")
        console.print("Please edit it with your project details.")
```

- [ ] **Step 4: Commit**

```bash
git add src/opencli/cli.py
git commit -m "feat: add /memory and /init commands"
```

---

## Task 5: Integration Test

**Files:**
- Create: `tests/test_memory_integration.py`

- [ ] **Step 1: Write integration test**

```python
# tests/test_memory_integration.py
import pytest
import tempfile
from pathlib import Path
from opencli.memory.loader import MemoryLoader
from opencli.memory.auto_memory import AutoMemory

def test_full_memory_flow():
    """Test full memory flow: create, load, verify."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)

        # Create user home structure
        user_home = tmpdir / "user"
        user_home.mkdir()

        # Create project structure
        project = tmpdir / "project"
        project.mkdir()

        # Write AGENTS.md
        agents_path = project / "AGENTS.md"
        agents_path.write_text("# Test Project\n\nPython 3.11", encoding="utf-8")

        # Load memory
        loader = MemoryLoader(user_home=user_home, project_path=project)
        context = loader.build_context()

        assert "Test Project" in context
        assert "Python 3.11" in context

        # Write auto-memory
        auto_mem = AutoMemory.from_loader(loader)
        auto_mem.add_discovery("test command: pytest")
        auto_mem.flush()

        # Verify auto-memory was written
        assert loader.load_project_auto_memory() == "- test command: pytest"
```

- [ ] **Step 2: Run integration test**

Run: `pytest tests/test_memory_integration.py -v`

- [ ] **Step 3: Commit**

```bash
git add tests/test_memory_integration.py
git commit -m "test: add memory system integration test"
```

---

## Task 6: Verify End-to-End

- [ ] **Step 1: Run full test suite**

Run: `pytest tests/ -v`

- [ ] **Step 2: Manual test**

```bash
# Create test project
mkdir test_project
cd test_project
echo "# Python Project" > AGENTS.md

# Run opencli
opencli "remember that I prefer type hints"

# Verify memory was created
cat ~/.opencli/memory/*/MEMORY.md
```

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete memory system implementation"
```

---

## Self-Review Checklist

- [ ] Spec coverage: All requirements from design doc implemented?
- [ ] No placeholders: All steps have actual code/commands?
- [ ] Type consistency: All method names consistent throughout?
- [ ] Test coverage: Each component has tests?
- [ ] Files created: `memory/__init__.py`, `memory/loader.py`, `memory/auto_memory.py`?
- [ ] Files modified: `agent/engine.py`, `cli.py`?
- [ ] Commands added: `/memory view`, `/memory edit`, `/memory clear`, `/init`?

---

## Plan Complete

**Saved to:** `thoughts/shared/plans/2026-05-12-opencli-memory-system.md`

**Two execution options:**

1. **Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

2. **Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
