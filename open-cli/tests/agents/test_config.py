# tests/agents/test_config.py
import pytest
from opencli.agents.config import AgentConfig


def test_agent_config_creation():
    """Test AgentConfig creation with defaults."""
    config = AgentConfig(
        name="test",
        description="Test agent",
        allowed_tools=["read_file"],
    )
    assert config.name == "test"
    assert config.denied_tools == []
    assert config.memory_enabled is True
    assert config.max_turns == 10
    assert config.timeout == 300


def test_agent_config_all_fields():
    """Test AgentConfig with all fields."""
    config = AgentConfig(
        name="test",
        description="Test agent",
        allowed_tools=["read_file"],
        denied_tools=["write_file"],
        model="test-model",
        memory_enabled=False,
        max_turns=5,
        timeout=60,
    )
    assert config.model == "test-model"
    assert config.memory_enabled is False
    assert config.max_turns == 5
    assert config.timeout == 60