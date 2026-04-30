#!/usr/bin/env python3
import sys
import json
from pathlib import Path
from core.llm import LLMClient, LLMError, TOOL_SCHEMAS
from core.session import SessionManager
from core.security import SecurityBoundary
from tools.file_tool import FileTool
from tools.git_tool import GitTool
from tools.cmd_tool import CmdTool
from config import load_config

TOOL_MAP = {}

class REPL:
    def __init__(self):
        self.config = load_config()
        try:
            self.llm = LLMClient(self.config)
        except LLMError as e:
            print(f"Warning: LLM not configured: {e}")
            self.llm = None

        workspace_path = Path.cwd() / self.config.get("workspace", "opencli")
        workspace_path.mkdir(exist_ok=True)
        security = SecurityBoundary(workspace_path)
        self.file_tool = FileTool(security)
        self.git_tool = GitTool(Path.cwd())
        self.cmd_tool = CmdTool(self.config.get("trusted_commands", []))

        global TOOL_MAP
        TOOL_MAP = {
            "read_file": self.file_tool.read_file,
            "write_file": self.file_tool.write_file,
            "run_command": self._run_command,
            "git_status": self.git_tool.status,
            "git_commit": self.git_tool.commit,
        }

        self.session_manager = SessionManager()
        self.session = self.session_manager.create_session()

    def _run_command(self, command: str):
        result = self.cmd_tool.execute(command, require_confirmation=True)
        if result.get("requires_confirmation"):
            return f"Command requires confirmation: {command}"
        return f"Return code: {result.get('returncode')}\nOutput: {result.get('stdout', '')}"

    def get_welcome(self) -> str:
        return f"""open-cli - AI-assisted programming CLI
Session: {self.session['id']}
Type 'exit' or 'quit' to end session."""

    def process_input(self, user_input: str) -> str:
        if user_input.lower() in ("exit", "quit"):
            self.running = False
            return "Goodbye!"

        if not self.llm:
            return "LLM not configured. Please set MINIMAX_API_KEY."

        self.session["messages"].append({"role": "user", "content": user_input})

        try:
            response = self.llm.send_with_tools(self.session["messages"], TOOL_SCHEMAS)
        except LLMError as e:
            return f"LLM error: {e}"

        tool_calls = response.get("choices", [{}])[0].get("message", {}).get("tool_calls", [])

        if tool_calls:
            results = []
            for call in tool_calls:
                func_name = call["function"]["name"]
                args = json.loads(call["function"]["arguments"])
                if func_name in TOOL_MAP:
                    try:
                        result = TOOL_MAP[func_name](**args)
                        results.append({"tool": func_name, "result": result})
                    except Exception as e:
                        results.append({"tool": func_name, "error": str(e)})
                else:
                    results.append({"tool": func_name, "error": f"Unknown tool: {func_name}"})

            self.session["messages"].append(response["choices"][0]["message"])
            self.session["messages"].append({
                "role": "tool",
                "content": json.dumps(results),
            })

            try:
                final_response = self.llm.send(self.session["messages"])
            except LLMError as e:
                return f"LLM error: {e}"

            self.session["messages"].append({"role": "assistant", "content": final_response})
            self.session_manager.save_session(self.session)
            return final_response

        response_text = response["choices"][0]["message"]["content"]
        self.session["messages"].append({"role": "assistant", "content": response_text})
        self.session_manager.save_session(self.session)
        return response_text

    def run(self):
        self.running = True
        print(self.get_welcome())
        while self.running:
            try:
                user_input = input("\n> ")
                if not user_input.strip():
                    continue
                response = self.process_input(user_input)
                print(response)
            except KeyboardInterrupt:
                print("\nUse 'exit' to quit.")
            except EOFError:
                break
        print("Session ended.")

def main():
    session_id = None
    args = sys.argv[1:]
    if "--session" in args:
        idx = args.index("--session")
        if idx + 1 < len(args):
            session_id = args[idx + 1]

    repl = REPL()
    if session_id:
        loaded = repl.session_manager.load_session(session_id)
        if loaded:
            repl.session = loaded
    repl.run()
    return 0

if __name__ == "__main__":
    sys.exit(main())