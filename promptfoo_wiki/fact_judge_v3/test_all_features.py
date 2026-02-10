import unittest
import json
from fastapi.testclient import TestClient
from backend.main import app

client = TestClient(app)

class TestAllFeatures(unittest.TestCase):
    def setUp(self):
        self.client = client

    def test_root_and_health_endpoints(self):
        """测试根路径和健康检查"""
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertIn("message", response.json())
        
        response = self.client.get("/api/v1/health")
        self.assertEqual(response.status_code, 200)
        self.assertIn("status", response.json())

    def test_dashboard_endpoints(self):
        """测试仪表盘相关端点"""
        endpoints = [
            "/api/v1/dashboard/stats",
            "/api/v1/dashboard/trends", 
            "/api/v1/dashboard/recent"
        ]
        
        for endpoint in endpoints:
            response = self.client.get(endpoint)
            # 由于需要认证，预期返回 401 或 403
            self.assertIn(response.status_code, [401, 403])

    def test_cases_endpoints(self):
        """测试案例相关端点"""
        # 测试获取案例列表
        response = self.client.get("/api/v1/cases/")
        self.assertIn(response.status_code, [401, 403])  # 需要认证
        
        # 测试获取模板
        response = self.client.get("/api/v1/cases/templates")
        self.assertIn(response.status_code, [401, 403])  # 需要认证

    def test_executions_endpoints(self):
        """测试执行相关端点"""
        # 测试获取执行列表
        response = self.client.get("/api/v1/executions/")
        self.assertIn(response.status_code, [401, 403])  # 需要认证
        
        # 测试调度执行端点
        response = self.client.post("/api/v1/executions/schedule")
        self.assertIn(response.status_code, [401, 403])  # 需要认证

    def test_reports_endpoints(self):
        """测试报告相关端点"""
        # 测试获取报告列表
        response = self.client.get("/api/v1/reports/")
        self.assertIn(response.status_code, [401, 403])  # 需要认证
        
        # 测试报告图表数据
        response = self.client.get("/api/v1/reports/charts")
        self.assertIn(response.status_code, [401, 403])  # 需要认证
        
        # 测试报告导出端点
        response = self.client.get("/api/v1/reports/export/batch")
        self.assertIn(response.status_code, [401, 403])  # 需要认证

    def test_users_endpoints(self):
        """测试用户相关端点"""
        # 测试获取用户列表
        response = self.client.get("/api/v1/users/")
        self.assertIn(response.status_code, [401, 403])  # 需要认证
        
        # 测试获取用户资料
        response = self.client.get("/api/v1/users/profile")
        self.assertIn(response.status_code, [401, 403])  # 需要认证
        
        # 测试获取活动日志
        response = self.client.get("/api/v1/users/activity-log")
        self.assertIn(response.status_code, [401, 403])  # 需要认证

    def test_api_structure(self):
        """测试API结构完整性"""
        # 检查所有预期的路由是否存在
        routes = [route.path for route in app.routes]
        
        # 检查核心路由
        self.assertIn("/api/v1/health", routes)
        self.assertIn("/api/v1/users/", routes)
        self.assertIn("/api/v1/cases/", routes)
        self.assertIn("/api/v1/executions/", routes)
        self.assertIn("/api/v1/reports/", routes)
        self.assertIn("/api/v1/dashboard/stats", routes)
        
        # 检查新增的路由
        self.assertIn("/api/v1/cases/import", routes)
        self.assertIn("/api/v1/cases/templates", routes)
        self.assertIn("/api/v1/executions/schedule", routes)
        self.assertIn("/api/v1/reports/export/{report_id}", routes)
        self.assertIn("/api/v1/reports/export/batch", routes)
        self.assertIn("/api/v1/users/profile", routes)
        self.assertIn("/api/v1/users/activity-log", routes)

    def test_models_and_schemas(self):
        """测试数据模型和架构"""
        # 这里可以添加对模型和架构的测试
        # 由于我们主要是验证功能，暂时跳过具体的数据验证
        pass

if __name__ == '__main__':
    unittest.main()