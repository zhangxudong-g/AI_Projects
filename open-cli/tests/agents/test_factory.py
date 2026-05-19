# tests/agents/test_factory.py
import pytest
from opencli.agents.types import AgentType
from opencli.agents.factory import AgentFactory
from opencli.agents.config import AgentConfig


def test_factory_create_explore():
    """Test creating Explore agent."""
    config = AgentFactory.create(AgentType.EXPLORE)
    assert config.name == "explore"
    assert "read_file" in config.allowed_tools
    assert "write_file" not in config.allowed_tools


def test_factory_create_plan():
    """Test creating Plan agent."""
    config = AgentFactory.create(AgentType.PLAN)
    assert config.name == "plan"
    assert "read_file" in config.allowed_tools
    assert "write_file" not in config.allowed_tools


def test_factory_create_build():
    """Test creating Build agent."""
    config = AgentFactory.create(AgentType.BUILD)
    assert config.name == "build"
    assert "*" in config.allowed_tools or len(config.allowed_tools) > 5


def test_factory_create_with_override():
    """Test creating agent with config override."""
    config = AgentFactory.create(AgentType.EXPLORE, model="custom-model")
    assert config.model == "custom-model"