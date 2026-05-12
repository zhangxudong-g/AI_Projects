import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.extensions.skills import Skill, SkillRegistry

class TestSkillRegistryExtended:
    def test_find_by_keyword_exact_match(self):
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
        
        result = registry.find_by_keyword("interface")
        assert result is skill

    def test_find_by_keyword_phrase_match(self):
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
        
        result = registry.find_by_keyword("generate interface")
        assert result is skill

    def test_find_by_keyword_no_match(self):
        registry = SkillRegistry()
        skill = Skill(
            name="test",
            description="desc",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["test"]
        )
        registry.register(skill)
        
        result = registry.find_by_keyword("interface")
        assert result is None

    def test_find_all_by_keyword(self):
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
        
        results = registry.find_all_by_keyword("analyze")
        assert len(results) == 1
        assert results[0].name == "analyze"
        
        # "docs" matches nothing
        results = registry.find_all_by_keyword("interface")
        assert len(results) == 0

    def test_find_all_by_keyword_multiple_matches(self):
        registry = SkillRegistry()
        skill1 = Skill(
            name="tdd",
            description="Test driven",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["test", "tdd"]
        )
        skill2 = Skill(
            name="testing",
            description="Testing helpers",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["test", "testing"]
        )
        registry.register(skill1)
        registry.register(skill2)
        
        results = registry.find_all_by_keyword("test")
        assert len(results) == 2

    def test_find_by_keyword_returns_first_by_specificity(self):
        """Longest trigger match wins"""
        registry = SkillRegistry()
        skill_short = Skill(
            name="debug",
            description="Debug",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["debug"]
        )
        skill_long = Skill(
            name="debug_error",
            description="Debug errors",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["debug error", "debug errors"]
        )
        registry.register(skill_short)
        registry.register(skill_long)
        
        result = registry.find_by_keyword("debug error")
        assert result.name == "debug_error"