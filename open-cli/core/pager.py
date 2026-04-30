"""Simple pager for long output"""

import sys

class Pager:
    def __init__(self, lines_per_page: int = 30):
        self.lines_per_page = lines_per_page
        self.current_line = 0

    def write(self, text: str):
        """Write text with paging."""
        lines = text.split('\n')
        for line in lines:
            sys.stdout.write(line + '\n')
            self.current_line += 1
            if self.current_line >= self.lines_per_page:
                self._wait_for_input()

    def _wait_for_input(self):
        """Wait for user input to continue or quit."""
        sys.stdout.write('\033[93m-- More --\033[0m (Space/Enter: next, Q: quit) ')
        sys.stdout.flush()
        key = sys.stdin.read(1)
        if key.lower() == 'q':
            raise KeyboardInterrupt
        self.current_line = 0
        sys.stdout.write('\033[2K\r')

    def close(self):
        pass