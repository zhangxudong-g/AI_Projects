import pytest
from opencli.agents.types import AgentType
from opencli.agents.config import AgentConfig
from opencli.agents.explorer import ExploreAgent


def test_explore_agent_creation():
    """Test ExploreAgent creation."""
    config = AgentConfig(
        name="explore",
        description="Explore agent",
        allowed_tools=["read_file", "glob", "grep"],
    )
    agent = ExploreAgent(config)
    assert agent.name == "explore"


def test_explore_agent_run():
    """Test ExploreAgent.run returns AgentResult."""
    import asyncio
    config = AgentConfig(
        name="explore",
        description="Explore agent",
        allowed_tools=["read_file", "glob", "grep"],
    )
    agent = ExploreAgent(config)
    result = asyncio.run(agent.run("find python files"))
    assert isinstance(result.summary, str)
    assert isinstance(result.key_findings, list)
