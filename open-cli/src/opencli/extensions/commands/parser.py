import re
from typing import Optional

class CommandParser:
    PATTERN = re.compile(r'^/(\w+)(?:\s+(.*))?$')

    def parse(self, input_text: str) -> tuple[Optional[str], Optional[str]]:
        if not input_text:
            return None, None
        match = self.PATTERN.match(input_text.strip())
        if match:
            return match.group(1), match.group(2)
        return None, None

    def is_command(self, input_text: str) -> bool:
        return self.PATTERN.match(input_text.strip()) is not None