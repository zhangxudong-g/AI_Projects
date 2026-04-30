# open-cli Design Specification

## Project Overview

- **Project Name**: open-cli
- **Type**: AI-assisted programming CLI tool
- **Core Functionality**: Interactive REPL session with LLM-driven code generation, file operations, Git integration, and command execution
- **Target Users**: Individual developers

## Technical Stack

- **Language**: Python 3.10+
- **LLM Integration**: LiteLLM (unified wrapper for MiniMax API)
- **Dependencies**: Minimal - only essential libraries

## Architecture

```
open-cli/
├── cli.py              # Entry point, REPL main loop
├── core/
│   ├── __init__.py
│   ├── llm.py          # LLM call wrapper
│   ├── session.py       # Session management
│   └── security.py      # File operation security boundary
├── tools/
│   ├── __init__.py
│   ├── file_tool.py     # File read/write/edit
│   ├── git_tool.py      # Git operations
│   └── cmd_tool.py      # Shell command execution
├── config.py           # Configuration management
├── requirements.txt
└── README.md
```

## Core Interaction Flow

1. Start CLI → Check `opencli/` workspace → Load or create session
2. User input → Send to LLM → Parse response (text/tool calls)
3. Tool call → Security check → Execute → Return result
4. LLM integrate results → Generate reply → Display to user

## Security Mechanism

- **Workspace Restriction**: All file operations limited to `./opencli/` directory
- **Confirmation Mode**: Sensitive operations (delete, overwrite) require user confirmation
- **Command Whitelist**: Configurable list of trusted commands that execute automatically

## Session Management

- **Storage Location**: `~/.opencli/sessions/`
- **Format**: JSON file, one file per session
- **Recovery**: Support `--session <id>` to restore historical sessions

## LLM Configuration

- **Provider**: MiniMax (via LiteLLM)
- **Configuration**: Environment variables or `~/.opencli/config.yaml`
- **Model**: MiniMax default model (configurable)

## Project Structure Decisions

- `core/`: Core modules for LLM, session, and security
- `tools/`: Tool modules for file, git, and command operations
- `config.py`: Configuration management at project level
- `~/.opencli/`: User-level config and session storage

## Implementation Priority

1. Core LLM integration (MiniMax via LiteLLM)
2. Basic REPL loop
3. Session management
4. File tool with security boundary
5. Git tool
6. Command execution tool
7. Confirmation mode for sensitive operations