import unittest
from fastapi.testclient import TestClient
from backend.main import app

client = TestClient(app)

class TestEndToEndFlow(unittest.TestCase):
    """测试端到端流程：编辑案例 -> 执行 -> 查看报告"""
    
    def setUp(self):
        self.client = client

    def test_complete_workflow(self):
        """测试完整的端到端工作流程"""
        # 1. 创建一个测试案例
        case_data = {
            "name": "Test Case for E2E Flow",
            "description": "A test case created for end-to-end workflow testing",
            "config_yaml": "type: java-controller\ntechnology: spring-boot\nfeatures:\n  - rest-api\n  - validation\n"
        }
        
        response = self.client.post("/api/v1/cases/", json=case_data)
        self.assertEqual(response.status_code, 200)
        case_id = response.json()["id"]
        self.assertIsNotNone(case_id)
        
        # 2. 获取案例列表，确认案例已创建
        response = self.client.get("/api/v1/cases/")
        self.assertEqual(response.status_code, 200)
        cases = response.json()
        self.assertGreaterEqual(len(cases), 1)
        
        # 3. 更新案例（模拟编辑操作）
        update_data = {
            "description": "Updated description for end-to-end workflow testing"
        }
        response = self.client.put(f"/api/v1/cases/{case_id}", json=update_data)
        self.assertEqual(response.status_code, 200)
        updated_case = response.json()
        self.assertEqual(updated_case["description"], "Updated description for end-to-end workflow testing")
        
        # 4. 创建执行
        execution_data = {
            "case_id": case_id,
            "status": "queued",
            "progress": 0
        }
        response = self.client.post("/api/v1/executions/", json=execution_data)
        self.assertEqual(response.status_code, 200)
        execution_id = response.json()["id"]
        self.assertIsNotNone(execution_id)
        
        # 5. 启动执行（模拟为运行状态）
        update_execution_data = {
            "status": "running",
            "progress": 50
        }
        response = self.client.put(f"/api/v1/executions/{execution_id}", json=update_execution_data)
        self.assertEqual(response.status_code, 200)
        
        # 6. 完成执行
        complete_execution_data = {
            "status": "completed",
            "progress": 100
        }
        response = self.client.put(f"/api/v1/executions/{execution_id}", json=complete_execution_data)
        self.assertEqual(response.status_code, 200)
        
        # 7. 创建报告
        report_data = {
            "execution_id": execution_id,
            "case_id": case_id,
            "final_score": 85,
            "result": "PASS",
            "details": {
                "summary": "Good documentation quality",
                "comprehension_support": "HIGH",
                "engineering_usefulness": "MEDIUM",
                "explanation_reasonableness": "HIGH",
                "abstraction_quality": "GOOD",
                "fabrication_risk": "LOW",
                "engineering_action": {
                    "level": "SAFE_TO_USE",
                    "description": "Can be used as primary reference",
                    "recommended_action": "Use as main documentation"
                }
            }
        }
        response = self.client.post("/api/v1/reports/", json=report_data)
        self.assertEqual(response.status_code, 200)
        report_id = response.json()["id"]
        self.assertIsNotNone(report_id)
        
        # 8. 获取报告列表，确认报告已创建
        response = self.client.get("/api/v1/reports/")
        self.assertEqual(response.status_code, 200)
        reports = response.json()
        self.assertGreaterEqual(len(reports), 1)
        
        # 9. 获取特定报告，确认内容正确
        response = self.client.get(f"/api/v1/reports/{report_id}")
        self.assertEqual(response.status_code, 200)
        report = response.json()
        self.assertEqual(report["final_score"], 85)
        self.assertEqual(report["result"], "PASS")
        self.assertEqual(report["execution_id"], execution_id)
        self.assertEqual(report["case_id"], case_id)
        
        # 10. 获取图表数据
        response = self.client.get("/api/v1/reports/charts")
        self.assertEqual(response.status_code, 200)
        chart_data = response.json()
        self.assertIn("scoreDistribution", chart_data)
        self.assertIn("successRate", chart_data)
        self.assertIn("totalReports", chart_data)
        
        print("✅ 完整的端到端工作流程测试通过！")
        print(f"   - 创建案例: {case_id}")
        print(f"   - 创建执行: {execution_id}")
        print(f"   - 创建报告: {report_id}")
        print(f"   - 最终分数: {report['final_score']} (结果: {report['result']})")

if __name__ == '__main__':
    unittest.main()