import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

import pytest
from opencli.messages.messages import AgentType, Session, Message
from opencli.server.agent import Agent, AgentConfig
from opencli.server.orchestrator import AgentOrchestrator
from opencli.server.session import SessionManager
from opencli.tools.registry import ToolRegistry


class MockProvider:
    @property
    def name(self):
        return "mock"

    @property
    def supports_tools(self):
        return True

    @property
    def supports_streaming(self):
        return True

    async def chat(self, messages, tools=None, **kwargs):
        yield "Hello"


class MockAgent(Agent):
    async def run(self, prompt: str, session: "Session") -> "AsyncIterator[str]":
        yield f"Mock response to: {prompt}"


class TestAgentConfig:
    def test_agent_config_defaults(self):
        config = AgentConfig(agent_type=AgentType.PLAN)
        assert config.agent_type == AgentType.PLAN
        assert config.model is None
        assert config.temperature == 0.7
        assert config.max_tokens == 4096
        assert config.system_prompt is None

    def test_agent_config_custom(self):
        config = AgentConfig(
            agent_type=AgentType.BUILD,
            model="gpt-4",
            temperature=0.5,
            max_tokens=2048,
            system_prompt="You are a builder."
        )
        assert config.agent_type == AgentType.BUILD
        assert config.model == "gpt-4"
        assert config.temperature == 0.5
        assert config.max_tokens == 2048
        assert config.system_prompt == "You are a builder."


class TestAgent:
    def test_get_system_prompt_general(self):
        config = AgentConfig(agent_type=AgentType.GENERAL)
        registry = ToolRegistry()
        provider = MockProvider()

        class TestAgent(Agent):
            async def run(self, prompt, session):
                yield ""

        agent = TestAgent(config, registry, provider)
        prompt = agent.get_system_prompt()
        assert "helpful AI coding assistant" in prompt
        assert "PLAN MODE" not in prompt

    def test_get_system_prompt_plan(self):
        config = AgentConfig(agent_type=AgentType.PLAN)
        registry = ToolRegistry()
        provider = MockProvider()

        class TestAgent(Agent):
            async def run(self, prompt, session):
                yield ""

        agent = TestAgent(config, registry, provider)
        prompt = agent.get_system_prompt()
        assert "PLAN MODE" in prompt
        assert "CANNOT modify anything" in prompt


class TestAgentOrchestrator:
    def test_orchestrator_init(self):
        provider = MockProvider()
        registry = ToolRegistry()
        orchestrator = AgentOrchestrator(provider, registry)
        assert orchestrator.provider is provider
        assert orchestrator.registry is registry
        assert orchestrator.agents == {}

    def test_register_agent(self):
        provider = MockProvider()
        registry = ToolRegistry()
        orchestrator = AgentOrchestrator(provider, registry)

        config = AgentConfig(agent_type=AgentType.GENERAL)
        agent = MockAgent(config, registry, provider)
        orchestrator.register_agent(AgentType.GENERAL, agent)

        assert orchestrator.agents[AgentType.GENERAL] is agent

    @pytest.mark.asyncio
    async def test_run_agent(self):
        provider = MockProvider()
        registry = ToolRegistry()
        orchestrator = AgentOrchestrator(provider, registry)

        config = AgentConfig(agent_type=AgentType.GENERAL)
        agent = MockAgent(config, registry, provider)
        orchestrator.register_agent(AgentType.GENERAL, agent)

        session = Session(id="test-session", agent_type=AgentType.GENERAL)
        chunks = []
        async for chunk in orchestrator.run(AgentType.GENERAL, "Hello", session):
            chunks.append(chunk)

        assert len(chunks) == 1
        assert "Hello" in chunks[0]

    @pytest.mark.asyncio
    async def test_run_unregistered_agent_raises(self):
        provider = MockProvider()
        registry = ToolRegistry()
        orchestrator = AgentOrchestrator(provider, registry)

        session = Session(id="test-session", agent_type=AgentType.PLAN)

        with pytest.raises(ValueError, match="No agent registered"):
            async for _ in orchestrator.run(AgentType.PLAN, "Hello", session):
                pass


class TestSessionManager:
    def test_session_manager_init(self, tmp_path):
        sm = SessionManager(storage_path=tmp_path)
        assert sm.storage_path == tmp_path

    @pytest.mark.asyncio
    async def test_create_session(self, tmp_path):
        sm = SessionManager(storage_path=tmp_path)
        session = await sm.create(AgentType.BUILD)
        assert session.id is not None
        assert session.agent_type == AgentType.BUILD
        assert session.messages == []

    @pytest.mark.asyncio
    async def test_save_and_load_session(self, tmp_path):
        sm = SessionManager(storage_path=tmp_path)
        session = await sm.create(AgentType.BUILD)
        await sm.save(session)

        loaded = await sm.load(session.id)
        assert loaded is not None
        assert loaded.id == session.id

    @pytest.mark.asyncio
    async def test_get_session(self, tmp_path):
        sm = SessionManager(storage_path=tmp_path)
        session = await sm.create(AgentType.PLAN)
        result = sm.get(session.id)
        assert result is not None
        assert result.id == session.id
