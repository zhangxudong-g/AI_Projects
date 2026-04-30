import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.extensions.skills import Skill, SkillRegistry, SkillLoader

class TestSkill:
    def test_skill_creation(self):
        skill = Skill(
            name="test_skill",
            description="A test skill",
            version="1.0.0",
            path=Path("/tmp/skill"),
            prompt_template="Test template",
            agent_type="build",
            tools=["tool1", "tool2"]
        )
        assert skill.name == "test_skill"
        assert skill.version == "1.0.0"
        assert skill.tools == ["tool1", "tool2"]

    def test_skill_from_directory_missing(self):
        with pytest.raises(ValueError):
            Skill.from_directory(Path("/nonexistent"))

class TestSkillRegistry:
    def test_registry_init(self):
        registry = SkillRegistry()
        assert registry._skills == {}

    def test_register(self):
        registry = SkillRegistry()
        skill = Skill(
            name="test",
            description="desc",
            version="1.0",
            path=Path("/tmp"),
            prompt_template=""
        )
        registry.register(skill)
        assert registry.get("test") is skill

    def test_get_nonexistent(self):
        registry = SkillRegistry()
        assert registry.get("nonexistent") is None

    def test_list_all(self):
        registry = SkillRegistry()
        skill1 = Skill("s1", "d1", "1.0", Path("/1"), "")
        skill2 = Skill("s2", "d2", "1.0", Path("/2"), "")
        registry.register(skill1)
        registry.register(skill2)
        assert len(registry.list_all()) == 2

    def test_iter(self):
        registry = SkillRegistry()
        skill = Skill("s1", "d1", "1.0", Path("/1"), "")
        registry.register(skill)
        assert skill in list(registry)

class TestSkillLoader:
    def test_load_from_nonexistent_directory(self, tmp_path):
        registry = SkillRegistry()
        loader = SkillLoader(registry)
        loader.load_from_directory(tmp_path / "nonexistent")
        assert len(registry) == 0

    def test_load_skill(self):
        registry = SkillRegistry()
        loader = SkillLoader(registry)
        skill = Skill("test", "desc", "1.0", Path("/tmp"), "template")
        loader.load_skill(skill)
        assert registry.get("test") is skill