import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from unittest.mock import AsyncMock
from opencli.extensions.mcp.tools import MCPTool
from opencli.tools.base import ToolDefinition, ToolResult

class TestMCPTool:
    def test_tool_definition(self):
        tool = MCPTool("test_server", "test_tool", "A test tool", {"type": "object"})
        defn = tool.get_definition()
        assert defn.name == "test_server/test_tool"
        assert defn.description == "A test tool"
        assert defn.input_schema == {"type": "object"}

    @pytest.mark.asyncio
    async def test_execute_without_session(self):
        tool = MCPTool("test_server", "test_tool", "A test tool", {})
        result = await tool.execute()
        assert result.success is False
        assert "No MCP session" in result.error

    @pytest.mark.asyncio
    async def test_execute_with_mock_session(self):
        tool = MCPTool("test_server", "test_tool", "A test tool", {})
        mock_session = AsyncMock()
        mock_result = AsyncMock()
        mock_result.content = "result content"
        mock_session.call_tool = AsyncMock(return_value=mock_result)

        result = await tool.execute(session=mock_session, arg1="value1")
        assert result.success is True
        assert result.content == "result content"
        mock_session.call_tool.assert_called_once_with("test_tool", arguments={"arg1": "value1"})