---
date: 2026-05-12
topic: "open-cli Memory System"
status: draft
---

# open-cli Memory System Design

## Problem Statement

open-cli currently has **no memory system**. Every session starts completely blank with zero knowledge of:
- The project structure and tech stack
- User's coding preferences
- Build/test commands for the project
- Common patterns and conventions

Users must re-explain their project in every session. This is the #1 friction point compared to Claude Code, OpenCode, and Gemini CLI.

---

## Constraints

1. **Backward compatible** - Don't break existing functionality
2. **Simple** - Prefer files over complex databases
3. **Windows-friendly** - Handle GBK console encoding
4. **Non-intrusive** - Memory files are optional; CLI works without them
5. **Git-friendly** - Project memory can be committed to repo

---

## Design: Two-Tier Memory System

### Tier 1: AGENTS.md (Human-Written)

Project-level instructions written by humans. Persists across all sessions.

### Tier 2: MEMORY.md (AI-Written Auto-Memory)

AI learns from corrections and discoveries. Persists across sessions.

---

## AGENTS.md Specification

### File Locations (Priority Order)

| Location | Scope | Purpose |
|----------|-------|---------|
| `./AGENTS.md` | Project | Team-shared instructions (commit to repo) |
| `./.opencli/AGENTS.md` | Project | Alternative location |
| `~/.opencli/AGENTS.md` | User | Personal preferences for all projects |
| `~/.opencli/memory/default/MEMORY.md` | User | Auto-learned across projects |
| `.opencli/memory/<project>/MEMORY.md` | Project | Auto-learned per project |

### Loading Order

```
1. System prompt (built-in instructions)
2. User-level AGENTS.md (~/.opencli/AGENTS.md)
3. Project AGENTS.md (./AGENTS.md or ./.opencli/AGENTS.md)
4. Project auto-memory (first 200 lines)
5. User auto-memory (first 200 lines)
```

More specific overrides less specific.

### AGENTS.md Format

```markdown
# Project Context

## Tech Stack
- Python 3.11+, FastAPI, React 18

## Build Commands
- Backend: `cd backend && pip install -r requirements.txt`
- Frontend: `cd frontend && npm install && npm run dev`

## Coding Standards
- Use type hints on all functions
- 2-space indentation
- Error handling: always log + raise

## Project Structure
- backend/: FastAPI server
- frontend/: React SPA
- shared/: Shared types/utilities
```

### Section Organization

| Section | Purpose |
|---------|---------|
| `# Tech Stack` | Languages, frameworks, dependencies |
| `# Build Commands` | How to build, test, run the project |
| `# Coding Standards` | Style conventions, patterns to follow |
| `# Project Structure` | Directory layout and purposes |
| `# Workflows` | Common procedures (PR process, release, etc.) |
| `# Gotchas` | Known issues, common mistakes to avoid |

---

## MEMORY.md Specification (Auto-Memory)

### When AI Writes to MEMORY.md

AI should automatically save notes when:

1. **User correction** - User says "remember that..." or corrects the AI
2. **Discovery** - AI learns something useful (build command, file pattern)
3. **Session end** - Accumulated knowledge worth saving

### MEMORY.md Format

```markdown
# Auto-Generated Memory

## Build & Run
- Tests: `pytest tests/ -v`
- Dev server: `npm run dev`
- Lint: `flake8 .`

## Debug Patterns
- API errors → check backend/logs/
- Frontend errors → Chrome DevTools on port 3000

## User Preferences
- Prefers short explanations
- Wants inline error messages
- Runs tests after each change

## Project Patterns
- API routes in backend/routes/
- Components in frontend/src/components/
```

### Size Limit

- First 200 lines or 25KB loaded at session start (whichever first)
- Beyond that, loaded on-demand when relevant

---

## Directory Structure

```
~/.opencli/
├── config.yaml              # Existing config
├── memory/
│   ├── default/             # User-wide auto-memory
│   │   └── MEMORY.md
│   └── <project-hash>/     # Per-project memory
│       └── MEMORY.md
├── sessions/               # Existing sessions
└── checkpoints/            # Existing checkpoints

project/
├── AGENTS.md               # Project-level instructions
└── .opencli/               # Project-specific config
    └── AGENTS.md           # Alternative location
```

### Project Hash Calculation

Use git root if available:
```python
import hashlib
project_path = subprocess.run(["git", "rev-parse", "--show-toplevel"], ...)
project_id = hashlib.md5(project_path.encode()).hexdigest()[:8]
```

---

## Implementation Plan

### Phase 1: AGENTS.md Reader

1. Create `MemoryLoader` class in `src/opencli/memory/loader.py`
2. Implement `load_memory(project_path) -> str` function
3. Integrate into `AgentEngine` before LLM call
4. Support all loading locations with priority

### Phase 2: Auto-Memory Writer

1. Create `AutoMemory` class
2. Track corrections during session
3. Write to MEMORY.md at appropriate times
4. Implement size limit (200 lines / 25KB)

### Phase 3: CLI Integration

1. Add `/memory` command to view/edit memory
2. Add `/init` command to bootstrap new projects
3. Add `--no-memory` flag to disable (privacy)

---

## Integration with AgentEngine

### Modified AgentEngine Flow

```
run(task):
    1. Load memory (system + user + project + auto)
    2. Build context = memory + task
    3. Generate plan via LLM
    4. Execute tools
    5. Track corrections for auto-memory
    6. On session end, flush auto-memory
```

### Memory Context Format

```python
memory_context = f"""
# Project Context (from AGENTS.md)
{project_memory}

# Your Memory (from MEMORY.md)
{auto_memory}

## User Preferences (from ~/.opencli/AGENTS.md)
{user_memory}
"""
```

---

## Error Handling

| Situation | Behavior |
|-----------|----------|
| AGENTS.md doesn't exist | Skip, no error |
| AGENTS.md malformed | Log warning, skip |
| MEMORY.md doesn't exist | Create empty |
| MEMORY.md too large | Truncate oldest entries |
| No write permission | Log warning, continue without saving |

---

## Testing Strategy

1. **Unit tests** for `MemoryLoader`
   - Test all loading locations
   - Test priority ordering
   - Test size limits

2. **Integration tests**
   - Create temp project with AGENTS.md
   - Verify it's loaded into context

3. **E2E test**
   - `echo "hello" | opencli "remember my name is test"`
   - Verify MEMORY.md contains "test"

---

## Open Questions

1. **Merge strategy**: Should project and user MEMORY.md be merged or separate?
   - Recommendation: Separate, project memory is scoped to project

2. **Sync mechanism**: Should MEMORY.md sync across machines?
   - Recommendation: No, machine-local by default

3. **Privacy**: Should `--no-memory` also disable reading memory?
   - Recommendation: Yes, for sensitive projects

---

## References

- [Claude Code Memory Docs](https://code.claude.com/docs/en/memory)
- [OpenCode AGENTS.md](https://opencode.ai/docs)
- [Gemini CLI GEMINI.md](https://geminicli.com/docs/cli/gemini-md)
