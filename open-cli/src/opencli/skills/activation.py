from typing import Optional, List, Tuple
from ..extensions.skills import Skill, SkillRegistry

def detect_skill_invocation(message: str) -> Tuple[bool, Optional[str]]:
    """Detect explicit skill invocation via /skill prefix.
    
    Returns:
        Tuple of (was_invoked, skill_name_or_none)
        
    Examples:
        "/interface generate UserTable" → (True, "interface")
        "/skill interface" → (True, "interface")
        "/skill name value" → (True, "name")
        "regular message" → (False, None)
    """
    stripped = message.strip()
    
    if not stripped.startswith("/"):
        return (False, None)
    
    # Remove leading slash
    rest = stripped[1:]
    
    # Check for "/skill <name>" format
    if rest.startswith("skill "):
        parts = rest.split(" ", 1)
        if len(parts) > 1:
            return (True, parts[1].strip())
        return (False, None)
    
    # "/skillname" format - rest is the skill name (first word before space)
    # Validate it's a known skill name (alphanumeric + underscore)
    first_word = rest.split()[0] if rest else ""
    if first_word.replace("_", "").replace("-", "").isalnum():
        return (True, first_word)
    
    return (False, None)

def match_skill_by_keyword(message: str, registry: SkillRegistry) -> List[Skill]:
    """Find all skills matching trigger keywords in the message.
    
    Returns all matching skills sorted by specificity (longest trigger first).
    """
    return registry.find_all_by_keyword(message)

def parse_skill_args(message: str) -> dict:
    """Parse key=value arguments from skill invocation.
    
    Example:
        "/tdd mode=strict verbose=true" → {"mode": "strict", "verbose": "true"}
    """
    args = {}
    parts = message.split()
    for part in parts[1:]:  # Skip skill name
        if "=" in part:
            key, value = part.split("=", 1)
            args[key.strip()] = value.strip()
    return args