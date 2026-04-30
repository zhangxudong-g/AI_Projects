# AGENTS.md

## Platform
- **Windows** with PowerShell. Use PowerShell syntax, not Bash.
- All paths use backslashes or forward slashes (both work on Windows).

## Projects (independent, no monorepo tool)

| Project | Entry point | Key command |
|---------|-------------|-------------|
| `auto_coder/` | FastAPI + LangChain/LangGraph | `python cli.py "prompt"` or `python run_interactive.py` |
| `ai_chat_app/` | Flutter 3.x | `flutter run -d chrome` |
| `wiki_fact_judge/` | FastAPI + React | Has its own `AGENTS.md` |
| `server_monitor/` | Python FastAPI | `python server_monitor/main.py` |
| `chroma_viewer/` | Python Flask | `python chroma_viewer/view_chroma_db.py` |
| `plsql_ir/` | `plsql_extractor.py` | Single script, no server |
| `open_battery/` | Documentation only | No build/test commands |

## Common patterns
- Each project has its own `requirements.txt` or `pubspec.yaml`.
- No shared build system, CI config, or pre-commit hooks at root.
- Each Python project uses `pip install -r requirements.txt`.

## auto_coder
```powershell
cd auto_coder
pip install -r requirements.txt
python -m uvicorn app.main:app --port 8001 --reload
python cli.py "your prompt here"
python run_interactive.py
pytest tests/ -v
```
- Port 8001 is the standard dev port (cli.py and start.sh both use 8001 now)
- Uses Ollama at `http://133.238.28.90:51434` by default
- Generated code goes to `workspace/` (gitignored)
- Workspace isolation enforced - file ops only allowed in workspace/

## ai_chat_app
```powershell
cd ai_chat_app
flutter pub get
flutter run -d chrome
flutter analyze
```
- Uses Ollama for chat at `http://133.238.28.90:51434`
- State managed via Riverpod (manual StateNotifier pattern, no code generation)
- dio package was removed (unused)
- assets/ folder is empty

## wiki_fact_judge
See `wiki_fact_judge/AGENTS.md` for full details on its CLI pipeline and frontend workflow.

Backend dev: `cd backend; uvicorn main:app --reload --port 8765`
Frontend dev: `cd frontend; npm start`

## server_monitor
```powershell
cd server_monitor
pip install -r requirements.txt
python main.py
```
- Config in `config.yaml` - passwords use `${ENV_VAR}` syntax, set via environment variables `SSH_PASSWORD` and `SUDO_PASSWORD`
- Runs on port 9000
- Requires SSH access to remote servers

## chroma_viewer
```powershell
pip install chromadb flask
python chroma_viewer/view_chroma_db.py --list-projects
python chroma_viewer/view_chroma_db.py --project <name>
python chroma_viewer/chroma_web_viewer/app.py  # Web UI on port 5000
```

## plsql_ir
```powershell
cd plsql_ir
python plsql_extractor.py <file.sql>
python plsql_extractor.py <directory>
python plsql_extractor.py <directory> --output <outdir>
```
- No external dependencies (standard library only)
- Supports: TABLE, VIEW, FUNCTION, PROCEDURE, PACKAGE, PACKAGE_BODY, TYPE
- Auto-detects encoding (utf-8, cp932, shift_jis, gb2312, gbk, latin-1)