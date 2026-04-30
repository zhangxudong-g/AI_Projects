from .orchestrator import AgentOrchestrator
from .session import SessionManager
from ..providers.litellm import LiteLLMProvider
from ..tools.registry import ToolRegistry

class Engine:
    def __init__(self, config):
        self.config = config
        self.provider = LiteLLMProvider(
            api_key=config.providers["litellm"].api_key,
            default_model=config.providers["litellm"].default_model
        )
        self.tool_registry = ToolRegistry()
        self.orchestrator = AgentOrchestrator(self.provider, self.tool_registry)
        self.session_manager = SessionManager()
