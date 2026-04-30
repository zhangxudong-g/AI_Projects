from dataclasses import dataclass, field
from pathlib import Path

@dataclass
class Skill:
    name: str
    description: str
    version: str
    path: Path
    prompt_template: str
    agent_type: str = "build"
    tools: list[str] = field(default_factory=list)

    @classmethod
    def from_directory(cls, path: Path) -> "Skill":
        import yaml
        skill_yaml = path / "skill.yaml"
        skill_md = path / "SKILL.md"

        if not skill_yaml.exists() or not skill_md.exists():
            raise ValueError(f"Skill at {path} missing required files (skill.yaml, SKILL.md)")

        with open(skill_yaml) as f:
            meta = yaml.safe_load(f)
        with open(skill_md) as f:
            prompt = f.read()

        return cls(
            name=meta["name"],
            description=meta["description"],
            version=meta["version"],
            path=path,
            prompt_template=prompt,
            agent_type=meta.get("agent_type", "build"),
            tools=meta.get("tools", [])
        )