import yaml
from typing import List, Optional
from pydantic import BaseModel
from pathlib import Path


class ServerConfig(BaseModel):
    name: str
    host: str
    port: int
    username: str
    ssh_key_path: Optional[str] = None
    password: Optional[str] = None
    sudo_password: Optional[str] = None


class MonitoringConfig(BaseModel):
    refresh_interval: float = 1.0
    gpu_refresh_interval: float = 0.5


class WebhookNotificationConfig(BaseModel):
    url: str = ""
    headers: Optional[dict] = {}
    enabled: bool = False
    timeout: int = 30  # 请求超时时间（秒）


class EmailNotificationConfig(BaseModel):
    smtp_server: str = "smtp.gmail.com"
    smtp_port: int = 587
    username: str
    password: str
    sender_email: str
    recipient_emails: List[str]
    enabled: bool = False
    use_tls: bool = True


class CustomCommandConfig(BaseModel):
    name: str
    command: str
    enabled: bool = True
    interval: int = 60  # 执行间隔（秒）


class OllamaConfig(BaseModel):
    enabled: bool = True
    endpoint: str = "http://localhost:11434"


class MonitoringConfig(BaseModel):
    refresh_interval: float = 1.0
    gpu_refresh_interval: float = 0.5
    custom_commands: List[CustomCommandConfig] = []
    email_notifications: EmailNotificationConfig = EmailNotificationConfig(
        username="",
        password="",
        sender_email="",
        recipient_emails=[]
    )
    webhook_notifications: WebhookNotificationConfig = WebhookNotificationConfig()
    enable_compression: bool = False  # 是否启用数据压缩


class AppConfig(BaseModel):
    servers: List[ServerConfig]
    monitoring: MonitoringConfig
    ollama: OllamaConfig


def load_config(config_path: str = "config.yaml") -> AppConfig:
    """
    从 YAML 文件加载配置
    """
    config_file = Path(config_path)
    
    if not config_file.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_path}")
    
    with open(config_file, 'r', encoding='utf-8') as f:
        config_data = yaml.safe_load(f)
    
    return AppConfig(**config_data)


# 全局配置实例
config = load_config()