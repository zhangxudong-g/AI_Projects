import litellm
from typing import AsyncIterator, Optional
from .base import BaseProvider
from ..messages.messages import Message


class LiteLLMProvider(BaseProvider):
    def __init__(self, api_key: str, default_model: str = "claude-3-5-sonnet"):
        self.api_key = api_key
        self.default_model = default_model
        litellm.api_key = api_key

    @property
    def name(self) -> str:
        return "litellm"

    async def chat(
        self,
        messages: list[Message],
        tools: Optional[list[dict]] = None,
        **kwargs
    ) -> AsyncIterator[str]:
        response = await litellm.acompletion(
            model=kwargs.get("model", self.default_model),
            messages=[self.format_message(m) for m in messages],
            tools=tools,
            stream=True,
        )
        async for chunk in response:
            if chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content
