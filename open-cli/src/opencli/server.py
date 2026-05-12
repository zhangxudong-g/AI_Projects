from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import StreamingResponse
import json
import asyncio

app = FastAPI(title="open-cli Server")

# 存储活跃连接
active_connections: list[WebSocket] = []


@app.get("/health")
async def health():
    return {"status": "ok", "version": "2.0.0"}


@app.post("/api/v1/session")
async def create_session():
    from .messages.messages import Session, AgentType
    import uuid
    session = Session(id=str(uuid.uuid4()), agent_type=AgentType.BUILD)
    return {"session_id": session.id, "agent_type": session.agent_type.value}


@app.get("/api/v1/session/{session_id}")
async def get_session(session_id: str):
    return {"session_id": session_id, "status": "active"}


@app.websocket("/api/v1/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    active_connections.append(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            
            # 处理消息
            method = message.get("method")
            if method == "chat":
                # 处理聊天
                await websocket.send_text(json.dumps({"type": "thinking", "content": "Processing..."}))
            elif method == "ping":
                await websocket.send_text(json.dumps({"type": "pong"}))
    except WebSocketDisconnect:
        active_connections.remove(websocket)


def run_server():
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)


if __name__ == "__main__":
    run_server()
