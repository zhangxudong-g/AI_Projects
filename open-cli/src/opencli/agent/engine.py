import asyncio
from dataclasses import dataclass
from typing import AsyncIterator, Optional
from ..providers.base import BaseProvider
from ..types.messages import Session, Message, AgentMessage, MessageType
from .executor import ToolExecutor

@dataclass
class AgentConfig:
    provider: BaseProvider
    max_retries: int = 3

class AgentEngine:
    def __init__(self, config: AgentConfig):
        self.config = config
        self.provider = config.provider
        self.executor = None

    async def run(self, task: str, session: Session) -> AsyncIterator[AgentMessage]:
        yield AgentMessage(type=MessageType.THINKING, content=f"Parsing task: {task}")

        plan = await self._generate_plan(task, session)
        yield AgentMessage(type=MessageType.PLAN, content=plan)

        from ..tools.registry import ToolRegistry
        self.executor = ToolExecutor(ToolRegistry())

        for step in self._parse_plan(plan):
            yield AgentMessage(
                type=MessageType.TOOL_CALL,
                content=f"Executing {step['tool']}",
                tool_name=step["tool"],
                tool_args=step["args"]
            )

            result = await self.executor.execute(step["tool"], step["args"])
            yield AgentMessage(
                type=MessageType.TOOL_RESULT,
                content=result.content if result.success else result.error,
                tool_name=step["tool"],
                success=result.success
            )

        yield AgentMessage(type=MessageType.DONE, content="Task completed")

    async def _generate_plan(self, task: str, session: Session) -> str:
        prompt = f"Task: {task}\nBreak down into tool calls. Available tools: file_read, file_write, cmd_execute, git_command"
        messages = [Message(id="0", role="user", content=prompt)]

        plan_parts = []
        async for chunk in self.provider.chat(messages):
            plan_parts.append(chunk)
        return "".join(plan_parts)

    def _parse_plan(self, plan: str) -> list[dict]:
        steps = []
        lines = plan.split("\n")
        for line in lines:
            line = line.strip()
            if line.startswith("- [ ]") or line.startswith("1.") or line.startswith("-"):
                content = line.lstrip("0123456789.- []")
                if ":" in content:
                    tool, args_str = content.split(":", 1)
                    steps.append({"tool": tool.strip(), "args": {}})
                elif " " in content:
                    parts = content.split(" ", 1)
                    steps.append({"tool": parts[0], "args": {"path": parts[1] if len(parts) > 1 else ""}})
        return steps if steps else [{"tool": "cmd_execute", "args": {"cmd": plan}}]
