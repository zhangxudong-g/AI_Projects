import pytest
from opencli.agents.types import AgentType
from opencli.agents.config import AgentConfig
from opencli.agents.planner import PlanAgent


def test_plan_agent_creation():
    """Test PlanAgent creation."""
    config = AgentConfig(
        name="plan",
        description="Plan agent",
        allowed_tools=["read_file", "glob", "grep"],
    )
    agent = PlanAgent(config)
    assert agent.name == "plan"


def test_plan_agent_run():
    """Test PlanAgent.run returns AgentResult."""
    import asyncio
    config = AgentConfig(
        name="plan",
        description="Plan agent",
        allowed_tools=["read_file", "glob", "grep"],
    )
    agent = PlanAgent(config)
    result = asyncio.run(agent.run("create a plan"))
    assert isinstance(result.summary, str)
    assert isinstance(result.key_findings, list)
