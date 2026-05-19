import pytest
import json
import asyncio
from io import StringIO
from opencli.agent.engine import AgentEngine, AgentConfig
from opencli.agent.executor import ToolExecutor
from opencli.messages.messages import Session, AgentType, Message, AgentMessage, MessageType
from opencli.tools.registry import ToolRegistry
from opencli.tools.base import BaseTool, ToolDefinition, ToolResult

class MockProvider:
    async def chat(self, messages, tools=None):
        yield "I will execute: file_write(path='test.py')"

class MockFileWriteTool(BaseTool):
    def get_definition(self) -> ToolDefinition:
        return ToolDefinition(name="file_write", description="Write to file", input_schema={})

    async def execute(self, **kwargs) -> ToolResult:
        return ToolResult(success=True, content=f"Written: {kwargs.get('path', 'unknown')}")

@pytest.mark.asyncio
async def test_end_to_end_task():
    registry = ToolRegistry()
    registry.register(MockFileWriteTool())
    executor = ToolExecutor(registry)
    provider = MockProvider()

    config = AgentConfig(provider=provider)
    engine = AgentEngine(config)

    session = Session(id="test", agent_type=AgentType.BUILD)

    messages = []
    async for msg in engine.run("create a test file", session):
        messages.append(msg)

    assert len(messages) > 0
    assert any(m.type.value in ["thinking", "plan", "tool_call"] for m in messages)

@pytest.mark.asyncio
async def test_agent_message_to_dict_serialization():
    msg = AgentMessage(
        type=MessageType.TOOL_CALL,
        content="Executing file_write",
        tool_name="file_write",
        tool_args={"path": "test.py"},
        success=True
    )

    d = msg.to_dict()
    assert d["type"] == "tool_call"
    assert d["tool_name"] == "file_write"
    assert d["success"] is True
    assert json.dumps(d)
