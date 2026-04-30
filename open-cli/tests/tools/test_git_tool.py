import pytest
import tempfile
import shutil
from pathlib import Path
from tools.git_tool import GitTool

@pytest.fixture
def temp_git_repo():
    tmp = tempfile.mkdtemp()
    repo_path = Path(tmp)
    import subprocess
    subprocess.run(["git", "init"], cwd=repo_path, capture_output=True)
    subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=repo_path, capture_output=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=repo_path, capture_output=True)
    yield repo_path
    shutil.rmtree(tmp)

def test_git_tool_init(temp_git_repo):
    gt = GitTool(repo_root=temp_git_repo)
    assert gt.repo_root == temp_git_repo

def test_git_status(temp_git_repo):
    gt = GitTool(repo_root=temp_git_repo)
    status = gt.status()
    assert "branch" in status
    assert "files" in status

def test_git_diff_no_changes(temp_git_repo):
    gt = GitTool(repo_root=temp_git_repo)
    diff = gt.diff()
    assert diff == "No changes."

def test_git_diff_with_changes(temp_git_repo):
    """Test diff after adding file to git tracking."""
    gt = GitTool(repo_root=temp_git_repo)
    (temp_git_repo / "test.txt").write_text("changes")
    import subprocess
    subprocess.run(["git", "add", "test.txt"], cwd=temp_git_repo, capture_output=True)
    subprocess.run(["git", "commit", "-m", "add file"], cwd=temp_git_repo, capture_output=True)
    (temp_git_repo / "test.txt").write_text("modified content")
    diff = gt.diff()
    assert "test.txt" in diff

def test_git_commit(temp_git_repo):
    gt = GitTool(repo_root=temp_git_repo)
    (temp_git_repo / "test.txt").write_text("content")
    import subprocess
    subprocess.run(["git", "add", "."], cwd=temp_git_repo, capture_output=True)
    result = gt.commit("Initial commit")
    assert result["success"] is True