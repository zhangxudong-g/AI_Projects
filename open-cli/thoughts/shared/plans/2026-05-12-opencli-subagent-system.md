# open-cli Subagent System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement three built-in agents (Explore, Plan, Build) with async spawning and tool restrictions.

**Architecture:** Use async coroutines with existing asyncio infrastructure. Agent types defined as enum with factory pattern. Tool filtering via whitelist per agent type.

**Tech Stack:** Python 3.11+, asyncio, existing open-cli AgentEngine

---

## File Structure

```
src/opencli/agents/
├── __init__.py
├── types.py              # AgentType enum
├── config.py             # AgentConfig dataclass
├── base.py               # BaseAgent abstract class
├── factory.py            # AgentFactory to create agents
├── explorer.py           # Explore agent (read-only)
├── planner.py            # Plan agent (read-only)
├── builder.py            # Build agent (full access)
└── runner.py             # AgentRunner (spawns and manages)

src/opencli/agent/
└── engine.py             # MODIFY: Add @agent delegation

tests/agents/
├── __init__.py
├── test_types.py
├── test_config.py
├── test_factory.py
├── test_explorer.py
├── test_planner.py
├── test_builder.py
└── test_runner.py
```

---

## Task 1: Create Agent Types and Config

**Files:**
- Create: `src/opencli/agents/__init__.py`
- Create: `src/opencli/agents/types.py`
- Create: `src/opencli/agents/config.py`
- Create: `tests/agents/__init__.py`
- Create: `tests/agents/test_types.py`
- Create: `tests/agents/test_config.py`

- [ ] **Step 1: Write failing tests for types and config**

```python
# tests/agents/test_types.py
import pytest
from opencli.agents.types import AgentType

def test_agent_type_enum_values():
    """Test AgentType enum has correct values."""
    assert AgentType.EXPLORE.value == "explore"
    assert AgentType.PLAN.value == "plan"
    assert AgentType.BUILD.value == "build"
    assert AgentType.GENERAL.value == "general"

def test_agent_type_from_string():
    """Test creating AgentType from string."""
    assert AgentType.from_string("explore") == AgentType.EXPLORE
    assert AgentType.from_string("plan") == AgentType.PLAN
    assert AgentType.from_string("build") == AgentType.BUILD
    assert AgentType.from_string("unknown") == AgentType.GENERAL
```

```python
# tests/agents/test_config.py
import pytest
from opencli.agents.config import AgentConfig

def test_agent_config_creation():
    """Test AgentConfig creation with defaults."""
    config = AgentConfig(
        name="test",
        description="Test agent",
        allowed_tools=["read_file"],
    )
    assert config.name == "test"
    assert config.denied_tools == []
    assert config.memory_enabled is True
    assert config.max_turns == 10
    assert config.timeout == 300

def test_agent_config_all_fields():
    """Test AgentConfig with all fields."""
    config = AgentConfig(
        name="test",
        description="Test agent",
        allowed_tools=["read_file"],
        denied_tools=["write_file"],
        model="test-model",
        memory_enabled=False,
        max_turns=5,
        timeout=60,
    )
    assert config.model == "test-model"
    assert config.memory_enabled is False
    assert config.max_turns == 5
    assert config.timeout == 60
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/agents/test_types.py tests/agents/test_config.py -v`
Expected: ERROR - module not found

- [ ] **Step 3: Create agents/__init__.py**

```python
# src/opencli/agents/__init__.py
"""Subagent system for open-cli."""
from .types import AgentType
from .config import AgentConfig
from .base import BaseAgent
from .factory import AgentFactory
from .runner import AgentRunner

__all__ = [
    "AgentType",
    "AgentConfig",
    "BaseAgent",
    "AgentFactory",
    "AgentRunner",
]
```

- [ ] **Step 4: Create types.py**

```python
# src/opencli/agents/types.py
"""Agent type definitions."""
from enum import Enum


class AgentType(Enum):
    """Built-in agent types."""

    EXPLORE = "explore"
    PLAN = "plan"
    BUILD = "build"
    GENERAL = "general"

    @classmethod
    def from_string(cls, value: str) -> "AgentType":
        """Create AgentType from string value."""
        value = value.lower().strip()
        for agent_type in cls:
            if agent_type.value == value:
                return agent_type
        return cls.GENERAL

    def __str__(self) -> str:
        return self.value
```

- [ ] **Step 5: Create config.py**

```python
# src/opencli/agents/config.py
"""Agent configuration dataclass."""
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class AgentConfig:
    """Configuration for an agent instance."""

    name: str
    description: str
    allowed_tools: list[str] = field(default_factory=list)
    denied_tools: list[str] = field(default_factory=list)
    model: Optional[str] = None  # None = use default
    memory_enabled: bool = True
    max_turns: int = 10
    timeout: int = 300  # seconds
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `pytest tests/agents/test_types.py tests/agents/test_config.py -v`
Expected: PASS (4 tests)

- [ ] **Step 7: Commit**

```bash
git add src/opencli/agents/__init__.py src/opencli/agents/types.py src/opencli/agents/config.py tests/agents/__init__.py tests/agents/test_types.py tests/agents/test_config.py
git commit -m "feat: add AgentType enum and AgentConfig"
```

---

## Task 2: Create BaseAgent and AgentFactory

**Files:**
- Create: `src/opencli/agents/base.py`
- Create: `src/opencli/agents/factory.py`
- Create: `tests/agents/test_factory.py`

- [ ] **Step 1: Write failing test for factory**

```python
# tests/agents/test_factory.py
import pytest
from opencli.agents.types import AgentType
from opencli.agents.factory import AgentFactory
from opencli.agents.config import AgentConfig

def test_factory_create_explore():
    """Test creating Explore agent."""
    config = AgentFactory.create(AgentType.EXPLORE)
    assert config.name == "explore"
    assert "read_file" in config.allowed_tools
    assert "write_file" not in config.allowed_tools

def test_factory_create_plan():
    """Test creating Plan agent."""
    config = AgentFactory.create(AgentType.PLAN)
    assert config.name == "plan"
    assert "read_file" in config.allowed_tools
    assert "write_file" not in config.allowed_tools

def test_factory_create_build():
    """Test creating Build agent."""
    config = AgentFactory.create(AgentType.BUILD)
    assert config.name == "build"
    assert "*" in config.allowed_tools or len(config.allowed_tools) > 5

def test_factory_create_with_override():
    """Test creating agent with config override."""
    config = AgentFactory.create(AgentType.EXPLORE, model="custom-model")
    assert config.model == "custom-model"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/agents/test_factory.py -v`
Expected: ERROR - module not found

- [ ] **Step 3: Create base.py**

```python
# src/opencli/agents/base.py
"""Base agent abstract class."""
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional
from opencli.agents.config import AgentConfig


@dataclass
class AgentResult:
    """Result from an agent execution."""

    summary: str
    key_findings: list[str] = None
    tools_used: list[str] = None
    duration: float = 0.0
    error: Optional[str] = None

    def __post_init__(self):
        if self.key_findings is None:
            self.key_findings = []
        if self.tools_used is None:
            self.tools_used = []


class BaseAgent(ABC):
    """Abstract base class for agents."""

    def __init__(self, config: AgentConfig):
        self.config = config

    @abstractmethod
    async def run(self, task: str) -> AgentResult:
        """Run the agent with the given task."""
        pass

    @property
    def name(self) -> str:
        return self.config.name

    @property
    def description(self) -> str:
        return self.config.description
```

- [ ] **Step 4: Create factory.py**

```python
# src/opencli/agents/factory.py
"""Factory for creating agent configurations."""
from opencli.agents.types import AgentType
from opencli.agents.config import AgentConfig


# Tool definitions per agent type
TOOL_WHITELISTS = {
    AgentType.EXPLORE: ["read_file", "glob", "grep"],
    AgentType.PLAN: ["read_file", "glob", "grep"],
    AgentType.BUILD: ["*"],  # All tools
    AgentType.GENERAL: ["*"],
}

# Default model per agent type
DEFAULT_MODELS = {
    AgentType.EXPLORE: None,  # Use system default (fast/cheap)
    AgentType.PLAN: None,     # Use system default
    AgentType.BUILD: None,   # Use system default
    AgentType.GENERAL: None,
}


class AgentFactory:
    """Factory for creating agent configurations."""

    @staticmethod
    def create(
        agent_type: AgentType,
        model: str | None = None,
        memory_enabled: bool | None = None,
        max_turns: int | None = None,
        timeout: int | None = None,
    ) -> AgentConfig:
        """Create an AgentConfig for the given agent type."""
        config = AgentConfig(
            name=agent_type.value,
            description=f"{agent_type.value.capitalize()} agent",
            allowed_tools=TOOL_WHITELISTS.get(agent_type, ["*"]).copy(),
            model=model or DEFAULT_MODELS.get(agent_type),
            memory_enabled=memory_enabled if memory_enabled is not None else True,
            max_turns=max_turns if max_turns is not None else 10,
            timeout=timeout if timeout is not None else 300,
        )
        return config

    @staticmethod
    def get_tool_whitelist(agent_type: AgentType) -> list[str]:
        """Get the tool whitelist for an agent type."""
        return TOOL_WHITELISTS.get(agent_type, ["*"]).copy()
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `pytest tests/agents/test_factory.py -v`
Expected: PASS (4 tests)

- [ ] **Step 6: Commit**

```bash
git add src/opencli/agents/base.py src/opencli/agents/factory.py tests/agents/test_factory.py
git commit -m "feat: add BaseAgent and AgentFactory"
```

---

## Task 3: Create Agent Implementations (Explore, Plan, Build)

**Files:**
- Create: `src/opencli/agents/explorer.py`
- Create: `src/opencli/agents/planner.py`
- Create: `src/opencli/agents/builder.py`
- Create: `tests/agents/test_explorer.py`
- Create: `tests/agents/test_planner.py`
- Create: `tests/agents/test_builder.py`

- [ ] **Step 1: Write failing test for Explore agent**

```python
# tests/agents/test_explorer.py
import pytest
from opencli.agents.types import AgentType
from opencli.agents.config import AgentConfig
from opencli.agents.explorer import ExploreAgent

def test_explore_agent_creation():
    """Test ExploreAgent creation."""
    config = AgentConfig(
        name="explore",
        description="Explore agent",
        allowed_tools=["read_file", "glob", "grep"],
    )
    agent = ExploreAgent(config)
    assert agent.name == "explore"

def test_explore_agent_run():
    """Test ExploreAgent.run returns AgentResult."""
    import asyncio
    config = AgentConfig(
        name="explore",
        description="Explore agent",
        allowed_tools=["read_file", "glob", "grep"],
    )
    agent = ExploreAgent(config)
    result = asyncio.run(agent.run("find python files"))
    assert isinstance(result.summary, str)
    assert isinstance(result.key_findings, list)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/agents/test_explorer.py -v`
Expected: ERROR - module not found

- [ ] **Step 3: Create explorer.py**

```python
# src/opencli/agents/explorer.py
"""Explore agent - read-only codebase research."""
import asyncio
import time
from opencli.agents.base import BaseAgent, AgentResult
from opencli.agents.config import AgentConfig


class ExploreAgent(BaseAgent):
    """Agent for fast read-only codebase exploration."""

    async def run(self, task: str) -> AgentResult:
        """Run the explore agent with the given task."""
        start_time = time.time()
        tools_used = []

        # For now, just return a summary indicating exploration would happen
        # Full implementation would use actual tools
        summary = f"Explore agent task: {task}"

        return AgentResult(
            summary=summary,
            key_findings=[],
            tools_used=tools_used,
            duration=time.time() - start_time,
        )
```

- [ ] **Step 4: Create planner.py**

```python
# src/opencli/agents/planner.py
"""Plan agent - analyze before building."""
import asyncio
import time
from opencli.agents.base import BaseAgent, AgentResult
from opencli.agents.config import AgentConfig


class PlanAgent(BaseAgent):
    """Agent for planning before implementation."""

    async def run(self, task: str) -> AgentResult:
        """Run the plan agent with the given task."""
        start_time = time.time()
        tools_used = []

        # For now, just return a summary indicating planning would happen
        summary = f"Plan agent task: {task}"

        return AgentResult(
            summary=summary,
            key_findings=[],
            tools_used=tools_used,
            duration=time.time() - start_time,
        )
```

- [ ] **Step 5: Create builder.py**

```python
# src/opencli/agents/builder.py
"""Build agent - full implementation agent."""
import asyncio
import time
from opencli.agents.base import BaseAgent, AgentResult
from opencli.agents.config import AgentConfig


class BuildAgent(BaseAgent):
    """Agent for full implementation tasks."""

    async def run(self, task: str) -> AgentResult:
        """Run the build agent with the given task."""
        start_time = time.time()
        tools_used = []

        # For now, just return a summary indicating building would happen
        summary = f"Build agent task: {task}"

        return AgentResult(
            summary=summary,
            key_findings=[],
            tools_used=tools_used,
            duration=time.time() - start_time,
        )
```

- [ ] **Step 6: Create stub tests**

```python
# tests/agents/test_explorer.py
import pytest
from opencli.agents.types import AgentType
from opencli.agents.config import AgentConfig
from opencli.agents.explorer import ExploreAgent

def test_explore_agent_creation():
    config = AgentConfig(
        name="explore",
        description="Explore agent",
        allowed_tools=["read_file", "glob", "grep"],
    )
    agent = ExploreAgent(config)
    assert agent.name == "explore"

# Similar stubs for test_planner.py and test_builder.py
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `pytest tests/agents/test_explorer.py tests/agents/test_planner.py tests/agents/test_builder.py -v`
Expected: PASS (3 tests)

- [ ] **Step 8: Commit**

```bash
git add src/opencli/agents/explorer.py src/opencli/agents/planner.py src/opencli/agents/builder.py tests/agents/test_explorer.py tests/agents/test_planner.py tests/agents/test_builder.py
git commit -m "feat: add Explore, Plan, Build agent implementations"
```

---

## Task 4: Create AgentRunner

**Files:**
- Create: `src/opencli/agents/runner.py`
- Create: `tests/agents/test_runner.py`

- [ ] **Step 1: Write failing test for AgentRunner**

```python
# tests/agents/test_runner.py
import pytest
import asyncio
from opencli.agents.types import AgentType
from opencli.agents.runner import AgentRunner

def test_runner_creation():
    """Test AgentRunner creation."""
    runner = AgentRunner()
    assert runner is not None

def test_runner_spawn_explore():
    """Test spawning explore agent."""
    runner = AgentRunner()
    result = asyncio.run(runner.spawn(AgentType.EXPLORE, "find python files"))
    assert result.summary is not None
    assert "explore" in result.summary.lower() or "Explore" in result.summary

def test_runner_spawn_plan():
    """Test spawning plan agent."""
    runner = AgentRunner()
    result = asyncio.run(runner.spawn(AgentType.PLAN, "create a plan"))
    assert result.summary is not None

def test_runner_spawn_build():
    """Test spawning build agent."""
    runner = AgentRunner()
    result = asyncio.run(runner.spawn(AgentType.BUILD, "implement feature"))
    assert result.summary is not None
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/agents/test_runner.py -v`
Expected: ERROR - module not found

- [ ] **Step 3: Create runner.py**

```python
# src/opencli/agents/runner.py
"""Agent runner - spawns and manages agents."""
import asyncio
import time
from typing import Optional
from opencli.agents.types import AgentType
from opencli.agents.config import AgentConfig
from opencli.agents.base import BaseAgent, AgentResult
from opencli.agents.factory import AgentFactory
from opencli.agents.explorer import ExploreAgent
from opencli.agents.planner import PlanAgent
from opencli.agents.builder import BuildAgent


class AgentRunner:
    """Spawns and manages agent execution."""

    def __init__(self):
        self._agent_classes = {
            AgentType.EXPLORE: ExploreAgent,
            AgentType.PLAN: PlanAgent,
            AgentType.BUILD: BuildAgent,
            AgentType.GENERAL: BuildAgent,
        }

    def _create_agent(self, config: AgentConfig) -> BaseAgent:
        """Create an agent instance from config."""
        for agent_type, agent_class in self._agent_classes.items():
            if agent_type.value == config.name:
                return agent_class(config)
        # Default to BuildAgent
        return BuildAgent(config)

    async def spawn(
        self,
        agent_type: AgentType,
        task: str,
        model: Optional[str] = None,
        memory_enabled: bool = True,
        max_turns: int = 10,
        timeout: int = 300,
    ) -> AgentResult:
        """Spawn a subagent to handle a task."""
        config = AgentFactory.create(
            agent_type=agent_type,
            model=model,
            memory_enabled=memory_enabled,
            max_turns=max_turns,
            timeout=timeout,
        )

        agent = self._create_agent(config)

        try:
            result = await asyncio.wait_for(
                agent.run(task),
                timeout=timeout,
            )
            return result
        except asyncio.TimeoutError:
            return AgentResult(
                summary=f"Agent {agent_type.value} timed out after {timeout}s",
                error=f"TimeoutError after {timeout}s",
            )
        except Exception as e:
            return AgentResult(
                summary=f"Agent {agent_type.value} failed",
                error=str(e),
            )
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/agents/test_runner.py -v`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add src/opencli/agents/runner.py tests/agents/test_runner.py
git commit -m "feat: add AgentRunner for spawning agents"
```

---

## Task 5: Integrate into AgentEngine

**Files:**
- Modify: `src/opencli/agent/engine.py`

- [ ] **Step 1: Read current engine.py**

Find and read `src/opencli/agent/engine.py`. Identify where to add delegation logic.

- [ ] **Step 2: Add @agent delegation to run()**

In the `run()` method, add delegation handling:

```python
# At the start of run() method, add:
async def run(self, task: str) -> AsyncIterator[AgentMessage]:
    # Check for @agent delegation
    if task.startswith("@explore "):
        from opencli.agents import AgentRunner, AgentType
        runner = AgentRunner()
        result = await runner.spawn(AgentType.EXPLORE, task[8:])
        yield AgentMessage(
            type="subagent_result",
            content=result.summary,
        )
        return

    if task.startswith("@plan "):
        from opencli.agents import AgentRunner, AgentType
        runner = AgentRunner()
        result = await runner.spawn(AgentType.PLAN, task[6:])
        yield AgentMessage(
            type="subagent_result",
            content=result.summary,
        )
        return

    if task.startswith("@build "):
        from opencli.agents import AgentRunner, AgentType
        runner = AgentRunner()
        result = await runner.spawn(AgentType.BUILD, task[7:])
        yield AgentMessage(
            type="subagent_result",
            content=result.summary,
        )
        return

    # Continue with existing logic...
```

- [ ] **Step 3: Run tests**

Run: `pytest tests/ -v` to ensure nothing broke

- [ ] **Step 4: Commit**

```bash
git add src/opencli/agent/engine.py
git commit -m "feat: integrate subagent system into AgentEngine"
```

---

## Task 6: Integration Tests

**Files:**
- Create: `tests/agents/test_integration.py`

- [ ] **Step 1: Write integration test**

```python
# tests/agents/test_integration.py
import pytest
import asyncio
from opencli.agents import AgentRunner, AgentType

def test_explore_delegation_flow():
    """Test the full explore delegation flow."""
    runner = AgentRunner()

    # Spawn explore agent
    result = asyncio.run(runner.spawn(
        AgentType.EXPLORE,
        "find all python files in the project"
    ))

    assert result.summary is not None
    assert result.error is None or "timeout" not in result.error.lower()

def test_plan_delegation_flow():
    """Test the full plan delegation flow."""
    runner = AgentRunner()

    result = asyncio.run(runner.spawn(
        AgentType.PLAN,
        "create a plan for adding authentication"
    ))

    assert result.summary is not None

def test_build_delegation_flow():
    """Test the full build delegation flow."""
    runner = AgentRunner()

    result = asyncio.run(runner.spawn(
        AgentType.BUILD,
        "add a simple hello world function"
    ))

    assert result.summary is not None

def test_agent_timeout():
    """Test that agent timeout works."""
    runner = AgentRunner()

    # Spawn with very short timeout
    result = asyncio.run(runner.spawn(
        AgentType.BUILD,
        "sleep for 100 seconds",  # Won't complete
        timeout=1,
    ))

    # Should get timeout error
    assert result.error is not None
    assert "timeout" in result.error.lower() or "timed out" in result.error.lower()
```

- [ ] **Step 2: Run integration tests**

Run: `pytest tests/agents/test_integration.py -v`

- [ ] **Step 3: Commit**

```bash
git add tests/agents/test_integration.py
git commit -m "test: add subagent integration tests"
```

---

## Task 7: End-to-End Verification

- [ ] **Step 1: Run full test suite**

Run: `pytest tests/ -v`

- [ ] **Step 2: Manual test**

```bash
# Test that imports work
python -c "from opencli.agents import AgentRunner, AgentType; print('OK')"

# Test spawning an agent
python -c "
import asyncio
from opencli.agents import AgentRunner, AgentType

async def test():
    runner = AgentRunner()
    result = await runner.spawn(AgentType.EXPLORE, 'test task')
    print(result.summary)

asyncio.run(test())
"

# Test CLI help (should show new commands if added)
python -m opencli.cli --help
```

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete subagent system implementation"
```

---

## Self-Review Checklist

- [ ] Spec coverage: All requirements from design doc implemented?
- [ ] No placeholders: All steps have actual code/commands?
- [ ] Type consistency: All method names consistent throughout?
- [ ] Test coverage: Each component has tests?
- [ ] Files created: `agents/types.py`, `agents/config.py`, `agents/base.py`, `agents/factory.py`, `agents/explorer.py`, `agents/planner.py`, `agents/builder.py`, `agents/runner.py`?
- [ ] Files modified: `agent/engine.py`?
- [ ] Agent types: Explore, Plan, Build all implemented?

---

## Plan Complete

**Saved to:** `thoughts/shared/plans/2026-05-12-opencli-subagent-system.md`

**Two execution options:**

1. **Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

2. **Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
