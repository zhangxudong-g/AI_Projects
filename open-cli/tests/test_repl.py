import pytest
from io import StringIO
from cli import REPL

def test_repl_initialization():
    repl = REPL()
    assert repl.llm is not None
    assert repl.running is False

def test_repl_welcome_message():
    repl = REPL()
    assert "open-cli" in repl.get_welcome()