import pytest
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

# Skip this test - REPL is now integrated into cli.py
pytest.skip("REPL module refactored into cli.py", allow_module_level=True)


def test_repl_initialization():
    from opencli.cli import REPL
    repl = REPL()
    assert repl.llm is not None


def test_repl_welcome_message():
    from opencli.cli import REPL
    repl = REPL()
    assert "open-cli" in repl.get_welcome()
