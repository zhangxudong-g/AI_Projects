from pathlib import Path
import json
from typing import Optional
from ..messages.messages import Session, AgentType


class SessionManager:
    def __init__(self, storage_path: Optional[Path] = None):
        self.storage_path = storage_path or Path.home() / ".opencli" / "sessions"
        self.storage_path.mkdir(parents=True, exist_ok=True)
        self.sessions: dict[str, Session] = {}

    async def create(self, agent_type: AgentType = AgentType.BUILD) -> Session:
        import uuid
        session = Session(id=str(uuid.uuid4()), agent_type=agent_type)
        self.sessions[session.id] = session
        await self.save(session)
        return session

    async def save(self, session: Session):
        """保存会话到文件"""
        filepath = self.storage_path / f"{session.id}.json"
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump({
                "id": session.id,
                "agent_type": session.agent_type.value,
                "created_at": session.created_at.isoformat(),
                "messages": [(m.id, m.role, m.content) for m in session.messages]
            }, f, ensure_ascii=False, indent=2)

    async def load(self, session_id: str) -> Optional[Session]:
        """从文件加载会话"""
        filepath = self.storage_path / f"{session_id}.json"
        if not filepath.exists():
            return None
        
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
            from ..messages.messages import Message
            session = Session(
                id=data["id"],
                agent_type=AgentType(data["agent_type"])
            )
            session.messages = [Message(id=m[0], role=m[1], content=m[2]) for m in data["messages"]]
            self.sessions[session_id] = session
            return session

    def get(self, session_id: str) -> Optional[Session]:
        return self.sessions.get(session_id)
