import pytest
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

# Skip this test if renderer doesn't exist
# The new architecture uses Rich for rendering
pytest.skip("Renderer module not implemented in new architecture", allow_module_level=True)


def test_render_plain_text():
    from opencli.ui.renderer import MarkdownRenderer
    renderer = MarkdownRenderer()
    result = renderer.render("Hello World")
    assert "Hello World" in result


def test_render_bold():
    from opencli.ui.renderer import MarkdownRenderer
    renderer = MarkdownRenderer()
    result = renderer.render("**bold**")
    assert "\033[1m" in result


def test_render_code_block():
    from opencli.ui.renderer import MarkdownRenderer
    renderer = MarkdownRenderer()
    result = renderer.render("```python\nprint('hi')\n```")
    assert "print('hi')" in result
