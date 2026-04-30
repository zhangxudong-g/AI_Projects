# open-cli

AI-assisted programming CLI tool with interactive REPL session and tool calling.

## Features

- **Interactive REPL** - Continuous AI-assisted coding sessions
- **Tool Calling** - Automatic file operations, Git integration, shell commands
- **Streaming Output** - Real-time AI response streaming
- **Colored Output** - Terminal-friendly color-coded messages
- **Session Management** - Save and resume conversations
- **Project Context** - `.opencli.md` for project-specific instructions
- **Non-Interactive Mode** - Use in scripts and pipelines
- **Windows Support** - Full encoding handling for Windows terminals

## Installation

### Option 1: pip install (recommended)

```bash
git clone https://github.com/yourusername/open-cli.git
cd open-cli
pip install -e .   # Development mode
```

### Option 2: pip from source

```bash
pip install .
```

## Usage

### Interactive Mode

```bash
# Basic usage
opencli

# Resume a previous session
opencli --session <session_id>

# Run in specific directory
cd myproject && opencli
```

### Non-Interactive Mode

```bash
# Single prompt, text output
opencli -p "Explain this function"

# Single prompt, JSON output
opencli -p "Explain this function" --output-format json
```

## Commands (Interactive Mode)

| Command | Description |
|---------|-------------|
| `help` | Show help message |
| `exit` / `quit` | End session |
| `clear` | Clear screen |
| `session` | Show current session ID |

Type naturally to communicate with the AI assistant.

## UI Features

### Rich Prompt
The prompt shows current workspace, git branch, and API status:
```
┌─[opencli]─[~/projects/open-cli]─[main]─❯
│ API: ●Connected  │  Session: a1b2c3d4
└──────────────────────────────────────────────────
```

### Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| Ctrl+C | Interrupt AI generation |
| Ctrl+L | Clear screen |
| Ctrl+U | Delete current line |
| Ctrl+R | Search command history |

### Markdown Rendering
AI responses support Markdown formatting with code syntax highlighting for ``` code blocks.

## AI Tools

The AI has access to these tools:

| Tool | Description |
|------|-------------|
| `read_file` | Read file contents |
| `write_file` | Write content to file |
| `list_directory` | List directory contents |
| `run_command` | Execute shell commands |
| `git_status` | Check git status |
| `git_commit` | Commit changes |

## Project Context

Create `.opencli.md` in your project root to add custom instructions:

```markdown
# My Project

## Tech Stack
- Python 3.12
- FastAPI

## Rules
- Use Chinese comments
- Follow PEP 8
```

## Configuration

Config file: `~/.opencli/config.yaml`

```yaml
anthropic_api_key: "your-api-key"
anthropic_base_url: "https://api.minimaxi.com/anthropic"
minimax_model: "MiniMax-M2.7"
trusted_commands:
  - git
  - python
  - pip
  - npm
  - node
  - pytest
  - dir
  - ls
  - pwd
  - mkdir
  - rm
  - cp
  - mv
  - cat
  - type
```

Or set environment variable `ANTHROPIC_API_KEY`.

## Architecture

```
open-cli/
├── cli.py           # Main REPL entry point
├── config.py        # Configuration management
├── core/
│   ├── llm.py       # LLM client with streaming
│   ├── security.py  # Security boundary
│   └── session.py   # Session management
├── tools/
│   ├── cmd_tool.py  # Shell command execution
│   ├── file_tool.py # File operations
│   └── git_tool.py  # Git integration
└── tests/           # Test suite
```

## Development

```bash
# Run tests
pytest tests/ -v

# Install with dev dependencies
pip install -e ".[dev]"
```

## License

MIT
