import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.extensions.skills import Skill, SkillRegistry, SkillLoader

class TestSkillLoaderExtended:
    def test_load_format_b_skill(self, tmp_path):
        """Load a skill from SKILL.md with YAML front matter only"""
        skill_dir = tmp_path / "format_b_skill"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text("""---
name: format_b
description: Format B skill
version: 1.0.0
triggers:
  - fb
  - format_b
---

# Format B Skill

This skill uses Format B (SKILL.md only).
""")

        registry = SkillRegistry()
        loader = SkillLoader(registry)
        skill = loader.load_from_path(skill_dir)

        assert skill is not None
        assert skill.name == "format_b"
        assert "format_b" in skill.triggers
        assert "Format B Skill" in skill.content

    def test_load_format_a_skill(self, tmp_path):
        """Load a skill from skill.yaml + SKILL.md"""
        skill_dir = tmp_path / "format_a_skill"
        skill_dir.mkdir()
        (skill_dir / "skill.yaml").write_text("""
name: format_a
description: Format A skill
version: 1.0.0
triggers:
  - fa
  - format_a
""")
        (skill_dir / "SKILL.md").write_text("# Format A Skill\n\nThis uses Format A.")

        registry = SkillRegistry()
        loader = SkillLoader(registry)
        skill = loader.load_from_path(skill_dir)

        assert skill is not None
        assert skill.name == "format_a"
        assert "format_a" in skill.triggers

    def test_discover_system_skills(self, tmp_path):
        """Discover skills from a directory structure"""
        skills_dir = tmp_path / "skills"
        skills_dir.mkdir()

        # Create two skills
        skill1 = skills_dir / "skill_one"
        skill1.mkdir()
        (skill1 / "skill.yaml").write_text("""
name: skill_one
description: First skill
version: 1.0.0
triggers: ["one", "first"]
""")
        (skill1 / "SKILL.md").write_text("# Skill One\n\nContent one.")

        skill2 = skills_dir / "skill_two"
        skill2.mkdir()
        (skill2 / "SKILL.md").write_text("""---
name: skill_two
description: Second skill
version: 1.0.0
triggers: ["two", "second"]
---

# Skill Two

Content two.
""")

        registry = SkillRegistry()
        loader = SkillLoader(registry)
        loader.discover_system_skills(skills_dir)

        assert len(registry) == 2
        assert registry.get("skill_one") is not None
        assert registry.get("skill_two") is not None