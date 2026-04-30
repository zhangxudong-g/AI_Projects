"""Simple interactive selector for CLI"""

import sys

class Selector:
    def __init__(self, options: list, prompt: str = "Select:"):
        self.options = options
        self.prompt = prompt
        self.selected = 0

    def run(self) -> str:
        """Run interactive selection. Returns selected option or None."""
        if not self.options:
            return None

        print(f"\n\033[93m? {self.prompt}\033[0m")
        self._display_options()

        while True:
            try:
                key = sys.stdin.read(1)
                if key == '\x1b':  # Arrow key prefix
                    next_key = sys.stdin.read(1)
                    if next_key == '[':
                        direction = sys.stdin.read(1)
                        if direction == 'A':  # Up
                            self.selected = max(0, self.selected - 1)
                        elif direction == 'B':  # Down
                            self.selected = min(len(self.options) - 1, self.selected + 1)
                        self._display_options()
                elif key == '\n' or key == '\r':
                    print(f"\033[2K\rSelected: {self.options[self.selected]}\033[0m")
                    return self.options[self.selected]
                elif ord(key) == 3:  # Ctrl+C
                    print("\n\033[91mCancelled\033[0m")
                    return None
            except KeyboardInterrupt:
                print("\n\033[91mCancelled\033[0m")
                return None

    def _display_options(self):
        """Redraw the selector options."""
        print("\033[2K\r", end='')
        print(f"\n\033[93m? {self.prompt}\033[0m")
        for i, opt in enumerate(self.options):
            marker = "▸" if i == self.selected else " "
            print(f"  {marker} {opt}")
        print("\033[s", end='')  # Save cursor position
