import pytest
import tempfile
import shutil
from pathlib import Path
import sys
import asyncio
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

from opencli.server.session import SessionManager
from opencli.messages.messages import AgentType


@pytest.fixture
def temp_session_dir():
    tmp = tempfile.mkdtemp()
    yield Path(tmp)
    shutil.rmtree(tmp)


def test_session_manager_init(temp_session_dir):
    sm = SessionManager(storage_path=temp_session_dir)
    assert sm.storage_path == temp_session_dir


@pytest.mark.asyncio
async def test_create_session(temp_session_dir):
    sm = SessionManager(storage_path=temp_session_dir)
    session = await sm.create(agent_type=AgentType.BUILD)
    assert session.id is not None
    assert session.agent_type == AgentType.BUILD


@pytest.mark.asyncio
async def test_save_and_load_session(temp_session_dir):
    sm = SessionManager(storage_path=temp_session_dir)
    session = await sm.create(agent_type=AgentType.BUILD)
    await sm.save(session)

    loaded = await sm.load(session.id)
    assert loaded.id == session.id
    assert loaded.agent_type == session.agent_type


@pytest.mark.asyncio
async def test_get_session(temp_session_dir):
    sm = SessionManager(storage_path=temp_session_dir)
    session = await sm.create(agent_type=AgentType.BUILD)
    retrieved = sm.get(session.id)
    assert retrieved.id == session.id
