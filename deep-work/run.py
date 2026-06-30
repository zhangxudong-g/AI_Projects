"""
终端交互入口：在命令行中与 Agent 进行多轮对话

用法：
    python run.py

输入 quit / exit / q 退出对话
Ctrl+C 随时中断当前操作
"""

import os
import sys
import time
import uuid
import threading
from datetime import datetime
from pathlib import Path
from agents import build_agent, WORKSPACE

# Windows 终端启用 ANSI 转义码支持
if sys.platform == "win32":
    os.system("")


# ---------------------------------------------------------------------------
# 等待动画
# ---------------------------------------------------------------------------

class Spinner:
    """终端旋转等待光标，在后台线程中循环显示。"""

    FRAMES = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

    def __init__(self, label: str = "思考中"):
        self._label = label
        self._stop = threading.Event()
        self._thread = None

    def start(self):
        self._stop.clear()
        self._thread = threading.Thread(target=self._spin, daemon=True)
        self._thread.start()

    def stop(self):
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=0.5)
        # 清除当前行的 spinner 文字
        sys.stdout.write("\r" + " " * (len(self._label) + 4) + "\r")
        sys.stdout.flush()

    def _spin(self):
        idx = 0
        while not self._stop.is_set():
            frame = self.FRAMES[idx % len(self.FRAMES)]
            sys.stdout.write(f"\r\033[90m{frame} {self._label}...\033[0m")
            sys.stdout.flush()
            idx += 1
            self._stop.wait(0.08)  # 80ms 一帧


# ---------------------------------------------------------------------------
# 消息解析
# ---------------------------------------------------------------------------

def _is_ai(msg) -> bool:
    t = str(getattr(msg, "type", ""))
    return t == "ai" or "AI" in t


def _get_text(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and block.get("type", "") in ("text", ""):
                parts.append(block.get("text", ""))
            elif isinstance(block, str):
                parts.append(block)
        return "".join(parts)
    return str(content) if content else ""


# ---------------------------------------------------------------------------
# 会话记录器
# ---------------------------------------------------------------------------

SESSIONS_DIR = WORKSPACE / "sessions"
SESSIONS_DIR.mkdir(parents=True, exist_ok=True)


class SessionLogger:
    """将每轮对话实时追加到 Markdown 文件，一次启动一个文件。"""

    def __init__(self):
        now = datetime.now()
        self.path = SESSIONS_DIR / f"session_{now:%Y%m%d_%H%M%S}.md"
        self._f = open(self.path, "w", encoding="utf-8")
        self._f.write(f"# Agent 会话记录\n\n")
        self._f.write(f"> 开始时间：{now:%Y-%m-%d %H:%M:%S}\n\n---\n\n")
        self._f.flush()

    def log_user(self, text: str):
        self._f.write(f"## 用户\n\n{text}\n\n")
        self._f.flush()

    def log_tool(self, name: str):
        self._f.write(f"> ⚙ 调用工具：`{name}`\n\n")
        self._f.flush()

    def log_agent(self, text: str):
        self._f.write(f"## Agent\n\n{text}\n\n---\n\n")
        self._f.flush()

    def close(self):
        self._f.write(f"> 结束时间：{datetime.now():%Y-%m-%d %H:%M:%S}\n")
        self._f.close()


# ---------------------------------------------------------------------------
# 流式输出引擎
# ---------------------------------------------------------------------------

_POLL_INTERVAL = 0.01  # 10ms 轮询间隔，保证流畅


def _collect_stream(agent, user_input, config, buf, lock, sentinel):
    """后台线程：从 agent.stream 收集事件，直接写入共享缓冲。"""
    seen = set()
    try:
        for chunk, _ in agent.stream(
            {"messages": [{"role": "user", "content": user_input}]},
            config=config,
            stream_mode="messages",
        ):
            if not _is_ai(chunk):
                continue

            for tc in getattr(chunk, "tool_calls", None) or []:
                cid = tc.get("id", "")
                if cid and cid not in seen:
                    seen.add(cid)
                    with lock:
                        buf.append(("tool", tc.get("name", "tool")))

            text = _get_text(chunk.content)
            if text:
                with lock:
                    buf.append(("text", text))
    except Exception as e:
        with lock:
            buf.append(("error", str(e)))
    finally:
        sentinel.set()


def _stream_response(agent, user_input: str, config: dict, logger: SessionLogger) -> bool:
    """主线程高频轮询共享缓冲，逐 token 写入终端。"""
    buf = []          # 共享缓冲：[(type, data), ...]
    lock = threading.Lock()
    sentinel = threading.Event()

    threading.Thread(
        target=_collect_stream,
        args=(agent, user_input, config, buf, lock, sentinel),
        daemon=True,
    ).start()

    spinner = Spinner()
    spinner.start()
    spinner_alive = True

    full_response = []
    printed = False
    need_prefix = True

    def _stop_spinner():
        nonlocal spinner_alive
        if spinner_alive:
            spinner.stop()
            spinner_alive = False

    def _write_text(text):
        """将文本片段写入终端。"""
        nonlocal printed, need_prefix
        if need_prefix:
            _stop_spinner()
            sys.stdout.write("\nAgent: ")
            need_prefix = False
        sys.stdout.write(text)
        sys.stdout.flush()
        full_response.append(text)
        printed = True

    def _write_tool(name):
        """写入工具调用提示。"""
        nonlocal printed
        _stop_spinner()
        if printed:
            sys.stdout.write("\n")
            printed = False
        elif need_prefix:
            # 还没输出过任何内容，先清掉 spinner
            sys.stdout.write("\r" + " " * 20 + "\r")
            need_prefix = True  # 后面文本还是要打 Agent:
        sys.stdout.write(f"\033[90m  ⚙ {name}(...)\033[0m\n")
        sys.stdout.flush()

    try:
        while True:
            # 从共享缓冲取出所有就绪事件
            with lock:
                events = buf[:]
                buf.clear()

            for evt, data in events:
                if evt == "text":
                    _write_text(data)
                elif evt == "tool":
                    _write_tool(data)
                    logger.log_tool(data)
                elif evt == "error":
                    _stop_spinner()
                    if printed:
                        sys.stdout.write("\n")
                        printed = False
                    sys.stdout.write(f"\n[错误] {data}\n")
                    sys.stdout.flush()

            if sentinel.is_set() and not buf:
                # 后台线程已结束且缓冲已清空
                with lock:
                    remaining = buf[:]
                    buf.clear()
                for evt, data in remaining:
                    if evt == "text":
                        _write_text(data)
                    elif evt == "tool":
                        _write_tool(data)
                        logger.log_tool(data)
                    elif evt == "error":
                        _stop_spinner()
                        if printed:
                            sys.stdout.write("\n")
                        sys.stdout.write(f"\n[错误] {data}\n")
                        sys.stdout.flush()
                break

            time.sleep(_POLL_INTERVAL)

    finally:
        _stop_spinner()

    # 保存完整回复
    if full_response:
        logger.log_agent("".join(full_response))

    return printed


# ---------------------------------------------------------------------------
# 主循环
# ---------------------------------------------------------------------------

def main():
    print("=" * 50)
    print("  MiniMax M3 Agent (Powered by DeepAgents)")
    print(f"  工作目录: {WORKSPACE}")
    print("  输入消息开始对话，输入 quit/exit/q 退出")
    print("  Ctrl+C 中断当前操作")
    print("=" * 50)
    print()

    agent = build_agent()
    thread_id = str(uuid.uuid4())
    config = {"configurable": {"thread_id": thread_id}}
    logger = SessionLogger()

    while True:
        try:
            user_input = input("你: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n再见！")
            break

        if not user_input:
            continue
        if user_input.lower() in ("quit", "exit", "q"):
            print("再见！")
            break

        try:
            logger.log_user(user_input)

            if not _stream_response(agent, user_input, config, logger):
                sys.stdout.write("\n（无回复）\n")
            sys.stdout.write("\n")
            sys.stdout.flush()

        except KeyboardInterrupt:
            sys.stdout.write("\r" + " " * 20 + "\r")
            print("（已中断）\n")
        except Exception as e:
            sys.stdout.write("\r" + " " * 20 + "\r")
            print(f"\n[错误] 调用失败: {e}\n")

    logger.close()
    print(f"会话已保存: {logger.path}")


if __name__ == "__main__":
    main()
