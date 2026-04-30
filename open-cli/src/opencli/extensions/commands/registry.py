from dataclasses import dataclass, field
from typing import Optional

@dataclass
class CustomCommand:
    name: str
    description: str
    prompt_template: str
    aliases: list[str] = field(default_factory=list)

class CommandRegistry:
    def __init__(self):
        self.commands: dict[str, CustomCommand] = {}

    def register(self, command: CustomCommand):
        self.commands[command.name] = command
        for alias in (command.aliases or []):
            self.commands[alias] = command

    def get(self, name: str) -> Optional[CustomCommand]:
        return self.commands.get(name)

    def list_all(self) -> list[CustomCommand]:
        return list(self.commands.values())

    def __len__(self) -> int:
        return len(self.commands)