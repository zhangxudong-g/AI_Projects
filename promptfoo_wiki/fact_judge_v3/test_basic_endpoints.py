from backend.main import app
from fastapi.testclient import TestClient

client = TestClient(app)

print("Testing basic endpoints...")

# 测试根路径
response = client.get('/')
print(f"Root path: {response.status_code}")
if response.status_code == 200:
    print(f"Response: {response.json()}")
else:
    print(f"Error: {response.text}")

# 测试健康检查
response = client.get('/api/v1/health')
print(f"Health check: {response.status_code}")
if response.status_code == 200:
    print(f"Response: {response.json()}")
else:
    print(f"Error: {response.text}")

print("\nBasic endpoints test completed.")