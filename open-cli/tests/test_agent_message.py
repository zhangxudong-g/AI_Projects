import pytest
from opencli.messages.messages import AgentMessage, MessageType

def test_agent_message_types():
    msg = AgentMessage(type=MessageType.THINKING, content="Analyzing task")
    assert msg.type == MessageType.THINKING
    assert msg.content == "Analyzing task"

def test_agent_message_to_dict():
    msg = AgentMessage(type=MessageType.TOOL_CALL, content="Calling tool", tool_name="file_read")
    d = msg.to_dict()
    assert d["type"] == "tool_call"
    assert d["tool_name"] == "file_read"
