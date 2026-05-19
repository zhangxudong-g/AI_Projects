import json
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Optional
import uuid


def generate_id() -> str:
    return str(uuid.uuid4())


@dataclass
class Checkpoint:
    id: str
    session_id: str
    snapshot: dict
    created_at: datetime = field(default_factory=datetime.now)
    description: str = ""


class CheckpointManager:
    def __init__(self, storage_path: Optional[Path] = None):
        self.storage_path = storage_path or Path.cwd() / ".opencli" / "checkpoints"
        self.storage_path.mkdir(parents=True, exist_ok=True)

    async def create(self, session: "Session", description: str = "") -> Checkpoint:
        checkpoint = Checkpoint(
            id=generate_id(),
            session_id=session.id,
            snapshot=self._snapshot(session),
            description=description
        )
        await self.save(checkpoint)
        return checkpoint

    async def save(self, checkpoint: Checkpoint):
        checkpoint_file = self.storage_path / f"{checkpoint.id}.json"
        with open(checkpoint_file, "w") as f:
            json.dump({
                "id": checkpoint.id,
                "session_id": checkpoint.session_id,
                "snapshot": checkpoint.snapshot,
                "created_at": checkpoint.created_at.isoformat(),
                "description": checkpoint.description
            }, f)

    async def restore(self, checkpoint_id: str) -> Optional[dict]:
        checkpoint_file = self.storage_path / f"{checkpoint_id}.json"
        if not checkpoint_file.exists():
            return None
        with open(checkpoint_file, "r") as f:
            data = json.load(f)
        return data.get("snapshot")

    async def load(self, checkpoint_id: str) -> Optional[Checkpoint]:
        checkpoint_file = self.storage_path / f"{checkpoint_id}.json"
        if not checkpoint_file.exists():
            return None
        with open(checkpoint_file, "r") as f:
            data = json.load(f)
        return Checkpoint(
            id=data["id"],
            session_id=data["session_id"],
            snapshot=data["snapshot"],
            created_at=datetime.fromisoformat(data["created_at"]),
            description=data["description"]
        )

    async def list_checkpoints(self, session_id: str) -> list[Checkpoint]:
        checkpoints = []
        for checkpoint_file in self.storage_path.glob("*.json"):
            with open(checkpoint_file, "r") as f:
                data = json.load(f)
            if data.get("session_id") == session_id:
                checkpoints.append(Checkpoint(
                    id=data["id"],
                    session_id=data["session_id"],
                    snapshot=data["snapshot"],
                    created_at=datetime.fromisoformat(data["created_at"]),
                    description=data["description"]
                ))
        return checkpoints

    def _snapshot(self, session: "Session") -> dict:
        return {
            "id": session.id,
            "agent_type": session.agent_type.value if hasattr(session.agent_type, 'value') else session.agent_type,
            "messages": [
                {"id": m.id, "role": m.role, "content": m.content if isinstance(m.content, str) else str(m.content)}
                for m in session.messages
            ],
        }
