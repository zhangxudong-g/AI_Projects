import unittest
from fastapi.testclient import TestClient
from backend.main import app

client = TestClient(app)

class TestAPIEndpoints(unittest.TestCase):
    def setUp(self):
        self.client = client

    def test_root_endpoint(self):
        """测试根端点"""
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertIn("message", response.json())
        self.assertEqual(response.json()["message"], "Engineering Judge v3 API")

    def test_health_check(self):
        """测试健康检查端点"""
        response = self.client.get("/api/v1/health")
        self.assertEqual(response.status_code, 200)
        self.assertIn("status", response.json())
        self.assertEqual(response.json()["status"], "healthy")

    def test_dashboard_endpoints(self):
        """测试仪表盘相关端点"""
        # 注意：这些端点需要认证，所以我们主要测试路径是否存在
        endpoints = [
            "/api/v1/dashboard/stats",
            "/api/v1/dashboard/trends", 
            "/api/v1/dashboard/recent"
        ]
        
        for endpoint in endpoints:
            # 由于需要认证，预期返回 401
            response = self.client.get(endpoint)
            # 如果没有认证头，应该返回 401
            self.assertIn(response.status_code, [401, 200])

    def test_cases_endpoints(self):
        """测试案例相关端点"""
        endpoints = [
            "/api/v1/cases/",
            "/api/v1/cases/non-existent-id"
        ]
        
        for endpoint in endpoints:
            # 由于需要认证，预期返回 401
            response = self.client.get(endpoint)
            self.assertIn(response.status_code, [401, 404])

    def test_executions_endpoints(self):
        """测试执行相关端点"""
        endpoints = [
            "/api/v1/executions/",
            "/api/v1/executions/non-existent-id"
        ]
        
        for endpoint in endpoints:
            response = self.client.get(endpoint)
            self.assertIn(response.status_code, [401, 404])

    def test_reports_endpoints(self):
        """测试报告相关端点"""
        endpoints = [
            "/api/v1/reports/",
            "/api/v1/reports/non-existent-id"
        ]
        
        for endpoint in endpoints:
            response = self.client.get(endpoint)
            self.assertIn(response.status_code, [401, 404])

    def test_users_endpoints(self):
        """测试用户相关端点"""
        endpoints = [
            "/api/v1/users/",
            "/api/v1/users/non-existent-id"
        ]
        
        for endpoint in endpoints:
            response = self.client.get(endpoint)
            self.assertIn(response.status_code, [401, 404])

if __name__ == '__main__':
    unittest.main()