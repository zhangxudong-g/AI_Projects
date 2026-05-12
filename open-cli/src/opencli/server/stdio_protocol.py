import json
import sys
import asyncio
from typing import AsyncIterator

class StdioProtocol:
    """JSON-RPC over STDIO协议"""

    async def read_message(self) -> dict:
        """从STDIN读取JSON-RPC消息"""
        line = await asyncio.get_event_loop().run_in_executor(None, sys.stdin.readline)
        return json.loads(line.strip())

    async def write_message(self, message: dict):
        """写入消息到STDOUT"""
        print(json.dumps(message), flush=True)

    async def handle_request(self, message: dict) -> dict:
        """处理请求并返回响应"""
        method = message.get("method")
        params = message.get("params", {})
        msg_id = message.get("id")

        if method == "chat":
            return {"jsonrpc": "2.0", "id": msg_id, "result": {"status": "ok"}}
        elif method == "initialize":
            return {"jsonrpc": "2.0", "id": msg_id, "result": {"protocolVersion": "1.0"}}
        elif method == "tools/list":
            return {"jsonrpc": "2.0", "id": msg_id, "result": {"tools": []}}
        elif method == "tools/call":
            return {"jsonrpc": "2.0", "id": msg_id, "result": {"success": True}}
        else:
            return {"jsonrpc": "2.0", "id": msg_id, "error": {"code": -32601, "message": "Method not found"}}

    async def run_loop(self):
        """主循环"""
        while True:
            try:
                message = await self.read_message()
                response = await self.handle_request(message)
                if response:
                    await self.write_message(response)
            except Exception as e:
                error_response = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": str(e)}}
                await self.write_message(error_response)
