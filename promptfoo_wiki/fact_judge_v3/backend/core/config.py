import os
from typing import List, Union
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Engineering Judge v3 API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    # 数据库配置
    DATABASE_URL: str = "sqlite:///./engineering_judge_v3.db"
    
    # 安全配置
    SECRET_KEY: str = os.getenv("SECRET_KEY", "dev-secret-key-change-in-production")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # CORS 配置
    BACKEND_CORS_ORIGINS: List[str] = ["*"]  # 在生产环境中应限制为特定域名
    
    # 任务队列配置
    USE_REDIS: bool = False  # Windows 环境下禁用 Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    
    # 日志配置
    LOG_LEVEL: str = "INFO"
    
    # 额外配置
    model_config = {"extra": "ignore"}  # 忽略额外字段

settings = Settings()