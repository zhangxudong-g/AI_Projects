from abc import ABC, abstractmethod
from typing import AsyncIterator, Optional
from ..messages.messages import Message, ContentBlock


class BaseProvider(ABC):
    @abstractmethod
    async def chat(
        self,
        messages: list[Message],
        tools: Optional[list[dict]] = None,
        **kwargs
    ) -> AsyncIterator[str]:
        """Stream chat response"""
        pass

    @property
    @abstractmethod
    def name(self) -> str:
        pass

    @property
    def supports_tools(self) -> bool:
        return True

    @property
    def supports_streaming(self) -> bool:
        return True

    def format_message(self, msg: Message) -> dict:
        """Format a message for the provider API."""
        content = msg.content
        if isinstance(content, list):
            return {"role": msg.role, "content": self._format_blocks(content)}
        return {"role": msg.role, "content": content}

    def _format_blocks(self, blocks: list[ContentBlock]) -> str:
        """Format content blocks into a string."""
        return "\n".join(b.text or "" for b in blocks)
