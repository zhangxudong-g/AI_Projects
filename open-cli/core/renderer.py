"""Markdown renderer for CLI output"""

from markdown import Markdown
from pygments import highlight
from pygments.lexers import get_lexer_by_name, guess_lexer
from pygments.formatters import Terminal256Formatter

class MarkdownRenderer:
    def __init__(self):
        self.md = Markdown(extensions=['tables', 'fenced_code'])

    def render(self, text: str) -> str:
        """Render markdown text to terminal-compatible string."""
        html = self.md.convert(text)
        return self._html_to_ansi(html)

    def _html_to_ansi(self, html: str) -> str:
        """Convert basic HTML to ANSI escape sequences."""
        import re
        text = html
        text = re.sub(r'<b>(.*?)</b>', r'\033[1m\1\033[0m', text)
        text = re.sub(r'<strong>(.*?)</strong>', r'\033[1m\1\033[0m', text)
        text = re.sub(r'<i>(.*?)</i>', r'\033[3m\1\033[0m', text)
        text = re.sub(r'<em>(.*?)</em>', r'\033[3m\1\033[0m', text)
        text = re.sub(r'<code>(.*?)</code>', r'\033[92m\1\033[0m', text)
        text = re.sub(r'<pre><code>(.*?)</code></pre>',
                      lambda m: self._highlight_code(m.group(1)), text, flags=re.DOTALL)
        text = re.sub(r'<br\s*/?>','\n', text)
        text = re.sub(r'</p>', '\n\n', text)
        text = re.sub(r'<[^>]+>', '', text)
        return text

    def _highlight_code(self, code: str) -> str:
        """Highlight code using Pygments."""
        try:
            lexer = guess_lexer(code) if not code.startswith('```') else None
            if lexer:
                return highlight(code, lexer, Terminal256Formatter())
        except:
            pass
        return f'\033[92m{code}\033[0m'

renderer = MarkdownRenderer()