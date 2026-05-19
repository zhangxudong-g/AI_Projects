import pytest
import tempfile
import shutil
from pathlib import Path
from opencli.server.checkpoint import CheckpointManager, Checkpoint
from opencli.messages.messages import Session, Message, AgentType


@pytest.fixture
def temp_checkpoint_dir():
    tmp = tempfile.mkdtemp()
    yield Path(tmp)
    shutil.rmtree(tmp)


@pytest.fixture
def sample_session():
    return Session(
        id="test-session-123",
        agent_type=AgentType.BUILD,
        messages=[
            Message(id="msg-1", role="user", content="Hello"),
            Message(id="msg-2", role="assistant", content="Hi there!")
        ]
    )


def test_checkpoint_manager_init(temp_checkpoint_dir):
    cm = CheckpointManager(storage_path=temp_checkpoint_dir)
    assert cm.storage_path == temp_checkpoint_dir
    assert temp_checkpoint_dir.exists()


@pytest.mark.asyncio
async def test_create_checkpoint(temp_checkpoint_dir, sample_session):
    cm = CheckpointManager(storage_path=temp_checkpoint_dir)
    checkpoint = await cm.create(sample_session, description="Test checkpoint")

    assert checkpoint.id is not None
    assert checkpoint.session_id == sample_session.id
    assert checkpoint.description == "Test checkpoint"
    assert checkpoint.snapshot is not None


@pytest.mark.asyncio
async def test_save_and_load_checkpoint(temp_checkpoint_dir, sample_session):
    cm = CheckpointManager(storage_path=temp_checkpoint_dir)
    checkpoint = await cm.create(sample_session, description="Test checkpoint")

    loaded = await cm.load(checkpoint.id)
    assert loaded is not None
    assert loaded.id == checkpoint.id
    assert loaded.session_id == sample_session.id


@pytest.mark.asyncio
async def test_list_checkpoints(temp_checkpoint_dir, sample_session):
    cm = CheckpointManager(storage_path=temp_checkpoint_dir)
    await cm.create(sample_session, description="Checkpoint 1")
    await cm.create(sample_session, description="Checkpoint 2")

    checkpoints = await cm.list_checkpoints(sample_session.id)
    assert len(checkpoints) == 2


@pytest.mark.asyncio
async def test_restore_checkpoint(temp_checkpoint_dir, sample_session):
    cm = CheckpointManager(storage_path=temp_checkpoint_dir)
    checkpoint = await cm.create(sample_session, description="Test checkpoint")

    restored = await cm.restore(checkpoint.id)
    assert restored is not None
    assert restored["id"] == sample_session.id