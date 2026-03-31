"""Git 操作工具 - 版本控制管理"""

import logging
from pathlib import Path
from typing import Optional, List

from app.core.config import get_settings
from app.tools.shell_tools import run_command

logger = logging.getLogger(__name__)


def _get_workspace_path() -> Path:
    """获取工作空间路径"""
    settings = get_settings()
    workspace = Path(settings.workspace_dir)
    workspace.mkdir(parents=True, exist_ok=True)
    return workspace


def git_init(path: str = ".") -> dict:
    """初始化 Git 仓库
    
    Args:
        path: 目录路径（相对于 workspace）
    
    Returns:
        操作结果
    """
    workspace = _get_workspace_path()
    target_path = workspace / path
    
    # 确保目录存在
    target_path.mkdir(parents=True, exist_ok=True)
    
    logger.info(f"初始化 Git 仓库：{path}")
    
    result = run_command("git init", cwd=path)
    
    if result["success"]:
        logger.info(f"Git 仓库初始化成功：{path}")
    else:
        logger.warning(f"Git 仓库初始化失败：{path}, {result.get('stderr', '')}")
    
    return result


def git_add(files: List[str], path: str = ".") -> dict:
    """添加文件到 Git 暂存区
    
    Args:
        files: 文件列表
        path: 目录路径（相对于 workspace）
    
    Returns:
        操作结果
    """
    if not files:
        return {
            "success": False,
            "error": "未指定文件",
            "message": "请指定要添加的文件",
        }
    
    files_str = " ".join(files)
    cmd = f"git add {files_str}"
    
    logger.info(f"添加文件到 Git: {files}")
    
    return run_command(cmd, cwd=path)


def git_commit(message: str, path: str = ".") -> dict:
    """提交 Git 变更
    
    Args:
        message: 提交信息
        path: 目录路径（相对于 workspace）
    
    Returns:
        操作结果
    """
    if not message:
        return {
            "success": False,
            "error": "未指定提交信息",
            "message": "请指定提交信息",
        }
    
    # 转义提交信息
    safe_message = message.replace('"', '\\"')
    cmd = f'git commit -m "{safe_message}"'
    
    logger.info(f"Git 提交：{message[:50]}...")
    
    return run_command(cmd, cwd=path)


def git_status(path: str = ".") -> dict:
    """查看 Git 状态
    
    Args:
        path: 目录路径（相对于 workspace）
    
    Returns:
        操作结果和状态信息
    """
    logger.info(f"查看 Git 状态：{path}")
    
    result = run_command("git status", cwd=path)
    
    if result["success"]:
        result["status"] = result.get("stdout", "")
    
    return result


def git_log(limit: int = 5, path: str = ".") -> dict:
    """查看 Git 提交历史
    
    Args:
        limit: 显示条数
        path: 目录路径（相对于 workspace）
    
    Returns:
        操作结果和提交历史
    """
    cmd = f"git log -n {limit} --oneline"
    
    logger.info(f"查看 Git 历史：{path}")
    
    result = run_command(cmd, cwd=path)
    
    if result["success"]:
        result["commits"] = result.get("stdout", "").strip().split("\n")
    
    return result


def git_diff(path: str = ".", cached: bool = False) -> dict:
    """查看 Git 变更
    
    Args:
        path: 目录路径（相对于 workspace）
        cached: 是否查看暂存区变更
    
    Returns:
        操作结果和变更内容
    """
    cmd = "git diff --cached" if cached else "git diff"
    
    logger.info(f"查看 Git 变更：{path}")
    
    result = run_command(cmd, cwd=path)
    
    if result["success"]:
        result["diff"] = result.get("stdout", "")
    
    return result


def git_branch(branch_name: Optional[str] = None, path: str = ".") -> dict:
    """查看或创建 Git 分支
    
    Args:
        branch_name: 分支名称（可选，如果提供则创建分支）
        path: 目录路径（相对于 workspace）
    
    Returns:
        操作结果
    """
    if branch_name:
        cmd = f"git checkout -b {branch_name}"
        logger.info(f"创建并切换分支：{branch_name}")
    else:
        cmd = "git branch"
        logger.info("查看分支列表")
    
    return run_command(cmd, cwd=path)


def git_checkout(branch_name: str, path: str = ".") -> dict:
    """切换 Git 分支
    
    Args:
        branch_name: 分支名称
        path: 目录路径（相对于 workspace）
    
    Returns:
        操作结果
    """
    cmd = f"git checkout {branch_name}"
    
    logger.info(f"切换分支：{branch_name}")
    
    return run_command(cmd, cwd=path)


def git_push(remote: str = "origin", branch: str = "main", path: str = ".") -> dict:
    """推送 Git 变更
    
    Args:
        remote: 远程仓库名
        branch: 分支名
        path: 目录路径（相对于 workspace）
    
    Returns:
        操作结果
    """
    cmd = f"git push {remote} {branch}"
    
    logger.info(f"推送分支：{remote}/{branch}")
    
    return run_command(cmd, cwd=path)


def git_pull(remote: str = "origin", branch: str = "main", path: str = ".") -> dict:
    """拉取 Git 变更
    
    Args:
        remote: 远程仓库名
        branch: 分支名
        path: 目录路径（相对于 workspace）
    
    Returns:
        操作结果
    """
    cmd = f"git pull {remote} {branch}"
    
    logger.info(f"拉取分支：{remote}/{branch}")
    
    return run_command(cmd, cwd=path)
