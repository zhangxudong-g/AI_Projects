import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.extensions.skills import Skill

class TestSkillExtended:
    def test_skill_with_triggers(self):
        skill = Skill(
            name="test_skill",
            description="A test skill",
            version="1.0.0",
            path=Path("/tmp/skill"),
            prompt_template="Test template",
            agent_type="build",
            tools=["tool1"],
            triggers=["test", "run test"],
            content="# Test Skill\n\nUse this skill for testing."
        )
        assert skill.triggers == ["test", "run test"]
        assert "Test Skill" in skill.content

    def test_skill_default_triggers_empty(self):
        skill = Skill(
            name="test",
            description="desc",
            version="1.0",
            path=Path("/tmp"),
            prompt_template=""
        )
        assert skill.triggers == []
        assert skill.content == ""

    def test_skill_from_directory_with_format_a(self, tmp_path):
        skill_dir = tmp_path / "test_skill"
        skill_dir.mkdir()
        (skill_dir / "skill.yaml").write_text("""
name: interface
description: Generate interfaces
version: 1.0.0
agent_type: build
tools: []
triggers:
  - interface
  - generate interface
""")
        (skill_dir / "SKILL.md").write_text("# Interface Skill\n\nGenerate interfaces from data.")
        
        skill = Skill.from_directory(skill_dir)
        assert skill.name == "interface"
        assert "interface" in skill.triggers
        assert "Interface Skill" in skill.content

    def test_skill_from_directory_with_format_b(self, tmp_path):
        """Format B: SKILL.md with YAML front matter only"""
        skill_dir = tmp_path / "my_skill"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text("""---
name: my_skill
description: My skill description
version: 1.0.0
triggers:
  - my_skill
  - trigger
---

# My Skill Content

This is the skill content.
""")
        
        skill = Skill.from_skill_md(skill_dir / "SKILL.md")
        assert skill.name == "my_skill"
        assert skill.triggers == ["my_skill", "trigger"]
        assert "My Skill Content" in skill.content