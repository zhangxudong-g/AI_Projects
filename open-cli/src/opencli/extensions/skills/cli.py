from typing import List, Optional
from .skill import Skill

def format_skill_list(skills: List[Skill]) -> str:
    """Format a list of skills for display."""
    if not skills:
        return "No skills found."
    
    lines = ["Available Skills:", ""]
    for skill in skills:
        triggers_str = ", ".join(skill.triggers[:3])  # Show first 3 triggers
        lines.append(f"  {skill.name:<15} - {skill.description} [{triggers_str}]")
    
    return "\n".join(lines)

def format_skill_show(skill: Optional[Skill]) -> str:
    """Format a single skill for detailed display."""
    if skill is None:
        return "Skill not found. Use 'skill list' to see available skills."
    
    lines = [
        f"=== Skill: {skill.name} ===",
        f"Description: {skill.description}",
        f"Version: {skill.version}",
        f"Triggers: {', '.join(skill.triggers)}",
        f"Agent Type: {skill.agent_type}",
        "",
        "--- Content ---",
        skill.content[:500] + ("..." if len(skill.content) > 500 else ""),
    ]
    
    return "\n".join(lines)

def list_skills(registry) -> str:
    """List all registered skills."""
    return format_skill_list(registry.list_all())

def show_skill(registry, name: str) -> str:
    """Show detailed info for a specific skill."""
    skill = registry.get(name)
    return format_skill_show(skill)