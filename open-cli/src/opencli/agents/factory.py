# src/opencli/agents/factory.py
"""Factory for creating agent configurations."""
from opencli.agents.types import AgentType
from opencli.agents.config import AgentConfig


# Tool definitions per agent type
TOOL_WHITELISTS = {
    AgentType.EXPLORE: ["read_file", "glob", "grep"],
    AgentType.PLAN: ["read_file", "glob", "grep"],
    AgentType.BUILD: ["*"],  # All tools
    AgentType.GENERAL: ["*"],
}

# Default model per agent type
DEFAULT_MODELS = {
    AgentType.EXPLORE: None,  # Use system default (fast/cheap)
    AgentType.PLAN: None,     # Use system default
    AgentType.BUILD: None,   # Use system default
    AgentType.GENERAL: None,
}


class AgentFactory:
    """Factory for creating agent configurations."""

    @staticmethod
    def create(
        agent_type: AgentType,
        model: str | None = None,
        memory_enabled: bool | None = None,
        max_turns: int | None = None,
        timeout: int | None = None,
    ) -> AgentConfig:
        """Create an AgentConfig for the given agent type."""
        config = AgentConfig(
            name=agent_type.value,
            description=f"{agent_type.value.capitalize()} agent",
            allowed_tools=TOOL_WHITELISTS.get(agent_type, ["*"]).copy(),
            model=model or DEFAULT_MODELS.get(agent_type),
            memory_enabled=memory_enabled if memory_enabled is not None else True,
            max_turns=max_turns if max_turns is not None else 10,
            timeout=timeout if timeout is not None else 300,
        )
        return config

    @staticmethod
    def get_tool_whitelist(agent_type: AgentType) -> list[str]:
        """Get the tool whitelist for an agent type."""
        return TOOL_WHITELISTS.get(agent_type, ["*"]).copy()