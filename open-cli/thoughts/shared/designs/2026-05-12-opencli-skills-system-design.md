# open-cli Skills System Design

> **Design for Pillar 3: Skills as first-class workflow extensions**

---

## Problem Statement

Top CLI coding agents (Claude Code, OpenCode) have a **Skills System** that lets users define reusable workflows triggered by keywords or explicit invocation. open-cli has the `extensions/skills/` infrastructure but **no invocation mechanism** and **no prompt injection**.

**Goal:** Make skills invocable via `/skill` syntax or keyword triggers, with skill content injected into the LLM prompt.

---

## Constraints

- Skills must be **backward compatible** with existing `extensions/skills/` structure
- Skill loading must support both `skill.yaml` + `SKILL.md` AND single `SKILL.md` (Claude Code style)
- Skills inject **before** the main prompt (system-level instructions)
- Skill execution is **synchronous** - skill runs in current agent context
- No new CLI commands required for basic skill invocation

---

## Approach

**I'm using keyword + explicit invocation hybrid:**

1. **Explicit invocation:** `/skillname` or `/skill <name>` at start of message
2. **Keyword trigger:** Certain keywords auto-activate corresponding skills
3. **Skill chaining:** One skill can invoke another via `/skillname` internally

This matches Claude Code's approach while being simpler to implement.

---

## Architecture

### Skill Resolution Flow

```
User message: "generate interfaces from this data"
                    ↓
            Check for /skill prefix
                    ↓
            Keyword match against registry
                    ↓
            Load skill's SKILL.md content
                    ↓
            Prepend to prompt (system-level)
                    ↓
            Continue with normal agent flow
```

### Skill Structure (Two Formats Supported)

**Format A: skill.yaml + SKILL.md (existing open-cli)**
```
~/.opencli/skills/my-skill/
├── skill.yaml      # Metadata (name, description, trigger keywords)
└── SKILL.md        # Full prompt template
```

**Format B: SKILL.md only (Claude Code style)**
```
~/.opencli/skills/my-skill/
└── SKILL.md        # YAML front matter + content
```

Both formats resolve to the same `Skill` dataclass.

### Skill Dataclass (Existing, extends)

```python
@dataclass
class Skill:
    name: str                    # Unique identifier
    description: str             # What the skill does
    triggers: list[str]          # Keywords that activate this skill
    content: str                 # Full skill content (from SKILL.md)
    prompt_template: str         # How to inject into prompt
    agent_type: str = "general"  # Which agent type (explore/plan/build)
```

### SkillRegistry (Existing, extends)

Add methods:
- `find_by_keyword(text: str) -> Skill | None` - find first matching skill
- `find_all_by_keyword(text: str) -> list[Skill]` - find all matching skills

### SkillLoader (Existing, extends)

Add support for:
- `load_from_path(path: Path) -> Skill` - single skill directory
- `discover_system_skills() -> SkillRegistry` - load from `~/.opencli/skills/`
- `load_format_b(path: Path) -> Skill` - parse SKILL.md with YAML front matter

---

## Components

### 1. Skill Activation

**Trigger Detection:**
```python
def detect_skill_invocation(message: str) -> tuple[bool, str | None]:
    """
    Returns (was_invoked, skill_name_or_none)
    - "/skillname" → (True, "skillname")
    - "/skill name" → (True, "name")
    - "regular message" → (False, None)
    """
```

**Keyword Matching:**
```python
def match_skill_by_keyword(message: str, registry: SkillRegistry) -> list[Skill]:
    """
    Scans message for skill trigger keywords.
    Returns all matching skills (sorted by specificity).
    """
```

### 2. Skill Prompt Injection

**Injection Logic:**
```python
def inject_skill_into_prompt(
    message: str,
    skills: list[Skill],
    memory_context: str = ""
) -> str:
    """
    Prepends skill content to prompt:
    
    <skill content from SKILL.md>
    
    ---
    [Memory context if present]
    
    User: <original message>
    """
```

**Skill Header Format:**
```
=== SKILL: {skill_name} ===
{skill content}
==========================

```

### 3. Skill Execution (within AgentEngine)

Modify `AgentEngine.run()` to:
1. Check for `/skill` prefix → extract skill name
2. Check for keyword triggers → find matching skills
3. Load skill content from registry
4. Inject skill content at start of prompt
5. Continue with normal execution

---

## Data Flow

### Explicit Invocation Flow

```
User: "/interface generate UserTable interfaces"
         ↓
AgentEngine.run() detects "/interface" prefix
         ↓
SkillRegistry.get("interface") → Skill found
         ↓
Skill content injected into prompt
         ↓
LLM sees: skill instructions + memory + task
         ↓
Normal response flow
```

### Keyword Trigger Flow

```
User: "generate interfaces from my database schema"
         ↓
Keyword matcher finds "interface" in "generate interfaces"
         ↓
SkillRegistry.find_by_keyword("interface") → InterfaceSkill
         ↓
Skill content injected into prompt
         ↓
LLM follows skill's interface-generation protocol
         ↓
Response follows skill's output format
```

### Multiple Skills Flow

```
User: "analyze this code and generate docs"
         ↓
Keyword matches: [analyze_skill, docs_skill]
         ↓
Skills sorted by specificity (analyze before docs)
         ↓
All skill contents injected in order
         ↓
LLM follows combined skill instructions
```

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| `/skill unknown` | Warning: "Skill 'unknown' not found. Available: ..." |
| Skill file missing | Warning: "Skill '{name}' has no content, skipping" |
| Keyword matches nothing | Continue with normal prompt |
| Multiple keyword matches | Inject all, warn if conflicts detected |
| Circular skill invoke | Detect and prevent, warn: "Skill '{name}' already active" |

---

## Testing Strategy

### Unit Tests
- `test_skill_activation.py`: Test `/skill` prefix detection
- `test_keyword_matching.py`: Test keyword → skill matching
- `test_skill_injection.py`: Test prompt injection formatting

### Integration Tests
- `test_skill_execution.py`: End-to-end skill invocation
- `test_skill_chaining.py`: One skill invoking another

### Manual Tests
```bash
# Create a skill
mkdir -p ~/.opencli/skills/interface
cat > ~/.opencli/skills/interface/SKILL.md << 'EOF'
---
name: interface
description: Generate interfaces from data
triggers:
  - interface
  - generate interface
---

# Interface Generation Skill

When user asks to generate interfaces:
1. Analyze the data structure
2. Generate TypeScript/Python interface
3. Follow output format in references/
EOF

# Test invocation
echo "/interface generate UserTable" | python -m opencli.cli
```

---

## Open Questions

1. **Should skills support arguments?** (`/skill arg1=value arg2=value`)
   - **Decision:** Yes, parse `key=value` pairs into `skill.args` dict

2. **Should skill output be validated?**
   - **Decision:** No, skills are guidance not enforcement

3. **Should built-in skills exist?**
   - **Decision:** Yes, ship with 3-5 essential skills (TDD, Debug, Review, etc.)

4. **Skill priority when multiple match?**
   - **Decision:** Longest trigger wins. Explicit invocation wins over keyword.

---

## Implementation Order

1. **Extend Skill dataclass** - add `triggers`, `content`
2. **Extend SkillRegistry** - add `find_by_keyword()`
3. **Extend SkillLoader** - support Format B (SKILL.md only)
4. **Add SkillActivation** - detection logic
5. **Integrate into AgentEngine** - inject into prompt
6. **Add built-in skills** - TDD, Debug, Review, etc.
7. **Add CLI command** - `skill list`, `skill show <name>`

---

## Files to Create/Modify

### New Files
- `src/opencli/skills/activation.py` - skill detection logic
- `src/opencli/skills/injection.py` - prompt injection
- `src/opencli/skills/builtins.py` - built-in skills

### Modify Files
- `src/opencli/extensions/skills/skill.py` - add `triggers`, `content`
- `src/opencli/extensions/skills/registry.py` - add `find_by_keyword()`
- `src/opencli/extensions/skills/loader.py` - add Format B support
- `src/opencli/agent/engine.py` - integrate skill detection/injection

### Test Files
- `tests/skills/test_activation.py`
- `tests/skills/test_keyword_matching.py`
- `tests/skills/test_injection.py`
- `tests/skills/test_builtins.py`
