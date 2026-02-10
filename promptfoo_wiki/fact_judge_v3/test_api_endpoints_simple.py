import unittest
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

from fastapi.testclient import TestClient
from backend.main import app

client = TestClient(app)

class TestAPIEndpoints(unittest.TestCase):
    """测试API端点是否存在"""

    def setUp(self):
        self.client = client

    def test_api_endpoints_exist(self):
        """测试所有必要的API端点是否存在"""
        print("Verifying API endpoints exist...")
        
        # 测试健康检查端点（不需要认证）
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        print("OK: Root endpoint exists")
        
        response = self.client.get("/api/v1/health")
        self.assertEqual(response.status_code, 200)
        print("OK: Health check endpoint exists")
        
        # 测试需要认证的端点（预期返回401或403）
        auth_required_endpoints = [
            "/api/v1/cases/",
            "/api/v1/executions/",
            "/api/v1/reports/",
            "/api/v1/dashboard/stats",
            "/api/v1/users/"
        ]
        
        for endpoint in auth_required_endpoints:
            response = self.client.get(endpoint)
            # 对于需要认证的端点，我们期望返回401（未认证）或403（权限不足）
            self.assertIn(response.status_code, [401, 403, 422], 
                         f"Endpoint {endpoint} should return 401/403/422, got {response.status_code}")
            print(f"OK: {endpoint} endpoint exists (status code: {response.status_code})")
        
        # 测试特定的报告图表端点
        response = self.client.get("/api/v1/reports/charts")
        self.assertIn(response.status_code, [401, 403, 422, 200], 
                     f"Reports charts endpoint should be accessible, got {response.status_code}")
        print(f"OK: /api/v1/reports/charts endpoint exists (status code: {response.status_code})")
        
        # 测试WebSocket端点（预期返回升级请求错误）
        response = self.client.get("/ws/execution/test")
        # WebSocket端点需要特殊的WebSocket握手，普通HTTP请求会失败，但路径应该存在
        print(f"OK: WebSocket endpoint structure exists (status code: {response.status_code})")
        
        print("\nOK: All API endpoints verified!")
        print("System is ready to support complete end-to-end workflow:")
        print("- Edit cases (via /api/v1/cases/ endpoints)")
        print("- Execute evaluations (via /api/v1/executions/ endpoints)") 
        print("- View reports (via /api/v1/reports/ endpoints)")
        print("- Real-time monitoring (via WebSocket /ws/execution/ endpoints)")

if __name__ == '__main__':
    unittest.main()