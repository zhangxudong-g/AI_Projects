import os
from typing import List, Dict
import litellm
from litellm import completion
from config import load_config

class LLMError(Exception):
    pass

TOOL_SCHEMAS = [
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read the contents of a file from the workspace",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {"type": "string", "description": "Path to the file"}
                },
                "required": ["file_path"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "write_file",
            "description": "Write content to a file in the workspace",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {"type": "string", "description": "Path to the file"},
                    "content": {"type": "string", "description": "Content to write"}
                },
                "required": ["file_path", "content"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "run_command",
            "description": "Execute a shell command",
            "parameters": {
                "type": "object",
                "properties": {
                    "command": {"type": "string", "description": "The command to run"}
                },
                "required": ["command"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "git_status",
            "description": "Check git repository status",
            "parameters": {"type": "object", "properties": {}}
        }
    },
    {
        "type": "function",
        "function": {
            "name": "git_commit",
            "description": "Commit changes to git",
            "parameters": {
                "type": "object",
                "properties": {
                    "message": {"type": "string", "description": "Commit message"}
                },
                "required": ["message"]
            }
        }
    }
]

class LLMClient:
    def __init__(self, config=None):
        self.config = config or load_config()
        self.model = self.config.get("minimax_model", "MiniMax-Text-01")
        self.api_key = self.config.get("minimax_api_key")
        self.base_url = self.config.get("minimax_base_url")

    def _litellm_model(self):
        return f"minimax/{self.model}"

    def send(self, messages: List[Dict[str, str]]) -> str:
        if not self.api_key:
            raise LLMError("MINIMAX_API_KEY not configured")

        os.environ["MINIMAX_API_KEY"] = self.api_key
        if self.base_url:
            os.environ["MINIMAX_BASE_URL"] = self.base_url

        try:
            response = completion(
                model=self._litellm_model(),
                messages=messages,
            )
            return response["choices"][0]["message"]["content"]
        except Exception as e:
            raise LLMError(f"LLM call failed: {e}")

    def send_with_tools(self, messages: List[Dict[str, str]], tools: List[Dict]) -> Dict:
        if not self.api_key:
            raise LLMError("MINIMAX_API_KEY not configured")

        os.environ["MINIMAX_API_KEY"] = self.api_key
        if self.base_url:
            os.environ["MINIMAX_BASE_URL"] = self.base_url

        try:
            response = completion(
                model=self._litellm_model(),
                messages=messages,
                tools=tools,
            )
            return response
        except Exception as e:
            raise LLMError(f"LLM call failed: {e}")