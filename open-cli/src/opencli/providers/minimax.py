import httpx
import json
from typing import AsyncIterator, Optional
from .base import BaseProvider
from ..messages.messages import Message, ContentBlock


class MiniMaxProvider(BaseProvider):
    def __init__(
        self,
        api_key: str,
        default_model: str = "MiniMax-M2.7",
        base_url: str = "https://api.minimaxi.com/v1/text/chatcompletion_v2"
    ):
        self.api_key = api_key
        self.default_model = default_model
        self.base_url = base_url
        self._client = httpx.AsyncClient(timeout=120.0)

    @property
    def name(self) -> str:
        return "minimax"

    @property
    def supports_tools(self) -> bool:
        return False

    @property
    def supports_streaming(self) -> bool:
        return True

    async def chat(
        self,
        messages: list[Message],
        tools: Optional[list[dict]] = None,
        **kwargs
    ) -> AsyncIterator[str]:
        model = kwargs.get("model", self.default_model)

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        payload = {
            "model": model,
            "messages": [self.format_message(m) for m in messages],
            "stream": True,
            "temperature": kwargs.get("temperature", 1),
            "top_p": kwargs.get("top_p", 0.95),
            "max_completion_tokens": kwargs.get("max_tokens", 16384)
        }

        async with self._client.stream("POST", self.base_url, headers=headers, json=payload) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                if line.startswith("data: "):
                    data = line[6:]
                    if data == "[DONE]":
                        break
                    try:
                        chunk = json.loads(data)
                        content = chunk.get("choices", [{}])[0].get("delta", {}).get("content")
                        if content:
                            yield content
                    except json.JSONDecodeError:
                        continue
