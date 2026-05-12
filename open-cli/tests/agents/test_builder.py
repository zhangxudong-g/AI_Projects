import pytest
from opencli.agents.types import AgentType
from opencli.agents.config import AgentConfig
from opencli.agents.builder import BuildAgent


def test_build_agent_creation():
    """Test BuildAgent creation."""
    config = AgentConfig(
        name="build",
        description="Build agent",
        allowed_tools=["*"],
    )
    agent = BuildAgent(config)
    assert agent.name == "build"


def test_build_agent_run():
    """Test BuildAgent.run returns AgentResult."""
    import asyncio
    config = AgentConfig(
        name="build",
        description="Build agent",
        allowed_tools=["*"],
    )
    agent = BuildAgent(config)
    result = asyncio.run(agent.run("implement feature"))
    assert isinstance(result.summary, str)
    assert isinstance(result.key_findings, list)
