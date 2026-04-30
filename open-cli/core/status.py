"""Status bar for CLI"""

class StatusBar:
    def __init__(self):
        self.api_status = "●"
        self.response_time = 0.0
        self.token_count = 0

    def set_api_status(self, connected: bool):
        self.api_status = "●" if connected else "○"

    def set_response_time(self, seconds: float):
        self.response_time = seconds

    def set_token_count(self, count: int):
        self.token_count = count

    def render(self) -> str:
        """Render status bar."""
        return (
            f"\033[90m{self.api_status} Ready\033[0m | "
            f"\033[90m⏱ {self.response_time:.1f}s\033[0m | "
            f"\033[90m💬 {self.token_count:,} tokens\033[0m"
        )