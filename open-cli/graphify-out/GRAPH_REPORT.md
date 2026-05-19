# Graph Report - D:\AI_Projects\open-cli  (2026-05-12)

## Corpus Check
- Corpus is ~23,918 words - fits in a single context window. You may not need a graph.

## Summary
- 725 nodes · 1180 edges · 79 communities (44 shown, 35 thin omitted)
- Extraction: 64% EXTRACTED · 36% INFERRED · 0% AMBIGUOUS · INFERRED: 420 edges (avg confidence: 0.66)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Tool Execution & Testing|Tool Execution & Testing]]
- [[_COMMUNITY_Agent Engine & Executor|Agent Engine & Executor]]
- [[_COMMUNITY_LLM Providers|LLM Providers]]
- [[_COMMUNITY_Security & Policy|Security & Policy]]
- [[_COMMUNITY_Session & Memory|Session & Memory]]
- [[_COMMUNITY_Architecture Design|Architecture Design]]
- [[_COMMUNITY_Commands Extension|Commands Extension]]
- [[_COMMUNITY_Hooks Extension|Hooks Extension]]
- [[_COMMUNITY_Skills Extension|Skills Extension]]
- [[_COMMUNITY_MCP Client & Protocol|MCP Client & Protocol]]
- [[_COMMUNITY_Config Schema|Config Schema]]
- [[_COMMUNITY_Server & Orchestrator|Server & Orchestrator]]
- [[_COMMUNITY_CLI Entry Point|CLI Entry Point]]
- [[_COMMUNITY_TUI Components|TUI Components]]
- [[_COMMUNITY_File & Git Tools|File & Git Tools]]
- [[_COMMUNITY_Checkpoint Manager|Checkpoint Manager]]
- [[_COMMUNITY_Markdown Renderer|Markdown Renderer]]
- [[_COMMUNITY_Hook Manager|Hook Manager]]
- [[_COMMUNITY_Provider Chat|Provider Chat]]
- [[_COMMUNITY_Security Boundary|Security Boundary]]
- [[_COMMUNITY_Path Checking|Path Checking]]
- [[_COMMUNITY_Context & Undo|Context & Undo]]
- [[_COMMUNITY_Policy Engine|Policy Engine]]
- [[_COMMUNITY_Trusted Folders|Trusted Folders]]
- [[_COMMUNITY_Session Core|Session Core]]
- [[_COMMUNITY_Agent Rationale|Agent Rationale]]
- [[_COMMUNITY_Init Module|Init Module]]
- [[_COMMUNITY_Registry Pattern|Registry Pattern]]
- [[_COMMUNITY_Message Types|Message Types]]
- [[_COMMUNITY_Shutdown & Health|Shutdown & Health]]
- [[_COMMUNITY_Parser Commands|Parser Commands]]
- [[_COMMUNITY_Skill Loader|Skill Loader]]
- [[_COMMUNITY_Model Selector|Model Selector]]
- [[_COMMUNITY_Theme Support|Theme Support]]
- [[_COMMUNITY_TUI Design|TUI Design]]
- [[_COMMUNITY_Agent Server|Agent Server]]
- [[_COMMUNITY_Implementation Plans|Implementation Plans]]
- [[_COMMUNITY_LLM Core|LLM Core]]
- [[_COMMUNITY_Commands Test|Commands Test]]
- [[_COMMUNITY_Hooks Test|Hooks Test]]
- [[_COMMUNITY_Skills Test|Skills Test]]
- [[_COMMUNITY_MCP Test|MCP Test]]
- [[_COMMUNITY_Permission Read|Permission Read]]
- [[_COMMUNITY_Registry List|Registry List]]
- [[_COMMUNITY_Skill Get|Skill Get]]
- [[_COMMUNITY_Skill List|Skill List]]
- [[_COMMUNITY_Security Level|Security Level]]
- [[_COMMUNITY_Security Context|Security Context]]
- [[_COMMUNITY_Effect Allow|Effect Allow]]
- [[_COMMUNITY_Effect Deny|Effect Deny]]
- [[_COMMUNITY_Path Normalize|Path Normalize]]
- [[_COMMUNITY_Is Trusted|Is Trusted]]
- [[_COMMUNITY_Checkpoint|Checkpoint]]
- [[_COMMUNITY_REPL|REPL]]
- [[_COMMUNITY_Command Entity|Command Entity]]
- [[_COMMUNITY_Security Policy|Security Policy]]
- [[_COMMUNITY_Tool Executor Test|Tool Executor Test]]
- [[_COMMUNITY_Markdown Renderer Test|Markdown Renderer Test]]
- [[_COMMUNITY_Message|Message]]
- [[_COMMUNITY_Tests|Tests]]
- [[_COMMUNITY_Tool Framework|Tool Framework]]
- [[_COMMUNITY_Server Health|Server Health]]
- [[_COMMUNITY_Agent Core|Agent Core]]
- [[_COMMUNITY_Agent Type|Agent Type]]
- [[_COMMUNITY_Content Block|Content Block]]
- [[_COMMUNITY_Tool Call|Tool Call]]
- [[_COMMUNITY_Provider Base|Provider Base]]
- [[_COMMUNITY_AutoMemory|AutoMemory]]
- [[_COMMUNITY_CheckpointManager|CheckpointManager]]
- [[_COMMUNITY_Learning|Learning]]
- [[_COMMUNITY_MemoryCategory|MemoryCategory]]

## God Nodes (most connected - your core abstractions)
1. `ToolRegistry` - 43 edges
2. `GitTool` - 30 edges
3. `cli.py` - 29 edges
4. `ToolResult` - 25 edges
5. `CmdTool` - 25 edges
6. `FileTool` - 25 edges
7. `AgentOrchestrator` - 23 edges
8. `SessionManager` - 23 edges
9. `ToolDefinition` - 23 edges
10. `Session` - 22 edges

## Surprising Connections (you probably didn't know these)
- `Session Management` --conceptually_related_to--> `Session`  [INFERRED]
  README.md → tests/test_integration_cli.py
- `MockProvider` --uses--> `ToolExecutor`  [INFERRED]
  tests/test_integration_cli.py → src/opencli/agent/executor.py
- `MockFileWriteTool` --uses--> `ToolExecutor`  [INFERRED]
  tests/test_integration_cli.py → src/opencli/agent/executor.py
- `test_end_to_end_task()` --calls--> `ToolExecutor`  [INFERRED]
  tests/test_integration_cli.py → src/opencli/agent/executor.py
- `test_execute_no_matching_hooks()` --calls--> `HookManager`  [INFERRED]
  tests/extensions/test_hooks.py → src/opencli/extensions/hooks/manager.py

## Communities (79 total, 35 thin omitted)

### Community 0 - "Tool Execution & Testing"
Cohesion: 0.05
Nodes (48): ToolExecutor, MockTool, test_executor_executes_tool(), test_executor_unknown_tool(), BaseTool, test_normalize_path_prevents_traversal(), test_path_outside_workspace_rejected(), test_path_within_workspace_allowed() (+40 more)

### Community 1 - "Agent Engine & Executor"
Cohesion: 0.06
Nodes (40): ABC, Agent, AgentConfig, AgentEngine, test_engine_run_returns_stream(), test_create_session(), test_list_sessions(), test_save_and_load_session() (+32 more)

### Community 2 - "LLM Providers"
Cohesion: 0.06
Nodes (15): TestPolicyEngine, TestTrustedFolderManager, Enum, SecurityContext, SecurityLevel, Effect, PolicyEngine, PolicyRule (+7 more)

### Community 3 - "Security & Policy"
Cohesion: 0.08
Nodes (16): BaseProvider, ContentBlock, LiteLLMProvider, LiteLLMProvider._format_blocks, LiteLLMProvider._format_msg, Message, MiniMaxProvider, MiniMaxProvider._format_blocks (+8 more)

### Community 4 - "Session & Memory"
Cohesion: 0.09
Nodes (33): open-cli Design Specification, open-cli V2 详细设计文档, Open-CLI TUI Design, AgentEngine, Agent Orchestrator, AutoMemory, Build Agent, CheckpointManager (+25 more)

### Community 5 - "Architecture Design"
Cohesion: 0.11
Nodes (6): TestSkill, TestSkillLoader, TestSkillRegistry, SkillLoader, SkillRegistry, Skill

### Community 6 - "Commands Extension"
Cohesion: 0.11
Nodes (6): CommandParser, CommandRegistry, CustomCommand, TestCommandParser, TestCommandRegistry, TestCustomCommand

### Community 7 - "Hooks Extension"
Cohesion: 0.13
Nodes (8): test_execute_hook_script_not_found(), test_execute_no_matching_hooks(), TestHook, TestHookManager, TestHookType, HookManager, Hook, HookType

### Community 8 - "Skills Extension"
Cohesion: 0.08
Nodes (25): AgentConfig, AgentEngine, AgentMessage, AgentType, AutoMemory, BaseTool, Checkpoint, CheckpointManager (+17 more)

### Community 9 - "MCP Client & Protocol"
Cohesion: 0.09
Nodes (23): AgentConfig, AgentEngine, GracefulShutdown, LiteLLMProvider, MiniMaxProvider, Session, create_provider, AgentEngine (+15 more)

### Community 10 - "Config Schema"
Cohesion: 0.15
Nodes (5): test_execute_with_mock_session(), test_execute_without_session(), TestMCPTool, MCPClient, MCPTool

### Community 11 - "Server & Orchestrator"
Cohesion: 0.19
Nodes (8): Checkpoint, CheckpointManager, generate_id(), test_checkpoint_manager_init(), test_create_checkpoint(), test_list_checkpoints(), test_restore_checkpoint(), test_save_and_load_checkpoint()

### Community 12 - "CLI Entry Point"
Cohesion: 0.16
Nodes (18): Colored Output, git_commit Tool, git_status Tool, Interactive REPL, Keyboard Shortcuts, list_directory Tool, Non-Interactive Mode, open-cli (+10 more)

### Community 13 - "TUI Components"
Cohesion: 0.15
Nodes (16): ChatPanel, cli.py, Client TUI, Confirmation Mode, Pager Module, Security Boundary Module, core/security.py - Security boundary, Status Bar Module (+8 more)

### Community 14 - "File & Git Tools"
Cohesion: 0.19
Nodes (14): BaseTool, CmdTool, FileTool, GitTool, ToolDefinition, ToolRegistry, ToolResult, GitTool._git_commit (+6 more)

### Community 15 - "Checkpoint Manager"
Cohesion: 0.16
Nodes (14): BaseTool from tools.base, ToolDefinition from tools.base, ToolResult from tools.base, MCPClient, MCPTool usage in client, connect method, disconnect method, execute_tool method (+6 more)

### Community 16 - "Markdown Renderer"
Cohesion: 0.17
Nodes (12): open-cli UI 2.0 设计方案, Command Palette Module, core/pager.py, core/renderer.py, Interactive Selector Module, core/selector.py, InteractiveSelector, Layout Manager Module (+4 more)

### Community 18 - "Hook Manager"
Cohesion: 0.33
Nodes (7): BaseModel, load_config(), OpenCLIConfig, ProviderConfig, SecurityConfig, TrustedFolderConfig, UIConfig

### Community 19 - "Provider Chat"
Cohesion: 0.2
Nodes (6): LLM Module (LiteLLM/MiniMax), LiteLLM Library, MiniMax Model, Prompt Builder (Rich Prompt), REPL Architecture, Basic REPL Loop

### Community 20 - "Security Boundary"
Cohesion: 0.22
Nodes (9): Agent (Abstract Base Class), AgentConfig Dataclass, CheckpointManager Class, Engine Class, AutoMemory Class, Learning Dataclass, MemoryCategory Enum, AgentOrchestrator Class (+1 more)

### Community 21 - "Path Checking"
Cohesion: 0.31
Nodes (9): Hooks Public API, HookManager Class, HookManager._execute_hook Method, HookManager.execute Method, HookManager.get_hooks Method, HookManager.register Method, HookManager.unregister Method, Hook Dataclass (+1 more)

### Community 22 - "Context & Undo"
Cohesion: 0.25
Nodes (9): Config Profiles, Plugin System Module, open-cli Implementation Plan, open-cli TUI Implementation Plan, open-cli UI 2.0 Implementation Plan, open-cli v2 Implementation Plan, Session Persistence, Tool Abstraction Layer (+1 more)

### Community 23 - "Policy Engine"
Cohesion: 0.29
Nodes (3): Markdown Renderer Module, Markdown Rendering, Tests for MarkdownRenderer

### Community 24 - "Trusted Folders"
Cohesion: 0.33
Nodes (7): AgentMessage, AgentType, ContentBlock, Message, MessageType, Session, ToolCall

### Community 25 - "Session Core"
Cohesion: 0.33
Nodes (7): Skill, Skill.from_directory, SkillLoader, SkillLoader.load_from_directory, SkillLoader.load_skill, SkillRegistry, SkillRegistry.register

### Community 26 - "Agent Rationale"
Cohesion: 0.33
Nodes (6): load_config function, OpenCLIConfig, ProviderConfig, SecurityConfig, TrustedFolderConfig, UIConfig

### Community 27 - "Init Module"
Cohesion: 0.33
Nodes (6): Hook, HookManager, HookType, TestHook, TestHookManager, TestHookType

### Community 28 - "Registry Pattern"
Cohesion: 0.4
Nodes (6): Skill, SkillLoader, SkillRegistry, TestSkill, TestSkillLoader, TestSkillRegistry

### Community 29 - "Message Types"
Cohesion: 0.33
Nodes (6): CommandParser, CommandRegistry, CustomCommand, TestCommandParser, TestCommandRegistry, TestCustomCommand

### Community 31 - "Parser Commands"
Cohesion: 1.0
Nodes (4): CommandParser, CommandRegistry, CustomCommand, commands Extension Module

### Community 32 - "Skill Loader"
Cohesion: 0.5
Nodes (4): config.py - Configuration management, Configuration Management, ~/.opencli/config.yaml, pyyaml (>=6.0)

### Community 33 - "Model Selector"
Cohesion: 0.5
Nodes (4): MCPTool, TestMCPTool, ToolDefinition, ToolResult

### Community 34 - "Theme Support"
Cohesion: 0.67
Nodes (4): PolicyEngine, SecurityBoundary, TrustedFolder, TrustedFolderManager

### Community 36 - "TUI Design"
Cohesion: 0.67
Nodes (3): anthropic (>=0.25.0), core/llm.py - LLM client with streaming, Streaming Output

### Community 37 - "Agent Server"
Cohesion: 0.67
Nodes (3): Context Management Module, Session Management Module, Undo/Redo Module

### Community 38 - "Implementation Plans"
Cohesion: 0.67
Nodes (3): SecurityBoundary.is_path_allowed, SecurityContext.is_path_allowed, TrustedFolderManager._is_under

## Knowledge Gaps
- **149 isolated node(s):** `Main entry point for open-cli.`, `open-cli - AI Coding Agent`, `Execute agent and yield response chunks`, `ToolCall`, `Tests for MarkdownRenderer` (+144 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **35 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `cli.py` connect `TUI Components` to `Tool Execution & Testing`, `Skill Loader`, `Session & Memory`, `Agent Server`, `TUI Design`, `Skills Extension`, `CLI Entry Point`, `Markdown Renderer`, `Provider Chat`, `Policy Engine`?**
  _High betweenness centrality (0.171) - this node is a cross-community bridge._
- **Why does `FileTool` connect `Tool Execution & Testing` to `Provider Format`?**
  _High betweenness centrality (0.076) - this node is a cross-community bridge._
- **Why does `ToolRegistry` connect `Agent Engine & Executor` to `Tool Execution & Testing`, `Provider Format`?**
  _High betweenness centrality (0.072) - this node is a cross-community bridge._
- **Are the 37 inferred relationships involving `ToolRegistry` (e.g. with `AgentConfig` and `AgentEngine`) actually correct?**
  _`ToolRegistry` has 37 INFERRED edges - model-reasoned connections that need verification._
- **Are the 21 inferred relationships involving `GitTool` (e.g. with `BaseTool` and `ToolDefinition`) actually correct?**
  _`GitTool` has 21 INFERRED edges - model-reasoned connections that need verification._
- **Are the 18 inferred relationships involving `ToolResult` (e.g. with `ToolExecutor` and `MCPTool`) actually correct?**
  _`ToolResult` has 18 INFERRED edges - model-reasoned connections that need verification._
- **Are the 19 inferred relationships involving `CmdTool` (e.g. with `BaseTool` and `ToolDefinition`) actually correct?**
  _`CmdTool` has 19 INFERRED edges - model-reasoned connections that need verification._