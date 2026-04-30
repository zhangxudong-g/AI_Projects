import os
from typing import List, Dict
import anthropic
from config import load_config

class LLMError(Exception):
    pass

TOOL_SCHEMAS = [
    {
        "name": "read_file",
        "description": "Read the contents of a file from the workspace",
        "input_schema": {
            "type": "object",
            "properties": {
                "file_path": {"type": "string", "description": "Path to the file"}
            },
            "required": ["file_path"]
        }
    },
    {
        "name": "write_file",
        "description": "Write content to a file in the workspace",
        "input_schema": {
            "type": "object",
            "properties": {
                "file_path": {"type": "string", "description": "Path to the file"},
                "content": {"type": "string", "description": "Content to write"}
            },
            "required": ["file_path", "content"]
        }
    },
    {
        "name": "run_command",
        "description": "Execute a shell command",
        "input_schema": {
            "type": "object",
            "properties": {
                "command": {"type": "string", "description": "The command to run"}
            },
            "required": ["command"]
        }
    },
    {
        "name": "git_status",
        "description": "Check git repository status",
        "input_schema": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "git_commit",
        "description": "Commit changes to git",
        "input_schema": {
            "type": "object",
            "properties": {
                "message": {"type": "string", "description": "Commit message"}
            },
            "required": ["message"]
        }
    }
]

def format_messages(messages: List[Dict]) -> List[Dict]:
    formatted = []
    for msg in messages:
        role = msg.get("role", "user")
        content = msg.get("content", "")

        if isinstance(content, str):
            formatted.append({
                "role": role,
                "content": [{"type": "text", "text": content}]
            })
        elif isinstance(content, list):
            formatted.append({
                "role": role,
                "content": content
            })
        else:
            formatted.append({
                "role": role,
                "content": [{"type": "text", "text": str(content)}]
            })
    return formatted

class LLMClient:
    def __init__(self, config=None):
        self.config = config or load_config()
        self.model = self.config.get("minimax_model", "MiniMax-M2.7")
        self.api_key = self.config.get("anthropic_api_key")
        self.base_url = self.config.get("anthropic_base_url", "https://api.minimaxi.com/anthropic")

        if not self.api_key:
            raise LLMError("ANTHROPIC_API_KEY not configured")

    def send(self, messages: List[Dict[str, str]]) -> str:
        if not self.api_key:
            raise LLMError("ANTHROPIC_API_KEY not configured")

        client = anthropic.Anthropic(
            api_key=self.api_key,
            base_url=self.base_url,
        )

        formatted_messages = format_messages(messages)

        try:
            response = client.messages.create(
                model=self.model,
                max_tokens=1024,
                messages=formatted_messages,
            )
            return response.content[0].text
        except Exception as e:
            raise LLMError(f"LLM call failed: {e}")

    def send_with_tools(self, messages: List[Dict[str, str]], tools: List[Dict]) -> Dict:
        if not self.api_key:
            raise LLMError("ANTHROPIC_API_KEY not configured")

        client = anthropic.Anthropic(
            api_key=self.api_key,
            base_url=self.base_url,
        )

        formatted_messages = format_messages(messages)

        try:
            response = client.messages.create(
                model=self.model,
                max_tokens=1024,
                messages=formatted_messages,
                tools=tools,
            )
            return response
        except Exception as e:
            raise LLMError(f"LLM call failed: {e}")