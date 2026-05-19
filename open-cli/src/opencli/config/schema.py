from pydantic import BaseModel, Field
from typing import Optional


class ProviderConfig(BaseModel):
    type: str = "litellm"
    api_key: str
    base_url: Optional[str] = None
    default_model: str = "claude-3-5-sonnet"


class TrustedFolderConfig(BaseModel):
    path: str
    permissions: list[str] = ["read"]
    recursive: bool = True


class SecurityConfig(BaseModel):
    trusted_folders: list[TrustedFolderConfig] = []
    sandbox_enabled: bool = True


class UIConfig(BaseModel):
    theme: str = "default"
    show_file_explorer: bool = True
    font_size: int = 14


class OpenCLIConfig(BaseModel):
    version: str = "2.0.0"
    providers: dict[str, ProviderConfig] = {}
    security: SecurityConfig = Field(default_factory=SecurityConfig)
    ui: UIConfig = Field(default_factory=UIConfig)
