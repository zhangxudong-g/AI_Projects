import subprocess
import shlex
from typing import Dict, Any, List

class CmdError(Exception):
    pass

class CmdTool:
    def __init__(self, trusted_commands: List[str] = None):
        self.trusted_commands = trusted_commands or []

    def is_trusted(self, command: str) -> bool:
        if not self.trusted_commands:
            return False
        try:
            parts = shlex.split(command)
            cmd = parts[0] if parts else ""
            return cmd in self.trusted_commands
        except Exception:
            return False

    def parse_command(self, command: str) -> Dict[str, Any]:
        try:
            parts = shlex.split(command)
            if not parts:
                return {"valid": False, "error": "Empty command"}

            cmd = parts[0]
            args = parts[1:]
            return {"valid": True, "cmd": cmd, "args": args}
        except Exception as e:
            return {"valid": False, "error": str(e)}

    def execute(self, command: str, require_confirmation: bool = False,
                cwd: str = None) -> Dict[str, Any]:
        parsed = self.parse_command(command)
        if not parsed["valid"]:
            return {"success": False, "error": parsed["error"]}

        trusted = self.is_trusted(command)

        if require_confirmation and not trusted:
            return {
                "requires_confirmation": True,
                "command": command,
                "trusted": False,
            }

        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                cwd=cwd,
                timeout=30,
            )
            return {
                "success": result.returncode == 0,
                "returncode": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "trusted": trusted,
            }
        except subprocess.TimeoutExpired:
            return {"success": False, "error": "Command timed out"}
        except Exception as e:
            return {"success": False, "error": str(e)}