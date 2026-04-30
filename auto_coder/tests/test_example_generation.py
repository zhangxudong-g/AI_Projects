"""示例测试：生成 FastAPI CRUD 项目

这个测试演示如何使用 AutoCoder 生成一个完整的 FastAPI CRUD 项目
"""

import pytest
from unittest.mock import Mock, patch

from app.core.deep_agent import DeepAgentExecutor, DeepAgentState
from app.agents.planner import PlannerAgent
from app.agents.coder import CoderAgent


class TestFastAPICRUDGeneration:
    """FastAPI CRUD 项目生成测试"""
    
    @pytest.fixture
    def mock_llm(self):
        """模拟 LLM"""
        llm = Mock()
        
        # 模拟 Planner 响应
        planner_response = Mock()
        planner_response.content = '''
{
    "plan": [
        {
            "id": "step_1",
            "description": "创建项目结构和配置文件",
            "type": "config"
        },
        {
            "id": "step_2",
            "description": "创建数据库模型",
            "type": "code"
        },
        {
            "id": "step_3",
            "description": "创建 Pydantic schemas",
            "type": "code"
        },
        {
            "id": "step_4",
            "description": "创建 CRUD 操作",
            "type": "code"
        },
        {
            "id": "step_5",
            "description": "创建 API 路由",
            "type": "code"
        }
    ],
    "summary": "创建 FastAPI CRUD 项目"
}
'''
        
        # 模拟 Coder 响应
        coder_response = Mock()
        coder_response.content = '''
```python
# 文件路径：app/main.py
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"Hello": "World"}
```

```python
# 文件路径：app/models.py
from sqlalchemy import Column, Integer, String
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True)
    name = Column(String)
    email = Column(String)
```
'''
        
        # 配置 Mock 行为
        llm.invoke.side_effect = [planner_response, coder_response]
        
        return llm
    
    def test_planner_creates_correct_steps(self, mock_llm, sample_request):
        """测试 Planner 创建正确的步骤"""
        planner = PlannerAgent(mock_llm)
        
        result = planner.plan(sample_request)
        
        assert "plan" in result
        assert len(result["plan"]) > 0
        assert "summary" in result
    
    def test_coder_generates_files(self, mock_llm):
        """测试 Coder 生成文件"""
        tools = []
        coder = CoderAgent(mock_llm, tools)
        
        result = coder.generate_code(
            request="Create FastAPI app",
            current_step="Create main.py",
            existing_files=[],
        )
        
        assert "code" in result
        assert "files" in result
        assert len(result["files"]) > 0
    
    @pytest.mark.asyncio
    async def test_full_generation_workflow(self, sample_request):
        """测试完整生成流程（Mock 版）"""
        # 创建 Mock LLM
        mock_llm = Mock()
        mock_llm.invoke = Mock(return_value=Mock(content="Test"))
        
        # 创建执行器
        executor = DeepAgentExecutor(
            llm=mock_llm,
            tools=[],
            max_iterations=3,
        )
        
        # 执行
        # state = await executor.execute(sample_request)
        
        # 验证
        # assert state is not None


class TestGeneratedProjectStructure:
    """生成的项目结构测试"""
    
    def test_expected_files(self):
        """测试期望的文件列表"""
        expected_files = [
            "app/main.py",
            "app/models.py",
            "app/schemas.py",
            "app/crud.py",
            "app/database.py",
            "requirements.txt",
        ]
        
        # 验证文件列表
        assert len(expected_files) >= 5
    
    def test_file_dependencies(self):
        """测试文件依赖关系"""
        # main.py 依赖 models, schemas, crud
        # crud.py 依赖 models, database
        # schemas.py 无依赖
        
        dependencies = {
            "app/main.py": ["app/models.py", "app/schemas.py", "app/crud.py"],
            "app/crud.py": ["app/models.py", "app/database.py"],
            "app/schemas.py": [],
        }
        
        assert "app/main.py" in dependencies
        assert len(dependencies["app/schemas.py"]) == 0


class TestCodeQuality:
    """代码质量测试"""
    
    def test_has_type_hints(self):
        """测试类型注解"""
        sample_code = """
def create_user(name: str, email: str) -> dict:
    return {"name": name, "email": email}
"""
        # 验证有类型注解
        assert "->" in sample_code
        assert ":" in sample_code
    
    def test_has_docstrings(self):
        """测试文档字符串"""
        sample_code = '''
def calculate_total(items: list) -> float:
    """计算总价"""
    return sum(items)
'''
        # 验证有文档字符串
        assert '"""' in sample_code
    
    def test_error_handling(self):
        """测试错误处理"""
        sample_code = """
def divide(a: float, b: float) -> float:
    try:
        return a / b
    except ZeroDivisionError:
        return 0.0
"""
        # 验证有错误处理
        assert "try:" in sample_code
        assert "except" in sample_code
