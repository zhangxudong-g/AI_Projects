import json
import uuid
from pathlib import Path
from datetime import datetime
from typing import Optional, List, Dict

class SessionError(Exception):
    pass

class SessionManager:
    def __init__(self, session_dir: Path = None):
        if session_dir is None:
            session_dir = Path.home() / ".opencli" / "sessions"
        self.session_dir = Path(session_dir)
        self.session_dir.mkdir(parents=True, exist_ok=True)

    def create_session(self) -> Dict:
        session_id = str(uuid.uuid4())[:8]
        session = {
            "id": session_id,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat(),
            "messages": [],
        }
        self.save_session(session)
        return session

    def save_session(self, session: Dict):
        session["updated_at"] = datetime.now().isoformat()
        session_file = self.session_dir / f"{session['id']}.json"
        with open(session_file, "w", encoding="utf-8") as f:
            json.dump(session, f, ensure_ascii=False, indent=2)

    def load_session(self, session_id: str) -> Optional[Dict]:
        session_file = self.session_dir / f"{session_id}.json"
        if not session_file.exists():
            return None
        with open(session_file, encoding="utf-8") as f:
            return json.load(f)

    def list_sessions(self) -> List[Dict]:
        sessions = []
        for session_file in self.session_dir.glob("*.json"):
            with open(session_file, encoding="utf-8") as f:
                session = json.load(f)
                sessions.append({
                    "id": session["id"],
                    "created_at": session["created_at"],
                    "updated_at": session["updated_at"],
                    "message_count": len(session.get("messages", [])),
                })
        sessions.sort(key=lambda s: s["updated_at"], reverse=True)
        return sessions

    def delete_session(self, session_id: str) -> bool:
        session_file = self.session_dir / f"{session_id}.json"
        if session_file.exists():
            session_file.unlink()
            return True
        return False