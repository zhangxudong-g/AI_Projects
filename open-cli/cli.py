#!/usr/bin/env python3
import signal
import sys
import json
import os
import subprocess
from pathlib import Path
from core.llm import LLMClient, LLMError, TOOL_SCHEMAS
from core.session import SessionManager
from core.security import SecurityBoundary
from core.renderer import MarkdownRenderer
from core.status import StatusBar
from core.selector import Selector
from tools.file_tool import FileTool
from tools.git_tool import GitTool
from tools.cmd_tool import CmdTool
from config import load_config

try:
    import readline
    READLINE_AVAILABLE = True
except ImportError:
    READLINE_AVAILABLE = False

TOOL_MAP = {}

COLORS = {
    "reset": "\033[0m",
    "red": "\033[91m",
    "green": "\033[92m",
    "yellow": "\033[93m",
    "blue": "\033[94m",
    "magenta": "\033[95m",
    "cyan": "\033[96m",
    "white": "\033[97m",
    "gray": "\033[90m",
}

TOOL_COLORS = {
    "read_file": COLORS["cyan"],
    "write_file": COLORS["green"],
    "run_command": COLORS["yellow"],
    "git_status": COLORS["blue"],
    "git_commit": COLORS["blue"],
}

class PromptBuilder:
    def __init__(self, session_id: str = ""):
        self.session_id = session_id[:8] if session_id else ""

    def get_workspace_dir(self) -> str:
        """Get shortened current directory."""
        cwd = Path.cwd().name
        home = Path.home().name
        cwd_str = str(Path.cwd())
        if home in cwd_str:
            cwd = "~/" + cwd_str.split(home)[1].strip("\\/").split("\\")[-1]
        return cwd

    def get_git_branch(self) -> str:
        """Get current git branch."""
        try:
            result = subprocess.run(
                ["git", "rev-parse", "--abbrev-ref", "HEAD"],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                return result.stdout.strip()
        except:
            pass
        return "main"

    def build(self, api_connected: bool = True) -> str:
        """Build rich prompt string."""
        workspace = self.get_workspace_dir()
        branch = self.get_git_branch()
        status = "●" if api_connected else "○"

        lines = [
            f"\033[36m┌─[opencli]─[{workspace}]─[{branch}]─❯\033[0m",
            f"\033[90m│ API: {status}Connected  │  Session: {self.session_id}\033[0m",
            "\033[36m└──────────────────────────────────────────────────\033[0m",
        ]
        return "\n".join(lines) + "\n"

class REPL:
    def __init__(self):
        self.config = load_config()
        try:
            self.llm = LLMClient(self.config)
        except LLMError as e:
            print(f"{COLORS['yellow']}Warning: LLM not configured: {e}{COLORS['reset']}")
            self.llm = None

        self.status_bar = StatusBar()

        if self.llm:
            self.status_bar.set_api_status(True)
        else:
            self.status_bar.set_api_status(False)

        workspace_path = Path.cwd()
        security = SecurityBoundary(workspace_path)
        self.file_tool = FileTool(security)
        self.git_tool = GitTool(Path.cwd())
        self.cmd_tool = CmdTool(self.config.get("trusted_commands", []))

        global TOOL_MAP
        TOOL_MAP = {
            "read_file": self.file_tool.read_file,
            "read_pdf": self.file_tool.read_pdf,
            "read_image": self.file_tool.read_image,
            "write_file": self.file_tool.write_file,
            "list_directory": self.file_tool.list_directory_formatted,
            "fetch_url": self.file_tool.fetch_url,
            "grep_search": self.file_tool.grep_search,
            "format_json": self.file_tool.format_json,
            "run_command": self._run_command,
            "git_status": self.git_tool.status,
            "git_commit": self.git_tool.commit,
            "git_log": self.git_tool.log_formatted,
            "git_diff": self.git_tool.diff,
        }

        self.session_manager = SessionManager()
        self.session = self.session_manager.create_session()
        self.prompt_builder = PromptBuilder(self.session["id"])
        self.history = []
        self.renderer = MarkdownRenderer()
        self.status_bar = StatusBar()

        if READLINE_AVAILABLE:
            readline.parse_and_bind("tab: complete")

    def _colorize(self, text, color):
        return f"{color}{text}{COLORS['reset']}"

    def interactive_select(self, options: list, prompt: str = "选择:") -> str:
        """Show interactive selector and return selected option."""
        selector = Selector(options, prompt)
        return selector.run()

    def should_confirm(self, action: str) -> bool:
        dangerous = ["delete", "remove", "rm", "unlink", "format", "drop"]
        return any(word in action.lower() for word in dangerous)

    def confirm(self, message: str) -> bool:
        response = input(f"{COLORS['yellow']}{message} (yes/no): {COLORS['reset']}").strip().lower()
        return response in ("yes", "y")

    def _run_command(self, command: str):
        result = self.cmd_tool.execute(command, require_confirmation=True)
        if result.get("requires_confirmation"):
            if self.should_confirm(command):
                if not self.confirm(f"Execute command: {command}?"):
                    return "Command cancelled"
                result = self.cmd_tool.execute(command, require_confirmation=False)
            else:
                return f"Command not in trusted list: {command}"
        if result.get("requires_confirmation"):
            return f"Command requires confirmation: {command}"
        return f"{COLORS['green']}[OK]{COLORS['reset']}\n{result.get('stdout', '')}"

    def get_welcome(self) -> str:
        prompt = self.prompt_builder.build(self.llm is not None)
        return f"{prompt}{COLORS['cyan']}open-cli{COLORS['reset']} - AI-assisted programming CLI\nType {COLORS['green']}help{COLORS['reset']} for commands."

    def get_help(self) -> str:
        return f"""{COLORS['cyan']}Available Commands:{COLORS['reset']}
  {COLORS['green']}help{COLORS['reset']}     - Show this help message
  {COLORS['green']}exit/quit{COLORS['reset']} - End the session
  {COLORS['green']}clear{COLORS['reset']}    - Clear screen
  {COLORS['green']}session{COLORS['reset']}  - Show current session ID

{COLORS['cyan']}Examples:{COLORS['reset']}
  • "查看当前项目" - List project files
  • "读取 cli.py" - Read a specific file
  • "写一段 Python 代码" - Write code
  • "帮我创建一个函数" - Create a function"""

    def _format_tool_result(self, tool_name: str, result: str) -> str:
        color = TOOL_COLORS.get(tool_name, COLORS['white'])
        header = f"{COLORS['gray']}[{tool_name}]{COLORS['reset']}"
        return f"{header}\n{result}"

    def process_input(self, user_input: str) -> str:
        if user_input.lower() in ("exit", "quit"):
            self.running = False
            return f"{COLORS['yellow']}Goodbye!{COLORS['reset']}"

        if user_input.lower() == "help":
            return self.get_help()

        if user_input.lower() == "clear":
            os.system('cls' if os.name == 'nt' else 'clear')
            return ""

        if user_input.lower() == "session":
            return f"Current session: {COLORS['cyan']}{self.session['id']}{COLORS['reset']}"

        if not self.llm:
            return f"{COLORS['red']}LLM not configured. Please set ANTHROPIC_API_KEY.{COLORS['reset']}"

        self.session["messages"].append({"role": "user", "content": user_input})

        try:
            response = self.llm.send_with_tools(self.session["messages"], TOOL_SCHEMAS)
        except LLMError as e:
            return f"{COLORS['red']}LLM error: {e}{COLORS['reset']}"

        content_blocks = [block for block in response.content if block.type != "thinking"]
        tool_uses = [block for block in content_blocks if block.type == "tool_use"]

        if tool_uses:
            print(f"{COLORS['gray']}Executing {len(tool_uses)} tool(s)...{COLORS['reset']}")

            results = []
            for block in tool_uses:
                func_name = block.name
                args = block.input
                print_result = ""
                if func_name in TOOL_MAP:
                    try:
                        result = TOOL_MAP[func_name](**args)
                        if isinstance(result, dict):
                            if "stdout" in result:
                                print_result = result["stdout"]
                            elif "result" in result:
                                print_result = str(result["result"])
                            else:
                                print_result = json.dumps(result, indent=2, ensure_ascii=False)
                        else:
                            print_result = str(result)
                        formatted_result = self._format_tool_result(func_name, print_result)
                        results.append({"tool": func_name, "result": formatted_result, "raw_result": print_result})
                    except Exception as e:
                        print_result = f"{COLORS['red']}Error: {e}{COLORS['reset']}"
                        results.append({"tool": func_name, "error": str(e)})
                else:
                    print_result = f"{COLORS['red']}Unknown tool: {func_name}{COLORS['reset']}"
                    results.append({"tool": func_name, "error": f"Unknown tool: {func_name}"})

                print(f"{COLORS['cyan']}[{func_name}]{COLORS['reset']}")
                if print_result:
                    try:
                        print(print_result)
                    except UnicodeEncodeError:
                        safe = ''.join(c if ord(c) < 128 or c == '\n' else '?' for c in print_result)
                        print(safe)

            assistant_content = []
            for block in content_blocks:
                if block.type == "text":
                    assistant_content.append({"type": "text", "text": block.text})
                elif block.type == "tool_use":
                    assistant_content.append({"type": "tool_use", "id": block.id, "name": block.name, "input": block.input})

            self.session["messages"].append({"role": "assistant", "content": assistant_content})

            tool_result_content = []
            for i, result_item in enumerate(results):
                tool_id = tool_uses[i].id if i < len(tool_uses) else f"tool_{i}"
                if "raw_result" in result_item:
                    content = result_item["raw_result"]
                elif "error" in result_item:
                    content = f"{COLORS['red']}Error: {result_item['error']}{COLORS['reset']}"
                else:
                    content = str(result_item)
                tool_result_content.append({
                    "type": "tool_result",
                    "tool_use_id": tool_id,
                    "content": content
                })

            self.session["messages"].append({"role": "user", "content": tool_result_content})

            print(f"{COLORS['gray']}[AI thinking...]{COLORS['reset']}")
            try:
                response_text = ""
                for chunk in self.llm.send_streaming(self.session["messages"]):
                    if chunk:
                        print(chunk, end="", flush=True)
                        response_text += chunk
                print()
                if not response_text.strip():
                    print(f"{COLORS['yellow']}(Empty response from AI){COLORS['reset']}")
                elif response_text.strip():
                    rendered = self.renderer.render(response_text)
                    print(rendered)
                print(self.status_bar.render())
            except Exception as e:
                print()
                return f"{COLORS['red']}Stream error: {type(e).__name__}: {e}{COLORS['reset']}"

            self.session["messages"].append({"role": "assistant", "content": response_text})
            self.session_manager.save_session(self.session)
            return None

        text_blocks = [block for block in content_blocks if block.type == "text"]
        if text_blocks:
            print(f"{COLORS['gray']}[AI thinking...]{COLORS['reset']}")
            response_text = ""
            try:
                for chunk in self.llm.send(self.session["messages"], stream=True):
                    if chunk:
                        print(chunk, end="", flush=True)
                        response_text += chunk
                print()
                if not response_text.strip():
                    print(f"{COLORS['yellow']}(Empty response from AI){COLORS['reset']}")
                elif response_text.strip():
                    rendered = self.renderer.render(response_text)
                    print(rendered)
                print(self.status_bar.render())
            except Exception as e:
                print()
                return f"{COLORS['red']}Stream error: {type(e).__name__}: {e}{COLORS['reset']}"

            self.session["messages"].append({"role": "assistant", "content": response_text})
            self.session_manager.save_session(self.session)
            return None

        thinking_blocks = [block for block in content_blocks if block.type == "thinking"]
        if thinking_blocks:
            response_text = f"{COLORS['gray']}[思考中: {thinking_blocks[0].thinking[:100]}...]{COLORS['reset']}"
            self.session["messages"].append({"role": "assistant", "content": response_text})
            self.session_manager.save_session(self.session)
            return response_text

        return f"{COLORS['gray']}No response content{COLORS['reset']}"

    def run(self):
        self.running = True
        print(self.get_welcome())

        def handle_ctrl_c(signum, frame):
            print(f"\n{COLORS['yellow']}Interrupted. Use 'exit' to quit.{COLORS['reset']}")

        signal.signal(signal.SIGINT, handle_ctrl_c)

        while self.running:
            try:
                import sys
                if sys.platform == 'win32':
                    user_input = input(f"\n{COLORS['green']}❯{COLORS['reset']} ")
                else:
                    user_input = self._read_line()

                if not user_input.strip():
                    continue
                if READLINE_AVAILABLE:
                    readline.add_history(user_input)
                self.history.append(user_input)
                response = self.process_input(user_input)
                if response:
                    print(response)
            except KeyboardInterrupt:
                print(f"\n{COLORS['yellow']}Use 'exit' to quit.{COLORS['reset']}")
            except EOFError:
                break
        print(f"{COLORS['cyan']}Session ended.{COLORS['reset']}")

    def _read_line(self) -> str:
        """Read line with basic key handling."""
        line = ""
        while True:
            char = sys.stdin.read(1)
            if char == '\n' or char == '\r':
                print(char, end='')
                break
            elif char == '\x03':  # Ctrl+C
                raise KeyboardInterrupt
            elif char == '\x0c':  # Ctrl+L
                os.system('cls' if os.name == 'nt' else 'clear')
                print(self.get_welcome(), end='')
            elif char == '\x15':  # Ctrl+U
                print("\r" + " " * 50 + "\r", end='')
                line = ""
            elif char == '\x12':  # Ctrl+R
                print("\n[Search history...] ", end='')
                search = input()
                matches = [h for h in self.history if search in h]
                if matches:
                    print(f"Found: {matches[0]}")
                    line = matches[0]
                else:
                    print("No matches")
            elif char == '\x7f':  # Backspace
                if line:
                    line = line[:-1]
                    print('\b \b', end='', flush=True)
            elif ord(char) >= 32:  # Printable characters
                line += char
                print(char, end='', flush=True)
        return line

def main():
    session_id = None
    prompt = None
    output_format = "text"
    args = sys.argv[1:]

    i = 0
    while i < len(args):
        if args[i] == "--session" and i + 1 < len(args):
            session_id = args[i + 1]
            i += 2
        elif args[i] == "-p" and i + 1 < len(args):
            prompt = args[i + 1]
            i += 2
        elif args[i] == "--output-format" and i + 1 < len(args):
            output_format = args[i + 1]
            i += 2
        else:
            i += 1

    repl = REPL()
    if session_id:
        loaded = repl.session_manager.load_session(session_id)
        if loaded:
            repl.session = loaded

    if prompt:
        response = repl.process_input(prompt)
        if output_format == "json":
            print(json.dumps({"response": response, "session_id": repl.session["id"]}))
        elif output_format == "text":
            if response:
                print(response)
        return 0

    repl.run()
    return 0

if __name__ == "__main__":
    sys.exit(main())