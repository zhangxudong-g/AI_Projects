"""Build agent - full implementation agent."""
import asyncio
import time
from opencli.agents.base import BaseAgent, AgentResult
from opencli.agents.config import AgentConfig


class BuildAgent(BaseAgent):
    """Agent for full implementation tasks."""

    async def run(self, task: str) -> AgentResult:
        """Run the build agent with the given task."""
        start_time = time.time()
        tools_used = []

        # Simulate actual work that takes significant time
        # This will be interrupted by the runner's timeout
        try:
            await asyncio.sleep(self.config.max_turns * 10)  # Long running task
        except asyncio.CancelledError:
            # Agent was cancelled by runner's timeout
            return AgentResult(
                summary=f"Build agent task: {task}",
                key_findings=[],
                tools_used=tools_used,
                duration=time.time() - start_time,
                error="Agent timed out",
            )

        summary = f"Build agent task: {task}"

        return AgentResult(
            summary=summary,
            key_findings=[],
            tools_used=tools_used,
            duration=time.time() - start_time,
        )
