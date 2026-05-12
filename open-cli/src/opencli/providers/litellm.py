import litellm
from typing import AsyncIterator, Optional
from .base import BaseProvider
from ..messages.messages import Message, ContentBlock


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
            messages=[self._format_msg(m) for m in messages],
            tools=tools,
            stream=True,
        )
        async for chunk in response:
            if chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content

    def _format_msg(self, msg: Message) -> dict:
        content = msg.content
        if isinstance(content, list):
            return {"role": msg.role, "content": self._format_blocks(content)}
        return {"role": msg.role, "content": content}

    def _format_blocks(self, blocks: list[ContentBlock]) -> str:
        return "\n".join(b.text or "" for b in blocks)
