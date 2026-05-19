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
        auto_mem_content = loader.load_project_auto_memory()
        assert "- test command: pytest" in auto_mem_content

def test_memory_priority_order():
    """Test that project memory comes after user in priority but has higher specificity."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        user_home = tmpdir / "user"
        user_home.mkdir()
        project = tmpdir / "project"
        project.mkdir()

        # User memory
        user_agents = user_home / "AGENTS.md"
        user_agents.write_text("# User Memory\n", encoding="utf-8")

        # Project memory
        project_agents = project / "AGENTS.md"
        project_agents.write_text("# Project Memory\n", encoding="utf-8")

        loader = MemoryLoader(user_home=user_home, project_path=project)
        priority = loader.get_loading_priority()

        # Verify priority order
        assert priority == ["system", "user", "project", "project_auto", "user_auto"]