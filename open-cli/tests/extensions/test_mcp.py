import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
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
        assert "MCP client not initialized" in result.error

    @pytest.mark.asyncio
    async def test_execute_with_server_not_connected(self):
        """Test when MCP client exists but server is not connected"""
        from unittest.mock import patch, MagicMock
        tool = MCPTool("test_server", "test_tool", "A test tool", {})

        # Mock MCPClient.get_instance() to return a client without our server
        mock_client = MagicMock()
        mock_client.sessions = {}  # Empty - server not connected
        with patch('opencli.extensions.mcp.client.MCPClient.get_instance', return_value=mock_client):
            result = await tool.execute()
            assert result.success is False
            assert "server not connected" in result.error
