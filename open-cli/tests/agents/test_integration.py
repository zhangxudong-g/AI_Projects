# tests/agents/test_integration.py
import pytest
import asyncio
from opencli.agents import AgentRunner, AgentType


def test_explore_delegation_flow():
    """Test the full explore delegation flow."""
    runner = AgentRunner()

    # Spawn explore agent
    result = asyncio.run(runner.spawn(
        AgentType.EXPLORE,
        "find all python files in the project"
    ))

    assert result.summary is not None
    assert result.error is None or "timeout" not in result.error.lower()


def test_plan_delegation_flow():
    """Test the full plan delegation flow."""
    runner = AgentRunner()

    result = asyncio.run(runner.spawn(
        AgentType.PLAN,
        "create a plan for adding authentication"
    ))

    assert result.summary is not None


def test_build_delegation_flow():
    """Test the full build delegation flow."""
    runner = AgentRunner()

    result = asyncio.run(runner.spawn(
        AgentType.BUILD,
        "add a simple hello world function"
    ))

    assert result.summary is not None


def test_agent_timeout():
    """Test that agent timeout works."""
    runner = AgentRunner()

    # Spawn with very short timeout
    result = asyncio.run(runner.spawn(
        AgentType.BUILD,
        "sleep for 100 seconds",  # Won't complete
        timeout=1,
    ))

    # Should get timeout error
    assert result.error is not None
    assert "timeout" in result.error.lower() or "timed out" in result.error.lower()
