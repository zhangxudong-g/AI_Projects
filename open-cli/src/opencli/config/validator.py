from pydantic import ValidationError
from .schema import OpenCLIConfig


def validate_config(config: OpenCLIConfig) -> list[str]:
    errors = []
    try:
        for name, provider in config.providers.items():
            if not provider.api_key:
                errors.append(f"Provider '{name}' is missing api_key")
    except ValidationError as e:
        errors.append(str(e))
    return errors
