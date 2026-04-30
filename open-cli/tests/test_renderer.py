"""Tests for MarkdownRenderer"""

import pytest
from core.renderer import MarkdownRenderer

def test_render_plain_text():
    renderer = MarkdownRenderer()
    result = renderer.render("Hello World")
    assert "Hello World" in result

def test_render_bold():
    renderer = MarkdownRenderer()
    result = renderer.render("**bold**")
    assert "\033[1m" in result

def test_render_code_block():
    renderer = MarkdownRenderer()
    result = renderer.render("```python\nprint('hi')\n```")
    assert "print('hi')" in result