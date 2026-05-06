import pytest
from opencli.agent.executor import ToolExecutor
from opencli.tools.registry import ToolRegistry
from opencli.tools.base import BaseTool, ToolDefinition, ToolResult

class MockTool(BaseTool):
    def get_definition(self) -> ToolDefinition:
        return ToolDefinition(name="mock_tool", description="Mock tool", input_schema={})

    async def execute(self, **kwargs) -> ToolResult:
        return ToolResult(success=True, content="mock result")

@pytest.mark.asyncio
async def test_executor_executes_tool():
    registry = ToolRegistry()
    registry.register(MockTool())
    executor = ToolExecutor(registry)

    result = await executor.execute("mock_tool", {"arg": "value"})
    assert result.success is True
    assert result.content == "mock result"

@pytest.mark.asyncio
async def test_executor_unknown_tool():
    executor = ToolExecutor(ToolRegistry())
    result = await executor.execute("unknown_tool", {})
    assert result.success is False
    assert "Unknown tool" in result.error
