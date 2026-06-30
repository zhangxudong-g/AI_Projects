"""
基于 LangChain DeepAgents + MiniMax M3 的本地对话 Agent

使用 MiniMax 的 Anthropic 兼容接口，通过 deepagents 框架构建
一个具备对话记忆、联网搜索、本地文件读写和代码执行能力的智能助手。
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path
from dotenv import load_dotenv

# 加载 .env 中的环境变量（API Key、Base URL）
load_dotenv()

from ddgs import DDGS
from langchain.tools import tool
from deepagents import create_deep_agent
from langgraph.checkpoint.memory import MemorySaver


# ---------------------------------------------------------------------------
# 工作目录：Agent 的文件操作限制在此目录内，防止越权访问
# ---------------------------------------------------------------------------

WORKSPACE = Path(
    os.environ.get("AGENT_WORKSPACE", os.path.join(os.path.dirname(__file__), "workspace"))
).resolve()
WORKSPACE.mkdir(parents=True, exist_ok=True)


def _safe_path(user_path: str) -> Path:
    """将用户传入的路径解析为工作目录内的绝对路径，防止目录穿越。"""
    target = (WORKSPACE / user_path).resolve()
    # 使用 commonpath 精确判断，避免 startswith 对 /workspace vs /workspace_evil 的误判
    try:
        if os.path.commonpath([str(target), str(WORKSPACE)]) != str(WORKSPACE):
            raise ValueError
    except ValueError:
        raise PermissionError(f"路径越权：{user_path}（不允许访问工作目录以外的文件）")
    return target


# ---------------------------------------------------------------------------
# 联网搜索工具
# ---------------------------------------------------------------------------

@tool
def internet_search(
    query: str,
    max_results: int = 5,
    region: str = "cn-zh",
) -> str:
    """在互联网上搜索信息。当用户询问时事新闻、最新数据、技术文档
    或任何需要实时信息的问题时，使用此工具。

    Args:
        query: 搜索关键词，尽量简洁精准
        max_results: 返回结果数量，默认 5 条
        region: 搜索地区，默认 cn-zh（中文）
    """
    try:
        with DDGS() as ddgs:
            results = list(ddgs.text(query, region=region, max_results=max_results))

        if not results:
            return f"未找到与「{query}」相关的搜索结果。"

        output_parts = []
        for i, r in enumerate(results, 1):
            title = r.get("title", "无标题")
            href = r.get("href", "")
            body = r.get("body", "无摘要")
            output_parts.append(f"[{i}] {title}\n    {href}\n    {body}")

        return "\n\n".join(output_parts)

    except Exception as e:
        return f"搜索失败: {e}"


# ---------------------------------------------------------------------------
# 文件读写工具
# ---------------------------------------------------------------------------

@tool
def read_file(path: str) -> str:
    """读取工作目录内的文件内容。

    Args:
        path: 相对于工作目录的文件路径，例如 "notes.txt" 或 "data/report.csv"
    """
    try:
        file_path = _safe_path(path)
        if not file_path.exists():
            return f"文件不存在：{path}"
        if not file_path.is_file():
            return f"路径不是文件：{path}"
        content = file_path.read_text(encoding="utf-8")
        # 限制返回长度，避免上下文溢出
        if len(content) > 8000:
            return content[:8000] + f"\n\n... (文件过长，已截断，共 {len(content)} 字符)"
        return content
    except PermissionError as e:
        return str(e)
    except UnicodeDecodeError:
        return f"无法读取 {path}：该文件不是文本文件（编码非 UTF-8）。"
    except Exception as e:
        return f"读取失败: {e}"


@tool
def write_file(path: str, content: str) -> str:
    """在工作目录内创建或覆盖文件。自动创建所需的子目录。

    Args:
        path: 相对于工作目录的文件路径，例如 "notes.txt" 或 "output/summary.md"
        content: 要写入的文本内容
    """
    try:
        file_path = _safe_path(path)
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_text(content, encoding="utf-8")
        return f"已写入 {path}（{len(content)} 字符）"
    except PermissionError as e:
        return str(e)
    except Exception as e:
        return f"写入失败: {e}"


@tool
def list_files(path: str = ".") -> str:
    """列出工作目录内指定目录下的文件和子目录。

    Args:
        path: 相对于工作目录的目录路径，默认为根目录 "."
    """
    try:
        dir_path = _safe_path(path)
        if not dir_path.exists():
            return f"目录不存在：{path}"
        if not dir_path.is_dir():
            return f"路径不是目录：{path}"

        entries = []
        for item in sorted(dir_path.iterdir()):
            prefix = "[目录]" if item.is_dir() else "[文件]"
            entries.append(f"  {prefix} {item.name}")

        if not entries:
            return f"目录 {path} 为空。"

        return f"目录 {path} 的内容：\n" + "\n".join(entries)
    except PermissionError as e:
        return str(e)
    except Exception as e:
        return f"列出目录失败: {e}"


@tool
def delete_file(path: str) -> str:
    """删除工作目录内的文件或空目录。

    Args:
        path: 相对于工作目录的文件路径
    """
    try:
        file_path = _safe_path(path)
        if not file_path.exists():
            return f"文件不存在：{path}"
        if file_path.is_dir():
            file_path.rmdir()
            return f"已删除目录：{path}"
        file_path.unlink()
        return f"已删除：{path}"
    except PermissionError as e:
        return str(e)
    except OSError as e:
        return f"删除失败: {e}"


# ---------------------------------------------------------------------------
# 代码执行工具
# ---------------------------------------------------------------------------

# 子进程不应继承的敏感环境变量（API Key 等）
_SENSITIVE_KEYS = {
    "ANTHROPIC_API_KEY", "OPENAI_API_KEY", "TAVILY_API_KEY",
    "MINIMAX_API_KEY", "SECRET_KEY", "PASSWORD",
}


def _build_subprocess_env() -> dict:
    """构建子进程环境变量，过滤掉敏感 Key。"""
    return {
        k: v for k, v in os.environ.items()
        if k not in _SENSITIVE_KEYS
    }


@tool
def run_python(code: str, timeout: int = 30) -> str:
    """执行 Python 代码并返回标准输出。代码在工作目录内运行，
    可以读写 workspace 中的文件。适合数学计算、数据处理、脚本运行等场景。

    Args:
        code: 要执行的 Python 代码
        timeout: 最大运行时间（秒），默认 30，最大 120
    """
    timeout = min(max(timeout, 1), 120)

    # 将代码写入临时文件执行，避免 shell 转义问题
    tmp = tempfile.NamedTemporaryFile(
        mode="w", suffix=".py", prefix="_agent_", dir=WORKSPACE,
        delete=False, encoding="utf-8",
    )
    try:
        tmp.write(code)
        tmp.close()

        result = subprocess.run(
            [sys.executable, tmp.name],
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=str(WORKSPACE),
            env={**_build_subprocess_env(), "PYTHONDONTWRITEBYTECODE": "1"},
        )

        stdout = result.stdout
        stderr = result.stderr

        # 截断过长输出
        max_len = 6000
        if len(stdout) > max_len:
            stdout = stdout[:max_len] + "\n... (输出已截断)"

        parts = []
        if stdout:
            parts.append(stdout.rstrip())
        if stderr:
            err_text = stderr[:2000] if len(stderr) > 2000 else stderr
            parts.append(f"[stderr]\n{err_text.rstrip()}")
        if result.returncode != 0 and not stderr:
            parts.append(f"[exit code: {result.returncode}]")

        return "\n\n".join(parts) if parts else "（代码执行成功，无输出）"

    except subprocess.TimeoutExpired:
        return f"代码执行超时（{timeout} 秒），请优化代码或增加 timeout 参数。"
    except Exception as e:
        return f"执行失败: {e}"
    finally:
        try:
            os.unlink(tmp.name)
        except OSError:
            pass


# ---------------------------------------------------------------------------
# Agent 构建
# ---------------------------------------------------------------------------

def build_agent():
    """
    构建并返回一个 Deep Agent 实例。

    - model: 使用 Anthropic 兼容协议调用 MiniMax-M3
    - tools: 联网搜索 + 文件读写 + 代码执行
    - system_prompt: Agent 的角色设定
    - checkpointer: MemorySaver 提供跨轮次对话记忆
    """
    checkpointer = MemorySaver()

    agent = create_deep_agent(
        model="anthropic:MiniMax-M3",
        tools=[internet_search, read_file, write_file, list_files, delete_file, run_python],
        system_prompt=(
            "你是一个高效的智能助手，基于 MiniMax M3 模型驱动。用中文回答。\n\n"

            "## 核心原则\n"
            "- 行动优先：当用户意图可以从对话上下文推断出来时，直接执行操作，不要反复确认或列出选项让用户选择。\n"
            "- 上下文感知：时刻关注对话历史。如果用户刚读了某个文件，随后的修改/更新指令大概率是针对那个文件的。\n"
            "- 简洁回复：回复要简洁直接，避免冗长的列表和不必要的格式化。完成任务后简短说明结果即可。\n"
            "- 诚实：不确定的事情直接说不知道，不要编造信息。\n\n"

            "## 工具使用\n"
            "- internet_search：获取实时信息、新闻、最新数据时主动使用。\n"
            "- read_file / write_file / list_files / delete_file：所有文件操作在 workspace 目录内，路径使用相对路径。\n"
            "- run_python：执行 Python 代码，适合数学计算、数据处理、文件批处理等。代码在 workspace 中运行。\n\n"

            "## 行为示例\n"
            "- 用户先说「读 readme.md」，然后说「加上今天的日期」→ 你应该直接读取 readme.md，追加日期，写入文件。不要问「你想更新什么？」。\n"
            "- 用户说「算一下斐波那契前20项」→ 直接写代码执行，不要先问「你要用递归还是迭代？」。\n"
            "- 搜索后给出整理好的回答并附上来源链接。\n"
        ),
        checkpointer=checkpointer,
    )

    return agent
