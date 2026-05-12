---
date: 2026-05-12
topic: "open-cli Subagent System"
status: draft
---

# open-cli Subagent System Design

## Problem Statement

open-cli currently has only a single agent that handles everything. This causes problems:
- **Context pollution**: Research results clutter the main conversation
- **No tool restrictions**: Explore tasks don't need file write access
- **No parallelization**: Can't research and implement simultaneously
- **No specialization**: Same agent for quick questions and complex tasks

Claude Code, OpenCode, and Gemini CLI all solve this with subagents.

---

## Design: Three Built-in Agents

### Agent Types

| Agent | Purpose | Tools | Model | Use Case |
|-------|---------|-------|-------|----------|
| **Explore** | Fast read-only research | Read, Glob, Grep | Fast/cheap | "Find files related to auth" |
| **Plan** | Analyze before building | Read, Glob, Grep | Standard | "Create a plan for adding tests" |
| **Build** | Full implementation | All tools | Capable | Default agent for all tasks |

### Why Three Agents?

- **Explore** is fast and cheap for discovery tasks
- **Plan** is a checkpoint before making changes
- **Build** is the capable agent for actual implementation

---

## Architecture

### Directory Structure

```
src/opencli/agents/
├── __init__.py
├── types.py              # AgentType enum
├── base.py               # BaseAgent abstract class
├── factory.py            # AgentFactory to create agents
├── config.py             # AgentConfig dataclass
├── explore.py            # Explore agent implementation
├── plan.py               # Plan agent implementation
├── build.py             # Build agent (wrapper for existing)
└── runner.py             # AgentRunner (spawns and manages agents)
```

### Core Classes

#### AgentConfig

```python
@dataclass
class AgentConfig:
    name: str
    description: str
    allowed_tools: list[str]  # Tool whitelist
    denied_tools: list[str]   # Tool blacklist
    model: str               # Model ID
    memory_enabled: bool      # Has own memory
    max_turns: int          # Max iterations
    timeout: int            # Timeout in seconds
```

#### AgentType Enum

```python
class AgentType(Enum):
    EXPLORE = "explore"
    PLAN = "plan"
    BUILD = "build"
    GENERAL = "general"  # Fallback
```

#### BaseAgent

```python
class BaseAgent(ABC):
    def __init__(self, config: AgentConfig):
        self.config = config
        self.tools = self._filter_tools(config)

    @abstractmethod
    async def run(self, task: str) -> AgentResult:
        pass

    def _filter_tools(self, config: AgentConfig) -> list[Tool]:
        """Filter tools based on agent config."""
        ...
```

---

## Implementation Details

### Tool Filtering

Each agent type has a tool whitelist:

```python
EXPLORE_TOOLS = ["read_file", "glob", "grep"]
PLAN_TOOLS = ["read_file", "glob", "grep"]
BUILD_TOOLS = ["*"]  # All tools
```

### Spawning Mechanism

Use async coroutines (integrates with existing async codebase):

```python
class AgentRunner:
    async def spawn(
        self,
        agent_type: AgentType,
        task: str,
        parent_context: dict | None = None,
    ) -> AgentResult:
        """Spawn a subagent to handle a task."""
        config = AgentFactory.create(agent_type)
        agent = BaseAgent.create(config)
        return await agent.run(task)
```

### Delegation Syntax

Users invoke subagents with `@` prefix:

```
@explore Find all files related to authentication
@plan Create a testing strategy for the API
@build Add unit tests for the auth module
```

### Result Format

```python
@dataclass
class AgentResult:
    summary: str           # Human-readable summary
    key_findings: list[str]  # Key discoveries
    tools_used: list[str    # Tools that were called
    duration: float        # Time taken
    error: str | None      # Error if failed
```

---

## Integration with Existing Engine

### Modified AgentEngine

```python
class AgentEngine:
    async def run(self, task: str) -> AsyncIterator[AgentMessage]:
        # Check for @agent delegation
        if task.startswith("@explore "):
            result = await self.runner.spawn(AgentType.EXPLORE, task[8:])
            yield AgentMessage(type="subagent_result", content=result.summary)
            return

        if task.startswith("@plan "):
            result = await self.runner.spawn(AgentType.PLAN, task[6:])
            yield AgentMessage(type="subagent_result", content=result.summary)
            return

        # Default: run as Build agent
        async for msg in self._run_build_agent(task):
            yield msg
```

### Memory Integration

- Subagents can access project memory (AGENTS.md, MEMORY.md)
- Subagents can optionally write to agent-specific memory
- Parent context can be passed to subagent

---

## Error Handling

| Situation | Behavior |
|-----------|----------|
| Agent timeout | Return timeout error, continue parent |
| Agent error | Return error in result, continue parent |
| Invalid agent type | Fallback to BUILD |
| Tool not allowed | Log warning, skip tool call |

---

## Testing Strategy

1. **Unit tests** for each agent type
   - Test tool filtering
   - Test result format

2. **Integration tests**
   - Test agent spawning
   - Test context passing

3. **E2E tests**
   - Test `@explore` invocation
   - Test `@plan` invocation
   - Test delegation chain

---

## Future Enhancements (Out of Scope for v1)

- Custom agent definitions (user-created agents)
- Agent-to-agent messaging
- Process-based isolation for untrusted code
- Persistent agent memory across sessions

---

## Open Questions

None - design is complete and ready for implementation.

---

## References

- [Claude Code Subagents](https://code.claude.com/docs/en/sub-agents)
- [OpenCode Agents](https://opencode.ai/docs/agents)
- [Gemini CLI Subagents](https://geminicli.com/docs/core/subagents/)
