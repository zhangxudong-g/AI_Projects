import pytest
import tempfile
import shutil
from pathlib import Path
from core.security import SecurityBoundary

@pytest.fixture
def temp_workspace():
    tmp = tempfile.mkdtemp()
    yield Path(tmp)
    shutil.rmtree(tmp)

def test_security_boundary_init(temp_workspace):
    sb = SecurityBoundary(workspace_root=temp_workspace)
    assert sb.workspace_root == temp_workspace

def test_path_within_workspace_allowed(temp_workspace):
    sb = SecurityBoundary(workspace_root=temp_workspace)
    allowed = sb.is_path_allowed(temp_workspace / "file.txt")
    assert allowed is True

def test_path_outside_workspace_rejected(temp_workspace):
    sb = SecurityBoundary(workspace_root=temp_workspace)
    outside = Path(temp_workspace).parent / "evil.txt"
    allowed = sb.is_path_allowed(outside)
    assert allowed is False

def test_normalize_path_prevents_traversal(temp_workspace):
    sb = SecurityBoundary(workspace_root=temp_workspace)
    traversal = temp_workspace / ".." / ".." / "etc" / "passwd"
    normalized = sb.normalize_path(traversal)
    assert not sb.is_path_allowed(normalized)