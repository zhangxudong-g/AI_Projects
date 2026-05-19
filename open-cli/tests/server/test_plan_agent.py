import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.messages.messages import AgentType, Session, Message
from opencli.server.agent import Agent, AgentConfig
from opencli.server.plan_agent import PlanAgent
from opencli.tools.registry import ToolRegistry


class MockProvider:
    @property
    def name(self):
        return "mock"

    @property
    def supports_tools(self):
        return True

    @property
    def supports_streaming(self):
        return True

    async def chat(self, messages, tools=None, **kwargs):
        yield "Plan analysis complete"


class TestPlanAgent:
    def test_plan_agent_inheritance(self):
        config = AgentConfig(agent_type=AgentType.PLAN)
        registry = ToolRegistry()
        provider = MockProvider()
        agent = PlanAgent(config, registry, provider)
        assert isinstance(agent, Agent)

    @pytest.mark.asyncio
    async def test_plan_agent_run(self):
        config = AgentConfig(agent_type=AgentType.PLAN)
        registry = ToolRegistry()
        provider = MockProvider()
        agent = PlanAgent(config, registry, provider)
        
        session = Session(id="test-session", agent_type=AgentType.PLAN)
        chunks = []
        async for chunk in agent.run("Analyze this code", session):
            chunks.append(chunk)
        
        assert len(chunks) == 1
        assert "Plan analysis complete" in chunks[0]
