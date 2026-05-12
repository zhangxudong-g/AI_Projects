from typing import List, Optional
from ..extensions.skills import Skill

def format_skill_header(skill: Skill) -> str:
    """Format a skill header for injection into prompts.
    
    Format:
        === SKILL: {skill_name} ===
        {skill description}
        ==========================
    """
    divider = "=" * len(f"SKILL: {skill.name}")
    return f"""=== SKILL: {skill.name} ===
{skill.description}
{divider}

"""

def inject_skill_into_prompt(
    message: str,
    skills: List[Skill],
    memory_context: Optional[str] = None
) -> str:
    """Prepend skill content to prompt.
    
    Format:
        === SKILL: {name} ===
        {content}
        ==========================
        
        [Memory context if present]
        
        User: {original message}
    """
    if not skills:
        return message
    
    skill_headers = []
    for skill in skills:
        skill_headers.append(f"{format_skill_header(skill)}{skill.content}")
    
    skills_section = "\n\n".join(skill_headers)
    
    if memory_context:
        return f"""{skills_section}

---
## Context
{memory_context}

## Your Task
{message}"""
    else:
        return f"""{skills_section}

## Your Task
{message}"""