from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional
import re


class MemoryCategory(Enum):
    BUILD_COMMAND = "build_command"
    TEST_COMMAND = "test_command"
    CODE_PATTERN = "code_pattern"


@dataclass
class Learning:
    content: str
    source: str
    category: MemoryCategory
    confidence: float
    created_at: datetime = field(default_factory=datetime.now)


class AutoMemory:
    def __init__(self, project_root: Optional[str] = None):
        self.project_root = project_root
        self.learnings: list[Learning] = []

    async def learn(self, observation: str, source: str, category: MemoryCategory):
        learning = Learning(
            content=observation,
            source=source,
            category=category,
            confidence=0.8
        )
        self.learnings.append(learning)

    async def recall(self, query: str) -> list[Learning]:
        results = []
        query_lower = query.lower()
        for learning in self.learnings:
            if query_lower in learning.content.lower() or query_lower in learning.source.lower():
                results.append(learning)
        return results[:10]

    async def recall_by_category(self, category: MemoryCategory) -> list[Learning]:
        return [l for l in self.learnings if l.category == category]

    def get_stats(self) -> dict:
        stats = {cat.value: 0 for cat in MemoryCategory}
        for learning in self.learnings:
            stats[learning.category.value] += 1
        return stats
