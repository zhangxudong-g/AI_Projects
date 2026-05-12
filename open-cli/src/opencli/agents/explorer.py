"""Explore agent - read-only codebase research."""
import asyncio
import time
from opencli.agents.base import BaseAgent, AgentResult
from opencli.agents.config import AgentConfig


class ExploreAgent(BaseAgent):
    """Agent for fast read-only codebase exploration."""

    async def run(self, task: str) -> AgentResult:
        """Run the explore agent with the given task."""
        start_time = time.time()
        tools_used = []

        # For now, just return a summary indicating exploration would happen
        # Full implementation would use actual tools
        summary = f"Explore agent task: {task}"

        return AgentResult(
            summary=summary,
            key_findings=[],
            tools_used=tools_used,
            duration=time.time() - start_time,
        )
