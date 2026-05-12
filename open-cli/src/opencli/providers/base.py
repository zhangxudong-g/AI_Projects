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
