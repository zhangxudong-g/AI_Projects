import json
from typing import AsyncIterator, Optional
import httpx


class ClientProtocol:
    """Client-Server通信协议"""
    
    def __init__(self, server_url: str = "http://localhost:8000"):
        self.server_url = server_url
        self.ws = None
    
    async def connect(self) -> bool:
        """连接到服务器"""
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{self.server_url}/health")
                return response.status_code == 200
        except Exception:
            return False
    
    async def send_chat(self, prompt: str, agent_type: str = "build") -> AsyncIterator[str]:
        """发送聊天请求"""
        async with httpx.AsyncClient(timeout=30.0) as client:
            async with client.stream(
                "POST",
                f"{self.server_url}/api/v1/chat",
                json={"prompt": prompt, "agent_type": agent_type}
            ) as response:
                async for line in response.aiter_lines():
                    if line:
                        data = json.loads(line)
                        if "content" in data:
                            yield data["content"]
    
    async def create_session(self, agent_type: str = "build") -> Optional[str]:
        """创建新会话"""
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.server_url}/api/v1/session",
                    json={"agent_type": agent_type}
                )
                if response.status_code == 200:
                    return response.json().get("session_id")
        except Exception:
            pass
        return None
