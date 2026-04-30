import asyncio
import os
from typing import TYPE_CHECKING, Optional

if TYPE_CHECKING:
    from mcp import ClientSession
    from mcp.client.stdio import stdio_client

class MCPClient:
    def __init__(self):
        self.sessions: dict[str, "ClientSession"] = {}
        self.tools: dict[str, "MCPTool"] = {}

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

    async def execute_tool(self, server_name: str, tool_name: str, arguments: dict) -> "MCPTool":
        key = f"{server_name}/{tool_name}"
        if key not in self.tools:
            raise ValueError(f"Tool not found: {key}")
        tool = self.tools[key]
        return await tool.execute(session=self.sessions.get(server_name), **arguments)