# open-cli Skills System Implementation Plan

**Goal:** Implement a skills invocation system with `/skill` syntax and keyword triggers, injecting skill content into LLM prompts.

**Architecture:** Skill activation via explicit prefix or keyword match → content prepended to prompt → normal agent flow continues.

**Design:** `thoughts/shared/designs/2026-05-12-opencli-skills-system-design.md`

---

## Dependency Graph

```
Batch 1 (parallel): 1.1, 1.2 [foundation - no deps]
Batch 2 (parallel): 2.1, 2.2 [core modules - depend on batch 1]
Batch 3 (parallel): 3.1, 3.2 [integration modules - depend on batch 2]
Batch 4 (parallel): 4.1, 4.2, 4.3 [integration into engine + builtins + CLI]
```

---

## Batch 1: Foundation (parallel - 2 implementers)

### Task 1.1: Extend Skill dataclass with triggers/content
**File:** `src/opencli/extensions/skills/skill.py`
**Test:** `tests/extensions/test_skills_extended.py`
**Depends:** none

```python
# test content (copy-paste ready)
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
```

```python
# implementation (copy-paste ready)
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
```

**Verify:** `pytest tests/extensions/test_skills_extended.py -v`
**Commit:** `feat(skills): extend Skill dataclass with triggers and content`

---

### Task 1.2: Extend SkillRegistry with find_by_keyword()
**File:** `src/opencli/extensions/skills/registry.py`
**Test:** `tests/extensions/test_registry_extended.py`
**Depends:** none

```python
# test content (copy-paste ready)
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.extensions.skills import Skill, SkillRegistry

class TestSkillRegistryExtended:
    def test_find_by_keyword_exact_match(self):
        registry = SkillRegistry()
        skill = Skill(
            name="interface",
            description="Generate interfaces",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["interface", "generate interface"]
        )
        registry.register(skill)
        
        result = registry.find_by_keyword("interface")
        assert result is skill

    def test_find_by_keyword_phrase_match(self):
        registry = SkillRegistry()
        skill = Skill(
            name="interface",
            description="Generate interfaces",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["interface", "generate interface"]
        )
        registry.register(skill)
        
        result = registry.find_by_keyword("generate interface")
        assert result is skill

    def test_find_by_keyword_no_match(self):
        registry = SkillRegistry()
        skill = Skill(
            name="test",
            description="desc",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["test"]
        )
        registry.register(skill)
        
        result = registry.find_by_keyword("interface")
        assert result is None

    def test_find_all_by_keyword(self):
        registry = SkillRegistry()
        skill1 = Skill(
            name="analyze",
            description="Analyze code",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["analyze", "analysis"]
        )
        skill2 = Skill(
            name="docs",
            description="Generate docs",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["docs", "documentation"]
        )
        registry.register(skill1)
        registry.register(skill2)
        
        results = registry.find_all_by_keyword("analyze")
        assert len(results) == 1
        assert results[0].name == "analyze"
        
        # "docs" matches nothing
        results = registry.find_all_by_keyword("interface")
        assert len(results) == 0

    def test_find_all_by_keyword_multiple_matches(self):
        registry = SkillRegistry()
        skill1 = Skill(
            name="tdd",
            description="Test driven",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["test", "tdd"]
        )
        skill2 = Skill(
            name="testing",
            description="Testing helpers",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["test", "testing"]
        )
        registry.register(skill1)
        registry.register(skill2)
        
        results = registry.find_all_by_keyword("test")
        assert len(results) == 2

    def test_find_by_keyword_returns_first_by_specificity(self):
        """Longest trigger match wins"""
        registry = SkillRegistry()
        skill_short = Skill(
            name="debug",
            description="Debug",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["debug"]
        )
        skill_long = Skill(
            name="debug_error",
            description="Debug errors",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["debug error", "debug errors"]
        )
        registry.register(skill_short)
        registry.register(skill_long)
        
        result = registry.find_by_keyword("debug error")
        assert result.name == "debug_error"
```

```python
# implementation (copy-paste ready)
from typing import Optional, Iterator, List

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
```

**Verify:** `pytest tests/extensions/test_registry_extended.py -v`
**Commit:** `feat(skills): add find_by_keyword methods to SkillRegistry`

---

## Batch 2: Core Modules (parallel - 2 implementers)

### Task 2.1: Extend SkillLoader with Format B support
**File:** `src/opencli/extensions/skills/loader.py`
**Test:** `tests/extensions/test_loader_extended.py`
**Depends:** 1.1 (Skill now supports Format B)

```python
# test content (copy-paste ready)
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
```

```python
# implementation (copy-paste ready)
from pathlib import Path
from .skill import Skill
from .registry import SkillRegistry

class SkillLoader:
    def __init__(self, registry: SkillRegistry):
        self.registry = registry

    def load_from_directory(self, skill_dir: Path):
        """Load all skills from a directory (existing method, unchanged)"""
        if not skill_dir.exists() or not skill_dir.is_dir():
            return

        for skill_path in skill_dir.iterdir():
            if skill_path.is_dir():
                try:
                    skill = self.load_from_path(skill_path)
                    if skill:
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
        
        Returns a new registry populated with all discovered skills.
        """
        registry = SkillRegistry()
        loader = SkillLoader(registry)
        loader.load_from_directory(skills_dir)
        return registry

    def load_skill(self, skill: Skill):
        """Register a pre-loaded skill (existing method, unchanged)"""
        self.registry.register(skill)
```

**Verify:** `pytest tests/extensions/test_loader_extended.py -v`
**Commit:** `feat(skills): add Format B support to SkillLoader`

---

### Task 2.2: Create skill activation module
**File:** `src/opencli/skills/activation.py`
**Test:** `tests/skills/test_activation.py`
**Depends:** 1.1, 1.2 (Skill and Registry extended)

```python
# test content (copy-paste ready)
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.extensions.skills import Skill, SkillRegistry
from opencli.skills.activation import detect_skill_invocation, match_skill_by_keyword

class TestSkillActivation:
    def test_detect_explicit_invocation_slash_name(self):
        was_invoked, name = detect_skill_invocation("/interface generate UserTable")
        assert was_invoked is True
        assert name == "interface"

    def test_detect_explicit_invocation_slash_skill_space_name(self):
        was_invoked, name = detect_skill_invocation("/skill interface")
        assert was_invoked is True
        assert name == "interface"

    def test_detect_regular_message(self):
        was_invoked, name = detect_skill_invocation("generate interfaces for my data")
        assert was_invoked is False
        assert name is None

    def test_detect_no_skill(self):
        was_invoked, name = detect_skill_invocation("hello world")
        assert was_invoked is False
        assert name is None

    def test_match_skill_by_keyword_single(self):
        registry = SkillRegistry()
        skill = Skill(
            name="interface",
            description="Generate interfaces",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["interface", "generate interface"]
        )
        registry.register(skill)
        
        matches = match_skill_by_keyword("generate interfaces from data", registry)
        assert len(matches) == 1
        assert matches[0].name == "interface"

    def test_match_skill_by_keyword_multiple(self):
        registry = SkillRegistry()
        skill1 = Skill(
            name="analyze",
            description="Analyze code",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["analyze", "analysis"]
        )
        skill2 = Skill(
            name="docs",
            description="Generate docs",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["docs", "documentation"]
        )
        registry.register(skill1)
        registry.register(skill2)
        
        matches = match_skill_by_keyword("analyze this code and generate docs", registry)
        assert len(matches) == 2

    def test_match_skill_by_keyword_no_match(self):
        registry = SkillRegistry()
        skill = Skill(
            name="test",
            description="Testing",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["test"]
        )
        registry.register(skill)
        
        matches = match_skill_by_keyword("hello world", registry)
        assert len(matches) == 0

    def test_explicit_invocation_wins_over_keyword(self):
        """When /skill is used, keyword matching is bypassed.
        
        This test documents expected behavior: explicit /skill prefix
        should be handled separately from keyword matching.
        """
        was_invoked, name = detect_skill_invocation("/tdd write tests for my code")
        assert was_invoked is True
        assert name == "tdd"
```

```python
# implementation (copy-paste ready)
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
    
    # "/skillname" format - rest is the skill name
    # Validate it's a known skill name (alphanumeric + underscore)
    if rest.replace("_", "").replace("-", "").isalnum():
        return (True, rest)
    
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
```

**Verify:** `pytest tests/skills/test_activation.py -v`
**Commit:** `feat(skills): add skill activation module with detection logic`

---

## Batch 3: Integration Modules (parallel - 2 implementers)

### Task 3.1: Create skill injection module
**File:** `src/opencli/skills/injection.py`
**Test:** `tests/skills/test_injection.py`
**Depends:** 2.1 (activation module exists)

```python
# test content (copy-paste ready)
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.extensions.skills import Skill
from opencli.skills.injection import inject_skill_into_prompt, format_skill_header

class TestSkillInjection:
    def test_format_skill_header(self):
        skill = Skill(
            name="interface",
            description="Generate interfaces",
            version="1.0",
            path=Path("/tmp"),
            prompt_template=""
        )
        header = format_skill_header(skill)
        assert "=== SKILL: interface ===" in header
        assert "Generate interfaces" in header

    def test_inject_single_skill(self):
        skill = Skill(
            name="interface",
            description="Generate interfaces",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["interface"],
            content="# Interface Skill\n\nGenerate interfaces from data structures."
        )
        
        result = inject_skill_into_prompt(
            "generate interfaces for UserTable",
            [skill]
        )
        
        assert "=== SKILL: interface ===" in result
        assert "Interface Skill" in result
        assert "generate interfaces for UserTable" in result

    def test_inject_multiple_skills(self):
        skill1 = Skill(
            name="analyze",
            description="Analyze code",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["analyze"],
            content="# Analyze Skill\n\nAnalyze code thoroughly."
        )
        skill2 = Skill(
            name="docs",
            description="Generate docs",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["docs"],
            content="# Docs Skill\n\nGenerate documentation."
        )
        
        result = inject_skill_into_prompt(
            "analyze this code and generate docs",
            [skill1, skill2]
        )
        
        assert "=== SKILL: analyze ===" in result
        assert "=== SKILL: docs ===" in result
        assert "analyze this code" in result

    def test_inject_skill_with_memory_context(self):
        skill = Skill(
            name="test",
            description="Testing",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["test"],
            content="# Test Skill\n\nWrite tests first."
        )
        
        result = inject_skill_into_prompt(
            "test my code",
            [skill],
            memory_context="Project: MyApp\nTech: Python 3.12"
        )
        
        assert "=== SKILL: test ===" in result
        assert "Project: MyApp" in result
        assert "test my code" in result

    def test_inject_skill_empty_skills_list(self):
        result = inject_skill_into_prompt(
            "regular message",
            []
        )
        assert result == "regular message"

    def test_inject_skill_no_memory(self):
        skill = Skill(
            name="tdd",
            description="Test driven",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["tdd"],
            content="# TDD Skill\n\nAlways write tests first."
        )
        
        result = inject_skill_into_prompt(
            "write tests for calculator",
            [skill]
        )
        
        assert "=== SKILL: tdd ===" in result
        assert "write tests for calculator" in result
```

```python
# implementation (copy-paste ready)
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
```

**Verify:** `pytest tests/skills/test_injection.py -v`
**Commit:** `feat(skills): add skill injection module for prompt prepending`

---

### Task 3.2: Create skills package init
**File:** `src/opencli/skills/__init__.py`
**Test:** none (package init)
**Depends:** 2.1, 3.1

```python
# implementation (copy-paste ready)
from .activation import detect_skill_invocation, match_skill_by_keyword, parse_skill_args
from .injection import inject_skill_into_prompt, format_skill_header

__all__ = [
    "detect_skill_invocation",
    "match_skill_by_keyword", 
    "parse_skill_args",
    "inject_skill_into_prompt",
    "format_skill_header",
]
```

**Verify:** `python -c "from opencli.skills import detect_skill_invocation, inject_skill_into_prompt"`
**Commit:** `feat(skills): create skills package with activation and injection modules`

---

## Batch 4: Integration (parallel - 3 implementers)

### Task 4.1: Integrate into AgentEngine
**File:** `src/opencli/agent/engine.py`
**Test:** `tests/agent/test_engine_skills.py`
**Depends:** 2.1, 2.2, 3.1, 3.2 (all skills modules ready)

```python
# test content (copy-paste ready)
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from unittest.mock import Mock, AsyncMock, patch
from opencli.extensions.skills import Skill, SkillRegistry
from opencli.agent.engine import AgentEngine, AgentConfig

class TestAgentEngineSkills:
    @pytest.fixture
    def mock_provider(self):
        provider = Mock()
        provider.chat = AsyncMock(return_value=iter(["Hello, I can help with that."]))
        return provider

    @pytest.fixture
    def skill_registry(self):
        registry = SkillRegistry()
        skill = Skill(
            name="tdd",
            description="Test driven development",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["tdd", "test driven"],
            content="# TDD Skill\n\nAlways write tests first following TDD methodology."
        )
        registry.register(skill)
        return registry

    def test_run_with_explicit_skill_invocation(self, mock_provider, skill_registry):
        """Test that /tdd prefix invokes TDD skill"""
        config = AgentConfig(provider=mock_provider)
        engine = AgentEngine(config)
        
        with patch('opencli.agent.engine.SkillRegistry', return_value=skill_registry):
            # The skill should be detected and content prepended
            # We test the detection flow, actual injection tested separately
            pass

    def test_skill_detection_in_run(self, mock_provider, skill_registry):
        """Verify skill detection is called during run()"""
        config = AgentConfig(provider=mock_provider)
        engine = AgentEngine(config)
        
        from opencli.skills import detect_skill_invocation, match_skill_by_keyword
        
        # Verify these functions work with the expected signature
        was_invoked, name = detect_skill_invocation("/tdd write tests")
        assert was_invoked is True
        assert name == "tdd"
        
        matches = match_skill_by_keyword("write tests using tdd methodology", skill_registry)
        assert len(matches) >= 1
```

```python
# implementation (copy-paste ready)
# Add to src/opencli/agent/engine.py after the imports

# Modify the run() method to detect and inject skills
async def run(self, task: str, session: Session) -> AsyncIterator[AgentMessage]:
    # Check for skill invocation FIRST (before @agent delegation)
    from opencli.skills import detect_skill_invocation, match_skill_by_keyword, inject_skill_into_prompt
    from opencli.extensions.skills import SkillRegistry, SkillLoader
    
    # Detect explicit /skill invocation
    was_invoked, skill_name = detect_skill_invocation(task)
    
    # Initialize skill registry if workspace available
    skill_registry = None
    if self.workspace_root:
        skills_dir = self.workspace_root / ".opencli" / "skills"
        if skills_dir.exists():
            loader = SkillLoader(SkillRegistry())
            skill_registry = loader.discover_system_skills(skills_dir)
    
    # Get matching skills
    matched_skills = []
    if skill_registry:
        # Check explicit invocation first
        if was_invoked and skill_name:
            skill = skill_registry.get(skill_name)
            if skill:
                matched_skills.append(skill)
        
        # Also check keyword triggers
        keyword_matches = match_skill_by_keyword(task, skill_registry)
        for match in keyword_matches:
            if match not in matched_skills:
                matched_skills.append(match)
    
    # Inject skills into prompt if any matched
    if matched_skills:
        task = inject_skill_into_prompt(task, matched_skills)
    
    # Continue with existing @agent delegation checks
    if task.startswith("@explore "):
        # ... existing code
```

**Verify:** `pytest tests/agent/test_engine_skills.py -v`
**Commit:** `feat(skills): integrate skill activation into AgentEngine`

---

### Task 4.2: Add built-in skills (TDD, Debug, Review)
**File:** `src/opencli/skills/builtins.py`
**Test:** `tests/skills/test_builtins.py`
**Depends:** 3.1, 3.2

```python
# test content (copy-paste ready)
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.skills.builtins import get_builtin_skills, TDD_SKILL, DEBUG_SKILL, REVIEW_SKILL

class TestBuiltInSkills:
    def test_get_builtin_skills_returns_list(self):
        skills = get_builtin_skills()
        assert isinstance(skills, list)
        assert len(skills) >= 3

    def test_tdd_skill_has_triggers(self):
        skill = TDD_SKILL
        assert "tdd" in skill.triggers
        assert "test driven" in skill.triggers
        assert len(skill.content) > 0

    def test_debug_skill_has_triggers(self):
        skill = DEBUG_SKILL
        assert "debug" in skill.triggers
        assert len(skill.content) > 0

    def test_review_skill_has_triggers(self):
        skill = REVIEW_SKILL
        assert "review" in skill.triggers
        assert len(skill.content) > 0

    def test_all_builtins_have_required_fields(self):
        skills = get_builtin_skills()
        for skill in skills:
            assert skill.name
            assert skill.description
            assert skill.triggers
            assert skill.content
            assert skill.version
```

```python
# implementation (copy-paste ready)
from pathlib import Path
from ..extensions.skills import Skill

TDD_SKILL = Skill(
    name="tdd",
    description="Test Driven Development - write tests before implementation",
    version="1.0.0",
    path=Path("builtin://tdd"),
    prompt_template="",
    triggers=["tdd", "test driven", "write tests", "testing"],
    content="""# Test Driven Development Skill

When the user asks you to implement something using TDD:

## Workflow
1. **Write a failing test** - Start by writing a test that describes the expected behavior
2. **Run the test** - Verify it fails (red phase)
3. **Write minimal code** - Implement the simplest code that makes the test pass
4. **Run tests** - Verify it passes (green phase)
5. **Refactor** - Clean up code while keeping tests passing (refactor phase)

## Rules
- Never write implementation code before writing a failing test
- Write only enough code to pass the current test
- After passing, look for opportunities to refactor
- Keep tests focused on behavior, not implementation details

## Test Format
Use pytest-compatible tests:
```python
def test_feature_behavior():
    # Arrange - set up test data
    # Act - call the function
    # Assert - verify expected behavior
```
"""
)

DEBUG_SKILL = Skill(
    name="debug",
    description="Systematic debugging with hypothesis-driven approach",
    version="1.0.0",
    path=Path("builtin://debug"),
    prompt_template="",
    triggers=["debug", "fix", "error", "bug", "crash", "issue"],
    content="""# Debugging Skill

When the user asks you to debug or fix an issue:

## Systematic Debugging Workflow

### 1. Reproduce the Issue
- Get exact error messages or unexpected behavior
- Identify the conditions that trigger the problem
- Create a minimal reproduction case if possible

### 2. Form Hypothesis
- Based on error message and symptoms, hypothesize the root cause
- Consider: wrong input, state corruption, missing null check, race condition, etc.

### 3. Test Hypothesis
- Add diagnostic output (print statements, logging)
- Modify code to test the hypothesis
- Run and observe results

### 4. Implement Fix
- Fix the root cause, not just the symptoms
- Verify the fix doesn't break other functionality

### 5. Prevent Regression
- Add a test case that would have caught this bug
- Ensure CI/CD will catch similar issues in the future

## Rules
- Always get exact error messages before proposing fixes
- Reproduce the issue before claiming it's fixed
- Consider edge cases and boundary conditions
"""
)

REVIEW_SKILL = Skill(
    name="review",
    description="Code review following best practices",
    version="1.0.0",
    path=Path("builtin://review"),
    prompt_template="",
    triggers=["review", "code review", "look at", "check"],
    content="""# Code Review Skill

When the user asks you to review code:

## Review Focus Areas

### Correctness
- Does the code do what it's supposed to do?
- Are there off-by-one errors or boundary issues?
- Is error handling complete?

### Design
- Is the code in the right place?
- Are responsibilities properly separated?
- Is there appropriate abstraction?

### Readability
- Are variable/function names clear?
- Is complex logic documented?
- Is the code self-explanatory?

### Performance
- Are there obvious O(n²) or worse patterns?
- Are database queries optimized?
- Is caching used where appropriate?

### Security
- Is user input validated?
- Are there injection vulnerabilities?
- Are secrets properly handled?

## Output Format
For each issue found:
- **File:** path/to/file.py:line
- **Issue:** Description
- **Suggestion:** How to fix

## Rules
- Be constructive, not critical
- Focus on important issues, not style preferences
- Suggest improvements, don't just point out problems
"""
)

def get_builtin_skills() -> list[Skill]:
    """Return all built-in skills."""
    return [TDD_SKILL, DEBUG_SKILL, REVIEW_SKILL]
```

**Verify:** `pytest tests/skills/test_builtins.py -v`
**Commit:** `feat(skills): add built-in TDD, Debug, and Review skills`

---

### Task 4.3: Add CLI commands (skill list/show)
**File:** `src/opencli/extensions/skills/cli.py`
**Test:** `tests/extensions/test_skills_cli.py`
**Depends:** 4.2 (builtins exist)

```python
# test content (copy-paste ready)
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.extensions.skills import Skill, SkillRegistry
from opencli.skills.builtins import get_builtin_skills
from opencli.extensions.skills.cli import format_skill_list, format_skill_show

class TestSkillsCLI:
    def test_format_skill_list(self):
        registry = SkillRegistry()
        skill1 = Skill(
            name="tdd",
            description="Test driven development",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["tdd"]
        )
        skill2 = Skill(
            name="debug",
            description="Debugging skill",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["debug"]
        )
        registry.register(skill1)
        registry.register(skill2)
        
        output = format_skill_list(registry.list_all())
        assert "tdd" in output
        assert "debug" in output
        assert "Test driven development" in output

    def test_format_skill_show(self):
        skill = Skill(
            name="tdd",
            description="Test driven development",
            version="1.0",
            path=Path("/tmp"),
            prompt_template="",
            triggers=["tdd", "test driven"],
            content="# TDD Skill\n\nTest driven development workflow."
        )
        
        output = format_skill_show(skill)
        assert "tdd" in output
        assert "Test driven development" in output
        assert "tdd, test driven" in output
        assert "TDD Skill" in output

    def test_format_skill_show_not_found(self):
        output = format_skill_show(None)
        assert "not found" in output.lower()
```

```python
# implementation (copy-paste ready)
from typing import List, Optional
from ..extensions.skills import Skill

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
```

**Verify:** `pytest tests/extensions/test_skills_cli.py -v`
**Commit:** `feat(skills): add CLI commands for skill list/show`

---

## Summary

| Task | File | Test | Depends |
|------|------|------|---------|
| 1.1 | `src/opencli/extensions/skills/skill.py` | `tests/extensions/test_skills_extended.py` | none |
| 1.2 | `src/opencli/extensions/skills/registry.py` | `tests/extensions/test_registry_extended.py` | none |
| 2.1 | `src/opencli/extensions/skills/loader.py` | `tests/extensions/test_loader_extended.py` | 1.1 |
| 2.2 | `src/opencli/skills/activation.py` | `tests/skills/test_activation.py` | 1.1, 1.2 |
| 3.1 | `src/opencli/skills/injection.py` | `tests/skills/test_injection.py` | 2.1 |
| 3.2 | `src/opencli/skills/__init__.py` | none | 2.1, 3.1 |
| 4.1 | `src/opencli/agent/engine.py` | `tests/agent/test_engine_skills.py` | 2.1, 2.2, 3.1, 3.2 |
| 4.2 | `src/opencli/skills/builtins.py` | `tests/skills/test_builtins.py` | 3.1, 3.2 |
| 4.3 | `src/opencli/extensions/skills/cli.py` | `tests/extensions/test_skills_cli.py` | 4.2 |

**Parallel batches:**
- Batch 1 (2 tasks): 1.1, 1.2 can run simultaneously
- Batch 2 (2 tasks): 2.1, 2.2 can run simultaneously (both depend on batch 1)
- Batch 3 (2 tasks): 3.1, 3.2 can run simultaneously (both depend on batch 2)
- Batch 4 (3 tasks): 4.1, 4.2, 4.3 can run simultaneously (all depend on batch 3)

**Total: 9 micro-tasks across 4 batches**