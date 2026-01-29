import os
import importlib.util
import inspect
from typing import List, Dict, Any, Optional, Callable
from abc import ABC, abstractmethod
from dataclasses import dataclass
import logging

logger = logging.getLogger(__name__)

@dataclass
class PluginMetadata:
    """插件元数据"""
    name: str
    version: str
    author: str
    description: str
    enabled: bool = True

class BasePlugin(ABC):
    """插件基类"""

    def __init__(self, plugin_dir: str):
        self.plugin_dir = plugin_dir
        self.metadata: Optional[PluginMetadata] = None
        self.initialized = False

    @abstractmethod
    def initialize(self) -> bool:
        """初始化插件"""
        pass

    @abstractmethod
    def destroy(self) -> bool:
        """销毁插件"""
        pass

class MonitorPlugin(BasePlugin):
    """监控插件基类"""

    def collect_additional_metrics(self) -> Dict[str, Any]:
        """收集额外的监控指标"""
        return {}

class NotificationPlugin(BasePlugin):
    """通知插件基类"""

    async def send_notification(self, alert_data: Dict[str, Any]) -> bool:
        """发送通知"""
        return True

class DataProcessorPlugin(BasePlugin):
    """数据处理插件基类"""

    def process_data(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """处理数据"""
        return data

class PluginManager:
    """插件管理器"""

    def __init__(self, plugins_dir: str = "plugins"):
        self.plugins_dir = plugins_dir
        self.plugins: Dict[str, BasePlugin] = {}
        self.enabled_plugins: List[str] = []
        self.hooks: Dict[str, List[Callable]] = {}

        # 确保插件目录存在
        os.makedirs(plugins_dir, exist_ok=True)

    def load_plugin_from_file(self, plugin_path: str) -> Optional[BasePlugin]:
        """从文件加载插件"""
        try:
            # 获取文件名（不含扩展名）作为模块名
            module_name = os.path.splitext(os.path.basename(plugin_path))[0]

            # 动态加载模块
            spec = importlib.util.spec_from_file_location(module_name, plugin_path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)

            # 查找继承自BasePlugin的类
            for name, obj in inspect.getmembers(module, inspect.isclass):
                if obj != BasePlugin and issubclass(obj, BasePlugin):
                    # 实例化插件
                    plugin_instance = obj(self.plugins_dir)

                    # 检查插件元数据
                    if hasattr(obj, 'METADATA'):
                        plugin_instance.metadata = obj.METADATA

                    return plugin_instance

            logger.warning(f"No plugin class found in {plugin_path}")
            return None

        except Exception as e:
            logger.error(f"Error loading plugin from {plugin_path}: {e}")
            return None

    def load_plugins(self):
        """加载所有插件"""
        logger.info(f"Loading plugins from {self.plugins_dir}")

        for filename in os.listdir(self.plugins_dir):
            if filename.endswith('.py') and not filename.startswith('__'):
                plugin_path = os.path.join(self.plugins_dir, filename)
                plugin = self.load_plugin_from_file(plugin_path)

                if plugin:
                    plugin_name = plugin.__class__.__name__
                    self.plugins[plugin_name] = plugin
                    logger.info(f"Loaded plugin: {plugin_name}")

    def initialize_plugins(self):
        """初始化所有插件"""
        for plugin_name, plugin in self.plugins.items():
            if hasattr(plugin, 'metadata') and plugin.metadata and not plugin.metadata.enabled:
                continue

            try:
                success = plugin.initialize()
                if success:
                    self.enabled_plugins.append(plugin_name)
                    logger.info(f"Initialized plugin: {plugin_name}")
                else:
                    logger.error(f"Failed to initialize plugin: {plugin_name}")
            except Exception as e:
                logger.error(f"Error initializing plugin {plugin_name}: {e}")

    def register_hook(self, hook_name: str, callback: Callable):
        """注册钩子函数"""
        if hook_name not in self.hooks:
            self.hooks[hook_name] = []
        self.hooks[hook_name].append(callback)

    def trigger_hook(self, hook_name: str, *args, **kwargs) -> List[Any]:
        """触发钩子函数"""
        results = []
        if hook_name in self.hooks:
            for callback in self.hooks[hook_name]:
                try:
                    result = callback(*args, **kwargs)
                    results.append(result)
                except Exception as e:
                    logger.error(f"Error in hook {hook_name} callback: {e}")
        return results

    def get_enabled_plugins(self) -> List[BasePlugin]:
        """获取所有启用的插件"""
        return [self.plugins[name] for name in self.enabled_plugins if name in self.plugins]

    def get_monitor_plugins(self) -> List[MonitorPlugin]:
        """获取所有监控插件"""
        return [plugin for plugin in self.get_enabled_plugins() if isinstance(plugin, MonitorPlugin)]

    def get_notification_plugins(self) -> List[NotificationPlugin]:
        """获取所有通知插件"""
        return [plugin for plugin in self.get_enabled_plugins() if isinstance(plugin, NotificationPlugin)]

    def get_data_processor_plugins(self) -> List[DataProcessorPlugin]:
        """获取所有数据处理插件"""
        return [plugin for plugin in self.get_enabled_plugins() if isinstance(plugin, DataProcessorPlugin)]

    async def collect_additional_metrics(self) -> Dict[str, Any]:
        """收集所有插件的额外指标"""
        all_metrics = {}

        for plugin in self.get_monitor_plugins():
            try:
                plugin_metrics = plugin.collect_additional_metrics()
                all_metrics.update(plugin_metrics)
            except Exception as e:
                logger.error(f"Error collecting metrics from plugin {plugin.__class__.__name__}: {e}")

        return all_metrics

    async def send_notifications(self, alert_data: Dict[str, Any]):
        """通过所有通知插件发送通知"""
        for plugin in self.get_notification_plugins():
            try:
                await plugin.send_notification(alert_data)
            except Exception as e:
                logger.error(f"Error sending notification via plugin {plugin.__class__.__name__}: {e}")

    def process_data_with_plugins(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """使用所有数据处理插件处理数据"""
        processed_data = data.copy()

        for plugin in self.get_data_processor_plugins():
            try:
                processed_data = plugin.process_data(processed_data)
            except Exception as e:
                logger.error(f"Error processing data with plugin {plugin.__class__.__name__}: {e}")

        return processed_data

# 全局插件管理器实例
plugin_manager = PluginManager()