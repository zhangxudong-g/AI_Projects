from typing import Optional, Iterator, List
from .skill import Skill

class SkillRegistry:
    def __init__(self):
        self._skills: dict[str, Skill] = {}

    def register(self, skill: Skill):
        self._skills[skill.name] = skill

    def get(self, name: str) -> Optional[Skill]:
        return self._skills.get(name)

    def list_all(self) -> list[Skill]:
        return list(self._skills.values())

    def __iter__(self) -> Iterator[Skill]:
        return iter(self._skills.values())

    def __len__(self) -> int:
        return len(self._skills)

    def find_by_keyword(self, text: str) -> Optional[Skill]:
        """Find first skill matching keyword(s) in text.
        
        Returns the most specific match (longest trigger that matches).
        Explicit invocation (checked separately) takes priority.
        """
        text_lower = text.lower()
        best_match: Optional[Skill] = None
        best_trigger_len = 0
        
        for skill in self._skills.values():
            for trigger in skill.triggers:
                trigger_lower = trigger.lower()
                # Check if trigger appears as word-bounded substring
                if trigger_lower in text_lower:
                    trigger_len = len(trigger)
                    if trigger_len > best_trigger_len:
                        best_trigger_len = trigger_len
                        best_match = skill
        
        return best_match

    def find_all_by_keyword(self, text: str) -> List[Skill]:
        """Find all skills matching keyword(s) in text.
        
        Returns all skills that have at least one matching trigger,
        sorted by specificity (longest trigger first).
        """
        text_lower = text.lower()
        matches: List[tuple[int, Skill]] = []
        
        for skill in self._skills.values():
            for trigger in skill.triggers:
                trigger_lower = trigger.lower()
                if trigger_lower in text_lower:
                    matches.append((len(trigger), skill))
        
        # Sort by specificity (longest trigger first), deduplicate by skill name
        matches.sort(key=lambda x: x[0], reverse=True)
        seen = set()
        result = []
        for trigger_len, skill in matches:
            if skill.name not in seen:
                seen.add(skill.name)
                result.append(skill)
        
        return result
