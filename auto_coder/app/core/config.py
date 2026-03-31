"""配置模块 - 管理所有系统配置"""

import os
from typing import Optional, Literal
from pydantic import Field, AliasChoices
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """全局设置"""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
        protected_namespaces=(),
    )
    
    # 模型配置 - 支持多种环境变量名称
    model_provider: Literal["openai", "ollama"] = Field(
        default="openai",
        validation_alias=AliasChoices(
            "model_provider",
            "MODEL_PROVIDER",
            "provider",
            "MODEL_PROVIDER",
        )
    )
    model_name: str = Field(
        default="gpt-4o",
        validation_alias=AliasChoices(
            "model_name",
            "MODEL_NAME",
            "MODEL_MODEL_NAME",
            "model",
        )
    )
    model_base_url: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices(
            "model_base_url",
            "MODEL_BASE_URL",
            "base_url",
            "MODEL_URL",
        )
    )
    model_api_key: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices(
            "model_api_key",
            "MODEL_API_KEY",
            "api_key",
            "apikey",
        )
    )
    model_temperature: float = Field(
        default=0.7,
        ge=0.0,
        le=2.0,
        validation_alias=AliasChoices(
            "model_temperature",
            "MODEL_TEMPERATURE",
            "temperature",
        )
    )
    model_max_tokens: int = Field(
        default=4096,
        gt=0,
        validation_alias=AliasChoices(
            "model_max_tokens",
            "MODEL_MAX_TOKENS",
            "max_tokens",
        )
    )
    
    # 执行配置
    exec_max_iterations: int = Field(
        default=10,
        gt=0,
        validation_alias=AliasChoices(
            "exec_max_iterations",
            "EXEC_MAX_ITERATIONS",
            "max_iterations",
        )
    )
    exec_max_retries: int = Field(
        default=3,
        ge=0,
        validation_alias=AliasChoices(
            "exec_max_retries",
            "EXEC_MAX_RETRIES",
            "max_retries",
        )
    )
    exec_timeout_seconds: int = Field(
        default=300,
        gt=0,
        validation_alias=AliasChoices(
            "exec_timeout_seconds",
            "EXEC_TIMEOUT_SECONDS",
            "timeout_seconds",
        )
    )
    exec_workspace_dir: str = Field(
        default="workspace",
        validation_alias=AliasChoices(
            "exec_workspace_dir",
            "EXEC_WORKSPACE_DIR",
            "workspace_dir",
            "workspace",
        )
    )
    
    # 日志配置
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = Field(
        default="INFO",
        validation_alias=AliasChoices(
            "log_level",
            "LOG_LEVEL",
            "level",
        )
    )
    log_debug_mode: bool = Field(
        default=False,
        validation_alias=AliasChoices(
            "log_debug_mode",
            "LOG_DEBUG_MODE",
            "debug_mode",
            "debug",
        )
    )
    log_file: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices(
            "log_file",
            "LOG_FILE",
            "logfile",
        )
    )
    
    # 快捷属性
    @property
    def max_iterations(self) -> int:
        return self.exec_max_iterations
    
    @property
    def workspace_dir(self) -> str:
        return os.path.abspath(self.exec_workspace_dir)
    
    @property
    def debug_mode(self) -> bool:
        return self.log_debug_mode
    
    def get_model_config(self) -> dict:
        """获取模型配置字典"""
        return {
            "provider": self.model_provider,
            "model_name": self.model_name,
            "base_url": self.model_base_url,
            "api_key": self.model_api_key,
            "temperature": self.model_temperature,
            "max_tokens": self.model_max_tokens,
        }


# 全局设置实例
settings = Settings()


def get_settings() -> Settings:
    """获取设置实例"""
    return settings
