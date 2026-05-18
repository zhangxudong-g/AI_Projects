import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.extensions.skills import Skill, SkillRegistry
from opencli.skills.builtins import get_builtin_skills
from opencli.extensions.skills.cli import format_skill_list, format_skill_show

class TestSkillsCLI:
    def test_format_skill_list(self):
        registry = SkillRegistry()
        skill1 = Skill(
            name="tdd",
            description="Test driven development",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["tdd"]
        )
        skill2 = Skill(
            name="debug",
            description="Debugging skill",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["debug"]
        )
        registry.register(skill1)
        registry.register(skill2)
        
        output = format_skill_list(registry.list_all())
        assert "tdd" in output
        assert "debug" in output
        assert "Test driven development" in output

    def test_format_skill_show(self):
        skill = Skill(
            name="tdd",
            description="Test driven development",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["tdd", "test driven"],
            content="# TDD Skill\n\nTest driven development workflow."
        )
        
        output = format_skill_show(skill)
        assert "tdd" in output
        assert "Test driven development" in output
        assert "tdd, test driven" in output
        assert "TDD Skill" in output

    def test_format_skill_show_not_found(self):
        output = format_skill_show(None)
        assert "not found" in output.lower()