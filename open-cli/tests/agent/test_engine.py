import pytest
from opencli.agent.engine import AgentEngine, AgentConfig
from opencli.messages.messages import Session, AgentType, Message

@pytest.fixture
def mock_provider():
    class MockProvider:
        async def chat(self, messages, tools=None):
            yield "I will create a file."

    return MockProvider()

@pytest.mark.asyncio
async def test_engine_run_returns_stream(mock_provider):
    config = AgentConfig(provider=mock_provider)
    engine = AgentEngine(config)

    session = Session(id="test", agent_type=AgentType.BUILD)
    messages = []
    async for msg in engine.run("create a test file", session):
        messages.append(msg)

    assert len(messages) > 0
    assert messages[0].type.value in ["thinking", "plan", "tool_call"]
