import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.skills.builtins import get_builtin_skills, TDD_SKILL, DEBUG_SKILL, REVIEW_SKILL

class TestBuiltInSkills:
    def test_get_builtin_skills_returns_list(self):
        skills = get_builtin_skills()
        assert isinstance(skills, list)
        assert len(skills) >= 3

    def test_tdd_skill_has_triggers(self):
        skill = TDD_SKILL
        assert "tdd" in skill.triggers
        assert "test driven" in skill.triggers
        assert len(skill.content) > 0

    def test_debug_skill_has_triggers(self):
        skill = DEBUG_SKILL
        assert "debug" in skill.triggers
        assert len(skill.content) > 0

    def test_review_skill_has_triggers(self):
        skill = REVIEW_SKILL
        assert "review" in skill.triggers
        assert len(skill.content) > 0

    def test_all_builtins_have_required_fields(self):
        skills = get_builtin_skills()
        for skill in skills:
            assert skill.name
            assert skill.description
            assert skill.triggers
            assert skill.content
            assert skill.version
