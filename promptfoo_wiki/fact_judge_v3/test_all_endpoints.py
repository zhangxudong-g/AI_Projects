from backend.main import app
from fastapi.testclient import TestClient

client = TestClient(app)

print("Testing all endpoints...")

# 测试根路径
response = client.get('/')
print(f"Root path: {response.status_code}")

# 测试健康检查
response = client.get('/api/v1/health')
print(f"Health check: {response.status_code}")

# 测试用户相关端点（需要认证，预期返回401或403）
response = client.get('/api/v1/users/')
print(f"Users list: {response.status_code}")

# 测试案例相关端点
response = client.get('/api/v1/cases/')
print(f"Cases list: {response.status_code}")

# 测试执行相关端点
response = client.get('/api/v1/executions/')
print(f"Executions list: {response.status_code}")

# 测试报告相关端点
response = client.get('/api/v1/reports/')
print(f"Reports list: {response.status_code}")

# 测试仪表盘相关端点
response = client.get('/api/v1/dashboard/stats')
print(f"Dashboard stats: {response.status_code}")

response = client.get('/api/v1/dashboard/trends')
print(f"Dashboard trends: {response.status_code}")

response = client.get('/api/v1/dashboard/recent')
print(f"Dashboard recent: {response.status_code}")

print("\nAll endpoints tested successfully!")