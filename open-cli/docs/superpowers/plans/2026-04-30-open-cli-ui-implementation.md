# open-cli UI 2.0 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 open-cli 添加富文本 UI，包括增强提示符、Markdown 渲染、键盘快捷键、交互式选择器、分页和状态栏。

**Architecture:** 采用模块化设计，新建 `core/renderer.py` 处理 Markdown 渲染，新建 `core/prompt.py` 处理增强提示符，逐步集成键盘快捷键和状态栏功能。

**Tech Stack:** Python 3.8+, blessed, markdown, Pygments

---

## 文件结构

```
cli.py              # 修改: 集成所有新组件
core/
  __init__.py      # 修改: 导出新模块
  renderer.py      # 新建: Markdown 渲染器
  pager.py         # 新建: 分页器
  status.py        # 新建: 状态栏
tools/
  file_tool.py     # 修改: 添加格式化列表
pyproject.toml     # 修改: 添加依赖
tests/
  test_renderer.py  # 新建: 渲染器测试
  test_pager.py    # 新建: 分页器测试
```

---

## Phase 1: 基础增强

### Task 1: 添加依赖并创建基础模块

**Files:**
- Modify: `pyproject.toml:28-31`
- Create: `core/renderer.py`
- Create: `core/pager.py`
- Create: `core/status.py`

- [ ] **Step 1: 更新 pyproject.toml 添加依赖**

```toml
dependencies = [
    "anthropic>=0.25.0",
    "pyyaml>=6.0",
    "markdown>=3.0",
    "Pygments>=2.0",
    "blessed>=1.0",
]
```

- [ ] **Step 2: 安装新依赖**

Run: `pip install markdown Pygments blessed`

- [ ] **Step 3: 创建 core/renderer.py**

```python
"""Markdown renderer for CLI output"""

from markdown import Markdown
from pygments import highlight
from pygments.lexers import get_lexer_by_name, guess_lexer
from pygments.formatters import Terminal256Formatter

class MarkdownRenderer:
    def __init__(self):
        self.md = Markdown(extensions=['tables', 'fenced_code'])

    def render(self, text: str) -> str:
        """Render markdown text to terminal-compatible string."""
        html = self.md.convert(text)
        return self._html_to_ansi(html)

    def _html_to_ansi(self, html: str) -> str:
        """Convert basic HTML to ANSI escape sequences."""
        import re
        text = html
        text = re.sub(r'<b>(.*?)</b>', r'\033[1m\1\033[0m', text)
        text = re.sub(r'<i>(.*?)</i>', r'\033[3m\1\033[0m', text)
        text = re.sub(r'<code>(.*?)</code>', r'\033[92m\1\033[0m', text)
        text = re.sub(r'<pre><code>(.*?)</code></pre>',
                      lambda m: self._highlight_code(m.group(1)), text, flags=re.DOTALL)
        text = re.sub(r'<br\s*/?>','\n', text)
        text = re.sub(r'</p>', '\n\n', text)
        text = re.sub(r'<[^>]+>', '', text)
        return text

    def _highlight_code(self, code: str) -> str:
        """Highlight code using Pygments."""
        try:
            lexer = guess_lexer(code) if not code.startswith('```') else None
            if lexer:
                return highlight(code, lexer, Terminal256Formatter())
        except:
            pass
        return f'\033[92m{code}\033[0m'

renderer = MarkdownRenderer()
```

- [ ] **Step 4: 创建 core/pager.py**

```python
"""Simple pager for long output"""

import sys

class Pager:
    def __init__(self, lines_per_page: int = 30):
        self.lines_per_page = lines_per_page
        self.current_line = 0

    def write(self, text: str):
        """Write text with paging."""
        lines = text.split('\n')
        for line in lines:
            sys.stdout.write(line + '\n')
            self.current_line += 1
            if self.current_line >= self.lines_per_page:
                self._wait_for_input()

    def _wait_for_input(self):
        """Wait for user input to continue or quit."""
        sys.stdout.write('\033[93m-- More --\033[0m (Space/Enter: next, Q: quit) ')
        sys.stdout.flush()
        key = sys.stdin.read(1)
        if key.lower() == 'q':
            raise KeyboardInterrupt
        self.current_line = 0
        sys.stdout.write('\033[2K\r')

    def close(self):
        pass
```

- [ ] **Step 5: 创建 core/status.py**

```python
"""Status bar for CLI"""

class StatusBar:
    def __init__(self):
        self.api_status = "●"
        self.response_time = 0.0
        self.token_count = 0

    def set_api_status(self, connected: bool):
        self.api_status = "●" if connected else "○"

    def set_response_time(self, seconds: float):
        self.response_time = seconds

    def set_token_count(self, count: int):
        self.token_count = count

    def render(self) -> str:
        """Render status bar."""
        import time
        return (
            f"\033[90m{self.api_status} Ready\033[0m | "
            f"\033[90m⏱ {self.response_time:.1f}s\033[0m | "
            f"\033[90m💬 {self.token_count:,} tokens\033[0m"
        )
```

- [ ] **Step 6: 创建 tests/test_renderer.py**

```python
"""Tests for MarkdownRenderer"""

import pytest
from core.renderer import MarkdownRenderer

def test_render_plain_text():
    renderer = MarkdownRenderer()
    result = renderer.render("Hello World")
    assert "Hello World" in result

def test_render_bold():
    renderer = MarkdownRenderer()
    result = renderer.render("**bold**")
    assert "\033[1m" in result

def test_render_code_block():
    renderer = MarkdownRenderer()
    result = renderer.render("```python\nprint('hi')\n```")
    assert "print('hi')" in result
```

- [ ] **Step 7: 运行测试**

Run: `pytest tests/test_renderer.py -v`
Expected: 3 tests PASS

- [ ] **Step 8: 提交**

```bash
git add pyproject.toml core/renderer.py core/pager.py core/status.py tests/test_renderer.py
git commit -m "feat(ui): add markdown renderer, pager, and status bar modules"
```

---

### Task 2: 增强提示符 (Rich Prompt)

**Files:**
- Modify: `cli.py:97-100`

- [ ] **Step 1: 添加 PromptBuilder 类到 cli.py**

```python
class PromptBuilder:
    def __init__(self, session_id: str = ""):
        self.session_id = session_id[:8] if session_id else ""

    def get_workspace_dir(self) -> str:
        """Get shortened current directory."""
        cwd = Path.cwd().name
        home = Path.home().name
        cwd_str = str(Path.cwd())
        if home in cwd_str:
            cwd = "~/" + cwd_str.split(home)[1].strip("\\/").split("\\")[-1]
        return cwd

    def get_git_branch(self) -> str:
        """Get current git branch."""
        try:
            result = subprocess.run(
                ["git", "rev-parse", "--abbrev-ref", "HEAD"],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                return result.stdout.strip()
        except:
            pass
        return "main"

    def build(self, api_connected: bool = True) -> str:
        """Build rich prompt string."""
        workspace = self.get_workspace_dir()
        branch = self.get_git_branch()
        status = "●" if api_connected else "○"

        lines = [
            f"\033[36m┌─[opencli]─[{workspace}]─[{branch}]─❯\033[0m",
            f"\033[90m│ API: {status}Connected  │  Session: {self.session_id}\033[0m",
            "\033[36m└──────────────────────────────────────────────────\033[0m",
        ]
        return "\n".join(lines) + "\n"
```

- [ ] **Step 2: 在 REPL.__init__ 中初始化 PromptBuilder**

Modify `cli.py:67` after `self.session_manager`:
```python
self.prompt_builder = PromptBuilder(self.session["id"])
```

- [ ] **Step 3: 修改 get_welcome 方法**

Replace `cli.py:97-100`:
```python
def get_welcome(self) -> str:
    prompt = self.prompt_builder.build(self.llm is not None)
    return f"{prompt}{COLORS['cyan']}open-cli{COLORS['reset']} - AI-assisted programming CLI\nType {COLORS['green']}help{COLORS['reset']} for commands."
```

- [ ] **Step 4: 运行测试**

Run: `pytest tests/test_repl.py -v`
Expected: 2 tests PASS

- [ ] **Step 5: 提交**

```bash
git add cli.py
git commit -m "feat(ui): add rich prompt with workspace and git branch"
```

---

### Task 3: 键盘快捷键

**Files:**
- Modify: `cli.py:247-265`

- [ ] **Step 1: 添加信号处理导入**

Add to `cli.py:1-12` imports:
```python
import signal
import select
```

- [ ] **Step 2: 修改 run 方法添加 Ctrl+C 处理**

Replace `cli.py:247-265`:
```python
def run(self):
    self.running = True
    print(self.get_welcome())

    def handle_ctrl_c(signum, frame):
        print(f"\n{COLORS['yellow']}Interrupted. Use 'exit' to quit.{COLORS['reset']}")

    signal.signal(signal.SIGINT, handle_ctrl_c)

    while self.running:
        try:
            import sys
            if sys.platform == 'win32':
                user_input = input(f"\n{COLORS['green']}❯{COLORS['reset']} ")
            else:
                user_input = self._read_line()

            if not user_input.strip():
                continue
            if READLINE_AVAILABLE:
                readline.add_history(user_input)
            self.history.append(user_input)
            response = self.process_input(user_input)
            if response:
                print(response)
        except KeyboardInterrupt:
            print(f"\n{COLORS['yellow']}Use 'exit' to quit.{COLORS['reset']}")
        except EOFError:
            break
    print(f"{COLORS['cyan']}Session ended.{COLORS['reset']}")

def _read_line(self) -> str:
    """Read line with basic key handling."""
    line = ""
    while True:
        char = sys.stdin.read(1)
        if char == '\n' or char == '\r':
            print(char, end='')
            break
        elif char == '\x03':  # Ctrl+C
            raise KeyboardInterrupt
        elif char == '\x0c':  # Ctrl+L
            os.system('cls' if os.name == 'nt' else 'clear')
            print(self.get_welcome(), end='')
        elif char == '\x15':  # Ctrl+U
            print("\r" + " " * 50 + "\r", end='')
            line = ""
        elif char == '\x12':  # Ctrl+R
            print("\n[Search history...] ", end='')
            search = input()
            matches = [h for h in self.history if search in h]
            if matches:
                print(f"Found: {matches[0]}")
                line = matches[0]
            else:
                print("No matches")
        elif char == '\x7f':  # Backspace
            if line:
                line = line[:-1]
                print('\b \b', end='', flush=True)
        else:
            line += char
            print(char, end='', flush=True)
    return line
```

- [ ] **Step 3: 测试手动**

Run: `python cli.py` 并测试 Ctrl+C, Ctrl+L

- [ ] **Step 4: 提交**

```bash
git add cli.py
git commit -m "feat(ui): add keyboard shortcuts (Ctrl+C, Ctrl+L, Ctrl+U, Ctrl+R)"
```

---

## Phase 2: 交互增强

### Task 4: Markdown 渲染集成

**Files:**
- Modify: `cli.py:210-220`

- [ ] **Step 1: 导入 renderer**

Add to `cli.py:6-12`:
```python
from core.renderer import MarkdownRenderer
```

- [ ] **Step 2: 在 REPL.__init__ 初始化 renderer**

Add after `self.history = []`:
```python
self.renderer = MarkdownRenderer()
```

- [ ] **Step 3: 修改 process_input 中的输出渲染**

Replace `cli.py:210-220`:
```python
            # Render AI response with markdown
            if response_text:
                rendered = self.renderer.render(response_text)
                print(rendered)
```

- [ ] **Step 4: 测试**

Run: `python cli.py -p "列出 # 标题格式的列表"`

- [ ] **Step 5: 提交**

```bash
git add cli.py
git commit -m "feat(ui): integrate markdown renderer for AI responses"
```

---

### Task 5: 交互式选择器 (基础版)

**Files:**
- Create: `core/selector.py`
- Modify: `cli.py`

- [ ] **Step 1: 创建 core/selector.py**

```python
"""Simple interactive selector for CLI"""

class Selector:
    def __init__(self, options: list, prompt: str = "Select:"):
        self.options = options
        self.prompt = prompt
        self.selected = 0

    def run(self) -> str:
        """Run interactive selection. Returns selected option or None."""
        print(f"\n\033[93m? {self.prompt}\033[0m")
        for i, opt in enumerate(self.options):
            marker = "▸" if i == self.selected else " "
            print(f"  {marker} {opt}")
        print("\n\033[90mUse ↑↓ to navigate, Enter to confirm, Ctrl+C to cancel\033[0m")

        while True:
            try:
                import sys
                key = sys.stdin.read(1)
                if key == '\x1b':  # Arrow key prefix
                    next_key = sys.stdin.read(1)
                    if next_key == '[':
                        direction = sys.stdin.read(1)
                        if direction == 'A':  # Up
                            self.selected = max(0, self.selected - 1)
                        elif direction == 'B':  # Down
                            self.selected = min(len(self.options) - 1, self.selected + 1)
                        self._redraw()
                elif key == '\n' or key == '\r':
                    print(f"\033[2K\rSelected: {self.options[self.selected]}")
                    return self.options[self.selected]
                elif ord(key) == 3:  # Ctrl+C
                    print("\n\033[91mCancelled\033[0m")
                    return None
            except KeyboardInterrupt:
                print("\n\033[91mCancelled\033[0m")
                return None

    def _redraw(self):
        """Redraw the selector."""
        print("\033[2K\r", end='')
        print(f"\n\033[93m? {self.prompt}\033[0m")
        for i, opt in enumerate(self.options):
            marker = "▸" if i == self.selected else " "
            print(f"  {marker} {opt}")
        print("\033[s", end='')  # Save cursor
```

- [ ] **Step 2: 在 REPL 中添加选择方法**

Add to `cli.py` after `get_help`:
```python
    def interactive_select(self, options: list, prompt: str = "选择:") -> str:
        """Show interactive selector."""
        selector = Selector(options, prompt)
        return selector.run()
```

- [ ] **Step 3: 当用户输入模糊时使用选择器**

Modify `process_input` to detect ambiguous requests:
```python
    def process_input(self, user_input: str) -> str:
        # ... existing code ...

        # If user seems to want to do something but it's unclear
        if "?" in user_input or "怎么做" in user_input:
            # Could offer interactive help here
            pass
```

- [ ] **Step 4: 测试**

Run: `python cli.py` - 需要手动测试

- [ ] **Step 5: 提交**

```bash
git add core/selector.py cli.py
git commit -m "feat(ui): add basic interactive selector"
```

---

## Phase 3: 状态和优化

### Task 6: API 状态栏

**Files:**
- Modify: `cli.py`

- [ ] **Step 1: 初始化 StatusBar**

Add to `REPL.__init__`:
```python
from core.status import StatusBar
```

Add after `self.renderer`:
```python
self.status_bar = StatusBar()
```

- [ ] **Step 2: 修改输出显示状态栏**

Modify `process_input` at the end before returning:
```python
        if response_text:
            print(f"\n{self.status_bar.render()}")

        return response_text
```

- [ ] **Step 3: 更新状态栏**

Modify `process_input` after getting response:
```python
            self.status_bar.set_response_time(response_time)
            self.status_bar.set_token_count(len(response_text) // 4)  # Rough estimate
```

- [ ] **Step 4: 测试**

Run: `python cli.py -p "你好"`

- [ ] **Step 5: 提交**

```bash
git add cli.py
git commit -m "feat(ui): add API status bar with response time"
```

---

### Task 7: 最终测试和文档

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 运行所有测试**

Run: `pytest tests/ -v`
Expected: All tests PASS

- [ ] **Step 2: 更新 README 添加新功能说明**

Add to README.md:
```markdown
## UI Features

### Rich Prompt
```
┌─[opencli]─[~/projects/open-cli]─[main]─❯
│ API: ●Connected  │  Session: a1b2c3d4
└──────────────────────────────────────────────────
```

### Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| Ctrl+C | Interrupt AI |
| Ctrl+L | Clear screen |
| Ctrl+U | Delete line |
| Ctrl+R | Search history |

### Markdown Rendering
AI responses support Markdown formatting with code syntax highlighting.
```

- [ ] **Step 3: 提交**

```bash
git add README.md
git commit -m "docs: add UI features to README"
```

---

## 实施总结

| Task | 描述 | 预估时间 |
|------|------|----------|
| 1 | 基础模块 (renderer, pager, status) | 15分钟 |
| 2 | 增强提示符 | 10分钟 |
| 3 | 键盘快捷键 | 15分钟 |
| 4 | Markdown 渲染集成 | 10分钟 |
| 5 | 交互式选择器 | 15分钟 |
| 6 | API 状态栏 | 10分钟 |
| 7 | 测试和文档 | 15分钟 |

**总计:** 约 1.5 小时

---

**Plan complete and saved to `docs/superpowers/plans/2026-04-30-open-cli-ui-implementation.md`**

**Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
