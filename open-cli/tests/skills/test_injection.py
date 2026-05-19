import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.extensions.skills import Skill
from opencli.skills.injection import inject_skill_into_prompt, format_skill_header

class TestSkillInjection:
    def test_format_skill_header(self):
        skill = Skill(
            name="interface",
            description="Generate interfaces",
            version="1.0",
            path=Path("/tmp"),
            prompt_template=""
        )
        header = format_skill_header(skill)
        assert "=== SKILL: interface ===" in header
        assert "Generate interfaces" in header

    def test_inject_single_skill(self):
        skill = Skill(
            name="interface",
            description="Generate interfaces",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["interface"],
            content="# Interface Skill\n\nGenerate interfaces from data structures."
        )
        
        result = inject_skill_into_prompt(
            "generate interfaces for UserTable",
            [skill]
        )
        
        assert "=== SKILL: interface ===" in result
        assert "Interface Skill" in result
        assert "generate interfaces for UserTable" in result

    def test_inject_multiple_skills(self):
        skill1 = Skill(
            name="analyze",
            description="Analyze code",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["analyze"],
            content="# Analyze Skill\n\nAnalyze code thoroughly."
        )
        skill2 = Skill(
            name="docs",
            description="Generate docs",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["docs"],
            content="# Docs Skill\n\nGenerate documentation."
        )
        
        result = inject_skill_into_prompt(
            "analyze this code and generate docs",
            [skill1, skill2]
        )
        
        assert "=== SKILL: analyze ===" in result
        assert "=== SKILL: docs ===" in result
        assert "analyze this code" in result

    def test_inject_skill_with_memory_context(self):
        skill = Skill(
            name="test",
            description="Testing",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["test"],
            content="# Test Skill\n\nWrite tests first."
        )
        
        result = inject_skill_into_prompt(
            "test my code",
            [skill],
            memory_context="Project: MyApp\nTech: Python 3.12"
        )
        
        assert "=== SKILL: test ===" in result
        assert "Project: MyApp" in result
        assert "test my code" in result

    def test_inject_skill_empty_skills_list(self):
        result = inject_skill_into_prompt(
            "regular message",
            []
        )
        assert result == "regular message"

    def test_inject_skill_no_memory(self):
        skill = Skill(
            name="tdd",
            description="Test driven",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["tdd"],
            content="# TDD Skill\n\nAlways write tests first."
        )
        
        result = inject_skill_into_prompt(
            "write tests for calculator",
            [skill]
        )
        
        assert "=== SKILL: tdd ===" in result
        assert "write tests for calculator" in result