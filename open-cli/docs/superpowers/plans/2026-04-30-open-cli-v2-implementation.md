# open-cli V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform open-cli from a basic REPL to a full-featured AI coding agent with Client/Server architecture, Agent system, MCP/Skills/Commands/Hooks extensions, Rich TUI, and enterprise-grade security.

**Architecture:** Complete rewrite with modular architecture. Server handles all LLM/Tool/Agent logic; TUI Client provides rich interface. LiteLLM provides unified LLM access. MCP protocol enables external integrations.

**Tech Stack:**
- Python 3.11+
- Textual (TUI)
- LiteLLM (LLM abstraction)
- MCP SDK (extensions)
- Pydantic (validation)
- SQLAlchemy + aiosqlite (persistence)

---

## Phase 1: Project Scaffold

### 1.1 Restructure Directory Layout

**Files:**
- Create: `src/opencli/__init__.py`
- Create: `src/opencli/pyproject.toml` (move from root)
- Create: `src/opencli/cli.py`
- Create: `src/opencli/server.py`
- Create: `src/opencli/types/__init__.py`
- Create: `src/opencli/types/messages.py`
- Modify: `pyproject.toml` (simplify to reference src/)
- Delete: `cli.py`, `config.py`, `core/`, `tools/` (old structure)

- [ ] **Step 1: Create src/opencli directory structure**

```bash
mkdir -p src/opencli/{client,server,providers,tools,extensions/{mcp,skills,commands,hooks},security,config,types}
mkdir -p tests/{unit,integration,e2e}
```

- [ ] **Step 2: Create pyproject.toml with all dependencies**

```toml
[project]
name = "opencli"
version = "2.0.0"
requires-python = ">=3.11"
dependencies = [
    "httpx>=0.27.0",
    "pydantic>=2.0",
    "anyio>=4.0",
    "litellm>=1.0",
    "textual>=0.80",
    "rich>=13.0",
    "mcp>=1.0",
    "sqlalchemy>=2.0",
    "aiosqlite>=0.19",
    "PyYAML>=6.0",
    "structlog>=24.0",
    "typer>=0.12",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-asyncio>=0.23",
    "pytest-cov>=4.0",
    "ruff>=0.4",
    "mypy>=1.0",
]
```

- [ ] **Step 3: Create src/opencli/__init__.py**

```python
"""open-cli - AI Coding Agent"""
__version__ = "2.0.0"
```

- [ ] **Step 4: Create types/messages.py with core types**

```python
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, AsyncIterator, Optional

class AgentType(Enum):
    PLAN = "plan"
    BUILD = "build"
    GENERAL = "general"

@dataclass
class Message:
    id: str
    role: str
    content: str | list["ContentBlock"]
    timestamp: datetime = field(default_factory=datetime.now)

@dataclass
class ContentBlock:
    type: str
    text: Optional[str] = None
    tool_use: Optional[dict] = None
    tool_result: Optional[dict] = None

@dataclass
class ToolCall:
    id: str
    name: str
    arguments: dict

@dataclass
class Session:
    id: str
    agent_type: AgentType
    messages: list[Message] = field(default_factory=list)
    created_at: datetime = field(default_factory=datetime.now)
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "phase1: Create project scaffold structure"
```

---

### 1.2 Configuration System

**Files:**
- Create: `src/opencli/config/__init__.py`
- Create: `src/opencli/config/schema.py`
- Create: `src/opencli/config/loader.py`
- Create: `src/opencli/config/validator.py`

- [ ] **Step 1: Create config/schema.py**

```python
from pydantic import BaseModel, Field
from typing import Optional

class ProviderConfig(BaseModel):
    type: str = "litellm"
    api_key: str
    base_url: Optional[str] = None
    default_model: str = "claude-3-5-sonnet"

class TrustedFolderConfig(BaseModel):
    path: str
    permissions: list[str] = ["read"]
    recursive: bool = True

class SecurityConfig(BaseModel):
    trusted_folders: list[TrustedFolderConfig] = []
    sandbox_enabled: bool = True

class UIConfig(BaseModel):
    theme: str = "default"
    show_file_explorer: bool = True
    font_size: int = 14

class OpenCLIConfig(BaseModel):
    version: str = "2.0.0"
    providers: dict[str, ProviderConfig] = {}
    security: SecurityConfig = Field(default_factory=SecurityConfig)
    ui: UIConfig = Field(default_factory=UIConfig)
```

- [ ] **Step 2: Create config/loader.py**

```python
import yaml
from pathlib import Path
from .schema import OpenCLIConfig

def load_config() -> OpenCLIConfig:
    config_path = Path.home() / ".opencli" / "config.yaml"
    if config_path.exists():
        with open(config_path) as f:
            data = yaml.safe_load(f) or {}
        return OpenCLIConfig(**data)
    return OpenCLIConfig()
```

- [ ] **Step 3: Commit**

```bash
git add src/opencli/config/
git commit -m "phase1: Add configuration system"
```

---

## Phase 2: Provider System (LiteLLM)

### 2.1 Provider Interface

**Files:**
- Create: `src/opencli/providers/__init__.py`
- Create: `src/opencli/providers/base.py`
- Create: `src/opencli/providers/litellm.py`

- [ ] **Step 1: Create providers/base.py**

```python
from abc import ABC, abstractmethod
from typing import AsyncIterator, Optional
from ..types.messages import Message, ContentBlock

class BaseProvider(ABC):
    @abstractmethod
    async def chat(
        self,
        messages: list[Message],
        tools: Optional[list[dict]] = None,
        **kwargs
    ) -> AsyncIterator[str]:
        """Stream chat response"""
        pass

    @property
    @abstractmethod
    def name(self) -> str:
        pass

    @property
    def supports_tools(self) -> bool:
        return True

    @property
    def supports_streaming(self) -> bool:
        return True
```

- [ ] **Step 2: Create providers/litellm.py**

```python
import litellm
from typing import AsyncIterator
from .base import BaseProvider
from ..types.messages import Message

class LiteLLMProvider(BaseProvider):
    def __init__(self, api_key: str, default_model: str = "claude-3-5-sonnet"):
        self.api_key = api_key
        self.default_model = default_model
        litellm.api_key = api_key

    @property
    def name(self) -> str:
        return "litellm"

    async def chat(
        self,
        messages: list[Message],
        tools: Optional[list[dict]] = None,
        **kwargs
    ) -> AsyncIterator[str]:
        response = await litellm.acompletion(
            model=kwargs.get("model", self.default_model),
            messages=[self._format_msg(m) for m in messages],
            tools=tools,
            stream=True,
        )
        async for chunk in response:
            if chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content

    def _format_msg(self, msg: Message) -> dict:
        content = msg.content
        if isinstance(content, list):
            return {"role": msg.role, "content": self._format_blocks(content)}
        return {"role": msg.role, "content": content}

    def _format_blocks(self, blocks: list[ContentBlock]) -> str:
        return "\n".join(b.text or "" for b in blocks)
```

- [ ] **Step 3: Commit**

```bash
git add src/opencli/providers/
git commit -m "phase2: Add LiteLLM provider"
```

---

## Phase 3: Tool System

### 3.1 Tool Registry

**Files:**
- Create: `src/opencli/tools/__init__.py`
- Create: `src/opencli/tools/registry.py`
- Create: `src/opencli/tools/base.py`
- Create: `src/opencli/tools/file_tool.py`
- Create: `src/opencli/tools/git_tool.py`
- Create: `src/opencli/tools/cmd_tool.py`

- [ ] **Step 1: Create tools/base.py**

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any

@dataclass
class ToolDefinition:
    name: str
    description: str
    input_schema: dict

@dataclass
class ToolResult:
    success: bool
    content: Any
    error: Optional[str] = None

class BaseTool(ABC):
    @abstractmethod
    def get_definition(self) -> ToolDefinition:
        pass

    @abstractmethod
    async def execute(self, **kwargs) -> ToolResult:
        pass
```

- [ ] **Step 2: Create tools/registry.py**

```python
from typing import Optional
from .base import BaseTool, ToolDefinition

class ToolRegistry:
    def __init__(self):
        self._tools: dict[str, BaseTool] = {}

    def register(self, tool: BaseTool):
        self._tools[tool.get_definition().name] = tool

    def get(self, name: str) -> Optional[BaseTool]:
        return self._tools.get(name)

    def list_all(self) -> list[ToolDefinition]:
        return [t.get_definition() for t in self._tools.values()]
```

- [ ] **Step 3: Create tools/file_tool.py (simplified from current)**

```python
from pathlib import Path
from typing import Any
from .base import BaseTool, ToolDefinition, ToolResult

class FileTool(BaseTool):
    def get_definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="read_file",
            description="Read file contents",
            input_schema={
                "type": "object",
                "properties": {"file_path": {"type": "string"}},
                "required": ["file_path"]
            }
        )

    async def execute(self, file_path: str, **kwargs) -> ToolResult:
        try:
            content = Path(file_path).read_text()
            return ToolResult(success=True, content=content)
        except Exception as e:
            return ToolResult(success=False, content=None, error=str(e))
```

- [ ] **Step 4: Commit**

```bash
git add src/opencli/tools/
git commit -m "phase3: Add tool registry system"
```

---

## Phase 4: Agent System

### 4.1 Agent Base & Orchestrator

**Files:**
- Create: `src/opencli/server/agent.py`
- Create: `src/opencli/server/orchestrator.py`
- Create: `src/opencli/server/engine.py`

- [ ] **Step 1: Create server/agent.py**

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import AsyncIterator, Optional
from ..types.messages import Message, AgentType

@dataclass
class AgentConfig:
    agent_type: AgentType
    model: Optional[str] = None
    temperature: float = 0.7
    max_tokens: int = 4096
    system_prompt: Optional[str] = None

class Agent(ABC):
    def __init__(self, config: AgentConfig, registry, provider):
        self.config = config
        self.registry = registry
        self.provider = provider

    @abstractmethod
    async def run(self, prompt: str, session: "Session") -> AsyncIterator[str]:
        """Execute agent and yield response chunks"""
        pass

    def get_system_prompt(self) -> str:
        base = "You are a helpful AI coding assistant."
        if self.config.agent_type == AgentType.PLAN:
            base += "\n\n[PLAN MODE] You can read files and analyze code, but CANNOT modify anything."
        return base
```

- [ ] **Step 2: Create server/orchestrator.py**

```python
from typing import AsyncIterator
from .agent import Agent, AgentConfig
from ..types.messages import Session, Message, AgentType
from ..providers.base import BaseProvider
from ..tools.registry import ToolRegistry

class AgentOrchestrator:
    def __init__(self, provider: BaseProvider, registry: ToolRegistry):
        self.provider = provider
        self.registry = registry
        self.agents: dict[AgentType, Agent] = {}

    def register_agent(self, agent_type: AgentType, agent: Agent):
        self.agents[agent_type] = agent

    async def run(
        self,
        agent_type: AgentType,
        prompt: str,
        session: Session
    ) -> AsyncIterator[str]:
        agent = self.agents.get(agent_type)
        if not agent:
            raise ValueError(f"No agent registered for type: {agent_type}")
        async for chunk in agent.run(prompt, session):
            yield chunk
```

- [ ] **Step 3: Create server/engine.py (main entry)**

```python
from .orchestrator import AgentOrchestrator
from .session import SessionManager
from ..providers.litellm import LiteLLMProvider
from ..tools.registry import ToolRegistry

class Engine:
    def __init__(self, config):
        self.config = config
        self.provider = LiteLLMProvider(
            api_key=config.providers["litellm"].api_key,
            default_model=config.providers["litellm"].default_model
        )
        self.tool_registry = ToolRegistry()
        self.orchestrator = AgentOrchestrator(self.provider, self.tool_registry)
        self.session_manager = SessionManager()
```

- [ ] **Step 4: Commit**

```bash
git add src/opencli/server/
git commit -m "phase4: Add agent system with orchestrator"
```

---

## Phase 5: Security System

### 5.1 Security Boundary & Trusted Folders

**Files:**
- Create: `src/opencli/security/__init__.py`
- Create: `src/opencli/security/trusted.py`
- Create: `src/opencli/security/context.py`
- Create: `src/opencli/security/policy.py`

- [ ] **Step 1: Create security/trusted.py**

```python
from dataclasses import dataclass, field
from pathlib import Path
from enum import Enum

class Permission(Enum):
    READ = "read"
    WRITE = "write"
    EXECUTE = "execute"
    NETWORK = "network"

@dataclass
class TrustedFolder:
    path: Path
    permissions: set[Permission] = field(default_factory={Permission.READ})
    recursive: bool = True

class TrustedFolderManager:
    def __init__(self, folders: list[TrustedFolder] = None):
        self.folders = folders or []

    def check_access(self, path: Path, permission: Permission) -> bool:
        for folder in self.folders:
            if self._is_under(path, folder.path):
                if permission in folder.permissions:
                    return True
        return False

    def _is_under(self, path: Path, base: Path) -> bool:
        try:
            path.resolve().relative_to(base.resolve())
            return True
        except ValueError:
            return False
```

- [ ] **Step 2: Create security/policy.py**

```python
from dataclasses import dataclass
from enum import Enum

class Effect(Enum):
    ALLOW = "allow"
    DENY = "deny"

@dataclass
class PolicyRule:
    resource: str
    action: str
    effect: Effect = Effect.ALLOW

class PolicyEngine:
    def __init__(self):
        self.rules: list[PolicyRule] = [
            PolicyRule(resource="file", action="delete", effect=Effect.DENY),
        ]

    def evaluate(self, resource: str, action: str) -> bool:
        for rule in self.rules:
            if rule.resource == resource and rule.action == action:
                return rule.effect == Effect.ALLOW
        return True  # Default allow
```

- [ ] **Step 3: Commit**

```bash
git add src/opencli/security/
git commit -m "phase5: Add security system with Trusted Folders"
```

---

## Phase 6: Extension System

### 6.1 MCP Client

**Files:**
- Create: `src/opencli/extensions/mcp/__init__.py`
- Create: `src/opencli/extensions/mcp/client.py`
- Create: `src/opencli/extensions/mcp/protocol.py`

- [ ] **Step 1: Create mcp/client.py**

```python
from mcp import ClientSession
from mcp.client.stdio import stdio_client
from typing import Optional
from ...tools.base import BaseTool, ToolDefinition, ToolResult

class MCPClient:
    def __init__(self):
        self.sessions: dict[str, ClientSession] = {}
        self.tools: dict[str, BaseTool] = {}

    async def connect(self, name: str, command: list[str]) -> bool:
        try:
            async with stdio_client(command) as (read, write):
                session = ClientSession(read, write)
                await session.initialize()
                self.sessions[name] = session
                await self._load_tools(name, session)
                return True
        except Exception as e:
            return False

    async def _load_tools(self, server_name: str, session: ClientSession):
        tools = await session.list_tools()
        for tool in tools:
            mcp_tool = MCPTool(server_name, tool.name, tool.description, tool.inputSchema)
            self.tools[f"{server_name}/{tool.name}"] = mcp_tool

    async def disconnect(self, name: str):
        if name in self.sessions:
            await self.sessions[name].close()
            del self.sessions[name]
```

- [ ] **Step 2: Create mcp/tools.py**

```python
from ...tools.base import BaseTool, ToolDefinition, ToolResult

class MCPTool(BaseTool):
    def __init__(self, server: str, name: str, description: str, input_schema: dict):
        self.server = server
        self.name = name
        self.description = description
        self.input_schema = input_schema

    def get_definition(self) -> ToolDefinition:
        return ToolDefinition(
            name=f"{self.server}/{self.name}",
            description=self.description,
            input_schema=self.input_schema
        )

    async def execute(self, **kwargs) -> ToolResult:
        # Delegates to MCP session
        pass
```

- [ ] **Step 3: Commit**

```bash
git add src/opencli/extensions/mcp/
git commit -m "phase6: Add MCP client support"
```

---

### 6.2 Skills System

**Files:**
- Create: `src/opencli/extensions/skills/__init__.py`
- Create: `src/opencli/extensions/skills/registry.py`
- Create: `src/opencli/extensions/skills/loader.py`
- Create: `src/opencli/extensions/skills/skill.py`

- [ ] **Step 1: Create skills/skill.py**

```python
from dataclasses import dataclass
from pathlib import Path

@dataclass
class Skill:
    name: str
    description: str
    version: str
    path: Path
    prompt_template: str
    agent_type: str = "build"
    tools: list[str] = None

    @classmethod
    def from_directory(cls, path: Path) -> "Skill":
        import yaml
        with open(path / "skill.yaml") as f:
            meta = yaml.safe_load(f)
        with open(path / "SKILL.md") as f:
            prompt = f.read()
        return cls(
            name=meta["name"],
            description=meta["description"],
            version=meta["version"],
            path=path,
            prompt_template=prompt,
            agent_type=meta.get("agent_type", "build"),
            tools=meta.get("tools", [])
        )
```

- [ ] **Step 2: Create skills/loader.py**

```python
from pathlib import Path
from .skill import Skill
from .registry import SkillRegistry

class SkillLoader:
    def __init__(self, registry: SkillRegistry):
        self.registry = registry

    def load_from_directory(self, skill_dir: Path):
        for skill_path in skill_dir.iterdir():
            if skill_path.is_dir():
                skill = Skill.from_directory(skill_path)
                self.registry.register(skill)
```

- [ ] **Step 3: Commit**

```bash
git add src/opencli/extensions/skills/
git commit -m "phase6: Add Skills system"
```

---

### 6.3 Commands System

**Files:**
- Create: `src/opencli/extensions/commands/__init__.py`
- Create: `src/opencli/extensions/commands/registry.py`
- Create: `src/opencli/extensions/commands/parser.py`

- [ ] **Step 1: Create commands/registry.py**

```python
from dataclasses import dataclass
from typing import Optional

@dataclass
class CustomCommand:
    name: str
    description: str
    prompt_template: str
    aliases: list[str] = None

class CommandRegistry:
    def __init__(self):
        self.commands: dict[str, CustomCommand] = {}

    def register(self, command: CustomCommand):
        self.commands[command.name] = command
        for alias in (command.aliases or []):
            self.commands[alias] = command

    def get(self, name: str) -> Optional[CustomCommand]:
        return self.commands.get(name)

    def list_all(self) -> list[CustomCommand]:
        return list(self.commands.values())
```

- [ ] **Step 2: Create commands/parser.py**

```python
import re

class CommandParser:
    PATTERN = re.compile(r'^/(\w+)(?:\s+(.*))?$')

    def parse(self, input_text: str) -> tuple[Optional[str], Optional[str]]:
        match = self.PATTERN.match(input_text.strip())
        if match:
            return match.group(1), match.group(2)
        return None, None
```

- [ ] **Step 3: Commit**

```bash
git add src/opencli/extensions/commands/
git commit -m "phase6: Add Commands system"
```

---

### 6.4 Hooks System

**Files:**
- Create: `src/opencli/extensions/hooks/__init__.py`
- Create: `src/opencli/extensions/hooks/manager.py`
- Create: `src/opencli/extensions/hooks/types.py`

- [ ] **Step 1: Create hooks/types.py**

```python
from enum import Enum

class HookType(Enum):
    BEFORE_TOOL_CALL = "before_tool_call"
    AFTER_TOOL_CALL = "after_tool_call"
    BEFORE_AGENT_RUN = "before_agent_run"
    AFTER_AGENT_RUN = "after_agent_run"
    ON_ERROR = "on_error"
    ON_CHECKPOINT = "on_checkpoint"

@dataclass
class Hook:
    type: HookType
    script: str
    condition: dict = None
    timeout: int = 30
```

- [ ] **Step 2: Create hooks/manager.py**

```python
import asyncio
from typing import Optional
from .types import Hook, HookType

class HookManager:
    def __init__(self):
        self.hooks: list[Hook] = []

    def register(self, hook: Hook):
        self.hooks.append(hook)

    async def execute(self, hook_type: HookType, context: dict) -> bool:
        matching = [h for h in self.hooks if h.type == hook_type]
        for hook in matching:
            proc = await asyncio.create_subprocess_shell(
                hook.script,
                env={**os.environ, **context.get("env", {})},
            )
            try:
                await asyncio.wait_for(proc.wait(), timeout=hook.timeout)
                return proc.returncode == 0
            except asyncio.TimeoutError:
                proc.kill()
                return False
        return True
```

- [ ] **Step 3: Commit**

```bash
git add src/opencli/extensions/hooks/
git commit -m "phase6: Add Hooks system"
```

---

## Phase 7: Session System

### 7.1 Enhanced Session Management

**Files:**
- Modify: `src/opencli/server/session.py` (rename from core/session.py)
- Create: `src/opencli/server/checkpoint.py`
- Create: `src/opencli/server/memory.py`

- [ ] **Step 1: Create server/session.py**

```python
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional
from ..types.messages import Message, AgentType

@dataclass
class Session:
    id: str
    agent_type: AgentType
    messages: list[Message] = field(default_factory=list)
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)
    metadata: dict = field(default_factory=dict)

class SessionManager:
    def __init__(self, storage_path: Path):
        self.storage_path = storage_path
        self.sessions: dict[str, Session] = {}

    async def create(self, agent_type: AgentType = AgentType.BUILD) -> Session:
        session = Session(id=generate_id(), agent_type=agent_type)
        self.sessions[session.id] = session
        await self.save(session)
        return session

    async def save(self, session: Session):
        # Save to JSON file
        pass

    async def load(self, session_id: str) -> Optional[Session]:
        pass
```

- [ ] **Step 2: Create server/checkpoint.py**

```python
from dataclasses import dataclass
from datetime import datetime

@dataclass
class Checkpoint:
    id: str
    session_id: str
    snapshot: dict
    created_at: datetime = field(default_factory=datetime.now)
    description: str = ""

class CheckpointManager:
    def __init__(self, storage_path: Path):
        self.storage_path = storage_path

    async def create(self, session: Session, description: str = "") -> Checkpoint:
        checkpoint = Checkpoint(
            id=generate_id(),
            session_id=session.id,
            snapshot=self._snapshot(session),
            description=description
        )
        await self.save(checkpoint)
        return checkpoint

    async def restore(self, checkpoint_id: str) -> Session:
        pass
```

- [ ] **Step 3: Create server/memory.py**

```python
from dataclasses import dataclass
from datetime import datetime
from enum import Enum

class MemoryCategory(Enum):
    BUILD_COMMAND = "build_command"
    TEST_COMMAND = "test_command"
    CODE_PATTERN = "code_pattern"

@dataclass
class Learning:
    content: str
    source: str
    category: MemoryCategory
    confidence: float
    created_at: datetime = field(default_factory=datetime.now)

class AutoMemory:
    def __init__(self, project_root: Path):
        self.learnings: list[Learning] = []

    async def learn(self, observation: str, source: str, category: MemoryCategory):
        learning = Learning(
            content=observation,
            source=source,
            category=category,
            confidence=0.8
        )
        self.learnings.append(learning)

    async def recall(self, query: str) -> list[Learning]:
        return self.learnings[:10]  # Simple implementation
```

- [ ] **Step 4: Commit**

```bash
git add src/opencli/server/
git commit -m "phase7: Add session, checkpoint, and memory systems"
```

---

## Phase 8: Rich TUI

### 8.1 Textual TUI Application

**Files:**
- Create: `src/opencli/client/__init__.py`
- Create: `src/opencli/client/app.py`
- Create: `src/opencli/client/tui.py`
- Create: `src/opencli/client/panels/__init__.py`
- Create: `src/opencli/client/panels/chat.py`
- Create: `src/opencli/client/panels/status.py`

- [ ] **Step 1: Create client/app.py**

```python
from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Static
from .panels.chat import ChatPanel
from .panels.status import StatusBar

class OpenCLIApp(App):
    CSS = """
    Screen {
        layout: horizontal;
    }
    #sidebar {
        width: 30;
    }
    #main {
        width: 1fr;
    }
    """

    def compose(self) -> ComposeResult:
        yield Header()
        yield ChatPanel(id="main")
        yield StatusBar(id="status")
        yield Footer()

    async def on_mount(self):
        await self.connect_to_server()
```

- [ ] **Step 2: Create client/panels/chat.py**

```python
from textual.widgets import TextArea, ScrollableContainer
from textual import on
from textual.message import Message

class ChatPanel(ScrollableContainer):
    class SentMessage(Message):
        def __init__(self, text: str):
            self.text = text
            super().__init__()

    def compose(self):
        yield TextArea(id="input", placeholder="Type your message...")
        yield ScrollableContainer(id="messages")

    @on(TextArea.Changed, "#input")
    async def on_input(self, event: TextArea.Changed):
        if event.text_area.key == "enter":
            self.post_message(self.SentMessage(event.text_area.text))
            event.text_area.clear()
```

- [ ] **Step 3: Create client/panels/status.py**

```python
from textual.widgets import Static

class StatusBar(Static):
    def __init__(self):
        super().__init__()
        self.api_status = "●"
        self.model = ""

    def render(self) -> str:
        return f"[{self.api_status}] Connected | Model: {self.model}"
```

- [ ] **Step 4: Create client/tui.py**

```python
import asyncio
from .app import OpenCLIApp

async def run_tui():
    app = OpenCLIApp()
    await app.run_async()

if __name__ == "__main__":
    asyncio.run(run_tui())
```

- [ ] **Step 5: Commit**

```bash
git add src/opencli/client/
git commit -m "phase8: Add Rich TUI with Textual"
```

---

## Phase 9: Client/Server IPC

### 9.1 WebSocket & STDIO Protocol

**Files:**
- Create: `src/opencli/client/protocol.py`
- Create: `src/opencli/server/protocol.py`

- [ ] **Step 1: Create client/protocol.py**

```python
import json
from typing import AsyncIterator
import websockets

class ClientProtocol:
    def __init__(self, server_url: str = "ws://localhost:8080/ws"):
        self.server_url = server_url
        self.ws = None

    async def connect(self):
        self.ws = await websockets.connect(self.server_url)

    async def send(self, method: str, params: dict):
        message = {"jsonrpc": "2.0", "id": generate_id(), "method": method, "params": params}
        await self.ws.send(json.dumps(message))

    async def receive(self) -> AsyncIterator[dict]:
        async for msg in self.ws:
            yield json.loads(msg)
```

- [ ] **Step 2: Create server/protocol.py**

```python
import json
from typing import AsyncIterator
from websockets import WebSocketServerProtocol

class ServerProtocol:
    def __init__(self, engine):
        self.engine = engine

    async def handle_message(self, message: dict, ws: WebSocketServerProtocol):
        method = message.get("method")
        params = message.get("params", {})

        if method == "chat":
            async for chunk in self.engine.orchestrator.run(
                params.get("agent_type", "build"),
                params.get("prompt", ""),
                None  # session
            ):
                await ws.send(json.dumps({"type": "text", "content": chunk}))
        elif method == "session_create":
            session = await self.engine.session_manager.create()
            await ws.send(json.dumps({"type": "session", "id": session.id}))
```

- [ ] **Step 3: Create server.py entry point**

```python
import asyncio
from .engine import Engine
from .protocol import ServerProtocol
from ..config import load_config

async def main():
    config = load_config()
    engine = Engine(config)
    protocol = ServerProtocol(engine)
    # Start WebSocket server on port 8080
    # or STDIO mode

if __name__ == "__main__":
    asyncio.run(main())
```

- [ ] **Step 4: Commit**

```bash
git add src/opencli/server/protocol.py
git add src/opencli/client/protocol.py
git add src/opencli/server.py
git commit -m "phase9: Add WebSocket/STDIO IPC protocol"
```

---

## Phase 10: Integration & Testing

### 10.1 Basic Integration Tests

**Files:**
- Create: `tests/unit/test_tools.py`
- Create: `tests/unit/test_security.py`
- Create: `tests/integration/test_provider.py`

- [ ] **Step 1: Create tests/unit/test_tools.py**

```python
import pytest
from opencli.tools.file_tool import FileTool

@pytest.fixture
def file_tool():
    from opencli.security.trusted import TrustedFolderManager
    manager = TrustedFolderManager([TrustedFolder(Path("/tmp"), {Permission.READ})])
    return FileTool(manager)

def test_read_file(file_tool):
    result = file_tool.execute(file_path="test.txt")
    assert result.success
```

- [ ] **Step 2: Create tests/integration/test_provider.py**

```python
import pytest
from opencli.providers.litellm import LiteLLMProvider

@pytest.mark.asyncio
async def test_litellm_chat():
    if not os.getenv("LITELLM_API_KEY"):
        pytest.skip("No API key")
    provider = LiteLLMProvider(api_key=os.getenv("LITELLM_API_KEY"))
    chunks = []
    async for chunk in provider.chat([Message(role="user", content="Hello")]):
        chunks.append(chunk)
    assert len(chunks) > 0
```

- [ ] **Step 3: Commit**

```bash
git add tests/
git commit -m "phase10: Add integration tests"
```

---

## Summary

| Phase | Component | Key Files | Status |
|-------|-----------|-----------|--------|
| 1 | Scaffold | pyproject.toml, types/ | ⬜ |
| 2 | Provider | providers/base.py, providers/litellm.py | ⬜ |
| 3 | Tools | tools/registry.py, tools/file_tool.py | ⬜ |
| 4 | Agent | server/agent.py, server/orchestrator.py | ⬜ |
| 5 | Security | security/trusted.py, security/policy.py | ⬜ |
| 6 | Extensions | extensions/mcp/, extensions/skills/, extensions/commands/, extensions/hooks/ | ⬜ |
| 7 | Session | server/session.py, server/checkpoint.py, server/memory.py | ⬜ |
| 8 | TUI | client/app.py, client/panels/*.py | ⬜ |
| 9 | IPC | client/protocol.py, server/protocol.py | ⬜ |
| 10 | Testing | tests/ | ⬜ |

---

## Notes

- Each phase builds on previous phases - do in order
- Use TDD: write test first, then implementation
- Commit after each phase
- Full spec: `docs/superpowers/specs/2026-04-30-open-cli-v2-design.md`
