import requests
import sys
import threading
import time
from main import app
from uvicorn import Config, Server

# 启动服务器的函数
def run_server():
    config = Config(app=app, host="0.0.0.0", port=9000, log_level="info")
    server = Server(config=config)
    server.run()

# 在后台线程中启动服务器
server_thread = threading.Thread(target=run_server, daemon=True)
server_thread.start()

# 等待服务器启动
time.sleep(3)

# 测试API端点
try:
    print("Testing /api/servers endpoint...")
    response = requests.get("http://localhost:9000/api/servers", timeout=5)
    print(f"/api/servers status: {response.status_code}")
    if response.status_code == 200:
        print(f"/api/servers response: {response.json()}")
    else:
        print(f"/api/servers error: {response.text}")
        
    print("\nTesting /api/servers-detail endpoint...")
    response = requests.get("http://localhost:9000/api/servers-detail", timeout=5)
    print(f"/api/servers-detail status: {response.status_code}")
    if response.status_code == 200:
        print(f"/api/servers-detail response: {response.json()}")
    else:
        print(f"/api/servers-detail error: {response.text}")
        
except requests.exceptions.ConnectionError:
    print("无法连接到服务器。请确保server_monitor应用正在运行在端口9000上。")
except requests.exceptions.Timeout:
    print("请求超时。服务器可能未响应。")
except Exception as e:
    print(f"测试过程中发生错误: {e}")