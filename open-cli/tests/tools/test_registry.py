import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.tools.base import BaseTool, ToolDefinition, ToolResult
from opencli.tools.registry import ToolRegistry
from opencli.tools.file_tool import ReadFileTool, WriteFileTool, EditFileTool, ListDirectoryTool
from opencli.tools.git_tool import GitTool
from opencli.tools.cmd_tool import CmdTool, CmdError

class TestToolRegistry:
    def test_registry_init(self):
        registry = ToolRegistry()
        assert registry._tools == {}

    def test_register_tool(self):
        registry = ToolRegistry()
        tool = ReadFileTool()
        registry.register(tool)
        assert "read_file" in registry._tools

    def test_get_tool(self):
        registry = ToolRegistry()
        tool = ReadFileTool()
        registry.register(tool)
        retrieved = registry.get("read_file")
        assert retrieved is tool

    def test_get_nonexistent_tool(self):
        registry = ToolRegistry()
        retrieved = registry.get("nonexistent")
        assert retrieved is None

    def test_list_all(self):
        registry = ToolRegistry()
        registry.register(ReadFileTool())
        registry.register(GitTool())
        definitions = registry.list_all()
        assert len(definitions) == 2
        names = [d.name for d in definitions]
        assert "read_file" in names
        assert "git_status" in names

class TestToolDefinitions:
    def test_read_file_tool_definition(self):
        tool = ReadFileTool()
        defn = tool.get_definition()
        assert defn.name == "read_file"
        assert defn.description == "Read file contents"
        assert "file_path" in defn.input_schema["properties"]

    def test_write_file_tool_definition(self):
        tool = WriteFileTool()
        defn = tool.get_definition()
        assert defn.name == "write_file"
        assert "file_path" in defn.input_schema["properties"]
        assert "content" in defn.input_schema["properties"]

    def test_edit_file_tool_definition(self):
        tool = EditFileTool()
        defn = tool.get_definition()
        assert defn.name == "edit_file"
        assert "find" in defn.input_schema["properties"]
        assert "replace" in defn.input_schema["properties"]

    def test_list_directory_tool_definition(self):
        tool = ListDirectoryTool()
        defn = tool.get_definition()
        assert defn.name == "list_directory"

    def test_git_tool_definition(self):
        tool = GitTool()
        defn = tool.get_definition()
        assert defn.name == "git_status"

    def test_cmd_tool_definition(self):
        tool = CmdTool(trusted_commands=["echo"])
        defn = tool.get_definition()
        assert defn.name == "run_command"

@pytest.mark.asyncio
class TestReadFileTool:
    async def test_file_tool_execute(self, tmp_path):
        test_file = tmp_path / "test.txt"
        test_file.write_text("Hello World")
        tool = ReadFileTool()
        result = await tool.execute(file_path=str(test_file))
        assert result.success is True
        assert result.content == "Hello World"

    async def test_file_tool_execute_not_found(self, tmp_path):
        tool = ReadFileTool()
        result = await tool.execute(file_path=str(tmp_path / "nonexistent.txt"))
        assert result.success is False
        assert result.error is not None

@pytest.mark.asyncio
class TestWriteFileTool:
    async def test_write_file_create(self, tmp_path):
        tool = WriteFileTool()
        file_path = tmp_path / "output.txt"
        result = await tool.execute(file_path=str(file_path), content="Hello World")
        assert result.success is True
        assert file_path.read_text() == "Hello World"

    async def test_write_file_overwrite(self, tmp_path):
        tool = WriteFileTool()
        file_path = tmp_path / "output.txt"
        file_path.write_text("Original")
        result = await tool.execute(file_path=str(file_path), content="New Content")
        assert result.success is True
        assert file_path.read_text() == "New Content"

    async def test_write_file_append(self, tmp_path):
        tool = WriteFileTool()
        file_path = tmp_path / "output.txt"
        file_path.write_text("Line 1\n")
        result = await tool.execute(file_path=str(file_path), content="Line 2\n", append=True)
        assert result.success is True
        assert file_path.read_text() == "Line 1\nLine 2\n"

@pytest.mark.asyncio
class TestEditFileTool:
    async def test_edit_file_success(self, tmp_path):
        tool = EditFileTool()
        file_path = tmp_path / "edit_test.txt"
        file_path.write_text("Hello World")
        result = await tool.execute(file_path=str(file_path), find="World", replace="Universe")
        assert result.success is True
        assert file_path.read_text() == "Hello Universe"

    async def test_edit_file_not_found(self, tmp_path):
        tool = EditFileTool()
        file_path = tmp_path / "edit_test.txt"
        file_path.write_text("Hello World")
        result = await tool.execute(file_path=str(file_path), find="Not Found", replace="X")
        assert result.success is False
        assert "not found" in result.error.lower()

class TestGitTool:
    def test_git_tool_init(self, tmp_path):
        tool = GitTool(repo_root=tmp_path)
        assert tool.repo_root == tmp_path

    def test_git_tool_default_repo_root(self):
        tool = GitTool()
        assert tool.repo_root == Path.cwd()

    @pytest.mark.asyncio
    async def test_git_status(self, tmp_path):
        import subprocess
        subprocess.run(["git", "init"], cwd=tmp_path, capture_output=True)
        subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=tmp_path, capture_output=True)
        subprocess.run(["git", "config", "user.name", "Test"], cwd=tmp_path, capture_output=True)

        tool = GitTool(repo_root=tmp_path)
        result = await tool.execute(command="status")
        assert result.success is True
        assert "branch" in result.content
        assert "files" in result.content

    @pytest.mark.asyncio
    async def test_git_diff_no_changes(self, tmp_path):
        import subprocess
        subprocess.run(["git", "init"], cwd=tmp_path, capture_output=True)
        subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=tmp_path, capture_output=True)
        subprocess.run(["git", "config", "user.name", "Test"], cwd=tmp_path, capture_output=True)

        tool = GitTool(repo_root=tmp_path)
        result = await tool.execute(command="diff")
        assert result.success is True
        assert result.content == "No changes."

    @pytest.mark.asyncio
    async def test_git_commit(self, tmp_path):
        import subprocess
        subprocess.run(["git", "init"], cwd=tmp_path, capture_output=True)
        subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=tmp_path, capture_output=True)
        subprocess.run(["git", "config", "user.name", "Test"], cwd=tmp_path, capture_output=True)

        (tmp_path / "test.txt").write_text("content")
        subprocess.run(["git", "add", "."], cwd=tmp_path, capture_output=True)

        tool = GitTool(repo_root=tmp_path)
        result = await tool.execute(command="commit", message="Initial commit")
        assert result.success is True
        assert result.content["success"] is True

class TestCmdTool:
    def test_cmd_tool_init(self):
        tool = CmdTool(trusted_commands=["python", "git"])
        assert tool.trusted_commands == ["python", "git"]

    def test_is_trusted(self):
        tool = CmdTool(trusted_commands=["echo", "python"])
        assert tool.is_trusted("echo") is True
        assert tool.is_trusted("python") is True
        assert tool.is_trusted("rm") is False

    @pytest.mark.asyncio
    async def test_execute_trusted(self):
        tool = CmdTool(trusted_commands=["echo"])
        result = await tool.execute(command="echo hello")
        assert result.success is True
        assert result.content["returncode"] == 0
        assert "hello" in result.content["stdout"]

    @pytest.mark.asyncio
    async def test_execute_untrusted(self):
        tool = CmdTool(trusted_commands=["echo"])
        result = await tool.execute(command="rm -rf /")
        assert result.success is False
        assert "not trusted" in result.error

    @pytest.mark.asyncio
    async def test_execute_untrusted_with_confirmation(self):
        tool = CmdTool(trusted_commands=["echo"])
        result = await tool.execute(command="rm -rf /", require_confirmation=True)
        assert result.success is False
        assert "requires confirmation" in result.error.lower()

class TestCmdError:
    def test_cmd_error_is_exception(self):
        err = CmdError("test error")
        assert isinstance(err, Exception)
        assert str(err) == "test error"
