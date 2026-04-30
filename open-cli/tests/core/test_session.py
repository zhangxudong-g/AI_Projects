import pytest
import tempfile
import shutil
from pathlib import Path
from core.session import SessionManager

@pytest.fixture
def temp_session_dir():
    tmp = tempfile.mkdtemp()
    yield Path(tmp)
    shutil.rmtree(tmp)

def test_session_manager_init(temp_session_dir):
    sm = SessionManager(session_dir=temp_session_dir)
    assert sm.session_dir == temp_session_dir

def test_create_session(temp_session_dir):
    sm = SessionManager(session_dir=temp_session_dir)
    session = sm.create_session()
    assert session["id"] is not None
    assert "messages" in session
    assert session["messages"] == []

def test_save_and_load_session(temp_session_dir):
    sm = SessionManager(session_dir=temp_session_dir)
    session = sm.create_session()
    sm.save_session(session)

    loaded = sm.load_session(session["id"])
    assert loaded["id"] == session["id"]
    assert loaded["messages"] == []

def test_list_sessions(temp_session_dir):
    sm = SessionManager(session_dir=temp_session_dir)
    s1 = sm.create_session()
    s2 = sm.create_session()
    sessions = sm.list_sessions()
    assert len(sessions) == 2