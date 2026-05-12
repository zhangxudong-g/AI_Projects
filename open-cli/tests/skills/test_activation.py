import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.extensions.skills import Skill, SkillRegistry
from opencli.skills.activation import detect_skill_invocation, match_skill_by_keyword

class TestSkillActivation:
    def test_detect_explicit_invocation_slash_name(self):
        was_invoked, name = detect_skill_invocation("/interface generate UserTable")
        assert was_invoked is True
        assert name == "interface"

    def test_detect_explicit_invocation_slash_skill_space_name(self):
        was_invoked, name = detect_skill_invocation("/skill interface")
        assert was_invoked is True
        assert name == "interface"

    def test_detect_regular_message(self):
        was_invoked, name = detect_skill_invocation("generate interfaces for my data")
        assert was_invoked is False
        assert name is None

    def test_detect_no_skill(self):
        was_invoked, name = detect_skill_invocation("hello world")
        assert was_invoked is False
        assert name is None

    def test_match_skill_by_keyword_single(self):
        registry = SkillRegistry()
        skill = Skill(
            name="interface",
            description="Generate interfaces",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["interface", "generate interface"]
        )
        registry.register(skill)
        
        matches = match_skill_by_keyword("generate interfaces from data", registry)
        assert len(matches) == 1
        assert matches[0].name == "interface"

    def test_match_skill_by_keyword_multiple(self):
        registry = SkillRegistry()
        skill1 = Skill(
            name="analyze",
            description="Analyze code",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["analyze", "analysis"]
        )
        skill2 = Skill(
            name="docs",
            description="Generate docs",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["docs", "documentation"]
        )
        registry.register(skill1)
        registry.register(skill2)
        
        matches = match_skill_by_keyword("analyze this code and generate docs", registry)
        assert len(matches) == 2

    def test_match_skill_by_keyword_no_match(self):
        registry = SkillRegistry()
        skill = Skill(
            name="test",
            description="Testing",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["test"]
        )
        registry.register(skill)
        
        matches = match_skill_by_keyword("hello world", registry)
        assert len(matches) == 0

    def test_explicit_invocation_wins_over_keyword(self):
        """When /skill is used, keyword matching is bypassed.
        
        This test documents expected behavior: explicit /skill prefix
        should be handled separately from keyword matching.
        """
        was_invoked, name = detect_skill_invocation("/tdd write tests for my code")
        assert was_invoked is True
        assert name == "tdd"