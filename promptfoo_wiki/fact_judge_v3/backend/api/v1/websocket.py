from fastapi import WebSocket, WebSocketDisconnect
from typing import Dict, List
import asyncio
import json
from datetime import datetime

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, execution_id: str):
        await websocket.accept()
        self.active_connections[execution_id] = websocket

    def disconnect(self, execution_id: str):
        if execution_id in self.active_connections:
            del self.active_connections[execution_id]

    async def send_personal_message(self, message: str, execution_id: str):
        connection = self.active_connections.get(execution_id)
        if connection:
            await connection.send_text(message)

    async def broadcast(self, message: str):
        for connection in self.active_connections.values():
            await connection.send_text(message)

manager = ConnectionManager()

# WebSocket 端点
async def execution_websocket(websocket: WebSocket, execution_id: str):
    await manager.connect(websocket, execution_id)
    try:
        while True:
            # 保持连接，等待客户端消息
            data = await websocket.receive_text()
            # 可能处理客户端发送的消息
            await manager.send_personal_message(f"Received: {data}", execution_id)
    except WebSocketDisconnect:
        manager.disconnect(execution_id)