"""Memory Store - 持久化存储执行历史和生成结果"""

import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict, Any
from dataclasses import dataclass, asdict
from uuid import uuid4

from app.core.config import get_settings

logger = logging.getLogger(__name__)


@dataclass
class ExecutionRecord:
    """执行记录"""
    id: str
    request: str
    status: str
    created_at: str
    completed_at: Optional[str]
    files_generated: List[str]
    errors: List[str]
    iteration_count: int
    metadata: Dict[str, Any]
    
    @classmethod
    def create(
        cls,
        request: str,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> "ExecutionRecord":
        """创建新的执行记录"""
        now = datetime.now().isoformat()
        return cls(
            id=str(uuid4()),
            request=request,
            status="running",
            created_at=now,
            completed_at=None,
            files_generated=[],
            errors=[],
            iteration_count=0,
            metadata=metadata or {},
        )
    
    def complete(
        self,
        status: str,
        files: List[str],
        errors: List[str],
        iterations: int,
    ) -> None:
        """完成执行记录"""
        self.status = status
        self.completed_at = datetime.now().isoformat()
        self.files_generated = files
        self.errors = errors
        self.iteration_count = iterations
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return asdict(self)


@dataclass
class GeneratedProject:
    """生成的项目"""
    id: str
    name: str
    description: str
    execution_id: str
    files: Dict[str, str]  # path -> content
    created_at: str
    updated_at: str
    tags: List[str]
    
    @classmethod
    def create(
        cls,
        name: str,
        execution_id: str,
        files: Dict[str, str],
        description: str = "",
        tags: Optional[List[str]] = None,
    ) -> "GeneratedProject":
        """创建新的项目记录"""
        now = datetime.now().isoformat()
        return cls(
            id=str(uuid4()),
            name=name,
            description=description,
            execution_id=execution_id,
            files=files,
            created_at=now,
            updated_at=now,
            tags=tags or [],
        )
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return asdict(self)


class MemoryStore:
    """记忆存储类
    
    负责保存和检索：
    1. 执行历史
    2. 生成的文件
    3. 错误日志
    4. 项目信息
    """
    
    def __init__(self, storage_dir: Optional[str] = None):
        self.settings = get_settings()
        
        if storage_dir:
            self.storage_path = Path(storage_dir)
        else:
            self.storage_path = Path(self.settings.workspace_dir) / ".memory"
        
        self.storage_path.mkdir(parents=True, exist_ok=True)
        
        # 数据文件路径
        self.history_file = self.storage_path / "history.jsonl"
        self.projects_file = self.storage_path / "projects.json"
        self.errors_file = self.storage_path / "errors.jsonl"
        
        # 内存缓存
        self._history_cache: List[ExecutionRecord] = []
        self._projects_cache: Dict[str, GeneratedProject] = {}
        
        # 加载数据
        self._load()
    
    def _load(self) -> None:
        """加载数据"""
        # 加载历史记录
        if self.history_file.exists():
            with open(self.history_file, "r", encoding="utf-8") as f:
                for line in f:
                    if line.strip():
                        data = json.loads(line)
                        self._history_cache.append(ExecutionRecord(**data))
        
        # 加载项目
        if self.projects_file.exists():
            with open(self.projects_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                for proj_id, proj_data in data.items():
                    self._projects_cache[proj_id] = GeneratedProject(**proj_data)
        
        logger.info(f"加载记忆数据：{len(self._history_cache)} 条历史，{len(self._projects_cache)} 个项目")
    
    def _save_history(self) -> None:
        """保存历史记录"""
        with open(self.history_file, "w", encoding="utf-8") as f:
            for record in self._history_cache:
                f.write(json.dumps(record.to_dict(), ensure_ascii=False) + "\n")
    
    def _save_projects(self) -> None:
        """保存项目数据"""
        data = {k: v.to_dict() for k, v in self._projects_cache.items()}
        with open(self.projects_file, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    
    def add_execution(self, request: str) -> ExecutionRecord:
        """添加执行记录"""
        record = ExecutionRecord.create(request)
        self._history_cache.append(record)
        self._save_history()
        
        logger.info(f"添加执行记录：{record.id}")
        return record
    
    def update_execution(
        self,
        record_id: str,
        status: str,
        files: List[str],
        errors: List[str],
        iterations: int,
    ) -> Optional[ExecutionRecord]:
        """更新执行记录"""
        for record in self._history_cache:
            if record.id == record_id:
                record.complete(status, files, errors, iterations)
                self._save_history()
                
                logger.info(f"更新执行记录：{record_id}, 状态：{status}")
                return record
        
        logger.warning(f"未找到执行记录：{record_id}")
        return None
    
    def get_execution(self, record_id: str) -> Optional[ExecutionRecord]:
        """获取执行记录"""
        for record in self._history_cache:
            if record.id == record_id:
                return record
        return None
    
    def get_executions(
        self,
        limit: int = 10,
        status: Optional[str] = None,
    ) -> List[ExecutionRecord]:
        """获取执行记录列表"""
        records = self._history_cache
        
        if status:
            records = [r for r in records if r.status == status]
        
        # 按创建时间倒序
        records = sorted(records, key=lambda r: r.created_at, reverse=True)
        
        return records[:limit]
    
    def add_error_log(
        self,
        execution_id: str,
        error: str,
        error_type: str = "runtime",
    ) -> None:
        """添加错误日志"""
        error_record = {
            "id": str(uuid4()),
            "execution_id": execution_id,
            "error": error,
            "error_type": error_type,
            "timestamp": datetime.now().isoformat(),
        }
        
        with open(self.errors_file, "a", encoding="utf-8") as f:
            f.write(json.dumps(error_record, ensure_ascii=False) + "\n")
    
    def get_error_logs(
        self,
        execution_id: Optional[str] = None,
        limit: int = 50,
    ) -> List[Dict[str, Any]]:
        """获取错误日志"""
        errors = []
        
        if self.errors_file.exists():
            with open(self.errors_file, "r", encoding="utf-8") as f:
                for line in f:
                    if line.strip():
                        error = json.loads(line)
                        if execution_id is None or error.get("execution_id") == execution_id:
                            errors.append(error)
        
        # 按时间倒序
        errors = sorted(errors, key=lambda e: e.get("timestamp", ""), reverse=True)
        
        return errors[:limit]
    
    def save_project(
        self,
        name: str,
        execution_id: str,
        files: Dict[str, str],
        description: str = "",
        tags: Optional[List[str]] = None,
    ) -> GeneratedProject:
        """保存生成的项目"""
        project = GeneratedProject.create(
            name=name,
            execution_id=execution_id,
            files=files,
            description=description,
            tags=tags,
        )
        
        self._projects_cache[project.id] = project
        self._save_projects()
        
        logger.info(f"保存项目：{project.id}, 名称：{name}")
        return project
    
    def get_project(self, project_id: str) -> Optional[GeneratedProject]:
        """获取项目"""
        return self._projects_cache.get(project_id)
    
    def get_projects(self, limit: int = 10) -> List[GeneratedProject]:
        """获取项目列表"""
        projects = list(self._projects_cache.values())
        
        # 按更新时间倒序
        projects = sorted(projects, key=lambda p: p.updated_at, reverse=True)
        
        return projects[:limit]
    
    def search_projects(self, query: str) -> List[GeneratedProject]:
        """搜索项目"""
        query_lower = query.lower()
        
        results = []
        for project in self._projects_cache.values():
            if (query_lower in project.name.lower() or
                query_lower in project.description.lower() or
                any(query_lower in tag.lower() for tag in project.tags)):
                results.append(project)
        
        return results
    
    def get_stats(self) -> Dict[str, Any]:
        """获取统计信息"""
        total_executions = len(self._history_cache)
        successful = sum(1 for r in self._history_cache if r.status == "completed")
        failed = sum(1 for r in self._history_cache if r.status == "failed")
        
        return {
            "total_executions": total_executions,
            "successful": successful,
            "failed": failed,
            "success_rate": successful / total_executions if total_executions > 0 else 0,
            "total_projects": len(self._projects_cache),
        }


# 全局记忆存储实例
_memory_store: Optional[MemoryStore] = None


def get_memory_store() -> MemoryStore:
    """获取记忆存储实例"""
    global _memory_store
    if _memory_store is None:
        _memory_store = MemoryStore()
    return _memory_store
