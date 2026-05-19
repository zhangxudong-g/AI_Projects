# Open-CLI TUI Design

## Overview

Open-CLI TUI 是一个基于任务模式的 AI 编程助手，用户输入任务描述，AI 自动解析、规划并执行工具完成操作。

## Architecture

### 方案 1: Simple Agent Loop（已选定）

```
User Input (STDIN) → Agent Loop → Tools → Stream Output (STDOUT)
```

通过 JSON-RPC over STDIO 进行通信。

### 核心组件

| 组件 | 职责 |
|------|------|
| `cli.py` | STDIO 入口，解析输入，JSON-RPC 封装 |
| `agent/engine.py` | Agent 主循环，LLM 调用，计划生成 |
| `agent/executor.py` | 工具执行器 |
| `tools/registry.py` | 工具注册表 |
| `types/messages.py` | 消息类型定义 |

## Data Flow

1. 用户通过命令行输入任务：`opencli "implement login feature"`
2. `AgentEngine` 接收任务，调用 LLM 生成执行计划
3. `ToolExecutor` 执行具体工具操作（file/cmd/git）
4. 实时流式输出到 STDOUT
5. 用户可随时 Ctrl+C 中断

## Protocol

### JSON-RPC Commands

**Input (STDIN):**
```json
{"jsonrpc": "2.0", "method": "execute", "params": {"task": "implement login"}}
```

**Output (STDOUT) - Streaming:**
```json
{"type": "thinking", "content": "Analyzing task..."}
{"type": "plan", "content": "1. Create login.py\n2. Add route\n3. Write tests"}
{"type": "tool_call", "tool": "file_write", "args": {"path": "login.py"}}
{"type": "tool_result", "tool": "file_write", "success": true}
{"type": "done", "summary": "Login feature implemented"}
```

### Message Types

| Type | Description |
|------|-------------|
| `thinking` | AI 思考过程 |
| `plan` | 执行计划 |
| `tool_call` | 工具调用 |
| `tool_result` | 工具执行结果 |
| `error` | 错误信息 |
| `done` | 任务完成 |

## Agent Loop

```python
async def run(task: str, session: Session) -> AsyncIterator[Message]:
    # 1. Parse task
    yield Message(type="thinking", content=f"Parsing task: {task}")

    # 2. Generate plan via LLM
    plan = await llm.generate_plan(task)
    yield Message(type="plan", content=plan)

    # 3. Execute plan step by step
    for step in plan.steps:
        yield Message(type="tool_call", tool=step.tool, args=step.args)
        result = await executor.execute(step.tool, step.args)
        yield Message(type="tool_result", tool=step.tool, success=result.success)

    # 4. Done
    yield Message(type="done", summary="Task completed")
```

## Tool Execution

### Supported Tools

| Tool | Description |
|------|-------------|
| `file_read` | Read file content |
| `file_write` | Write file content |
| `file_edit` | Edit file (patch) |
| `cmd_execute` | Execute shell command |
| `git_command` | Run git command |

### Executor Interface

```python
class ToolExecutor:
    def __init__(self, registry: ToolRegistry):
        self.registry = registry

    async def execute(self, tool_name: str, args: dict) -> ToolResult:
        tool = self.registry.get(tool_name)
        if not tool:
            return ToolResult(success=False, error=f"Unknown tool: {tool_name}")
        return await tool.execute(**args)
```

## Interruption

用户可通过 Ctrl+C 发送 SIGINT 信号中断执行。

```python
import signal

def handle_interrupt(signum, frame):
    logger.info("Interrupted by user")
    # Cleanup and exit gracefully

signal.signal(signal.SIGINT, handle_interrupt)
```

## CLI Integration

### Entry Point

```python
# cli.py
import asyncio
import json
import signal

async def main():
    task = " ".join(sys.argv[1:])
    if not task:
        typer.echo("Usage: opencli <task description>")
        return

    engine = AgentEngine()
    signal.signal(signal.SIGINT, handle_interrupt)

    async for msg in engine.run(task):
        print(json.dumps(msg.model_dump()))

if __name__ == "__main__":
    asyncio.run(main())
```

### Commands

```bash
# Execute a task
opencli "implement user authentication"

# With verbose output
opencli --verbose "fix the login bug"
```

## Error Handling

| Error Type | Handling |
|------------|----------|
| LLM Error | Retry 3 times, then return error message |
| Tool Not Found | Return error, suggest available tools |
| Tool Execution Failed | Log error, continue with next step |
| User Interrupt | Clean shutdown, save checkpoint |

## Testing Strategy

1. Unit tests for each component
2. Integration tests for agent loop
3. E2E tests with mock LLM

## Future Enhancements

- Phase 9: WebSocket mode for remote connections
- Phase 10: Checkpoint/resume capability
- Persistent session memory
