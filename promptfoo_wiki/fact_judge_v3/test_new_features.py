import unittest
from fastapi.testclient import TestClient
from backend.main import app

client = TestClient(app)

class TestNewFeatures(unittest.TestCase):
    def setUp(self):
        self.client = client

    def test_websocket_endpoint_exists(self):
        """测试WebSocket端点是否存在"""
        # 检查路由是否存在
        routes = [route.path for route in app.routes]
        self.assertIn("/ws/execution/{execution_id}", routes)

    def test_schedule_execution_endpoint(self):
        """测试调度执行端点"""
        routes = [route.path for route in app.routes]
        self.assertIn("/api/v1/executions/schedule", routes)

    def test_import_cases_endpoint(self):
        """测试批量导入案例端点"""
        routes = [route.path for route in app.routes]
        self.assertIn("/api/v1/cases/import", routes)

    def test_export_reports_endpoints(self):
        """测试报告导出端点"""
        routes = [route.path for route in app.routes]
        self.assertIn("/api/v1/reports/export/{report_id}", routes)
        self.assertIn("/api/v1/reports/export/batch", routes)

    def test_user_profile_endpoints(self):
        """测试用户个人资料端点"""
        routes = [route.path for route in app.routes]
        self.assertIn("/api/v1/users/profile", routes)
        self.assertIn("/api/v1/users/activity-log", routes)

    def test_case_templates_endpoint(self):
        """测试案例模板端点"""
        routes = [route.path for route in app.routes]
        self.assertIn("/api/v1/cases/templates", routes)

    def test_report_filtering_sorting_endpoints(self):
        """测试报告过滤和排序端点"""
        # 这些功能主要在前端实现，后端提供数据支持
        # 验证相关端点是否存在
        routes = [route.path for route in app.routes]
        self.assertIn("/api/v1/reports/charts", routes)

if __name__ == '__main__':
    unittest.main()