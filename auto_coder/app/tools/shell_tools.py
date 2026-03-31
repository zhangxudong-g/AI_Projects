"""Shell 命令工具 - 安全的命令执行"""

import subprocess
import logging
import os
from typing import Optional
from pathlib import Path

from app.core.config import get_settings

logger = logging.getLogger(__name__)

# 危险命令黑名单
DANGEROUS_COMMANDS = [
    "rm -rf",
    "rmdir /s",
    "del /s",
    "format",
    "fdisk",
    "mkfs",
    "dd",
    "chmod -R 777",
    "chown -R",
    "sudo rm",
    "sudo apt remove",
    "sudo yum remove",
    "powershell -command \"Remove-Item",
    "cmd /c del",
    "cmd /c rd",
]

# 允许的命令白名单（部分）
ALLOWED_COMMANDS = [
    "python",
    "python3",
    "pip",
    "pip3",
    "npm",
    "yarn",
    "git",
    "ls",
    "dir",
    "pwd",
    "cd",
    "mkdir",
    "rmdir",
    "cp",
    "copy",
    "mv",
    "move",
    "cat",
    "type",
    "echo",
    "pytest",
    "unittest",
    "node",
    "curl",
    "wget",
]


def _is_safe_command(cmd: str) -> bool:
    """检查命令是否安全"""
    cmd_lower = cmd.lower()

    # 检查黑名单
    for dangerous in DANGEROUS_COMMANDS:
        if dangerous.lower() in cmd_lower:
            return False

    # 检查白名单（第一个词或前两个词）
    parts = cmd.split()
    first_word = parts[0] if parts else ""
    
    # python 命令应该被允许（包括 python -m 和 python 脚本）
    if first_word in ["python", "python3"]:
        return True
    
    if first_word not in ALLOWED_COMMANDS:
        # 如果不是白名单命令，但有危险关键词，也拒绝
        dangerous_keywords = ["rm", "del", "format", "kill", "shutdown"]
        for keyword in dangerous_keywords:
            if keyword in cmd_lower:
                return False
    
    return True


def _get_workspace_path() -> Path:
    """获取工作空间路径"""
    settings = get_settings()
    workspace = Path(settings.workspace_dir)
    workspace.mkdir(parents=True, exist_ok=True)
    return workspace


def run_command(
    cmd: str,
    timeout: int = 60,
    cwd: Optional[str] = None,
    check: bool = False,
) -> dict:
    """运行 Shell 命令
    
    Args:
        cmd: 命令字符串
        timeout: 超时时间（秒）
        cwd: 工作目录
        check: 是否检查返回码
    
    Returns:
        操作结果
    """
    # 安全检查
    if not _is_safe_command(cmd):
        logger.warning(f"检测到危险命令：{cmd}")
        return {
            "success": False,
            "command": cmd,
            "error": "命令被阻止：检测到危险命令",
            "message": "出于安全考虑，该命令被阻止执行",
            "returncode": -1,
        }
    
    try:
        # 设置工作目录
        if cwd is None:
            work_dir = str(_get_workspace_path())
        else:
            work_dir = str(_get_workspace_path() / cwd)
        
        # 确保工作目录存在
        os.makedirs(work_dir, exist_ok=True)
        
        logger.info(f"执行命令：{cmd}, cwd={work_dir}")
        
        # 执行命令
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=work_dir,
            encoding="utf-8",
            errors="replace",
        )
        
        # 记录输出
        if result.stdout:
            logger.debug(f"命令输出：{result.stdout[:500]}")
        if result.stderr:
            logger.debug(f"命令错误：{result.stderr[:500]}")
        
        response = {
            "success": result.returncode == 0,
            "command": cmd,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode,
            "message": f"命令执行{'成功' if result.returncode == 0 else '失败'}",
        }
        
        if check and result.returncode != 0:
            response["error"] = f"命令执行失败，返回码：{result.returncode}"
        
        return response
    
    except subprocess.TimeoutExpired:
        logger.error(f"命令超时：{cmd}")
        return {
            "success": False,
            "command": cmd,
            "error": f"命令执行超时（{timeout}秒）",
            "message": "命令执行超时",
            "returncode": -1,
        }
    except Exception as e:
        logger.exception(f"命令执行失败：{cmd}")
        return {
            "success": False,
            "command": cmd,
            "error": str(e),
            "message": f"命令执行失败：{e}",
            "returncode": -1,
        }


def check_command(cmd: str) -> dict:
    """检查命令是否可用
    
    Args:
        cmd: 命令名称
    
    Returns:
        检查结果
    """
    try:
        # Windows 使用 where，Unix 使用 which
        if os.name == "nt":
            check_cmd = f"where {cmd}"
        else:
            check_cmd = f"which {cmd}"
        
        result = subprocess.run(
            check_cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=5,
        )
        
        available = result.returncode == 0
        
        return {
            "success": True,
            "command": cmd,
            "available": available,
            "path": result.stdout.strip() if available else None,
            "message": f"命令{'可用' if available else '不可用'}：{cmd}",
        }
    except Exception as e:
        logger.exception(f"检查命令失败：{cmd}")
        return {
            "success": False,
            "command": cmd,
            "error": str(e),
            "message": f"检查命令失败：{e}",
        }


def get_python_version() -> dict:
    """获取 Python 版本
    
    Returns:
        版本信息
    """
    return run_command("python --version")
