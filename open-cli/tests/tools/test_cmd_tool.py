import pytest
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

# Skip these tests - they test the old API structure
pytest.skip("Old API structure tests - see test_registry.py for new tests", allow_module_level=True)


def test_cmd_tool_init():
    from opencli.tools.cmd_tool import CmdTool, CmdError
    trusted = ["python", "git"]
    ct = CmdTool(trusted_commands=trusted)
    assert ct.trusted_commands == trusted


def test_cmd_tool_is_trusted():
    from opencli.tools.cmd_tool import CmdTool
    ct = CmdTool(trusted_commands=["python", "git"])
    assert ct.is_trusted("python") is True
    assert ct.is_trusted("git") is True
    assert ct.is_trusted("rm") is False
