# tests/agents/test_types.py
import pytest
from opencli.agents.types import AgentType


def test_agent_type_enum_values():
    """Test AgentType enum has correct values."""
    assert AgentType.EXPLORE.value == "explore"
    assert AgentType.PLAN.value == "plan"
    assert AgentType.BUILD.value == "build"
    assert AgentType.GENERAL.value == "general"


def test_agent_type_from_string():
    """Test creating AgentType from string."""
    assert AgentType.from_string("explore") == AgentType.EXPLORE
    assert AgentType.from_string("plan") == AgentType.PLAN
    assert AgentType.from_string("build") == AgentType.BUILD
    assert AgentType.from_string("unknown") == AgentType.GENERAL