import os
from pathlib import Path
Key= "sk-cp-q6hyCftIk8An1s5VHPJZYFQOfypT4XVKnIuXoI0rtoqlh8I2h5CE3nbwxwkqErT3cm3CwjL-rGeVvfRiTDCLjHM0wLrTpvxZUPh6uCKWedeUnK0NulTpaPw"
DEFAULT_CONFIG = {
    "anthropic_api_key": os.environ.get("ANTHROPIC_API_KEY", Key),
    "anthropic_base_url": "https://api.minimaxi.com/anthropic",
    "minimax_model": "MiniMax-M2.7",
    "workspace": "opencli",
    "trusted_commands": ["git", "python", "pip", "npm", "node", "pytest", "dir", "ls", "cat", "type", "pwd", "mkdir", "rm", "cp", "mv", "find", "grep"],
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