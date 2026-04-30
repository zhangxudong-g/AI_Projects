# open-cli

AI-assisted programming CLI tool with interactive REPL session.

## Features

- Interactive REPL for continuous AI-assisted coding
- File operations with security boundary (restricted to workspace)
- Git integration (status, diff, commit)
- Shell command execution with confirmation mode
- Session history management

## Installation

```bash
pip install -r requirements.txt
```

## Configuration

Create `~/.opencli/config.yaml`:

```yaml
minimax_api_key: "your-api-key"
minimax_model: "MiniMax-Text-01"
workspace: "opencli"
trusted_commands:
  - git
  - python
  - pip
  - npm
```

Or set environment variable `MINIMAX_API_KEY`.

## Usage

```bash
python cli.py
python cli.py --session abc123  # Resume session
```

## Commands

- `exit` or `quit` - End session
- Type naturally to communicate with the AI

## Session History

Sessions are saved to `~/.opencli/sessions/` and can be resumed with `--session` flag.
