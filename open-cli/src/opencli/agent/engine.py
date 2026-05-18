import asyncio
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import AsyncIterator, Optional
from ..providers.base import BaseProvider
from ..messages.messages import Session, Message, AgentMessage, MessageType
from .executor import ToolExecutor


@dataclass
class AgentConfig:
    provider: BaseProvider
    max_retries: int = 3
    workspace_root: Optional[Path] = None


class AgentEngine:
    def __init__(self, config: AgentConfig):
        self.config = config
        self.provider = config.provider
        self.executor = None
        self.workspace_root = config.workspace_root
        self.memory_loader = None

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
            from opencli.agents import AgentRunner, AgentType
            runner = AgentRunner()
            result = await runner.spawn(AgentType.EXPLORE, task[8:])
            yield AgentMessage(
                type=MessageType.SUBAGENT_RESULT,
                content=result.summary,
            )
            return

        if task.startswith("@plan "):
            from opencli.agents import AgentRunner, AgentType
            runner = AgentRunner()
            result = await runner.spawn(AgentType.PLAN, task[6:])
            yield AgentMessage(
                type=MessageType.SUBAGENT_RESULT,
                content=result.summary,
            )
            return

        if task.startswith("@build "):
            from opencli.agents import AgentRunner, AgentType
            runner = AgentRunner()
            result = await runner.spawn(AgentType.BUILD, task[7:])
            yield AgentMessage(
                type=MessageType.SUBAGENT_RESULT,
                content=result.summary,
            )
            return

        yield AgentMessage(type=MessageType.THINKING, content=f"Parsing task: {task}")

        # Initialize memory loader if workspace is available
        if self.workspace_root and not self.memory_loader:
            from opencli.memory import MemoryLoader
            self.memory_loader = MemoryLoader(project_path=self.workspace_root)

        # Build memory context and prepend to task
        if self.memory_loader:
            memory_context = self.memory_loader.build_context()
            if memory_context:
                task = f"{memory_context}\n\n## Your Task\n{task}"

        # Track corrections if user says "remember"
        if self.memory_loader and "remember" in task.lower():
            from opencli.memory import AutoMemory
            auto_memory = AutoMemory.from_loader(self.memory_loader)
            auto_memory.add_correction(task)
            auto_memory.flush()

        plan = await self._generate_plan(task, session)
        yield AgentMessage(type=MessageType.PLAN, content=plan)

        steps = self._parse_plan(plan)

        if steps:
            # Execute tool calls
            from ..tools import get_registry
            registry = get_registry()
            self.executor = ToolExecutor(registry)

            for step in steps:
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
        else:
            # No tools needed - treat plan as direct response
            if plan and plan.strip():
                yield AgentMessage(type=MessageType.DONE, content=plan)
            else:
                yield AgentMessage(type=MessageType.DONE, content="I didn't understand that. Could you rephrase?")

    async def _generate_plan(self, task: str, session: Session) -> str:
        """Generate a response using the LLM.

        This is a general-purpose AI assistant. Respond naturally to questions,
        and use tools only when file operations are needed.
        """
        prompt = f"""Task: {task}

You are a helpful AI coding assistant. Respond naturally to questions.
Only use tools (read_file, write_file, edit_file, list_directory, git_status, run_command)
when the user explicitly asks for file operations or shell commands.

If no tool is needed, just respond directly in plain text/markdown.

Examples:
- "hello" -> Just greet them naturally
- "how are you?" -> Just respond naturally
- "write a python sort function" -> Write the code directly
- "explain this code" -> Explain naturally
- "read README.md" -> Use read_file tool
- "list files in current directory" -> Use list_directory tool
- "show git status" -> Use git_status tool
"""
        messages = [Message(id="0", role="user", content=prompt)]

        plan_parts = []
        async for chunk in self.provider.chat(messages):
            plan_parts.append(chunk)
        return "".join(plan_parts)

    def _parse_plan(self, plan: str) -> list[dict]:
        """Parse tool calls from the LLM response.

        If the response contains explicit JSON tool calls, parse them.
        Otherwise, treat the entire response as a direct response.
        """
        if not plan or not plan.strip():
            return []

        # Check for explicit JSON tool call format: [{"tool": ...}]
        # This could be in code blocks or bare
        json_str = self._extract_json_from_text(plan)
        if json_str:
            json_steps = self._parse_json_steps(json_str)
            if json_steps:
                return json_steps

        # If no tool calls found, return empty list (will be treated as direct response)
        return []

    def _extract_json_from_text(self, text: str) -> Optional[str]:
        """Extract JSON array string from text (handles code blocks)."""
        # Try code blocks first: ```json ... ```
        code_block_match = re.search(r'```(?:json)?\s*(\[[\s\S]*?\])\s*```', text, re.MULTILINE)
        if code_block_match:
            return code_block_match.group(1)

        # Try bare JSON array
        json_match = re.search(r'(\[[\s\S]*\])', text, re.MULTILINE)
        if json_match:
            candidate = json_match.group(1)
            # Verify it looks like JSON array of objects
            if '{"tool"' in candidate or '"tool"' in candidate:
                return candidate

        return None

    def _parse_json_steps(self, json_str: str) -> list[dict]:
        """Parse JSON string into steps list."""
        try:
            data = json.loads(json_str)
            if isinstance(data, list):
                steps = []
                for item in data:
                    if isinstance(item, dict) and "tool" in item:
                        tool = item["tool"]
                        args = item.get("args", {})
                        if self._validate_tool_and_args(tool, args):
                            steps.append({"tool": tool, "args": args})
                return steps
        except json.JSONDecodeError:
            pass
        return []

    def _validate_tool_and_args(self, tool: str, args: dict) -> bool:
        """Validate that tool name is known and args are present."""
        valid_tools = {
            "read_file", "write_file", "edit_file", "list_directory",
            "git_status", "run_command"
        }
        if tool not in valid_tools:
            return False

        # Check required args
        if tool == "read_file" and "file_path" not in args:
            return False
        if tool == "write_file" and ("file_path" not in args or "content" not in args):
            return False
        if tool == "edit_file" and not all(k in args for k in ["file_path", "find", "replace"]):
            return False
        if tool == "list_directory":
            pass  # path is optional
        if tool == "git_status" and "command" not in args:
            return False
        if tool == "run_command" and "command" not in args:
            return False

        return True

    def _parse_direct_response(self, plan: str) -> Optional[dict]:
        """Parse direct response format: {"direct": true, "content": "..."}"""
        plan = plan.strip()

        # Try to parse the entire plan as JSON
        try:
            data = json.loads(plan)
            if isinstance(data, dict) and data.get("direct") and "content" in data:
                return {"__direct__": True, "content": data["content"]}
        except json.JSONDecodeError:
            pass

        # Try to find direct response in code blocks
        code_block_match = re.search(r'```(?:json)?\s*(\{[\s\S]*?"direct"[\s\S]*?\})\s*```', plan, re.MULTILINE)
        if code_block_match:
            try:
                data = json.loads(code_block_match.group(1))
                if isinstance(data, dict) and data.get("direct") and "content" in data:
                    return {"__direct__": True, "content": data["content"]}
            except json.JSONDecodeError:
                pass

        return None

    def _parse_line_format(self, plan: str) -> list[dict]:
        """Parse bullet/list format like - read_file: path"""
        steps = []
        lines = plan.split("\n")

        # Tool name aliases mapping
        tool_aliases = {
            "read": "read_file",
            "read_file": "read_file",
            "file_read": "read_file",
            "write": "write_file",
            "write_file": "write_file",
            "file_write": "write_file",
            "edit": "edit_file",
            "edit_file": "edit_file",
            "ls": "list_directory",
            "dir": "list_directory",
            "list": "list_directory",
            "list_directory": "list_directory",
            "git": "git_status",
            "git_status": "git_status",
            "run": "run_command",
            "run_command": "run_command",
            "cmd": "run_command",
            "exec": "run_command",
            "shell": "run_command",
        }

        for line in lines:
            line = line.strip()
            # Match: - read_file: path OR 1. read_file: path OR - [ ] read_file: path
            if re.match(r'^[\-\*]?\s*\[?\s*\d*\.?\s*\]?\s*(\w+):\s*(.+)$', line):
                match = re.match(r'^[\-\*]?\s*\[?\s*\d*\.?\s*\]?\s*(\w+):\s*(.+)$', line)
                tool_raw = match.group(1)
                args_str = match.group(2).strip()

                tool = tool_aliases.get(tool_raw.lower(), tool_raw.lower())
                if tool not in tool_aliases.values():
                    continue

                # Parse args based on tool
                if tool == "read_file":
                    steps.append({"tool": tool, "args": {"file_path": args_str}})
                elif tool == "write_file":
                    # Format: path::content
                    if "::" in args_str:
                        path, content = args_str.split("::", 1)
                        steps.append({"tool": tool, "args": {"file_path": path.strip(), "content": content.strip()}})
                    else:
                        steps.append({"tool": tool, "args": {"file_path": args_str, "content": ""}})
                elif tool == "edit_file":
                    # Format: path::find::replace
                    parts = args_str.split("::")
                    if len(parts) >= 3:
                        steps.append({"tool": tool, "args": {"file_path": parts[0], "find": parts[1], "replace": parts[2]}})
                elif tool == "list_directory":
                    steps.append({"tool": tool, "args": {"path": args_str or "."}})
                elif tool == "git_status":
                    steps.append({"tool": tool, "args": {"command": args_str}})
                elif tool == "run_command":
                    steps.append({"tool": tool, "args": {"command": args_str}})

        return steps

    def _infer_tools_from_text(self, plan: str) -> list[dict]:
        """Infer tool calls from natural language text."""
        steps = []
        plan_lower = plan.lower()

        # List directory patterns
        if any(kw in plan_lower for kw in ["list directory", "list the", "ls", "dir", "列出目录", "查看目录", "当前目录"]):
            # Try to extract a path
            path_match = re.search(r'[\'""]?([\./\w]+)[\'""]?', plan)
            path = path_match.group(1) if path_match else "."
            steps.append({"tool": "list_directory", "args": {"path": path}})

        # Read file patterns
        if any(kw in plan_lower for kw in ["read file", "read", "读取", "打开文件"]):
            path_match = re.search(r'[\'""]?([\w/\-_.]+\.\w+)[\'""]?', plan)
            if path_match:
                steps.append({"tool": "read_file", "args": {"file_path": path_match.group(1)}})

        # Git status patterns
        if any(kw in plan_lower for kw in ["git status", "git log", "git diff", "git commit"]):
            cmd = "status"
            if "log" in plan_lower:
                cmd = "log"
            elif "diff" in plan_lower:
                cmd = "diff"
            elif "commit" in plan_lower:
                cmd = "commit"
            steps.append({"tool": "git_status", "args": {"command": cmd}})

        # Run command patterns
        trusted_patterns = ["git", "python", "pip", "npm", "node", "pytest", "dir", "ls", "pwd"]
        for cmd in trusted_patterns:
            if f"run {cmd}" in plan_lower or f"{cmd} " in plan_lower:
                # Extract the command
                cmd_match = re.search(rf'(?:run\s+)?({cmd}[^\s,]*)', plan, re.IGNORECASE)
                if cmd_match:
                    steps.append({"tool": "run_command", "args": {"command": cmd_match.group(1)}})
                    break

        return steps
