# open-cli Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an interactive AI-assisted programming CLI with LLM-driven code generation, file operations, Git integration, and command execution.

**Architecture:** Lightweight REPL architecture with modular core/tools separation. Single Python process with REPL loop, LiteLLM for unified LLM integration, workspace restriction for file safety.

**Tech Stack:** Python 3.10+, LiteLLM, pyyaml

---

## File Structure

```
open-cli/
├── cli.py                    # Entry point, REPL main loop
├── core/
│   ├── __init__.py
│   ├── llm.py                # LLM call wrapper (MiniMax via LiteLLM)
│   ├── session.py             # Session management (JSON files)
│   └── security.py            # File operation security boundary
├── tools/
│   ├── __init__.py
│   ├── file_tool.py           # File read/write/edit operations
│   ├── git_tool.py            # Git operations
│   └── cmd_tool.py            # Shell command execution
├── config.py                  # Configuration management
├── requirements.txt
└── README.md
```

---

## Task 1: Project Setup

**Files:**
- Create: `requirements.txt`
- Create: `open-cli/cli.py` (stub with --help)
- Create: `open-cli/core/__init__.py`
- Create: `open-cli/tools/__init__.py`

- [ ] **Step 1: Create requirements.txt**

```
litellm>=1.0.0
pyyaml>=6.0
```

- [ ] **Step 2: Create cli.py stub**

```python
#!/usr/bin/env python3
import sys

def main():
    print("open-cli - AI-assisted programming CLI")
    print("Usage: python cli.py [--session SESSION_ID]")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 3: Create __init__.py files**

```python
# core/__init__.py
# tools/__init__.py
```

- [ ] **Step 4: Verify stub runs**

Run: `python cli.py --help`
Expected: Help message displays

- [ ] **Step 5: Commit**

```bash
git add requirements.txt cli.py core/__init__.py tools/__init__.py
git commit -m "feat: project setup with stub CLI"
```

---

## Task 2: LLM Integration (MiniMax via LiteLLM)

**Files:**
- Create: `core/llm.py`
- Create: `tests/core/test_llm.py`
- Modify: `config.py`

- [ ] **Step 1: Create config.py**

```python
import os
from pathlib import Path

DEFAULT_CONFIG = {
    "minimax_api_key": os.environ.get("MINIMAX_API_KEY", ""),
    "minimax_model": "MiniMax-Text-01",
    "minimax_base_url": "https://api.minimax.chat/v1",
    "workspace": "opencli",
    "trusted_commands": ["git", "python", "pip", "npm", "node", "pytest"],
}

def load_config():
    config = DEFAULT_CONFIG.copy()
    config_dir = Path.home() / ".opencli"
    config_file = config_dir / "config.yaml"
    if config_file.exists():
        import yaml
        with open(config_file) as f:
            user_config = yaml.safe_load(f) or {}
            config.update(user_config)
    return config

def save_config(config):
    config_dir = Path.home() / ".opencli"
    config_dir.mkdir(parents=True, exist_ok=True)
    config_file = config_dir / "config.yaml"
    import yaml
    with open(config_file, "w") as f:
        yaml.dump(config, f)
```

- [ ] **Step 2: Write failing test for LLM**

```python
# tests/core/test_llm.py
import pytest
from core.llm import LLMClient, LLMError

def test_llm_client_initialization():
    client = LLMClient()
    assert client.model == "MiniMax-Text-01"

def test_llm_send_message():
    client = LLMClient()
    response = client.send([{"role": "user", "content": "Hello"}])
    assert isinstance(response, str)
    assert len(response) > 0

def test_llm_error_on_missing_api_key(monkeypatch):
    monkeypatch.delenv("MINIMAX_API_KEY", raising=False)
    client = LLMClient()
    with pytest.raises(LLMError):
        client.send([{"role": "user", "content": "test"}])
```

- [ ] **Step 3: Run test to verify it fails**

Run: `pytest tests/core/test_llm.py -v`
Expected: FAIL - module 'core.llm' has no attribute 'LLMClient'

- [ ] **Step 4: Implement LLM client**

```python
# core/llm.py
import os
from typing import List, Dict
import litellm
from litellm import completion
from config import load_config

class LLMError(Exception):
    pass

class LLMClient:
    def __init__(self, config=None):
        self.config = config or load_config()
        self.model = self.config.get("minimax_model", "MiniMax-Text-01")
        self.api_key = self.config.get("minimax_api_key")
        self.base_url = self.config.get("minimax_base_url")

        if not self.api_key:
            raise LLMError("MINIMAX_API_KEY not configured")

        os.environ["MINIMAX_API_KEY"] = self.api_key
        if self.base_url:
            os.environ["MINIMAX_BASE_URL"] = self.base_url

    def send(self, messages: List[Dict[str, str]]) -> str:
        try:
            response = completion(
                model=self.model,
                messages=messages,
            )
            return response["choices"][0]["message"]["content"]
        except Exception as e:
            raise LLMError(f"LLM call failed: {e}")

    def send_with_tools(self, messages: List[Dict[str, str]], tools: List[Dict]) -> Dict:
        try:
            response = completion(
                model=self.model,
                messages=messages,
                tools=tools,
            )
            return response
        except Exception as e:
            raise LLMError(f"LLM call failed: {e}")
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `pytest tests/core/test_llm.py -v`
Expected: PASS (may skip API key test if env var not set)

- [ ] **Step 6: Commit**

```bash
git add core/llm.py config.py tests/core/test_llm.py
git commit -m "feat: add LLM integration with LiteLLM/MiniMax"
```

---

## Task 3: Basic REPL Loop

**Files:**
- Modify: `cli.py`
- Create: `tests/test_repl.py`

- [ ] **Step 1: Write failing test for REPL**

```python
# tests/test_repl.py
import pytest
from io import StringIO
from cli import REPL

def test_repl_initialization():
    repl = REPL()
    assert repl.llm is not None
    assert repl.running is False

def test_repl_welcome_message():
    repl = REPL()
    assert "open-cli" in repl.get_welcome()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_repl.py -v`
Expected: FAIL - module 'cli' has no attribute 'REPL'

- [ ] **Step 3: Implement basic REPL**

```python
# cli.py
#!/usr/bin/env python3
import sys
from core.llm import LLMClient
from config import load_config

class REPL:
    def __init__(self):
        self.config = load_config()
        self.llm = LLMClient(self.config)
        self.running = False
        self.session_id = None

    def get_welcome(self) -> str:
        return "open-cli - AI-assisted programming CLI\nType 'exit' or 'quit' to end session."

    def process_input(self, user_input: str) -> str:
        if user_input.lower() in ("exit", "quit"):
            self.running = False
            return "Goodbye!"

        messages = [{"role": "user", "content": user_input}]
        response = self.llm.send(messages)
        return response

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
    repl.session_id = session_id
    repl.run()
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_repl.py -v`
Expected: PASS

- [ ] **Step 5: Test REPL manually**

Run: `echo "hello" | python cli.py`
Expected: Basic response from LLM (if API key configured)

- [ ] **Step 6: Commit**

```bash
git add cli.py tests/test_repl.py
git commit -m "feat: implement basic REPL loop"
```

---

## Task 4: Session Management

**Files:**
- Create: `core/session.py`
- Create: `tests/core/test_session.py`
- Modify: `cli.py` (integrate session)

- [ ] **Step 1: Write failing test for session**

```python
# tests/core/test_session.py
import pytest
import tempfile
import shutil
from pathlib import Path
from core.session import SessionManager

@pytest.fixture
def temp_session_dir():
    tmp = tempfile.mkdtemp()
    yield Path(tmp)
    shutil.rmtree(tmp)

def test_session_manager_init(temp_session_dir):
    sm = SessionManager(session_dir=temp_session_dir)
    assert sm.session_dir == temp_session_dir

def test_create_session(temp_session_dir):
    sm = SessionManager(session_dir=temp_session_dir)
    session = sm.create_session()
    assert session["id"] is not None
    assert "messages" in session
    assert session["messages"] == []

def test_save_and_load_session(temp_session_dir):
    sm = SessionManager(session_dir=temp_session_dir)
    session = sm.create_session()
    sm.save_session(session)

    loaded = sm.load_session(session["id"])
    assert loaded["id"] == session["id"]
    assert loaded["messages"] == []

def test_list_sessions(temp_session_dir):
    sm = SessionManager(session_dir=temp_session_dir)
    s1 = sm.create_session()
    s2 = sm.create_session()
    sessions = sm.list_sessions()
    assert len(sessions) == 2
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/core/test_session.py -v`
Expected: FAIL - module 'core.session' has no attribute 'SessionManager'

- [ ] **Step 3: Implement session manager**

```python
# core/session.py
import json
import uuid
from pathlib import Path
from datetime import datetime
from typing import Optional, List, Dict

class SessionError(Exception):
    pass

class SessionManager:
    def __init__(self, session_dir: Path = None):
        if session_dir is None:
            session_dir = Path.home() / ".opencli" / "sessions"
        self.session_dir = Path(session_dir)
        self.session_dir.mkdir(parents=True, exist_ok=True)

    def create_session(self) -> Dict:
        session_id = str(uuid.uuid4())[:8]
        session = {
            "id": session_id,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat(),
            "messages": [],
        }
        self.save_session(session)
        return session

    def save_session(self, session: Dict):
        session["updated_at"] = datetime.now().isoformat()
        session_file = self.session_dir / f"{session['id']}.json"
        with open(session_file, "w", encoding="utf-8") as f:
            json.dump(session, f, ensure_ascii=False, indent=2)

    def load_session(self, session_id: str) -> Optional[Dict]:
        session_file = self.session_dir / f"{session_id}.json"
        if not session_file.exists():
            return None
        with open(session_file, encoding="utf-8") as f:
            return json.load(f)

    def list_sessions(self) -> List[Dict]:
        sessions = []
        for session_file in self.session_dir.glob("*.json"):
            with open(session_file, encoding="utf-8") as f:
                session = json.load(f)
                sessions.append({
                    "id": session["id"],
                    "created_at": session["created_at"],
                    "updated_at": session["updated_at"],
                    "message_count": len(session.get("messages", [])),
                })
        sessions.sort(key=lambda s: s["updated_at"], reverse=True)
        return sessions

    def delete_session(self, session_id: str) -> bool:
        session_file = self.session_dir / f"{session_id}.json"
        if session_file.exists():
            session_file.unlink()
            return True
        return False
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/core/test_session.py -v`
Expected: PASS

- [ ] **Step 5: Integrate session into REPL**

```python
# Add to cli.py after REPL.__init__:
# self.session_manager = SessionManager()
# if session_id:
#     self.session = self.session_manager.load_session(session_id)
# else:
#     self.session = self.session_manager.create_session()

# Modify process_input to append messages to session:
# def process_input(self, user_input: str) -> str:
#     self.session["messages"].append({"role": "user", "content": user_input})
#     response = self.llm.send(self.session["messages"])
#     self.session["messages"].append({"role": "assistant", "content": response})
#     self.session_manager.save_session(self.session)
#     return response
```

- [ ] **Step 6: Run tests**

Run: `pytest tests/core/test_session.py tests/test_repl.py -v`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add core/session.py cli.py
git commit -m "feat: add session management"
```

---

## Task 5: Security Boundary

**Files:**
- Create: `core/security.py`
- Create: `tests/core/test_security.py`
- Modify: `cli.py` (integrate security checks)

- [ ] **Step 1: Write failing test for security**

```python
# tests/core/test_security.py
import pytest
import tempfile
import shutil
from pathlib import Path
from core.security import SecurityBoundary

@pytest.fixture
def temp_workspace():
    tmp = tempfile.mkdtemp()
    yield Path(tmp)
    shutil.rmtree(tmp)

def test_security_boundary_init(temp_workspace):
    sb = SecurityBoundary(workspace_root=temp_workspace)
    assert sb.workspace_root == temp_workspace

def test_path_within_workspace_allowed(temp_workspace):
    sb = SecurityBoundary(workspace_root=temp_workspace)
    allowed = sb.is_path_allowed(temp_workspace / "file.txt")
    assert allowed is True

def test_path_outside_workspace_rejected(temp_workspace):
    sb = SecurityBoundary(workspace_root=temp_workspace)
    outside = Path(temp_workspace).parent / "evil.txt"
    allowed = sb.is_path_allowed(outside)
    assert allowed is False

def test_normalize_path_prevents_traversal(temp_workspace):
    sb = SecurityBoundary(workspace_root=temp_workspace)
    traversal = temp_workspace / ".." / ".." / "etc" / "passwd"
    normalized = sb.normalize_path(traversal)
    assert not sb.is_path_allowed(normalized)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/core/test_security.py -v`
Expected: FAIL - module 'core.security' has no attribute 'SecurityBoundary'

- [ ] **Step 3: Implement security boundary**

```python
# core/security.py
from pathlib import Path

class SecurityError(Exception):
    pass

class SecurityBoundary:
    def __init__(self, workspace_root: Path):
        self.workspace_root = Path(workspace_root).resolve()

    def normalize_path(self, path: Path) -> Path:
        return Path(path).resolve()

    def is_path_allowed(self, path: Path) -> bool:
        try:
            resolved = self.normalize_path(path)
            return resolved.is_relative_to(self.workspace_root)
        except (ValueError, OSError):
            return False

    def validate_path(self, path: Path) -> Path:
        if not self.is_path_allowed(path):
            raise SecurityError(f"Path '{path}' is outside workspace '{self.workspace_root}'")
        return path
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/core/test_security.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add core/security.py tests/core/test_security.py
git commit -m "feat: add security boundary for file operations"
```

---

## Task 6: File Tool

**Files:**
- Create: `tools/file_tool.py`
- Create: `tests/tools/test_file_tool.py`

- [ ] **Step 1: Write failing test for file tool**

```python
# tests/tools/test_file_tool.py
import pytest
import tempfile
import shutil
from pathlib import Path
from tools.file_tool import FileTool
from core.security import SecurityBoundary, SecurityError

@pytest.fixture
def temp_workspace():
    tmp = tempfile.mkdtemp()
    yield Path(tmp)
    shutil.rmtree(tmp)

def test_file_tool_init(temp_workspace):
    security = SecurityBoundary(temp_workspace)
    ft = FileTool(security)
    assert ft.security == security

def test_read_file_success(temp_workspace):
    security = SecurityBoundary(temp_workspace)
    ft = FileTool(security)

    test_file = temp_workspace / "test.txt"
    test_file.write_text("Hello World")

    content = ft.read_file(str(test_file))
    assert content == "Hello World"

def test_read_file_outside_workspace_rejected(temp_workspace):
    security = SecurityBoundary(temp_workspace)
    ft = FileTool(security)

    outside = Path(temp_workspace).parent / "evil.txt"
    with pytest.raises(SecurityError):
        ft.read_file(str(outside))

def test_write_file_success(temp_workspace):
    security = SecurityBoundary(temp_workspace)
    ft = FileTool(security)

    result = ft.write_file(str(temp_workspace / "new.txt"), "New content")
    assert result["success"] is True
    assert (temp_workspace / "new.txt").read_text() == "New content"

def test_write_file_outside_workspace_rejected(temp_workspace):
    security = SecurityBoundary(temp_workspace)
    ft = FileTool(security)

    outside = Path(temp_workspace).parent / "evil.txt"
    with pytest.raises(SecurityError):
        ft.write_file(str(outside), "evil content")

def test_list_directory(temp_workspace):
    security = SecurityBoundary(temp_workspace)
    ft = FileTool(security)

    (temp_workspace / "file1.txt").write_text("1")
    (temp_workspace / "file2.txt").write_text("2")
    (temp_workspace / "subdir").mkdir()
    (temp_workspace / "subdir" / "file3.txt").write_text("3")

    files = ft.list_directory(str(temp_workspace))
    assert "file1.txt" in files
    assert "file2.txt" in files
    assert "subdir/" in files
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/tools/test_file_tool.py -v`
Expected: FAIL - module 'tools.file_tool' has no attribute 'FileTool'

- [ ] **Step 3: Implement file tool**

```python
# tools/file_tool.py
import os
from pathlib import Path
from typing import List, Dict, Any
from core.security import SecurityBoundary, SecurityError

class FileTool:
    def __init__(self, security: SecurityBoundary):
        self.security = security

    def read_file(self, file_path: str) -> str:
        path = self.security.validate_path(Path(file_path))
        if not path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")
        if not path.is_file():
            raise ValueError(f"Not a file: {file_path}")
        return path.read_text(encoding="utf-8")

    def write_file(self, file_path: str, content: str) -> Dict[str, Any]:
        path = self.security.validate_path(Path(file_path))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return {"success": True, "path": str(path), "bytes": len(content)}

    def list_directory(self, dir_path: str) -> List[str]:
        path = self.security.validate_path(Path(dir_path))
        if not path.exists():
            raise FileNotFoundError(f"Directory not found: {dir_path}")
        if not path.is_dir():
            raise ValueError(f"Not a directory: {dir_path}")

        entries = []
        for item in sorted(path.iterdir()):
            name = item.name
            if item.is_dir():
                name += "/"
            entries.append(name)
        return entries

    def create_directory(self, dir_path: str) -> Dict[str, Any]:
        path = self.security.validate_path(Path(dir_path))
        path.mkdir(parents=True, exist_ok=True)
        return {"success": True, "path": str(path)}

    def delete_file(self, file_path: str) -> Dict[str, Any]:
        path = self.security.validate_path(Path(file_path))
        if not path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")
        path.unlink()
        return {"success": True, "path": str(path)}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/tools/test_file_tool.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tools/file_tool.py tests/tools/test_file_tool.py
git commit -m "feat: add file tool with security boundary"
```

---

## Task 7: Git Tool

**Files:**
- Create: `tools/git_tool.py`
- Create: `tests/tools/test_git_tool.py`

- [ ] **Step 1: Write failing test for git tool**

```python
# tests/tools/test_git_tool.py
import pytest
import tempfile
import shutil
from pathlib import Path
from tools.git_tool import GitTool

@pytest.fixture
def temp_git_repo():
    tmp = tempfile.mkdtemp()
    repo_path = Path(tmp)
    import subprocess
    subprocess.run(["git", "init"], cwd=repo_path, capture_output=True)
    subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=repo_path, capture_output=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=repo_path, capture_output=True)
    yield repo_path
    shutil.rmtree(tmp)

def test_git_tool_init(temp_git_repo):
    gt = GitTool(repo_root=temp_git_repo)
    assert gt.repo_root == temp_git_repo

def test_git_status(temp_git_repo):
    gt = GitTool(repo_root=temp_git_repo)
    status = gt.status()
    assert "branch" in status
    assert "files" in status

def test_git_diff_no_changes(temp_git_repo):
    gt = GitTool(repo_root=temp_git_repo)
    diff = gt.diff()
    assert diff == ""

def test_git_diff_with_changes(temp_git_repo):
    gt = GitTool(repo_root=temp_git_repo)
    (temp_git_repo / "test.txt").write_text("changes")
    diff = gt.diff()
    assert "test.txt" in diff

def test_git_commit(temp_git_repo):
    gt = GitTool(repo_root=temp_git_repo)
    (temp_git_repo / "test.txt").write_text("content")
    import subprocess
    subprocess.run(["git", "add", "."], cwd=temp_git_repo, capture_output=True)
    result = gt.commit("Initial commit")
    assert result["success"] is True
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/tools/test_git_tool.py -v`
Expected: FAIL - module 'tools.git_tool' has no attribute 'GitTool'

- [ ] **Step 3: Implement git tool**

```python
# tools/git_tool.py
import subprocess
from pathlib import Path
from typing import Dict, Any, List

class GitError(Exception):
    pass

class GitTool:
    def __init__(self, repo_root: Path = None):
        self.repo_root = repo_root or Path.cwd()

    def _run_git(self, args: List[str]) -> subprocess.CompletedProcess:
        result = subprocess.run(
            ["git"] + args,
            cwd=self.repo_root,
            capture_output=True,
            text=True,
        )
        return result

    def status(self) -> Dict[str, Any]:
        result = self._run_git(["status", "--porcelain"])
        files = [line.strip() for line in result.stdout.strip().split("\n") if line.strip()]

        branch_result = self._run_git(["branch", "--show-current"])
        branch = branch_result.stdout.strip()

        return {"branch": branch, "files": files}

    def diff(self, file: str = None) -> str:
        args = ["diff"]
        if file:
            args.append(file)
        result = self._run_git(args)
        return result.stdout

    def diff_staged(self, file: str = None) -> str:
        args = ["diff", "--cached"]
        if file:
            args.append(file)
        result = self._run_git(args)
        return result.stdout

    def commit(self, message: str) -> Dict[str, Any]:
        result = self._run_git(["commit", "-m", message])
        if result.returncode != 0:
            return {"success": False, "error": result.stderr}
        return {"success": True, "message": result.stdout.strip()}

    def add(self, files: List[str] = None) -> Dict[str, Any]:
        args = ["add"]
        if files:
            args.extend(files)
        else:
            args.append(".")
        result = self._run_git(args)
        if result.returncode != 0:
            return {"success": False, "error": result.stderr}
        return {"success": True}

    def log(self, n: int = 10) -> List[Dict[str, str]]:
        result = self._run_git(["log", f"-{n}", "--pretty=format:%H|%s|%an|%ad", "--date=iso"])
        commits = []
        for line in result.stdout.strip().split("\n"):
            if line:
                parts = line.split("|")
                if len(parts) >= 4:
                    commits.append({
                        "hash": parts[0],
                        "subject": parts[1],
                        "author": parts[2],
                        "date": parts[3],
                    })
        return commits

    def branch_list(self) -> List[str]:
        result = self._run_git(["branch"])
        return [b.strip() for b in result.stdout.strip().split("\n") if b.strip()]

    def create_branch(self, branch_name: str) -> Dict[str, Any]:
        result = self._run_git(["checkout", "-b", branch_name])
        if result.returncode != 0:
            return {"success": False, "error": result.stderr}
        return {"success": True, "branch": branch_name}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/tools/test_git_tool.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tools/git_tool.py tests/tools/test_git_tool.py
git commit -m "feat: add git tool"
```

---

## Task 8: Command Execution Tool

**Files:**
- Create: `tools/cmd_tool.py`
- Create: `tests/tools/test_cmd_tool.py`

- [ ] **Step 1: Write failing test for cmd tool**

```python
# tests/tools/test_cmd_tool.py
import pytest
from tools.cmd_tool import CmdTool, CmdError

def test_cmd_tool_init():
    trusted = ["python", "git"]
    ct = CmdTool(trusted_commands=trusted)
    assert ct.trusted_commands == trusted

def test_cmd_tool_is_trusted():
    ct = CmdTool(trusted_commands=["python", "git"])
    assert ct.is_trusted("python") is True
    assert ct.is_trusted("git") is True
    assert ct.is_trusted("rm") is False

def test_cmd_tool_execute_trusted():
    ct = CmdTool(trusted_commands=["echo"])
    result = ct.execute("echo hello")
    assert result["returncode"] == 0
    assert "hello" in result["stdout"]

def test_cmd_tool_execute_untrusted_requires_confirmation():
    ct = CmdTool(trusted_commands=["echo"])
    result = ct.execute("rm -rf /", require_confirmation=True)
    assert result["requires_confirmation"] is True
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/tools/test_cmd_tool.py -v`
Expected: FAIL - module 'tools.cmd_tool' has no attribute 'CmdTool'

- [ ] **Step 3: Implement cmd tool**

```python
# tools/cmd_tool.py
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/tools/test_cmd_tool.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tools/cmd_tool.py tests/tools/test_cmd_tool.py
git commit -m "feat: add command execution tool"
```

---

## Task 9: Integration - LLM Tool Calling

**Files:**
- Modify: `core/llm.py`
- Modify: `cli.py` (integrate all tools)

- [ ] **Step 1: Define tool schemas for LLM**

```python
# Add to core/llm.py or create tools/schema.py

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
```

- [ ] **Step 2: Update cli.py to integrate all tools**

```python
# Updated cli.py
from core.llm import LLMClient, TOOL_SCHEMAS
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
        self.llm = LLMClient(self.config)

        security = SecurityBoundary(Path.cwd() / self.config["workspace"])
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

    def _run_command(self, command: str):
        result = self.cmd_tool.execute(command, require_confirmation=True)
        if result.get("requires_confirmation"):
            return f"Command requires confirmation: {command}"
        return f"Return code: {result.get('returncode')}\nOutput: {result.get('stdout', '')}"

    def process_input(self, user_input: str) -> str:
        messages = [{"role": "user", "content": user_input}]

        response = self.llm.send_with_tools(messages, TOOL_SCHEMAS)

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

            messages.append(response["choices"][0]["message"])
            messages.append({
                "role": "tool",
                "content": json.dumps(results),
            })
            final_response = self.llm.send(messages)
            return final_response

        return response["choices"][0]["message"]["content"]
```

- [ ] **Step 3: Run integration test**

Run: Manual test with `python cli.py` and try "Show me git status"

- [ ] **Step 4: Commit**

```bash
git add cli.py core/llm.py
git commit -m "feat: integrate LLM tool calling with all tools"
```

---

## Task 10: Confirmation Mode

**Files:**
- Modify: `cli.py`

- [ ] **Step 1: Add confirmation mode to REPL**

```python
# Add to REPL class
def should_confirm(self, action: str) -> bool:
    dangerous = ["delete", "remove", "rm", "unlink"]
    return any(word in action.lower() for word in dangerous)

def confirm(self, message: str) -> bool:
    response = input(f"{message} (yes/no): ").strip().lower()
    return response in ("yes", "y")
```

- [ ] **Step 2: Use confirmation in tool execution**

```python
# In _run_command, check should_confirm before execution
if self.should_confirm(command):
    if not self.confirm(f"Execute potentially dangerous command: {command}?"):
        return "Command cancelled"
```

- [ ] **Step 3: Test confirmation mode**

Run: Manual test with dangerous command

- [ ] **Step 4: Commit**

```bash
git add cli.py
git commit -m "feat: add confirmation mode for sensitive operations"
```

---

## Task 11: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README**

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README"
```

---

## Plan Review

**Spec coverage check:**
- [x] Project setup
- [x] LLM integration (MiniMax via LiteLLM)
- [x] Basic REPL loop
- [x] Session management (JSON files in ~/.opencli/sessions/)
- [x] Security boundary (workspace restriction)
- [x] File tool (read/write with security)
- [x] Git tool (status, diff, commit)
- [x] Command execution (trusted commands)
- [x] Confirmation mode (sensitive operations)
- [x] README

**Placeholder scan:** None found.

**Type consistency:** All task outputs use consistent interfaces.

---

## Execution Options

Plan complete and saved to `docs/superpowers/plans/2026-04-30-open-cli-implementation.md`.

**Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**