# src/opencli/agents/runner.py
"""Agent runner - spawns and manages agents."""
import asyncio
import time
from typing import Optional
from opencli.agents.types import AgentType
from opencli.agents.config import AgentConfig
from opencli.agents.base import BaseAgent, AgentResult
from opencli.agents.factory import AgentFactory
from opencli.agents.explorer import ExploreAgent
from opencli.agents.planner import PlanAgent
from opencli.agents.builder import BuildAgent


class AgentRunner:
    """Spawns and manages agent execution."""

    def __init__(self):
        self._agent_classes = {
            AgentType.EXPLORE: ExploreAgent,
            AgentType.PLAN: PlanAgent,
            AgentType.BUILD: BuildAgent,
            AgentType.GENERAL: BuildAgent,
        }

    def _create_agent(self, config: AgentConfig) -> BaseAgent:
        """Create an agent instance from config."""
        for agent_type, agent_class in self._agent_classes.items():
            if agent_type.value == config.name:
                return agent_class(config)
        # Default to BuildAgent
        return BuildAgent(config)

    async def spawn(
        self,
        agent_type: AgentType,
        task: str,
        model: Optional[str] = None,
        memory_enabled: bool = True,
        max_turns: int = 10,
        timeout: int = 300,
    ) -> AgentResult:
        """Spawn a subagent to handle a task."""
        config = AgentFactory.create(
            agent_type=agent_type,
            model=model,
            memory_enabled=memory_enabled,
            max_turns=max_turns,
            timeout=timeout,
        )

        agent = self._create_agent(config)

        try:
            result = await asyncio.wait_for(
                agent.run(task),
                timeout=timeout,
            )
            return result
        except asyncio.TimeoutError:
            return AgentResult(
                summary=f"Agent {agent_type.value} timed out after {timeout}s",
                error=f"TimeoutError after {timeout}s",
            )
        except Exception as e:
            return AgentResult(
                summary=f"Agent {agent_type.value} failed",
                error=str(e),
            )