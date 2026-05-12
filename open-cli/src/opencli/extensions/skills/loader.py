from pathlib import Path
from .skill import Skill
from .registry import SkillRegistry

class SkillLoader:
    def __init__(self, registry: SkillRegistry):
        self.registry = registry

    def load_from_directory(self, skill_dir: Path):
        if not skill_dir.exists() or not skill_dir.is_dir():
            return

        for skill_path in skill_dir.iterdir():
            if skill_path.is_dir():
                try:
                    skill = Skill.from_directory(skill_path)
                    self.registry.register(skill)
                except Exception:
                    pass

    def load_from_path(self, skill_path: Path) -> Skill:
        """Load a single skill from a directory path.
        
        Supports both Format A (skill.yaml + SKILL.md) and
        Format B (SKILL.md with YAML front matter).
        """
        if not skill_path.exists() or not skill_path.is_dir():
            raise ValueError(f"Invalid skill path: {skill_path}")
        
        return Skill.from_directory(skill_path)

    def discover_system_skills(self, skills_dir: Path) -> SkillRegistry:
        """Discover and load all skills from a directory structure.
        
        Loads skills into self.registry and returns it for chaining.
        """
        self.load_from_directory(skills_dir)
        return self.registry

    def load_skill(self, skill: Skill):
        """Register a pre-loaded skill (existing method, unchanged)"""
        self.registry.register(skill)