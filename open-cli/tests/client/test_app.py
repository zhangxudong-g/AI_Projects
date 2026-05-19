import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.client.app import OpenCLIApp, ChatPanel, StatusBar


class TestChatPanel:
    def test_chat_panel_compose(self):
        panel = ChatPanel()
        assert panel is not None


class TestStatusBar:
    def test_status_bar_defaults(self):
        bar = StatusBar()
        assert bar.api_status == "●"
        assert bar.model == ""

    def test_status_bar_render(self):
        bar = StatusBar()
        bar.model = "test-model"
        rendered = bar.render()
        assert "●" in rendered
        assert "Connected" in rendered
        assert "test-model" in rendered


class TestOpenCLIApp:
    def test_app_css_defined(self):
        assert OpenCLIApp.CSS is not None
        assert "#header" in OpenCLIApp.CSS
        assert "#main" in OpenCLIApp.CSS
        assert "#status" in OpenCLIApp.CSS
