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

    def load_skill(self, skill: Skill):
        self.registry.register(skill)