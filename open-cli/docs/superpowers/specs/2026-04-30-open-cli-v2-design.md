# open-cli V2 详细设计文档

版本: 2.0.0
日期: 2026-04-30
状态: 设计中

---

## 1. 项目概述

### 1.1 项目目标

open-cli V2 是一个现代化的 AI 编程 CLI 工具，目标成为世界上最好的开源 AI 编程助手。通过模块化架构、强大的扩展系统和优秀的安全性，赋能开发者更高效地完成编程任务。

### 1.2 核心价值

- **开放性**: 100% 开源，不绑定任何 LLM 提供商
- **可扩展性**: 通过 MCP、Skills、Commands、Hooks 提供全方位扩展能力
- **安全性**: 沙箱执行 + Trusted Folders + 细粒度权限控制
- **现代性**: Rich TUI + Client/Server 架构 + 多 Agent 协作

### 1.3 关键指标

| 指标 | V1 | V2 目标 |
|------|-----|---------|
| 支持 LLM 提供商 | 1 | 100+ (via LiteLLM) |
| MCP 支持 | ❌ | ✅ |
| Agent 系统 | ❌ | ✅ Plan/Build/General |
| TUI | ANSI | Rich (textual) |
| 架构 | 单进程 | Client/Server |
| 安全 | 基础目录限制 | 沙箱 + 策略引擎 |
| 扩展 | 无 | MCP + Skills + Commands + Hooks |

---

## 2. 系统架构

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                         Client (TUI)                             │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐             │
│  │  Chat   │  │ Files   │  │ Status  │  │ Tools   │             │
│  │ Panel   │  │ Panel   │  │ Bar     │  │ Output  │             │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘             │
└────────────────────────────┬────────────────────────────────────┘
                            │ WebSocket / STDIO
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Server (Engine)                          │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │                    Agent Orchestrator                    │     │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐           │     │
│  │  │   Plan    │  │   Build   │  │  General  │  ...     │     │
│  │  │   Agent   │  │   Agent   │  │  Subagent │           │     │
│  │  └───────────┘  └───────────┘  └───────────┘           │     │
│  └─────────────────────────────────────────────────────────┘     │
│                              │                                   │
│  ┌──────────┐  ┌──────────┐  │  ┌──────────┐  ┌──────────┐     │
│  │Provider  │  │   MCP    │  │  │  Skills  │  │  Hooks   │     │
│  │(LiteLLM) │  │ Client   │  │  │ Registry │  │ Manager  │     │
│  └──────────┘  └──────────┘  │  └──────────┘  └──────────┘     │
│                              │                                   │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │                    Tool Executor                         │     │
│  │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐        │     │
│  │  │  File  │  │  Git   │  │  Cmd   │  │  MCP   │  ...   │     │
│  │  │  Tool  │  │  Tool  │  │  Tool  │  │  Tool  │        │     │
│  │  └────────┘  └────────┘  └────────┘  └────────┘        │     │
│  └─────────────────────────────────────────────────────────┘     │
│                              │                                   │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │               Security Layer                             │     │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │     │
│  │  │ Sandbox  │  │  Trusted │  │  Policy  │              │     │
│  │  │ Executor │  │ Folders  │  │  Engine  │              │     │
│  │  └──────────┘  └──────────┘  └──────────┘              │     │
│  └─────────────────────────────────────────────────────────┘     │
│                              │                                   │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │               Session Manager                            │     │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │     │
│  │  │ Checkpoint│  │   Auto   │  │  Memory  │              │     │
│  │  │  Store   │  │  Memory  │  │  Store   │              │     │
│  │  └──────────┘  └──────────┘  └──────────┘              │     │
│  └─────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Client/Server 通信协议

#### 协议概述

- **传输层**: WebSocket (远程) / STDIO (本地)
- **消息格式**: JSON-RPC 2.0
- **认证**: Token-based (本地可跳过)

#### 消息类型

```typescript
// 客户端 → 服务器
interface ClientMessage {
  jsonrpc: "2.0";
  id: string;
  method: string;
  params?: {
    prompt?: string;
    session_id?: string;
    agent_type?: "plan" | "build" | "general";
    context?: Record<string, unknown>;
  };
}

// 服务器 → 客户端
interface ServerMessage {
  jsonrpc: "2.0";
  id?: string;
  method: string;
  params?: {
    type?: "text" | "tool_call" | "tool_result" | "status" | "error" | "checkpoint";
    content?: string;
    tool_name?: string;
    tool_args?: Record<string, unknown>;
    status?: string;
  };
}
```

#### STDIO 协议 (用于扩展客户端)

```bash
# 启动服务器
opencli server --stdio

# 通过 STDIO 通信
echo '{"jsonrpc":"2.0","id":"1","method":"chat","params":{"prompt":"hello"}}' | opencli server --stdio
```

### 2.3 目录结构

```
open-cli/
├── src/
│   └── opencli/
│       ├── __init__.py
│       ├── cli.py                 # CLI 入口
│       ├── server.py               # Server 入口
│       ├── client/                 # TUI 客户端
│       │   ├── __init__.py
│       │   ├── tui.py             # Textual TUI 主程序
│       │   ├── app.py             # Textual App
│       │   └── protocol.py        # Client-Server 协议
│       ├── server/                 # 服务端核心
│       │   ├── __init__.py
│       │   ├── engine.py           # 引擎主类
│       │   ├── agent.py            # Agent 基类
│       │   ├── orchestrator.py     # Agent 编排器
│       │   ├── session.py          # 会话管理
│       │   ├── checkpoint.py       # Checkpointing
│       │   └── memory.py           # Auto Memory
│       ├── providers/              # LLM Provider
│       │   ├── __init__.py
│       │   ├── base.py            # Provider 接口
│       │   └── litellm.py         # LiteLLM 实现
│       ├── tools/                  # 内置工具
│       │   ├── __init__.py
│       │   ├── registry.py         # 工具注册表
│       │   ├── file_tool.py
│       │   ├── git_tool.py
│       │   └── cmd_tool.py
│       ├── extensions/              # 扩展系统
│       │   ├── __init__.py
│       │   ├── mcp/                # MCP 协议
│       │   │   ├── __init__.py
│       │   │   ├── client.py
│       │   │   ├── protocol.py
│       │   │   └── tools.py
│       │   ├── skills/             # Agent Skills
│       │   │   ├── __init__.py
│       │   │   ├── registry.py
│       │   │   ├── loader.py
│       │   │   └── skill.py
│       │   ├── commands/            # 自定义命令
│       │   │   ├── __init__.py
│       │   │   ├── registry.py
│       │   │   └── parser.py
│       │   └── hooks/              # 生命周期钩子
│       │       ├── __init__.py
│       │       ├── manager.py
│       │       └── types.py
│       ├── security/               # 安全系统
│       │   ├── __init__.py
│       │   ├── sandbox.py          # 沙箱执行
│       │   ├── trusted.py          # Trusted Folders
│       │   ├── policy.py           # 策略引擎
│       │   └── context.py          # 安全上下文
│       ├── config/                 # 配置系统
│       │   ├── __init__.py
│       │   ├── schema.py          # 配置 schema
│       │   ├── loader.py          # 配置加载
│       │   └── validator.py       # 配置验证
│       └── types/                  # 公共类型
│           ├── __init__.py
│           └── messages.py        # 消息类型定义
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── docs/
│   └── specs/
├── pyproject.toml
└── README.md
```

---

## 3. Agent 系统

### 3.1 Agent 类型

```python
from enum import Enum

class AgentType(Enum):
    PLAN = "plan"      # 只读分析模式
    BUILD = "build"    # 完整操作模式
    GENERAL = "general" # 通用子 agent
```

### 3.2 Agent 接口

```python
from abc import ABC, abstractmethod
from typing import AsyncIterator, Optional
from dataclasses import dataclass

@dataclass
class AgentConfig:
    agent_type: AgentType
    model: Optional[str] = None
    temperature: float = 0.7
    max_tokens: int = 4096
    system_prompt: Optional[str] = None
    tools: Optional[list[str]] = None
    permissions: Optional[list[str]] = None

class Agent(ABC):
    @abstractmethod
    async def run(
        self,
        prompt: str,
        context: dict,
        session: "Session"
    ) -> AsyncIterator["AgentResponse"]:
        """执行 Agent 并返回响应流"""
        pass

    @abstractmethod
    async def plan(self, task: str, context: dict) -> "Plan":
        """生成任务计划 (Plan mode)"""
        pass

@dataclass
class AgentResponse:
    type: Literal["text", "tool_call", "tool_result", "status", "done", "error"]
    content: str
    tool_name: Optional[str] = None
    tool_args: Optional[dict] = None
    metadata: Optional[dict] = None

@dataclass
class Plan:
    steps: list["PlanStep"]
    estimated_time: str
    risks: list[str]

@dataclass
class PlanStep:
    order: int
    description: str
    tools_needed: list[str]
    rollback_plan: str
```

### 3.3 Plan Agent

**特性**:
- 只读模式，禁止文件修改
- 命令执行需要明确授权
- 生成详细的任务计划
- 展示工具调用预览

**Prompt 模板**:
```
你是一个安全规划专家。在 Plan 模式下：
1. 理解用户需求
2. 分析所需工具和步骤
3. 评估风险和回滚方案
4. 生成可执行计划

禁止：
- 修改任何文件
- 执行写操作
- 删除或覆盖内容
```

### 3.4 Build Agent

**特性**:
- 完整操作权限
- 执行所有工具
- 自动回滚失败操作
- 实时进度报告

### 3.5 Subagent 系统

```python
class SubagentManager:
    """管理多个并行子 agent"""

    async def spawn(
        self,
        task: str,
        agent_type: AgentType,
        config: AgentConfig
    ) -> str:  # 返回 subagent_id
        """启动子 agent"""
        pass

    async def get_result(self, subagent_id: str) -> "AgentResponse":
        """获取子 agent 结果"""
        pass

    async def cancel(self, subagent_id: str):
        """取消子 agent"""
        pass

    async def list_active(self) -> list[dict]:
        """列出所有活跃子 agent"""
        pass
```

**使用场景**:
- 多文件并行分析
- 并行执行独立任务
- Agent Team 协作

### 3.6 Agent 切换

- **Tab 键**: 在 Plan/Build 模式间切换
- **@general**: 启动通用子 agent
- **/agent <type>**: 切换 agent 类型

---

## 4. 扩展系统

### 4.1 MCP (Model Context Protocol)

#### 概述

MCP 是 AI 工具与外部数据源连接的开放标准协议。open-cli V2 支持完整的 MCP 客户端功能。

#### MCP 客户端架构

```python
class MCPClient:
    def __init__(self):
        self.servers: dict[str, MCPServerConnection] = {}
        self.tools: dict[str, MCPTool] = {}
        self.resources: dict[str, MCPResource] = {}

    async def connect(self, config: MCPConfig) -> bool:
        """连接到 MCP 服务器"""
        pass

    async def disconnect(self, server_name: str):
        """断开 MCP 服务器"""
        pass

    async def list_tools(self) -> list[MCPTool]:
        """列出所有可用工具"""
        pass

    async def call_tool(
        self,
        tool_name: str,
        arguments: dict
    ) -> ToolResult:
        """调用 MCP 工具"""
        pass
```

#### MCP 配置

```yaml
# ~/.opencli/config.yaml
mcp:
  servers:
    github:
      type: stdio
      command: ["npx", "-y", "@modelcontextprotocol/server-github"]
      env:
        GITHUB_TOKEN: "${GITHUB_TOKEN}"
    slack:
      type: http
      url: http://localhost:3000/mcp
      headers:
        Authorization: "Bearer ${SLACK_TOKEN}"
    filesystem:
      type: stdio
      command: ["npx", "-y", "@modelcontextprotocol/server-filesystem"]
      args: ["/allowed/path"]
```

#### 内置 MCP 工具映射

| MCP 资源类型 | open-cli 工具 |
|-------------|---------------|
| filesystem | file_tool |
| git | git_tool |
| database | (可扩展) |
| http | fetch_url |

### 4.2 Skills (技能)

#### 概述

Skills 是封装好的专业工作流，通过 `@skill_name` 调用。

#### Skill 结构

```
~/.opencli/skills/
├── brainstorming/
│   ├── skill.yaml           # Skill 元数据
│   ├── SKILL.md             # Skill 指令
│   └── scripts/             # 辅助脚本 (可选)
│       └── validate.sh
├── tdd/
│   ├── skill.yaml
│   ├── SKILL.md
│   └── templates/
│       └── test_template.py
└── code-review/
    ├── skill.yaml
    └── SKILL.md
```

#### skill.yaml 格式

```yaml
name: brainstorming
description: 用于头脑风暴和设计阶段的技能
version: 1.0.0
author: opencli team
triggers:
  - "@brainstorming"
  - "/brainstorm"
agent_type: plan  # 推荐使用的 agent 类型
tools:  # 可用的工具列表
  - read_file
  - grep_search
  - list_directory
permissions:  # 权限要求
  - read: all
  - write: none
  - exec: none
```

#### Skill 调用

```
# 在对话中调用
@brainstorming 帮助我设计一个新的用户认证系统

# 传递参数
@tdd implement login feature with email verification

# 组合使用
@brainstorming design API -> @code-review review -> @tdd implement
```

#### Skill 加载流程

```python
class SkillLoader:
    async def load_skill(self, skill_path: Path) -> Skill:
        """加载 skill"""
        # 1. 读取 skill.yaml
        # 2. 验证必要字段
        # 3. 加载 SKILL.md 内容
        # 4. 初始化工具权限
        # 5. 返回 Skill 实例

    async def invoke_skill(
        self,
        skill_name: str,
        prompt: str,
        context: dict
    ) -> AsyncIterator[str]:
        """调用 skill"""
        # 1. 查找 skill
        # 2. 注入 system prompt
        # 3. 执行 (可能多次 LLM 调用)
        # 4. 流式返回结果
```

### 4.3 Commands (命令)

#### 概述

Commands 是用户自定义的快捷命令，通过 `/command_name` 调用。

#### Command 结构

```python
@dataclass
class CustomCommand:
    name: str
    description: str
    prompt_template: str
    agent_type: AgentType = AgentType.BUILD
    aliases: list[str] = field(default_factory=list)

class CommandRegistry:
    def register(self, command: CustomCommand):
        """注册命令"""

    def unregister(self, name: str):
        """取消注册"""

    def get(self, name: str) -> Optional[CustomCommand]:
        """获取命令"""

    def list_all(self) -> list[CustomCommand]:
        """列出所有命令"""
```

#### 内置 Commands

| Command | 描述 |
|---------|------|
| `/help` | 显示帮助 |
| `/clear` | 清除对话 |
| `/session` | 会话信息 |
| `/agent` | 切换 agent |
| `/skills` | 列出 skills |
| `/mcp` | MCP 服务器管理 |
| `/checkpoint` | 创建检查点 |
| `/undo` | 回退操作 |
| `/redo` | 重做操作 |
| `/share` | 分享会话 |

#### 用户自定义 Commands

```yaml
# ~/.opencli/commands.yaml
commands:
  - name: pr-review
    description: Review a pull request
    aliases: [prr, review-pr]
    prompt_template: |
      Review this pull request:
      {pr_url}

      Focus on:
      - Code quality
      - Security issues
      - Test coverage

  - name: explain-code
    description: Explain code in detail
    aliases: [explain, what]
    prompt_template: |
      Explain this code in detail:
      ```{language}
      {code}
      ```
      Include:
      - What it does
      - How it works
      - Potential issues
```

### 4.4 Hooks (钩子)

#### 概述

Hooks 允许在特定事件发生时执行自定义脚本。

#### Hook 类型

```python
class HookType(Enum):
    BEFORE_TOOL_CALL = "before_tool_call"
    AFTER_TOOL_CALL = "after_tool_call"
    BEFORE_AGENT_RUN = "before_agent_run"
    AFTER_AGENT_RUN = "after_agent_run"
    ON_ERROR = "on_error"
    ON_CHECKPOINT = "on_checkpoint"
    ON_SESSION_START = "on_session_start"
    ON_SESSION_END = "on_session_end"
```

#### Hook 配置

```yaml
# ~/.opencli/hooks.yaml
hooks:
  - type: before_tool_call
    tool: write_file
    script: |
      #!/bin/bash
      echo "About to write: $OPENCLI_TOOL_ARGS_FILE_PATH"
    condition:
      file_pattern: "*.py"
    timeout: 5

  - type: after_tool_call
    tool: git_commit
    script:
      - python3 /path/to/notify_slack.py
    env:
      SLACK_WEBHOOK: "${SLACK_WEBHOOK}"

  - type: on_error
    script:
      - python3 /path/to/log_error.py
    continue_on_error: true
```

#### Hook 执行器

```python
class HookManager:
    async def execute(
        self,
        hook_type: HookType,
        context: HookContext
    ) -> HookResult:
        """执行匹配的 hooks"""
        # 1. 查找匹配的 hooks
        # 2. 准备环境变量
        # 3. 执行脚本 (with timeout)
        # 4. 处理结果
        # 5. 决定是否继续
```

---

## 5. 安全系统

### 5.1 安全架构

```
┌─────────────────────────────────────────────┐
│             Request Pipeline                │
├─────────────────────────────────────────────┤
│  1. Path Validation (Trusted Folders)        │
│  2. Permission Check (Policy Engine)         │
│  3. Sandbox Execution (Isolation)            │
│  4. Result Sanitization                      │
└─────────────────────────────────────────────┘
```

### 5.2 Trusted Folders

```python
@dataclass
class TrustedFolder:
    path: Path
    permissions: set[Permission]
    recursive: bool = True
    description: str = ""

class TrustedFolderManager:
    def __init__(self):
        self.folders: list[TrustedFolder] = []

    def add(self, folder: TrustedFolder):
        """添加信任目录"""

    def check_access(self, path: Path, permission: Permission) -> bool:
        """检查路径访问权限"""

    def get_allowed_paths(self) -> list[Path]:
        """获取所有允许的路径"""
```

#### Permission 类型

```python
class Permission(Enum):
    READ = "read"       # 读取文件
    WRITE = "write"     # 写入文件
    EXECUTE = "execute" # 执行命令
    NETWORK = "network" # 网络请求
    CREATE = "create"   # 创建文件/目录
    DELETE = "delete"   # 删除文件/目录
```

### 5.3 Policy Engine

```python
@dataclass
class Policy:
    name: str
    description: str
    rules: list[PolicyRule]
    enforcement: EnforcementMode = EnforcementMode.AUDIT

@dataclass
class PolicyRule:
    resource: str  # e.g., "file", "git", "network"
    action: str    # e.g., "read", "write", "push"
    conditions: dict[str, Any]
    effect: Effect = Effect.ALLOW

class PolicyEngine:
    def __init__(self):
        self.policies: list[Policy] = []
        self._load_default_policies()

    async def evaluate(
        self,
        action: str,
        resource: str,
        context: SecurityContext
    ) -> PolicyResult:
        """评估动作是否允许"""

    def load_policy(self, policy: Policy):
        """加载策略"""

    def remove_policy(self, name: str):
        """移除策略"""
```

#### 内置策略

| 策略名 | 描述 | 默认行为 |
|--------|------|---------|
| restricted-files | 禁止访问敏感文件 | 阻止 ~/.ssh, /etc/passwd 等 |
| git-safety | Git 操作安全限制 | 阻止 force push, 删除 branch |
| network-safety | 网络请求限制 | 仅允许配置的域名 |
| destructive-actions | 危险操作确认 | 删除/覆盖前要求确认 |

### 5.4 Sandbox (沙箱)

```python
class SandboxExecutor:
    """命令执行沙箱"""

    async def execute(
        self,
        command: str,
        timeout: int = 30,
        env: dict[str, str] = None
    ) -> ExecutionResult:
        """
        在隔离环境中执行命令
        - 限制文件系统访问
        - 限制网络访问
        - 限制资源使用 (CPU, memory, time)
        - 捕获所有输出
        """
        pass

    async def test_command(
        self,
        command: str,
        preview: bool = True
    ) -> CommandPreview:
        """
        预览命令执行效果 (不实际执行)
        """
        pass
```

#### 沙箱实现选项

1. **进程隔离** (默认): 使用 `ptrace` 或类似机制隔离
2. **容器模式**: 使用 Docker 容器执行危险命令
3. **Sysbox**: 轻量级容器，适合本地使用

### 5.5 安全上下文

```python
@dataclass
class SecurityContext:
    user_id: str
    session_id: str
    workspace_root: Path
    allowed_paths: list[Path]
    denied_paths: list[Path]
    current_permissions: set[Permission]
    tool_name: str
    tool_args: dict
    risk_level: RiskLevel = RiskLevel.UNKNOWN

class RiskLevel(Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"
```

---

## 6. 会话系统

### 6.1 Session 数据结构

```python
@dataclass
class Session:
    id: str
    created_at: datetime
    updated_at: datetime
    agent_type: AgentType
    messages: list[Message]
    checkpoints: list[Checkpoint]
    memory: SessionMemory
    context_files: list[Path]
    metadata: dict

@dataclass
class Message:
    id: str
    role: Literal["user", "assistant", "system", "tool"]
    content: str | list[ContentBlock]
    timestamp: datetime
    tool_calls: list[ToolCall] = None
    tool_results: list[ToolResult] = None

@dataclass
class Checkpoint:
    id: str
    created_at: datetime
    description: str
    snapshot: SessionSnapshot
    parent_id: str = None  # 用于 undo/redo
```

### 6.2 Checkpointing 系统

```python
class CheckpointManager:
    def __init__(self, storage_path: Path):
        self.storage_path = storage_path
        self.checkpoints: dict[str, list[Checkpoint]] = {}

    async def create(
        self,
        session_id: str,
        description: str
    ) -> Checkpoint:
        """创建检查点"""

    async def restore(
        self,
        checkpoint_id: str
    ) -> Session:
        """恢复到检查点"""

    async def list(
        self,
        session_id: str
    ) -> list[Checkpoint]:
        """列出会话的检查点"""

    async def delete(
        self,
        checkpoint_id: str
    ):
        """删除检查点"""
```

#### 自动 Checkpoint

- **时间触发**: 每 5 分钟自动创建
- **操作触发**: 重要操作前自动创建
- **命令触发**: `/checkpoint` 手动创建

### 6.3 Auto Memory

```python
class AutoMemory:
    """自动学习项目知识"""

    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.learnings: list[Learning] = []

    async def learn(
        self,
        observation: str,
        source: str,
        category: MemoryCategory
    ):
        """学习新知识"""
        # 从代码、对话、操作中提取知识

    async def recall(
        self,
        query: str,
        category: MemoryCategory = None
    ) -> list[Learning]:
        """回忆相关知识"""

    async def sync_to_context(
        self,
        session: Session
    ) -> str:
        """同步记忆到上下文"""

@dataclass
class Learning:
    id: str
    content: str
    source: str
    category: MemoryCategory
    confidence: float
    created_at: datetime

class MemoryCategory(Enum):
    BUILD_COMMAND = "build_command"
    TEST_COMMAND = "test_command"
    DEBUG_TIPS = "debug_tips"
    CODE_PATTERN = "code_pattern"
    PROJECT_STRUCTURE = "project_structure"
    PREFERENCES = "preferences"
```

#### 内存存储

```yaml
# ~/.opencli/projects/myproject/memory.json
{
  "project": "myproject",
  "learnings": [
    {
      "id": "uuid",
      "content": "Run tests with: pytest tests/ -v",
      "source": "conversation",
      "category": "test_command",
      "confidence": 0.9,
      "created_at": "2026-04-30T10:00:00Z"
    }
  ]
}
```

### 6.4 Session 持久化

```python
# 会话存储格式
~/.opencli/
├── sessions/
│   ├── {session_id}.json      # 会话数据
│   └── {session_id}.db        # 向量索引 (可选)
├── checkpoints/
│   └── {checkpoint_id}.json    # 检查点快照
├── memory/
│   └── {project}/memory.json   # 项目记忆
└── sessions.db                  # 会话索引数据库
```

---

## 7. TUI 设计

### 7.1 布局结构

```
┌────────────────────────────────────────────────────────────────┐
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Header Bar                             │  │
│  │  [open-cli] [workspace] [branch] [agent: plan]  [⚙️][?️] │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌────────────────────┐  ┌──────────────────────────────────┐  │
│  │                    │  │                                   │  │
│  │    File Explorer   │  │         Chat Panel                 │  │
│  │    (可折叠)         │  │                                   │  │
│  │                    │  │  ┌─────────────────────────────┐   │  │
│  │    📁 src/         │  │  │ User message               │   │  │
│  │    📁 tests/       │  │  └─────────────────────────────┘   │  │
│  │    📄 README.md    │  │  ┌─────────────────────────────┐   │  │
│  │                    │  │  │ Assistant response          │   │  │
│  │                    │  │  │ ...                         │   │  │
│  │                    │  │  └─────────────────────────────┘   │  │
│  │                    │  │                                   │  │
│  │                    │  └──────────────────────────────────┘  │
│  │                    │  ┌──────────────────────────────────┐  │
│  │                    │  │         Tools Output            │  │
│  │                    │  │  [read_file] result...          │  │
│  │                    │  └──────────────────────────────────┘  │
│  └────────────────────┘  ┌──────────────────────────────────┐  │
│  ┌────────────────────┐   │  ❯ User input here              │  │
│  │     Status Bar     │   └──────────────────────────────────┘  │
│  │ [●] Connected [Model: claude-3.5] [Tokens: 1024] [$$$]  │  │
│  └────────────────────┘  ┌──────────────────────────────────┐  │
│                         │  [Tab] Switch agent  [Ctrl+K] CMD  │  │
│                         └──────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

### 7.2 面板组件

#### ChatPanel

```python
class ChatPanel(Widget):
    """对话面板"""

    def compose(self) -> ComposeResult:
        yield ScrollableContainer(
            id="chat-messages"
        )
        yield Static("", id="typing-indicator")
        yield TextArea(
            id="input-area",
            placeholder="Type your message..."
        )

    async def on_key(self, event: Key) -> None:
        if event.key == "enter" and not event.shift:
            await self.send_message()
        elif event.key == "tab":
            await self.switch_agent()
```

#### FileExplorerPanel

```python
class FileExplorerPanel(Widget):
    """文件浏览器面板"""

    def __init__(self, root_path: Path):
        self.root_path = root_path
        self.selected_path: Path = None

    def refresh(self):
        """刷新文件列表"""

    def on_select(self, path: Path):
        """选择文件时触发"""
```

#### StatusBar

```python
class StatusBar(Widget):
    """状态栏"""

    def __init__(self):
        self.api_status: ConnectionStatus = ConnectionStatus.DISCONNECTED
        self.model: str = ""
        self.token_count: int = 0
        self.cost: float = 0.0

    def update_status(self, status: dict):
        """更新状态"""
```

### 7.3 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Tab` | 切换 Plan/Build 模式 |
| `Ctrl+C` | 中断生成 |
| `Ctrl+L` | 清除屏幕 |
| `Ctrl+K` | 命令面板 |
| `Ctrl+S` | 创建检查点 |
| `Ctrl+Z` | 撤销 |
| `Ctrl+R` | 重做 |
| `Ctrl+/` | 打开帮助 |
| `↑/↓` | 历史消息导航 |
| `Esc` | 取消选择 |

### 7.4 命令面板 (Ctrl+K)

```
┌─────────────────────────────────────┐
│  🔍 Search commands...             │
├─────────────────────────────────────┤
│  📁 File Operations                 │
│    /read <file>     Read a file     │
│    /write <file>   Write a file    │
│  🔧 Tools                           │
│    /git status     Git status      │
│    /grep <pattern> Search files    │
│  ⚙️ Settings                        │
│    /model <name>   Switch model     │
│    /agent <type>   Switch agent     │
│  🔌 Extensions                      │
│    /mcp list       List MCP servers│
│    /skill <name>   Use a skill     │
└─────────────────────────────────────┘
```

### 7.5 主题支持

```yaml
# ~/.opencli/themes/default.yaml
theme:
  name: default
  colors:
    primary: "#00D4AA"
    secondary: "#6366F1"
    accent: "#F59E0B"
    background: "#1E1E2E"
    surface: "#2A2A3E"
    text: "#E2E8F0"
    text_muted: "#94A3B8"
    error: "#EF4444"
    warning: "#F59E0B"
    success: "#10B981"
  font:
    family: "JetBrains Mono, Fira Code, monospace"
    size: 14
  layout:
    show_file_explorer: true
    show_status_bar: true
    panel_width: 300
```

---

## 8. Provider 系统

### 8.1 Provider 接口

```python
class BaseProvider(ABC):
    @abstractmethod
    async def chat(
        self,
        messages: list[Message],
        tools: list[Tool] = None,
        **kwargs
    ) -> AsyncIterator[Response]:
        """发送对话请求"""
        pass

    @abstractmethod
    async def list_models(self) -> list[ModelInfo]:
        """列出可用模型"""
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

### 8.2 LiteLLM Provider

```python
class LiteLLMProvider(BaseProvider):
    def __init__(self, config: ProviderConfig):
        self.config = config
        self.client = litellm

    async def chat(
        self,
        messages: list[Message],
        tools: list[Tool] = None,
        model: str = None,
        **kwargs
    ) -> AsyncIterator[Response]:
        response = await self.client.acompletion(
            model=model or self.config.default_model,
            messages=[m.to_litellm_format() for m in messages],
            tools=[t.to_litellm_format() for t in (tools or [])],
            streaming=True,
            **kwargs
        )
        async for chunk in response:
            yield self._parse_chunk(chunk)

    async def list_models(self) -> list[ModelInfo]:
        return await self.client.aget_models()
```

### 8.3 Provider 配置

```yaml
# ~/.opencli/config.yaml
providers:
  # LiteLLM 配置 (支持 100+ LLM)
  litellm:
    api_key: "${LITELLM_API_KEY}"
    fallback_models:
      - anthropic/claude-3-5-sonnet
      - openai/gpt-4o
      - google/gemini-pro
    cache:
      enabled: true
      type: "redis"  # 或 "disk"
      ttl: 3600

  # Anthropic (可选，直接使用)
  anthropic:
    api_key: "${ANTHROPIC_API_KEY}"
    base_url: "https://api.anthropic.com"

  # OpenAI (可选)
  openai:
    api_key: "${OPENAI_API_KEY}"
    organization: "${OPENAI_ORG}"

# 默认 Provider 路由
model_routing:
  default_provider: litellm
  rules:
    - if: task contains "reasoning"
      use: anthropic/claude-3-5-sonnet
    - if: task contains "fast"
      use: openai/gpt-4o-mini
    - if: project has "gpto"
      use: openai/gpt-4o
```

### 8.4 模型选择

```python
class ModelSelector:
    def __init__(self, config: RoutingConfig):
        self.config = config

    async def select(
        self,
        task: str,
        context: dict
    ) -> str:
        """根据任务选择最佳模型"""
        # 1. 检查规则
        # 2. 检查缓存
        # 3. 检查可用性
        # 4. 返回模型 ID
```

---

## 9. 配置系统

### 9.1 配置 Schema

```python
from pydantic import BaseModel
from typing import Optional

class OpenCLIConfig(BaseModel):
    # 全局设置
    version: str = "2.0.0"

    # Provider 配置
    providers: dict[str, ProviderConfig]

    # 默认模型路由
    model_routing: ModelRoutingConfig

    # MCP 配置
    mcp: MCPConfig

    # Security
    security: SecurityConfig

    # UI
    ui: UIConfig

    # Hooks
    hooks: list[HookConfig]

    # Skills
    skills: list[str]  # skill 路径列表

    # Commands
    commands: list[CommandConfig]

    # 会话
    sessions: SessionConfig

class ProviderConfig(BaseModel):
    type: Literal["litellm", "anthropic", "openai", "custom"]
    api_key: str
    base_url: Optional[str] = None
    models: list[str] = []
    default_model: Optional[str] = None

class SecurityConfig(BaseModel):
    trusted_folders: list[TrustedFolderConfig] = []
    policies: list[str] = []  # 策略名称列表
    sandbox_enabled: bool = True
    sandbox_level: Literal["process", "container", "sysbox"] = "process"

class UIConfig(BaseModel):
    theme: str = "default"
    show_file_explorer: bool = True
    show_status_bar: bool = True
    font_size: int = 14
    font_family: str = "monospace"
```

### 9.2 配置文件位置

```
~/.opencli/
├── config.yaml           # 主配置
├── config.local.yaml     # 本地覆盖 (不提交)
├── themes/
│   └── *.yaml           # 主题定义
├── commands.yaml        # 自定义命令
├── hooks.yaml           # Hook 配置
├── skills/              # Skills 目录
│   └── {skill}/
│       └── SKILL.md
├── sessions/            # 会话存储
│   └── *.json
├── memory/              # 记忆存储
│   └── {project}/
│       └── memory.json
└── logs/                # 日志
    └── opencli.log
```

---

## 10. Server API

### 10.1 API 端点

```yaml
# WebSocket Server
/api/v1:
  ws /ws:
    - Connect to server
    - Authenticate
    - Send/receive messages

  # REST API (可选)
  GET /health:
    - Server health check

  GET /session/{id}:
    - Get session info

  POST /session:
    - Create new session

  GET /session/{id}/messages:
    - Get session messages

  POST /session/{id}/checkpoint:
    - Create checkpoint

  POST /session/{id}/restore/{checkpoint_id}:
    - Restore from checkpoint

  GET /config:
    - Get server config (filtered)

  PUT /config:
    - Update server config
```

### 10.2 认证

```python
# Token-based auth
class AuthManager:
    def __init__(self):
        self.tokens: dict[str, TokenInfo] = {}

    async def authenticate(
        self,
        token: str
    ) -> Optional[UserInfo]:
        """验证 token"""

    async def create_token(
        self,
        user_id: str,
        scopes: list[str]
    ) -> str:
        """创建 token"""

# Scopes
# - session:read
# - session:write
# - session:execute
# - admin
```

### 10.3 IPC 协议

```python
# STDIO 协议用于扩展客户端
class StdioProtocol:
    async def read_message(self) -> Message:
        """从 STDIN 读取消息"""

    async def write_message(self, message: Message):
        """写入消息到 STDOUT"""

    async def read_event(self) -> Event:
        """读取服务器事件"""
```

---

## 11. 工具系统

### 11.1 工具注册表

```python
class ToolRegistry:
    def __init__(self):
        self._tools: dict[str, ToolDef] = {}
        self._mcp_tools: dict[str, MCPToolDef] = {}

    def register(self, tool: ToolDef):
        """注册内置工具"""

    def register_mcp(self, tool: MCPToolDef):
        """注册 MCP 工具"""

    def get(self, name: str) -> Optional[ToolDef]:
        """获取工具定义"""

    def list_all(self) -> list[ToolDef]:
        """列出所有工具"""

    def get_by_category(
        self,
        category: ToolCategory
    ) -> list[ToolDef]:
        """按类别获取工具"""
```

### 11.2 内置工具

| 工具 | 描述 | Category |
|------|------|----------|
| read_file | 读取文件 | file |
| write_file | 写入文件 | file |
| edit_file | 编辑文件 (diff) | file |
| create_directory | 创建目录 | file |
| delete_file | 删除文件 | file |
| list_directory | 列出目录 | file |
| grep_search | 搜索文件内容 | search |
| git_status | Git 状态 | git |
| git_log | Git 日志 | git |
| git_diff | Git diff | git |
| git_commit | Git 提交 | git |
| git_branch | Git 分支 | git |
| git_push | Git 推送 | git |
| git_pull | Git 拉取 | git |
| run_command | 执行命令 | system |
| search_web | 网络搜索 | web |
| fetch_url | 获取 URL 内容 | web |

### 11.3 工具执行流程

```python
class ToolExecutor:
    def __init__(
        self,
        security: SecurityBoundary,
        sandbox: SandboxExecutor,
        hooks: HookManager
    ):
        self.security = security
        self.sandbox = sandbox
        self.hooks = hooks

    async def execute(
        self,
        tool_name: str,
        arguments: dict,
        context: ExecutionContext
    ) -> ToolResult:
        # 1. 获取工具定义
        tool = self.registry.get(tool_name)

        # 2. 安全检查
        await self.security.check(tool, arguments)

        # 3. 执行 before_hook
        await self.hooks.execute(
            HookType.BEFORE_TOOL_CALL,
            context
        )

        # 4. 执行工具
        result = await self._do_execute(tool, arguments)

        # 5. 执行 after_hook
        await self.hooks.execute(
            HookType.AFTER_TOOL_CALL,
            context
        )

        # 6. 返回结果
        return result
```

---

## 12. 数据流

### 12.1 完整请求流程

```
User Input
    │
    ▼
┌─────────────────────────────────────────┐
│            TUI Client                    │
│  1. 解析用户输入                          │
│  2. 检测命令 (/command, @skill, etc)     │
│  3. 构建请求消息                          │
│  4. 通过 WebSocket/STDIO 发送            │
└──────────────────┬──────────────────────┘
                   │ WebSocket Message
                   ▼
┌─────────────────────────────────────────┐
│           Server Engine                  │
│  1. 解析消息                             │
│  2. 加载/验证会话                         │
│  3. 路由到正确的 Agent                    │
│  4. 检查并加载 Skills/Commands           │
└──────────────────┬──────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────┐
│         Agent Orchestrator              │
│  1. 构建 system prompt                  │
│  2. 注入 project context (AGENTS.md)     │
│  3. 注入 auto memory                    │
│  4. 加载可用 tools                      │
│  5. 调用 LLM                            │
└──────────────────┬──────────────────────┘
                   │
         ┌─────────┴─────────┐
         ▼                   ▼
┌─────────────────┐  ┌─────────────────┐
│   LLM Response   │  │    Tool Call    │
│   (Text/思考)    │  │   (需要执行)     │
└────────┬────────┘  └────────┬────────┘
         │                   │
         ▼                   ▼
┌─────────────────┐  ┌─────────────────┐
│   渲染到 TUI     │  │  Tool Executor  │
│   (流式输出)     │  │  1. 安全检查    │
└─────────────────┘  │  2. 执行工具    │
                      │  3. 返回结果    │
                      └────────┬────────┘
                               │
                               ▼
                      ┌─────────────────┐
                      │  循环: 再次调用  │
                      │  LLM (结果注入)  │
                      └────────┬────────┘
                               │
                               ▼
                      ┌─────────────────┐
                      │   完成响应       │
                      │  保存到会话      │
                      │  更新 checkpoint │
                      └─────────────────┘
```

### 12.2 并行 Subagent 流程

```
User: "分析所有微服务的代码"

┌─────────────────────────────────────────┐
│         Main Agent                       │
│  分析任务，拆分为子任务                    │
│  - user-service: 代码审查                │
│  - order-service: 代码审查                │
│  - payment-service: 代码审查              │
└──────────┬──────────────────────────────┘
           │ spawn subagents
           ▼
┌─────────────────────────────────────────┐
│      Subagent Pool (并行)               │
│  ┌─────────────┐ ┌─────────────┐        │
│  │ Subagent 1  │ │ Subagent 2  │  ...   │
│  │ user-svc    │ │ order-svc   │        │
│  └──────┬──────┘ └──────┬──────┘        │
└─────────┼───────────────┼───────────────┘
          │               │
          ▼               ▼
┌─────────────────┐ ┌─────────────────┐
│ Result 1        │ │ Result 2        │
│ user-svc review │ │ order-svc review│
└────────┬────────┘ └────────┬────────┘
         └───────────┬────────┘
                     ▼
          ┌─────────────────────┐
          │   Main Agent        │
          │   合并结果           │
          │   生成总结报告       │
          └─────────────────────┘
```

---

## 13. 错误处理

### 13.1 错误类型

```python
class ErrorCode(Enum):
    # 连接错误
    CONNECTION_FAILED = "connection_failed"
    AUTH_FAILED = "auth_failed"
    TIMEOUT = "timeout"

    # LLM 错误
    LLM_ERROR = "llm_error"
    MODEL_UNAVAILABLE = "model_unavailable"
    RATE_LIMITED = "rate_limited"
    CONTEXT_LENGTH = "context_length"

    # 安全错误
    SECURITY_VIOLATION = "security_violation"
    PATH_BLOCKED = "path_blocked"
    PERMISSION_DENIED = "permission_denied"

    # 执行错误
    TOOL_NOT_FOUND = "tool_not_found"
    TOOL_EXECUTION_FAILED = "tool_execution_failed"
    SANDBOX_ERROR = "sandbox_error"

    # 会话错误
    SESSION_NOT_FOUND = "session_not_found"
    SESSION_CORRUPTED = "session_corrupted"
    CHECKPOINT_FAILED = "checkpoint_failed"

    # MCP 错误
    MCP_CONNECTION_FAILED = "mcp_connection_failed"
    MCP_PROTOCOL_ERROR = "mcp_protocol_error"
```

### 13.2 错误响应格式

```python
@dataclass
class ErrorResponse:
    code: ErrorCode
    message: str
    details: dict = field(default_factory=dict)
    recoverable: bool = True
    retry_after: int = None  # seconds

    def to_user_message(self) -> str:
        """转换为用户友好消息"""
```

### 13.3 重试策略

```python
class RetryPolicy:
    def __init__(self):
        self.max_retries = 3
        self.base_delay = 1.0
        self.max_delay = 30.0
        self.exponential_base = 2

    async def execute_with_retry(
        self,
        operation: Callable,
        error_types: list[type] = None
    ) -> Any:
        """带重试的执行"""
```

---

## 14. 测试策略

### 14.1 测试分层

```
tests/
├── unit/                    # 单元测试
│   ├── test_tools.py
│   ├── test_security.py
│   ├── test_session.py
│   └── ...
├── integration/             # 集成测试
│   ├── test_mcp_client.py
│   ├── test_provider_litellm.py
│   └── test_hooks.py
├── e2e/                     # 端到端测试
│   ├── test_full_session.py
│   └── test_agent_collaboration.py
└── benchmarks/              # 性能测试
    ├── test_llm_latency.py
    └── test_tool_execution.py
```

### 14.2 测试夹具

```python
@pytest.fixture
async def server():
    """启动测试服务器"""
    async with create_test_server() as server:
        yield server

@pytest.fixture
async def client(server):
    """创建测试客户端"""
    async with create_test_client(server) as client:
        yield client

@pytest.fixture
def mock_llm():
    """Mock LLM 响应"""
    return MockLLMResponse(...)

@pytest.fixture
def sandbox():
    """测试沙箱"""
    with create_test_sandbox() as sandbox:
        yield sandbox
```

---

## 15. 实施优先级

### Phase 1: 核心架构 (MVP)

1. ✅ 项目脚手架重构
2. ✅ Provider 抽象层 (LiteLLM)
3. ✅ Agent 系统 (Plan/Build)
4. ✅ 基础工具注册表
5. ✅ 安全边界

### Phase 2: 扩展系统

6. MCP Client 实现
7. Skills 系统
8. Commands 系统
9. Hooks 系统

### Phase 3: 会话增强

10. Checkpointing 系统
11. Auto Memory
12. Session 持久化

### Phase 4: TUI

13. Rich TUI 实现
14. 面板组件
15. 主题支持

### Phase 5: 高级特性

16. Subagent 系统
17. Client/Server IPC
18. 策略引擎
19. 沙箱隔离

---

## 16. 依赖

```toml
[project]
requires-python = ">=3.11"
dependencies = [
    # Core
    "httpx>=0.27.0",
    "pydantic>=2.0",
    "anyio>=4.0",

    # LLM
    "litellm>=1.0",

    # TUI
    "textual>=0.80",
    "rich>=13.0",

    # MCP
    "mcp>=1.0",

    # Storage
    "sqlalchemy>=2.0",
    "aiosqlite>=0.19",

    # Security
    "PyYAML>=6.0",

    # Utils
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

---

## 17. 附录

### 17.1 术语表

| 术语 | 定义 |
|------|------|
| Agent | AI 执行单元，处理特定类型任务 |
| Skill | 封装的专业工作流 |
| Command | 用户自定义快捷命令 |
| Hook | 生命周期事件钩子 |
| Checkpoint | 会话状态快照 |
| Provider | LLM 服务提供商抽象 |
| Sandbox | 隔离执行环境 |
| Trusted Folder | 授权访问的目录 |

### 17.2 参考资料

- [Claude Code Documentation](https://code.claude.com/docs/en/overview)
- [OpenCode Documentation](https://opencode.ai/docs)
- [Gemini CLI Documentation](https://geminicli.com/docs/)
- [MCP Protocol Specification](https://modelcontextprotocol.io)
- [LiteLLM Documentation](https://docs.litellm.ai)
- [Textual Documentation](https://textual.textualize.io)

### 17.3 设计决策记录

| ID | 决策 | 理由 | 日期 |
|----|------|------|------|
| ADR-001 | 使用 LiteLLM 作为 Provider | 支持 100+ LLM，减少维护成本 | 2026-04-30 |
| ADR-002 | 使用 Textual 构建 TUI | 功能强大，支持复杂布局 | 2026-04-30 |
| ADR-003 | JSON-RPC 2.0 作为 IPC 协议 | 简单、通用、跨语言 | 2026-04-30 |
| ADR-004 | 分阶段实施 | 降低风险，保证质量 | 2026-04-30 |
