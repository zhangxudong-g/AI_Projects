import pytest
import tempfile
import shutil
from pathlib import Path
from tools.file_tool import FileTool
from core.security import SecurityBoundary, SecurityError

@pytest.fixture
def temp_workspace():
    tmp = tempfile.mkdtemp()
    yield Path(tmp)
    shutil.rmtree(tmp)

def test_file_tool_init(temp_workspace):
    security = SecurityBoundary(temp_workspace)
    ft = FileTool(security)
    assert ft.security == security

def test_read_file_success(temp_workspace):
    security = SecurityBoundary(temp_workspace)
    ft = FileTool(security)

    test_file = temp_workspace / "test.txt"
    test_file.write_text("Hello World")

    content = ft.read_file(str(test_file))
    assert content == "Hello World"

def test_read_file_outside_workspace_rejected(temp_workspace):
    security = SecurityBoundary(temp_workspace)
    ft = FileTool(security)

    outside = Path(temp_workspace).parent / "evil.txt"
    with pytest.raises(SecurityError):
        ft.read_file(str(outside))

def test_write_file_success(temp_workspace):
    security = SecurityBoundary(temp_workspace)
    ft = FileTool(security)

    result = ft.write_file(str(temp_workspace / "new.txt"), "New content")
    assert result["success"] is True
    assert (temp_workspace / "new.txt").read_text() == "New content"

def test_write_file_outside_workspace_rejected(temp_workspace):
    security = SecurityBoundary(temp_workspace)
    ft = FileTool(security)

    outside = Path(temp_workspace).parent / "evil.txt"
    with pytest.raises(SecurityError):
        ft.write_file(str(outside), "evil content")

def test_list_directory(temp_workspace):
    security = SecurityBoundary(temp_workspace)
    ft = FileTool(security)

    (temp_workspace / "file1.txt").write_text("1")
    (temp_workspace / "file2.txt").write_text("2")
    (temp_workspace / "subdir").mkdir()
    (temp_workspace / "subdir" / "file3.txt").write_text("3")

    files = ft.list_directory(str(temp_workspace))
    assert "file1.txt" in files
    assert "file2.txt" in files
    assert "subdir/" in files