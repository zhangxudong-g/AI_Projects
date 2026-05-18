from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

@dataclass
class Skill:
    name: str
    description: str
    version: str
    path: Path
    prompt_template: str
    agent_type: str = "build"
    tools: list[str] = field(default_factory=list)
    triggers: list[str] = field(default_factory=list)
    content: str = ""
    args: dict = field(default_factory=dict)

    @classmethod
    def from_directory(cls, path: Path) -> "Skill":
        """Load skill from directory - supports Format A (skill.yaml + SKILL.md)"""
        import yaml
        skill_yaml = path / "skill.yaml"
        skill_md = path / "SKILL.md"

        # Check for Format A: skill.yaml + SKILL.md
        if skill_yaml.exists() and skill_md.exists():
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
                tools=meta.get("tools", []),
                triggers=meta.get("triggers", []),
                content=prompt,
            )
        
        # Check for Format B: SKILL.md only with YAML front matter
        if skill_md.exists():
            return cls.from_skill_md(skill_md, path)
        
        raise ValueError(f"Skill at {path} missing required files")

    @classmethod
    def from_skill_md(cls, skill_md_path: Path, base_path: Optional[Path] = None) -> "Skill":
        """Load skill from SKILL.md with YAML front matter (Format B)"""
        import yaml
        
        content = skill_md_path.read_text(encoding="utf-8")
        
        # Parse YAML front matter
        if content.startswith("---"):
            parts = content.split("---", 2)
            if len(parts) >= 3:
                frontmatter = yaml.safe_load(parts[1])
                body = parts[2].strip()
            else:
                frontmatter = {}
                body = content
        else:
            frontmatter = {}
            body = content
        
        return cls(
            name=frontmatter.get("name", skill_md_path.parent.name),
            description=frontmatter.get("description", ""),
            version=frontmatter.get("version", "1.0.0"),
            path=base_path or skill_md_path.parent,
            prompt_template=body,
            agent_type=frontmatter.get("agent_type", "build"),
            tools=frontmatter.get("tools", []),
            triggers=frontmatter.get("triggers", []),
            content=body,
        )
