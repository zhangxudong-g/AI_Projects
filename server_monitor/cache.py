import asyncio
import time
from typing import Any, Dict, Optional, Callable
from threading import Lock
import hashlib
import json
from datetime import datetime, timedelta

class LRUCache:
    """
    LRU (Least Recently Used) 缓存实现
    """
    def __init__(self, capacity: int = 1000, ttl: int = 300):  # 默认容量1000，TTL 5分钟
        self.capacity = capacity
        self.ttl = ttl  # Time To Live (秒)
        self.cache: Dict[str, Dict[str, Any]] = {}
        self.access_order = {}  # 记录访问顺序
        self.lock = Lock()
        self.hits = 0
        self.misses = 0

    def _is_expired(self, timestamp: float) -> bool:
        """检查缓存项是否过期"""
        return time.time() - timestamp > self.ttl

    def get(self, key: str) -> Optional[Any]:
        """获取缓存值"""
        with self.lock:
            if key in self.cache:
                entry = self.cache[key]
                if self._is_expired(entry['timestamp']):
                    # 删除过期项
                    del self.cache[key]
                    del self.access_order[key]
                    self.misses += 1
                    return None
                
                # 更新访问时间
                self.access_order[key] = time.time()
                self.hits += 1
                return entry['value']
            
            self.misses += 1
            return None

    def put(self, key: str, value: Any):
        """设置缓存值"""
        with self.lock:
            # 检查是否已存在，如果是，更新访问时间
            if key in self.cache:
                self.access_order[key] = time.time()
            else:
                # 检查容量限制
                if len(self.cache) >= self.capacity:
                    # 找到最久未使用的项
                    oldest_key = min(self.access_order.keys(), key=lambda k: self.access_order[k])
                    del self.cache[oldest_key]
                    del self.access_order[oldest_key]
            
            # 添加新项
            self.cache[key] = {
                'value': value,
                'timestamp': time.time()
            }
            self.access_order[key] = time.time()

    def delete(self, key: str) -> bool:
        """删除缓存项"""
        with self.lock:
            if key in self.cache:
                del self.cache[key]
                del self.access_order[key]
                return True
            return False

    def clear(self):
        """清空缓存"""
        with self.lock:
            self.cache.clear()
            self.access_order.clear()
            self.hits = 0
            self.misses = 0

    def get_stats(self) -> Dict[str, Any]:
        """获取缓存统计信息"""
        total_requests = self.hits + self.misses
        hit_rate = self.hits / total_requests if total_requests > 0 else 0
        
        return {
            'size': len(self.cache),
            'capacity': self.capacity,
            'hits': self.hits,
            'misses': self.misses,
            'hit_rate': hit_rate,
            'ttl': self.ttl
        }

    def cleanup_expired(self):
        """清理过期的缓存项"""
        with self.lock:
            expired_keys = []
            current_time = time.time()
            
            for key, entry in self.cache.items():
                if current_time - entry['timestamp'] > self.ttl:
                    expired_keys.append(key)
            
            for key in expired_keys:
                del self.cache[key]
                del self.access_order[key]


class CacheManager:
    """
    缓存管理器，提供多种缓存策略
    """
    def __init__(self):
        # 为不同类型的数据创建不同的缓存实例
        self.server_metrics_cache = LRUCache(capacity=500, ttl=60)  # 服务器指标缓存，60秒TTL
        self.history_cache = LRUCache(capacity=200, ttl=300)  # 历史数据缓存，5分钟TTL
        self.analysis_cache = LRUCache(capacity=100, ttl=120)  # 分析结果缓存，2分钟TTL
        self.config_cache = LRUCache(capacity=50, ttl=600)  # 配置缓存，10分钟TTL
        
        # 启动定期清理任务
        self.cleanup_task = None

    async def start_cleanup_task(self):
        """启动定期清理任务"""
        if self.cleanup_task is None:
            self.cleanup_task = asyncio.create_task(self._periodic_cleanup())
    
    async def _periodic_cleanup(self):
        """定期清理过期缓存"""
        while True:
            try:
                await asyncio.sleep(30)  # 每30秒清理一次
                self.server_metrics_cache.cleanup_expired()
                self.history_cache.cleanup_expired()
                self.analysis_cache.cleanup_expired()
                self.config_cache.cleanup_expired()
            except asyncio.CancelledError:
                break
            except Exception as e:
                print(f"Error in cache cleanup: {e}")

    def get_cache_key(self, prefix: str, *args, **kwargs) -> str:
        """
        生成缓存键
        """
        # 将参数转换为字符串并生成哈希值以确保键的唯一性和长度可控
        params_str = f"{prefix}:{args}:{sorted(kwargs.items())}"
        return hashlib.md5(params_str.encode()).hexdigest()

    def get_server_metrics(self, server_name: str, duration_hours: int = 1) -> Optional[Any]:
        """获取服务器指标缓存"""
        key = self.get_cache_key("server_metrics", server_name, duration_hours)
        return self.server_metrics_cache.get(key)

    def set_server_metrics(self, server_name: str, duration_hours: int = 1, data: Any = None):
        """设置服务器指标缓存"""
        key = self.get_cache_key("server_metrics", server_name, duration_hours)
        self.server_metrics_cache.put(key, data)

    def get_history_data(self, server_name: str, start_time: str, end_time: str, limit: int) -> Optional[Any]:
        """获取历史数据缓存"""
        key = self.get_cache_key("history", server_name, start_time, end_time, limit)
        return self.history_cache.get(key)

    def set_history_data(self, server_name: str, start_time: str, end_time: str, limit: int, data: Any):
        """设置历史数据缓存"""
        key = self.get_cache_key("history", server_name, start_time, end_time, limit)
        self.history_cache.put(key, data)

    def get_analysis_data(self, server_name: str, hours: int) -> Optional[Any]:
        """获取分析数据缓存"""
        key = self.get_cache_key("analysis", server_name, hours)
        return self.analysis_cache.get(key)

    def set_analysis_data(self, server_name: str, hours: int, data: Any):
        """设置分析数据缓存"""
        key = self.get_cache_key("analysis", server_name, hours)
        self.analysis_cache.put(key, data)

    def get_config(self, config_name: str) -> Optional[Any]:
        """获取配置缓存"""
        key = self.get_cache_key("config", config_name)
        return self.config_cache.get(key)

    def set_config(self, config_name: str, data: Any):
        """设置配置缓存"""
        key = self.get_cache_key("config", config_name)
        self.config_cache.put(key, data)

    def invalidate_server_metrics(self, server_name: str):
        """使服务器指标缓存失效"""
        # 由于我们使用哈希键，无法直接按前缀删除，所以我们清空整个缓存
        # 在实际应用中，可以维护一个服务器名称到键的映射
        self.server_metrics_cache.clear()

    def get_all_stats(self) -> Dict[str, Any]:
        """获取所有缓存的统计信息"""
        return {
            'server_metrics': self.server_metrics_cache.get_stats(),
            'history': self.history_cache.get_stats(),
            'analysis': self.analysis_cache.get_stats(),
            'config': self.config_cache.get_stats()
        }

    async def close(self):
        """关闭缓存管理器"""
        if self.cleanup_task:
            self.cleanup_task.cancel()
            try:
                await self.cleanup_task
            except asyncio.CancelledError:
                pass


# 全局缓存管理器实例
cache_manager = CacheManager()