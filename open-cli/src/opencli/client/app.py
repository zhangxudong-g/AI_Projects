from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Static, TextArea
from textual import on


class ChatPanel(Static):
    """对话面板"""
    
    def compose(self) -> ComposeResult:
        yield TextArea(id="input", placeholder="Type your message...")


class StatusBar(Static):
    """状态栏"""
    def __init__(self):
        super().__init__()
        self.api_status = "●"
        self.model = ""

    def render(self) -> str:
        return f"[{self.api_status}] Connected | Model: {self.model}"


class OpenCLIApp(App):
    """open-cli TUI应用"""
    CSS = """
    Screen {
        layout: vertical;
    }
    #header {
        height: 3;
    }
    #main {
        height: 1fr;
    }
    #status {
        height: 3;
    }
    """
    
    def compose(self) -> ComposeResult:
        yield Header(id="header")
        yield ChatPanel(id="main")
        yield StatusBar(id="status")
        yield Footer()
