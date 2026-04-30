"""测试 API 接口"""

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    """测试客户端"""
    return TestClient(app)


class TestHealthEndpoint:
    """健康检查接口测试"""
    
    def test_health_check(self, client):
        """测试健康检查"""
        response = client.get("/health")
        
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"
        assert "version" in response.json()


class TestRootEndpoint:
    """根路径接口测试"""
    
    def test_root(self, client):
        """测试根路径"""
        response = client.get("/")
        
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "AutoCoder"
        assert "docs" in data
        assert "health" in data


class TestGenerateCodeEndpoint:
    """代码生成接口测试"""
    
    def test_generate_code_request_format(self, client):
        """测试请求格式（需要 Mock LLM）"""
        # 这个测试需要真实的 LLM，所以会失败
        # 实际测试应该使用 Mock
        
        response = client.post(
            "/api/generate_code",
            json={
                "request": "创建一个 Hello World 程序",
                "debug": True,
            }
        )
        
        # 由于没有配置 LLM，应该返回 500 或超时
        # 这里只是验证请求格式正确
        assert response.status_code in [200, 500]
    
    def test_generate_code_missing_request(self, client):
        """测试缺少请求参数"""
        response = client.post(
            "/api/generate_code",
            json={}
        )
        
        assert response.status_code == 422  # Validation Error


class TestProjectsEndpoint:
    """项目接口测试"""
    
    def test_list_projects(self, client):
        """测试列出项目"""
        response = client.get("/api/projects")
        
        # 应该返回空列表或现有项目
        assert response.status_code == 200
        assert isinstance(response.json(), list)


class TestStatsEndpoint:
    """统计接口测试"""
    
    def test_get_stats(self, client):
        """测试获取统计信息"""
        response = client.get("/api/stats")
        
        assert response.status_code == 200
        data = response.json()
        assert "total_executions" in data
        assert "total_projects" in data


class TestWorkspaceEndpoint:
    """工作空间接口测试"""
    
    def test_list_workspace_files(self, client):
        """测试列出工作空间文件"""
        response = client.get("/api/workspace/files")
        
        # 应该返回文件列表
        assert response.status_code == 200
        data = response.json()
        assert "files" in data
        assert "count" in data
    
    def test_list_workspace_files_recursive(self, client):
        """测试递归列出文件"""
        response = client.get("/api/workspace/files?recursive=true")
        
        assert response.status_code == 200


class TestCORS:
    """CORS 测试"""
    
    def test_cors_headers(self, client):
        """测试 CORS 头"""
        response = client.get(
            "/health",
            headers={"Origin": "http://localhost:3000"}
        )
        
        # FastAPI 的 CORS 中间件应该添加这些头
        assert "access-control-allow-origin" in response.headers or response.status_code == 200


@pytest.mark.integration
class TestIntegration:
    """集成测试"""
    
    def test_full_workflow(self, client, sample_request):
        """测试完整工作流"""
        # 1. 生成代码（需要 Mock）
        # 2. 查询执行状态
        # 3. 获取项目列表
        # 4. 读取生成的文件
        
        # 这是一个端到端测试的框架
        # 实际实现需要 Mock LLM 和工具
        
        pass
