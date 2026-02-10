from backend.main import app
from fastapi.testclient import TestClient

client = TestClient(app)

# 测试根路径
response = client.get('/')
print('Root path:', response.status_code, response.json() if response.status_code == 200 else 'Not found')

# 测试健康检查
response = client.get('/api/v1/health')
print('Health check:', response.status_code, response.json() if response.status_code == 200 else 'Not found')

# 测试所有路由
print('\nAvailable routes:')
for route in app.routes:
    if hasattr(route, 'methods') and hasattr(route, 'path'):
        print(f'{route.methods} {route.path}')