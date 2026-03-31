"""文件操作工具 - 安全的文件读写和管理"""

import os
import logging
from pathlib import Path
from typing import Optional

from app.core.config import get_settings

logger = logging.getLogger(__name__)


def _get_workspace_root() -> Path:
    """获取工作空间根目录"""
    settings = get_settings()
    workspace = Path(settings.workspace_dir)
    workspace.mkdir(parents=True, exist_ok=True)
    return workspace


def _safe_path(path: str) -> Path:
    """确保路径在工作空间内，防止目录穿越攻击"""
    workspace = _get_workspace_root()
    
    # 转换为绝对路径
    target = Path(path)
    if not target.is_absolute():
        target = workspace / target
    
    # 解析并验证路径
    try:
        target = target.resolve()
    except (OSError, ValueError):
        raise ValueError(f"无效的路径：{path}")
    
    # 检查是否在工作空间内
    if not str(target).startswith(str(workspace)):
        raise ValueError(f"路径必须在工作空间内：{path}")
    
    return target


def write_file(path: str, content: str, encoding: str = "utf-8") -> dict:
    """写入文件内容
    
    Args:
        path: 文件路径（相对于 workspace）
        content: 文件内容
        encoding: 文件编码

    Returns:
        操作结果
    """
    try:
        # 验证路径不是目录或空路径
        if not path or path.strip() in ["", ".", "/"]:
            return {
                "success": False,
                "path": str(path),
                "error": "无效的文件路径",
                "message": "文件路径不能为空或目录",
            }
        
        # 确保路径有文件扩展名
        path_obj = Path(path)
        if not path_obj.suffix:
            path = str(path_obj / "output.py")
        
        # 如果路径看起来像目录（包含 .gitignore 等文件名），跳过
        if path in [".gitignore", ".env", "README.md", "requirements.txt"]:
            # 这些是有效文件名，直接写入
            pass
        
        safe_path = _safe_path(path)

        # 创建父目录（处理已存在的情况）
        try:
            safe_path.parent.mkdir(parents=True, exist_ok=True)
        except FileExistsError:
            # 父路径存在且是文件，说明路径冲突
            return {
                "success": False,
                "path": str(path),
                "error": f"路径冲突：{safe_path.parent} 已存在且不是目录",
                "message": "无法创建文件，路径冲突",
            }

        # 写入文件
        safe_path.write_text(content, encoding=encoding)

        logger.info(f"文件已写入：{path}")

        return {
            "success": True,
            "path": str(path),
            "absolute_path": str(safe_path),
            "size": len(content),
            "message": f"成功写入文件：{path}",
        }
    except Exception as e:
        logger.exception(f"写入文件失败：{path}")
        return {
            "success": False,
            "path": str(path),
            "error": str(e),
            "message": f"写入文件失败：{e}",
        }


def read_file(path: str, encoding: str = "utf-8") -> dict:
    """读取文件内容
    
    Args:
        path: 文件路径（相对于 workspace）
        encoding: 文件编码
    
    Returns:
        操作结果和文件内容
    """
    try:
        safe_path = _safe_path(path)
        
        if not safe_path.exists():
            return {
                "success": False,
                "path": str(path),
                "error": "文件不存在",
                "message": f"文件不存在：{path}",
            }
        
        content = safe_path.read_text(encoding=encoding)
        
        logger.info(f"文件已读取：{path}")
        
        return {
            "success": True,
            "path": str(path),
            "content": content,
            "size": len(content),
            "message": f"成功读取文件：{path}",
        }
    except Exception as e:
        logger.exception(f"读取文件失败：{path}")
        return {
            "success": False,
            "path": str(path),
            "error": str(e),
            "message": f"读取文件失败：{e}",
        }


def list_files(path: str = ".", recursive: bool = False) -> dict:
    """列出目录内容
    
    Args:
        path: 目录路径（相对于 workspace）
        recursive: 是否递归列出
    
    Returns:
        操作结果和文件列表
    """
    try:
        safe_path = _safe_path(path)
        
        if not safe_path.exists():
            return {
                "success": False,
                "path": str(path),
                "error": "目录不存在",
                "message": f"目录不存在：{path}",
            }
        
        if not safe_path.is_dir():
            return {
                "success": False,
                "path": str(path),
                "error": "不是目录",
                "message": f"路径不是目录：{path}",
            }
        
        files = []
        if recursive:
            for item in safe_path.rglob("*"):
                rel_path = item.relative_to(safe_path)
                files.append({
                    "path": str(rel_path),
                    "is_dir": item.is_dir(),
                    "size": item.stat().st_size if item.is_file() else 0,
                })
        else:
            for item in safe_path.iterdir():
                rel_path = item.relative_to(safe_path)
                files.append({
                    "path": str(rel_path),
                    "is_dir": item.is_dir(),
                    "size": item.stat().st_size if item.is_file() else 0,
                })
        
        logger.info(f"列出目录：{path}, 共 {len(files)} 个项目")
        
        return {
            "success": True,
            "path": str(path),
            "files": files,
            "count": len(files),
            "message": f"成功列出目录：{path}",
        }
    except Exception as e:
        logger.exception(f"列出目录失败：{path}")
        return {
            "success": False,
            "path": str(path),
            "error": str(e),
            "message": f"列出目录失败：{e}",
        }


def file_exists(path: str) -> dict:
    """检查文件是否存在
    
    Args:
        path: 文件路径（相对于 workspace）
    
    Returns:
        操作结果和是否存在
    """
    try:
        safe_path = _safe_path(path)
        exists = safe_path.exists()
        
        return {
            "success": True,
            "path": str(path),
            "exists": exists,
            "is_file": safe_path.is_file() if exists else False,
            "is_dir": safe_path.is_dir() if exists else False,
            "message": f"文件{'存在' if exists else '不存在'}：{path}",
        }
    except Exception as e:
        logger.exception(f"检查文件失败：{path}")
        return {
            "success": False,
            "path": str(path),
            "error": str(e),
            "message": f"检查文件失败：{e}",
        }


def delete_file(path: str) -> dict:
    """删除文件
    
    Args:
        path: 文件路径（相对于 workspace）
    
    Returns:
        操作结果
    """
    try:
        safe_path = _safe_path(path)
        
        if not safe_path.exists():
            return {
                "success": False,
                "path": str(path),
                "error": "文件不存在",
                "message": f"文件不存在：{path}",
            }
        
        if safe_path.is_dir():
            safe_path.rmdir()
        else:
            safe_path.unlink()
        
        logger.info(f"文件已删除：{path}")
        
        return {
            "success": True,
            "path": str(path),
            "message": f"成功删除文件：{path}",
        }
    except Exception as e:
        logger.exception(f"删除文件失败：{path}")
        return {
            "success": False,
            "path": str(path),
            "error": str(e),
            "message": f"删除文件失败：{e}",
        }


def create_directory(path: str, parents: bool = True) -> dict:
    """创建目录
    
    Args:
        path: 目录路径（相对于 workspace）
        parents: 是否创建父目录
    
    Returns:
        操作结果
    """
    try:
        safe_path = _safe_path(path)
        safe_path.mkdir(parents=parents, exist_ok=True)
        
        logger.info(f"目录已创建：{path}")
        
        return {
            "success": True,
            "path": str(path),
            "absolute_path": str(safe_path),
            "message": f"成功创建目录：{path}",
        }
    except Exception as e:
        logger.exception(f"创建目录失败：{path}")
        return {
            "success": False,
            "path": str(path),
            "error": str(e),
            "message": f"创建目录失败：{e}",
        }


def apply_patch(diff: str, base_path: str = ".") -> dict:
    """应用补丁（简化实现）
    
    Args:
        diff: 补丁内容（统一格式）
        base_path: 基础路径
    
    Returns:
        操作结果
    """
    # TODO: 实现完整的 patch 应用逻辑
    # 目前仅作为占位实现
    logger.warning("apply_patch 尚未完全实现")
    
    return {
        "success": False,
        "error": "NotImplementedError",
        "message": "apply_patch 功能尚未实现，请使用 write_file 代替",
    }
