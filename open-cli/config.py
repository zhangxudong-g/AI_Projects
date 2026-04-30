import os
from pathlib import Path

DEFAULT_CONFIG = {
    "minimax_api_key": os.environ.get("MINIMAX_API_KEY", ""),
    "minimax_model": "MiniMax-Text-01",
    "minimax_base_url": "https://api.minimax.chat/v1",
    "workspace": "opencli",
    "trusted_commands": ["git", "python", "pip", "npm", "node", "pytest"],
}

def load_config():
    config = DEFAULT_CONFIG.copy()
    config_dir = Path.home() / ".opencli"
    config_file = config_dir / "config.yaml"
    if config_file.exists():
        import yaml
        with open(config_file) as f:
            user_config = yaml.safe_load(f) or {}
            config.update(user_config)
    return config

def save_config(config):
    config_dir = Path.home() / ".opencli"
    config_dir.mkdir(parents=True, exist_ok=True)
    config_file = config_dir / "config.yaml"
    import yaml
    with open(config_file, "w") as f:
        yaml.dump(config, f)