from pathlib import Path
import json
from typing import Optional
from ..types.messages import Session


class SessionManager:
    def __init__(self, session_dir: Optional[Path] = None):
        self.session_dir = session_dir or Path.cwd() / ".opencli" / "sessions"
        self.session_dir.mkdir(parents=True, exist_ok=True)

    def create_session(self, agent_type: str = "general") -> dict:
        import uuid
        session_id = str(uuid.uuid4())
        session = {
            "id": session_id,
            "agent_type": agent_type,
            "messages": [],
        }
        self.save_session(session)
        return session

    def save_session(self, session: dict):
        session_file = self.session_dir / f"{session['id']}.json"
        with open(session_file, "w") as f:
            json.dump(session, f)

    def load_session(self, session_id: str) -> Optional[dict]:
        session_file = self.session_dir / f"{session_id}.json"
        if not session_file.exists():
            return None
        with open(session_file, "r") as f:
            return json.load(f)

    def list_sessions(self) -> list[dict]:
        sessions = []
        for session_file in self.session_dir.glob("*.json"):
            with open(session_file, "r") as f:
                sessions.append(json.load(f))
        return sessions
