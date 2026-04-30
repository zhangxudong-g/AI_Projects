import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.extensions.commands import CustomCommand, CommandRegistry, CommandParser

class TestCustomCommand:
    def test_command_creation(self):
        cmd = CustomCommand(
            name="test_cmd",
            description="A test command",
            prompt_template="Do {arg}",
            aliases=["tc", "t"]
        )
        assert cmd.name == "test_cmd"
        assert cmd.aliases == ["tc", "t"]

class TestCommandRegistry:
    def test_registry_init(self):
        registry = CommandRegistry()
        assert registry.commands == {}

    def test_register(self):
        registry = CommandRegistry()
        cmd = CustomCommand("test", "desc", "template")
        registry.register(cmd)
        assert registry.get("test") is cmd

    def test_register_with_aliases(self):
        registry = CommandRegistry()
        cmd = CustomCommand("test", "desc", "template", aliases=["t"])
        registry.register(cmd)
        assert registry.get("test") is cmd
        assert registry.get("t") is cmd

    def test_get_nonexistent(self):
        registry = CommandRegistry()
        assert registry.get("nonexistent") is None

    def test_list_all(self):
        registry = CommandRegistry()
        cmd1 = CustomCommand("c1", "d1", "t1")
        cmd2 = CustomCommand("c2", "d2", "t2")
        registry.register(cmd1)
        registry.register(cmd2)
        assert len(registry.list_all()) == 2

    def test_len(self):
        registry = CommandRegistry()
        cmd = CustomCommand("test", "desc", "template")
        registry.register(cmd)
        assert len(registry) == 1

class TestCommandParser:
    def test_parse_valid(self):
        parser = CommandParser()
        name, args = parser.parse("/test arg1 arg2")
        assert name == "test"
        assert args == "arg1 arg2"

    def test_parse_no_args(self):
        parser = CommandParser()
        name, args = parser.parse("/test")
        assert name == "test"
        assert args is None

    def test_parse_empty(self):
        parser = CommandParser()
        assert parser.parse("") == (None, None)
        assert parser.parse(None) == (None, None)

    def test_parse_non_command(self):
        parser = CommandParser()
        name, args = parser.parse("just some text")
        assert name is None

    def test_is_command(self):
        parser = CommandParser()
        assert parser.is_command("/test") is True
        assert parser.is_command("not a command") is False
        assert parser.is_command("") is False