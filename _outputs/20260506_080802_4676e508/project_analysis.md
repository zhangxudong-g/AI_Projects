# AI Projects Analysis Report

Generated: 2026-05-06 16:08

---

## Repository Overview

| Property | Value |
|----------|-------|
| Root | `D:\AI_Projects` |
| Project Count | 16+ |
| Languages | Python, Dart/Flutter, TypeScript/React |
| VCS | Git (multi-branch) |

---

## Project Directory Structure

```
D:\AI_Projects\
|-- auto_coder/           # Auto code generation system
|-- ai_chat_app/          # Flutter AI chat application
|-- wiki_fact_judge/      # Fact judgment system
|-- server_monitor/       # Server monitoring
|-- chroma_viewer/         # Chroma DB viewer
|-- plsql_ir/             # PL/SQL extractor
|-- open-cli/             # CLI tool
|-- JIP/                  # JIP project
|-- promptfoo_wiki/       # Promptfoo config
|-- qwen-skills/          # Qwen skills library
|-- plsql-wiki-demo/      # PL/SQL Wiki demo
|-- documents/            # Documentation
|-- open_battery/        # Documentation only
|-- test/                 # Test directory
|-- test_kimi/           # Kimi tests
|-- test_minmax/          # Minmax tests
-- _outputs/              # Output directory (current session)
```

---

## Main Projects

### 1. auto_coder - Auto Code Generation System

**Tech Stack:** Python 3.11+ | FastAPI | LangChain | LangGraph | Ollama

**Features:**
- Multi-Agent collaboration (Planner/Coder/Tester/Fixer)
- Auto error fixing
- SSE real-time output
- Command whitelist + file sandbox security

**Commands:**
```powershell
cd auto_coder
python cli.py "prompt"
python run_interactive.py
python -m uvicorn app.main:app --port 8001 --reload
```

**Status:** Active development

---

### 2. ai_chat_app - Flutter AI Chat

**Tech Stack:** Flutter 3.x | Dart | Material Design 3 | Riverpod

**Features:**
- Cross-platform (Web/Android/iOS)
- Ollama AI integration
- Material 3 modern UI

**Commands:**
```powershell
cd ai_chat_app
flutter pub get
flutter run -d chrome
```

**Status:** Active development

---

### 3. wiki_fact_judge - Fact Judgment System

**Tech Stack:** Python | FastAPI | TypeScript | React | SQLite

**Features:**
- Wikipedia-based fact verification
- Multiple versions (fact_judge, v2, v3)
- Promptfoo evaluation

**Commands:**
```powershell
cd wiki_fact_judge
cd backend; uvicorn main:app --reload --port 8765
cd frontend; npm start
```

**Status:** Active development

---

### 4. server_monitor - Server Monitoring

**Tech Stack:** Python | FastAPI | SSH | YAML config

**Commands:**
```powershell
cd server_monitor
python main.py
```

**Status:** Active development

---

### 5. chroma_viewer - Chroma DB Viewer

**Tech Stack:** Python | Flask | ChromaDB

**Commands:**
```powershell
python chroma_viewer/view_chroma_db.py --list-projects
python chroma_viewer/chroma_web_viewer/app.py
```

**Status:** Maintenance

---

### 6. plsql_ir - PL/SQL IR Extractor

**Tech Stack:** Python | ANTLR4

**Features:**
- Extract PL/SQL structure (TABLE, VIEW, FUNCTION, etc.)
- Auto encoding detection

**Commands:**
```powershell
cd plsql_ir
python plsql_extractor.py <file.sql>
```

**Status:** Maintenance

---

## Tech Configuration

### Default Services
- **Ollama API:** http://133.238.28.90:51434

### Default Ports
| Service | Port |
|---------|------|
| auto_coder API | 8001 |
| wiki_fact_judge backend | 8765 |
| server_monitor | 9000 |
| chroma_viewer Web | 5000 |

### Git Branches
```
master
feature/
  |-- fact-judge-v3-improvements
  |-- open-cli
  |-- v2-implementation
  |-- web-ui-development
```

---

## Environment Requirements

- Python 3.11+
- Git
- Flutter 3.x (for ai_chat_app)
- Network access (for Ollama API)

---

## Quick Start

```powershell
# AutoCoder
cd D:\AI_Projects\auto_coder
pip install -r requirements.txt
python run_interactive.py

# AI Chat App
cd D:\AI_Projects\ai_chat_app
flutter pub get
flutter run -d chrome

# Wiki Fact Judge
cd D:\AI_Projects\wiki_fact_judge
pip install -r requirements.txt
python start.py
```

---

## Related Documentation

| File | Description |
|------|-------------|
| `AGENTS.md` | Agent system usage guide |
| `README.md` | Project overview |
| `AGENT_USAGE_GUIDE.md` | Usage guide |
| `DOCUMENTATION_INDEX.md` | Documentation index |

---

*Report generated: 2026-05-06 16:08*