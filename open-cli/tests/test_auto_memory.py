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
