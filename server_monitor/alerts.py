from dataclasses import dataclass
from typing import Dict, List, Optional, TYPE_CHECKING
from enum import Enum
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

if TYPE_CHECKING:
    from notifications import EmailNotifier, WebhookNotifier

class AlertSeverity(Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

class AlertType(Enum):
    CPU_USAGE = "cpu_usage"
    MEMORY_USAGE = "memory_usage"
    DISK_USAGE = "disk_usage"
    GPU_UTILIZATION = "gpu_utilization"
    TEMPERATURE = "temperature"
    CUSTOM_COMMAND = "custom_command"
    NETWORK_BANDWIDTH = "network_bandwidth"

@dataclass
class AlertRule:
    """告警规则"""
    name: str
    alert_type: AlertType
    threshold_value: float
    severity: AlertSeverity
    enabled: bool = True
    description: str = ""

@dataclass
class Alert:
    """告警信息"""
    id: str
    server_name: str
    alert_type: AlertType
    message: str
    severity: AlertSeverity
    current_value: float
    threshold_value: float
    timestamp: datetime
    acknowledged: bool = False
    acknowledged_by: Optional[str] = None
    acknowledged_at: Optional[datetime] = None

class AlertManager:
    """告警管理器"""
    def __init__(self):
        self.rules: List[AlertRule] = []
        self.active_alerts: List[Alert] = []
        self.history: List[Alert] = []
        self.alert_callbacks = []  # 用于通知回调函数

    def add_rule(self, rule: AlertRule):
        """添加告警规则"""
        self.rules.append(rule)
        logger.info(f"Added alert rule: {rule.name}")

    def remove_rule(self, rule_name: str):
        """移除告警规则"""
        self.rules = [rule for rule in self.rules if rule.name != rule_name]
        logger.info(f"Removed alert rule: {rule_name}")

    def evaluate_metrics(self, server_name: str, metrics_data: Dict):
        """评估指标并触发告警"""
        # 检查CPU使用率
        cpu_percent = metrics_data.get('system_resources', {}).get('cpu_percent')
        if cpu_percent is not None:
            self._check_cpu_usage(server_name, cpu_percent)

        # 检查内存使用率
        memory_used = metrics_data.get('system_resources', {}).get('memory_used')
        memory_total = metrics_data.get('system_resources', {}).get('memory_total')
        if memory_used is not None and memory_total is not None and memory_total > 0:
            memory_percent = (memory_used / memory_total) * 100
            self._check_memory_usage(server_name, memory_percent)

        # 检查磁盘使用率
        disk_info = metrics_data.get('system_resources', {}).get('disk_info', [])
        if disk_info is not None:
            for disk in disk_info:
                if 'percent' in disk:
                    self._check_disk_usage(server_name, disk['percent'], disk.get('mount_point', 'unknown'))

        # 检查GPU使用率
        gpu_info = metrics_data.get('gpu_info', [])
        if gpu_info is not None:
            for gpu in gpu_info:
                if 'utilization' in gpu:
                    self._check_gpu_utilization(server_name, gpu['utilization'], gpu.get('index', 'unknown'))

        # 检查温度
        temp_info = metrics_data.get('system_resources', {}).get('hardware_temp_info', [])
        if temp_info is not None:
            for temp in temp_info:
                if 'temperature' in temp:
                    self._check_temperature(server_name, temp['temperature'], temp.get('sensor_name', 'unknown'))

        # 检查自定义命令
        custom_commands = metrics_data.get('system_resources', {}).get('custom_command_results', [])
        if custom_commands is not None:
            for cmd_result in custom_commands:
                if not cmd_result.get('success', True):
                    self._check_custom_command_failure(server_name, cmd_result)

    def _check_cpu_usage(self, server_name: str, cpu_percent: float):
        """检查CPU使用率"""
        for rule in self.rules:
            if rule.alert_type == AlertType.CPU_USAGE and rule.enabled:
                if cpu_percent >= rule.threshold_value:
                    alert = Alert(
                        id=f"cpu_{server_name}_{datetime.utcnow().timestamp()}",
                        server_name=server_name,
                        alert_type=AlertType.CPU_USAGE,
                        message=f"CPU usage is {cpu_percent:.2f}% which exceeds threshold of {rule.threshold_value}%",
                        severity=rule.severity,
                        current_value=cpu_percent,
                        threshold_value=rule.threshold_value,
                        timestamp=datetime.utcnow()
                    )
                    self._trigger_alert(alert)

    def _check_memory_usage(self, server_name: str, memory_percent: float):
        """检查内存使用率"""
        for rule in self.rules:
            if rule.alert_type == AlertType.MEMORY_USAGE and rule.enabled:
                if memory_percent >= rule.threshold_value:
                    alert = Alert(
                        id=f"memory_{server_name}_{datetime.utcnow().timestamp()}",
                        server_name=server_name,
                        alert_type=AlertType.MEMORY_USAGE,
                        message=f"Memory usage is {memory_percent:.2f}% which exceeds threshold of {rule.threshold_value}%",
                        severity=rule.severity,
                        current_value=memory_percent,
                        threshold_value=rule.threshold_value,
                        timestamp=datetime.utcnow()
                    )
                    self._trigger_alert(alert)

    def _check_disk_usage(self, server_name: str, disk_percent: float, mount_point: str):
        """检查磁盘使用率"""
        for rule in self.rules:
            if rule.alert_type == AlertType.DISK_USAGE and rule.enabled:
                if disk_percent >= rule.threshold_value:
                    alert = Alert(
                        id=f"disk_{server_name}_{mount_point}_{datetime.utcnow().timestamp()}",
                        server_name=server_name,
                        alert_type=AlertType.DISK_USAGE,
                        message=f"Disk usage on {mount_point} is {disk_percent}% which exceeds threshold of {rule.threshold_value}%",
                        severity=rule.severity,
                        current_value=disk_percent,
                        threshold_value=rule.threshold_value,
                        timestamp=datetime.utcnow()
                    )
                    self._trigger_alert(alert)

    def _check_gpu_utilization(self, server_name: str, gpu_util: int, gpu_index: str):
        """检查GPU使用率"""
        for rule in self.rules:
            if rule.alert_type == AlertType.GPU_UTILIZATION and rule.enabled:
                if gpu_util >= rule.threshold_value:
                    alert = Alert(
                        id=f"gpu_{server_name}_{gpu_index}_{datetime.utcnow().timestamp()}",
                        server_name=server_name,
                        alert_type=AlertType.GPU_UTILIZATION,
                        message=f"GPU {gpu_index} utilization is {gpu_util}% which exceeds threshold of {rule.threshold_value}%",
                        severity=rule.severity,
                        current_value=gpu_util,
                        threshold_value=rule.threshold_value,
                        timestamp=datetime.utcnow()
                    )
                    self._trigger_alert(alert)

    def _check_temperature(self, server_name: str, temperature: float, sensor_name: str):
        """检查温度"""
        for rule in self.rules:
            if rule.alert_type == AlertType.TEMPERATURE and rule.enabled:
                if temperature >= rule.threshold_value:
                    alert = Alert(
                        id=f"temp_{server_name}_{sensor_name}_{datetime.utcnow().timestamp()}",
                        server_name=server_name,
                        alert_type=AlertType.TEMPERATURE,
                        message=f"Temperature sensor {sensor_name} is {temperature}°C which exceeds threshold of {rule.threshold_value}°C",
                        severity=rule.severity,
                        current_value=temperature,
                        threshold_value=rule.threshold_value,
                        timestamp=datetime.utcnow()
                    )
                    self._trigger_alert(alert)

    def _check_custom_command_failure(self, server_name: str, cmd_result: Dict):
        """检查自定义命令失败"""
        for rule in self.rules:
            if rule.alert_type == AlertType.CUSTOM_COMMAND and rule.enabled:
                # 对于自定义命令失败类型的告警，只要命令失败就触发
                if not cmd_result.get('success', True):
                    alert = Alert(
                        id=f"custom_cmd_{server_name}_{cmd_result.get('command', 'unknown')}_{datetime.utcnow().timestamp()}",
                        server_name=server_name,
                        alert_type=AlertType.CUSTOM_COMMAND,
                        message=f"Custom command failed: {cmd_result.get('command', 'unknown')}. Error: {cmd_result.get('error_message', 'Unknown error')}",
                        severity=rule.severity,
                        current_value=0,  # 对于失败的命令，当前值设为0
                        threshold_value=0,  # 对于失败的命令，阈值设为0
                        timestamp=datetime.utcnow()
                    )
                    self._trigger_alert(alert)

    def _trigger_alert(self, alert: 'Alert'):
        """触发告警"""
        # 检查是否已存在相同的活跃告警
        existing_alert = next(
            (a for a in self.active_alerts
             if a.server_name == alert.server_name
             and a.alert_type == alert.alert_type
             and a.current_value == alert.current_value),
            None
        )

        if existing_alert:
            # 如果已存在相同告警，不重复触发
            return

        logger.warning(f"Triggering alert: {alert.message}")

        # 添加到活跃告警列表
        self.active_alerts.append(alert)

        # 添加到历史记录
        self.history.append(alert)

        # 获取通知器实例
        try:
            email_notifier, webhook_notifier = get_notifiers()

            # 发送邮件通知
            try:
                email_notifier.send_alert_email(alert)
            except Exception as e:
                logger.error(f"Error sending email notification: {e}")

            # 发送Webhook通知 - 在后台任务中执行
            try:
                import asyncio
                loop = asyncio.get_event_loop()
                if loop.is_running():
                    # 如果事件循环正在运行，创建任务
                    loop.create_task(self._send_webhook_notification(alert, webhook_notifier))
                else:
                    # 如果事件循环未运行，直接运行
                    asyncio.run(self._send_webhook_notification(alert, webhook_notifier))
            except Exception as e:
                logger.error(f"Error scheduling webhook notification: {e}")
        except Exception as e:
            logger.error(f"Error getting notifiers: {e}")

        # 调用所有注册的回调函数
        for callback in self.alert_callbacks:
            try:
                callback(alert)
            except Exception as e:
                logger.error(f"Error in alert callback: {e}")

    async def _send_webhook_notification(self, alert: 'Alert', webhook_notifier: 'WebhookNotifier'):
        """异步发送Webhook通知"""
        try:
            await webhook_notifier.send_alert_webhook(alert)
        except Exception as e:
            logger.error(f"Error sending webhook notification: {e}")

    def acknowledge_alert(self, alert_id: str, user: str = "system"):
        """确认告警"""
        for alert in self.active_alerts:
            if alert.id == alert_id:
                alert.acknowledged = True
                alert.acknowledged_by = user
                alert.acknowledged_at = datetime.utcnow()
                
                # 从活跃告警中移除，移到历史记录
                self.active_alerts.remove(alert)
                self.history.append(alert)
                
                logger.info(f"Alert {alert_id} acknowledged by {user}")
                return True
        
        return False

    def register_callback(self, callback_func):
        """注册告警回调函数"""
        self.alert_callbacks.append(callback_func)

    def get_active_alerts(self) -> List[Alert]:
        """获取活跃告警"""
        return self.active_alerts

    def get_alert_history(self, limit: int = 100) -> List[Alert]:
        """获取告警历史"""
        return self.history[-limit:]

    def clear_resolved_alerts(self):
        """清除已解决的告警"""
        # 这里可以实现逻辑来清除那些指标已回到正常范围的告警
        pass

def get_notifiers():
    """延迟导入通知器以避免循环导入"""
    from notifications import email_notifier, webhook_notifier
    return email_notifier, webhook_notifier

# 创建全局告警管理器实例
alert_manager = AlertManager()

# 预设一些默认告警规则
default_rules = [
    AlertRule("High CPU Usage", AlertType.CPU_USAGE, 80.0, AlertSeverity.HIGH, description="CPU usage exceeds 80%"),
    AlertRule("Critical CPU Usage", AlertType.CPU_USAGE, 95.0, AlertSeverity.CRITICAL, description="CPU usage exceeds 95%"),
    AlertRule("High Memory Usage", AlertType.MEMORY_USAGE, 85.0, AlertSeverity.HIGH, description="Memory usage exceeds 85%"),
    AlertRule("Critical Memory Usage", AlertType.MEMORY_USAGE, 95.0, AlertSeverity.CRITICAL, description="Memory usage exceeds 95%"),
    AlertRule("High Disk Usage", AlertType.DISK_USAGE, 85.0, AlertSeverity.HIGH, description="Disk usage exceeds 85%"),
    AlertRule("Critical Disk Usage", AlertType.DISK_USAGE, 95.0, AlertSeverity.CRITICAL, description="Disk usage exceeds 95%"),
    AlertRule("High GPU Utilization", AlertType.GPU_UTILIZATION, 90.0, AlertSeverity.HIGH, description="GPU utilization exceeds 90%"),
    AlertRule("High Temperature", AlertType.TEMPERATURE, 75.0, AlertSeverity.HIGH, description="Temperature exceeds 75°C"),
    AlertRule("Critical Temperature", AlertType.TEMPERATURE, 85.0, AlertSeverity.CRITICAL, description="Temperature exceeds 85°C"),
    AlertRule("Custom Command Failure", AlertType.CUSTOM_COMMAND, 0.0, AlertSeverity.MEDIUM, description="Custom command fails to execute")
]

# 添加默认规则
for rule in default_rules:
    alert_manager.add_rule(rule)