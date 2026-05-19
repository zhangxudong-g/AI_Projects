import asyncio
import os
from typing import TYPE_CHECKING, Optional, Any

if TYPE_CHECKING:
    from mcp import ClientSession
    from mcp.client.stdio import stdio_client

class MCPClient:
    _instance = None

    def __init__(self):
        self.sessions: dict[str, "ClientSession"] = {}
        self.tools: dict[str, "MCPTool"] = {}

    @classmethod
    def get_instance(cls) -> "MCPClient":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    async def connect(self, name: str, command: list[str], env: Optional[dict] = None) -> bool:
        try:
            from mcp import ClientSession
            from mcp.client.stdio import stdio_client
            process_env = {**os.environ, **(env or {})}
            async with stdio_client(command, env=process_env) as (read, write):
                session = ClientSession(read, write)
                await session.initialize()
                self.sessions[name] = session
                await self._load_tools(name, session)
                return True
        except Exception as e:
            return False

    async def _load_tools(self, server_name: str, session: "ClientSession"):
        from .tools import MCPTool
        try:
            from mcp import ClientSession
            result = await session.list_tools()
            tools = result.tools if hasattr(result, 'tools') else result
            for tool in tools:
                mcp_tool = MCPTool(server_name, tool.name, tool.description, tool.inputSchema)
                self.tools[f"{server_name}/{tool.name}"] = mcp_tool
        except Exception:
            pass

    async def disconnect(self, name: str):
        if name in self.sessions:
            await self.sessions[name].close()
            del self.sessions[name]

    async def call_tool(self, tool_name: str, arguments: dict) -> Any:
        """调用MCP工具"""
        for server_name, session in self.sessions.items():
            if f"{server_name}/{tool_name}" in self.tools:
                result = await session.call_tool(tool_name, arguments)
                return result
        raise ValueError(f"Tool {tool_name} not found")

    async def list_tools(self) -> list:
        return list(self.tools.values())