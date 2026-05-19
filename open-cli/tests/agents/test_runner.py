# tests/agents/test_runner.py
import pytest
import asyncio
from opencli.agents.types import AgentType
from opencli.agents.runner import AgentRunner

def test_runner_creation():
    """Test AgentRunner creation."""
    runner = AgentRunner()
    assert runner is not None

def test_runner_spawn_explore():
    """Test spawning explore agent."""
    runner = AgentRunner()
    result = asyncio.run(runner.spawn(AgentType.EXPLORE, "find python files"))
    assert result.summary is not None
    assert "explore" in result.summary.lower() or "Explore" in result.summary

def test_runner_spawn_plan():
    """Test spawning plan agent."""
    runner = AgentRunner()
    result = asyncio.run(runner.spawn(AgentType.PLAN, "create a plan"))
    assert result.summary is not None

def test_runner_spawn_build():
    """Test spawning build agent."""
    runner = AgentRunner()
    result = asyncio.run(runner.spawn(AgentType.BUILD, "implement feature"))
    assert result.summary is not None