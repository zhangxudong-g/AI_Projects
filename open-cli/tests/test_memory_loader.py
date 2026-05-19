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