import os
from pathlib import Path
from typing import List, Dict
import anthropic
from config import load_config

SYSTEM_PROMPT_BASE = """You are a helpful AI coding assistant.

TOOL USAGE RULES:
1. When user asks to view/read the project or list files, use list_directory instead of run_command if possible
2. When user asks to read a specific file, use read_file with file_path parameter (SINGULAR, not files)
3. After tool results, ALWAYS provide a concise summary in Chinese

TOOL PARAMETERS - CRITICAL:
- read_file takes ONE parameter: file_path (string), NOT files or files[]
- list_directory takes ONE parameter: dir_path (string, optional, defaults to ".")
- NEVER use {"files": [...]} format for read_file

After getting tool results, respond with a helpful summary in Chinese."""

def get_project_context() -> str:
    """Load .opencli.md from current directory if exists."""
    context_file = Path.cwd() / ".opencli.md"
    if context_file.exists():
        try:
            content = context_file.read_text(encoding="utf-8")
            return f"\n\nPROJECT CONTEXT:\n{content}\n"
        except Exception:
            pass
    return ""

def get_system_prompt() -> str:
    """Get full system prompt with project context."""
    return SYSTEM_PROMPT_BASE + get_project_context()

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
        "name": "list_directory",
        "description": "List directory contents with file sizes and counts",
        "input_schema": {
            "type": "object",
            "properties": {
                "dir_path": {"type": "string", "description": "Directory path to list (optional, defaults to current directory)"}
            }
        }
    },
    {
        "name": "read_pdf",
        "description": "Read PDF file and extract text content",
        "input_schema": {
            "type": "object",
            "properties": {
                "file_path": {"type": "string", "description": "Path to the PDF file"}
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
    },
    {
        "name": "git_log",
        "description": "View recent git commit history",
        "input_schema": {
            "type": "object",
            "properties": {
                "n": {"type": "integer", "description": "Number of commits to show (default 10)"}
            }
        }
    },
    {
        "name": "git_diff",
        "description": "Show changes between commits or working tree",
        "input_schema": {
            "type": "object",
            "properties": {
                "file": {"type": "string", "description": "Specific file to diff (optional)"}
            }
        }
    },
    {
        "name": "fetch_url",
        "description": "Fetch and extract text from a URL",
        "input_schema": {
            "type": "object",
            "properties": {
                "url": {"type": "string", "description": "URL to fetch"}
            },
            "required": ["url"]
        }
    },
    {
        "name": "read_image",
        "description": "Read text from an image using OCR",
        "input_schema": {
            "type": "object",
            "properties": {
                "file_path": {"type": "string", "description": "Path to the image file"}
            },
            "required": ["file_path"]
        }
    },
    {
        "name": "grep_search",
        "description": "Search for text pattern in files",
        "input_schema": {
            "type": "object",
            "properties": {
                "pattern": {"type": "string", "description": "Search pattern (regex supported)"},
                "dir_path": {"type": "string", "description": "Directory to search in (default: current directory)"}
            },
            "required": ["pattern"]
        }
    },
    {
        "name": "format_json",
        "description": "Format and validate JSON string",
        "input_schema": {
            "type": "object",
            "properties": {
                "content": {"type": "string", "description": "JSON string to format"}
            },
            "required": ["content"]
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

    def send(self, messages: List[Dict[str, str]], stream: bool = False):
        if not self.api_key:
            raise LLMError("ANTHROPIC_API_KEY not configured")

        client = anthropic.Anthropic(
            api_key=self.api_key,
            base_url=self.base_url,
        )

        formatted_messages = format_messages(messages)

        try:
            if stream:
                result = ""
                with client.messages.stream(
                    model=self.model,
                    max_tokens=4096,
                    system=get_system_prompt(),
                    messages=formatted_messages,
                ) as stream_resp:
                    for event in stream_resp:
                        if event.type == "content_block_delta" and event.delta.type == "text_delta":
                            result += event.delta.text
                            yield event.delta.text
                return result
            else:
                response = client.messages.create(
                    model=self.model,
                    max_tokens=4096,
                    system=get_system_prompt(),
                    messages=formatted_messages,
                )
                for block in response.content:
                    if block.type == "text":
                        return block.text
                raise LLMError("No text block in response")
        except Exception as e:
            raise LLMError(f"LLM call failed: {e}")

    def send_streaming(self, messages: List[Dict[str, str]]):
        if not self.api_key:
            raise LLMError("ANTHROPIC_API_KEY not configured")

        client = anthropic.Anthropic(
            api_key=self.api_key,
            base_url=self.base_url,
        )

        formatted_messages = format_messages(messages)

        try:
            with client.messages.stream(
                model=self.model,
                max_tokens=4096,
                system=get_system_prompt(),
                messages=formatted_messages,
            ) as stream:
                for event in stream:
                    if event.type == "content_block_delta" and event.delta.type == "text_delta":
                        yield event.delta.text
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
                max_tokens=4096,
                system=get_system_prompt(),
                messages=formatted_messages,
                tools=tools,
            )
            return response
        except Exception as e:
            raise LLMError(f"LLM call failed: {e}")