import yaml
from pathlib import Path
from .schema import OpenCLIConfig


def load_config() -> OpenCLIConfig:
    config_path = Path.home() / ".opencli" / "config.yaml"
    if config_path.exists():
        with open(config_path) as f:
            data = yaml.safe_load(f) or {}
        return OpenCLIConfig(**data)
    return OpenCLIConfig()
