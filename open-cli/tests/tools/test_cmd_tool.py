import pytest
from tools.cmd_tool import CmdTool, CmdError

def test_cmd_tool_init():
    trusted = ["python", "git"]
    ct = CmdTool(trusted_commands=trusted)
    assert ct.trusted_commands == trusted

def test_cmd_tool_is_trusted():
    ct = CmdTool(trusted_commands=["python", "git"])
    assert ct.is_trusted("python") is True
    assert ct.is_trusted("git") is True
    assert ct.is_trusted("rm") is False

def test_cmd_tool_execute_trusted():
    ct = CmdTool(trusted_commands=["echo"])
    result = ct.execute("echo hello")
    assert result["returncode"] == 0
    assert "hello" in result["stdout"]

def test_cmd_tool_execute_untrusted_requires_confirmation():
    ct = CmdTool(trusted_commands=["echo"])
    result = ct.execute("rm -rf /", require_confirmation=True)
    assert result["requires_confirmation"] is True