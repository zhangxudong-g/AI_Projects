"""pytest 配置"""

import os
import sys
import pytest
from pathlib import Path

# 添加项目根目录到路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

# 设置测试环境变量
os.environ["MODEL_PROVIDER"] = "openai"
os.environ["MODEL_API_KEY"] = "test-key"
os.environ["EXEC_WORKSPACE_DIR"] = str(project_root / "workspace_test")
os.environ["LOG_DEBUG_MODE"] = "true"


@pytest.fixture(scope="session")
def test_workspace():
    """测试工作空间"""
    workspace = project_root / "workspace_test"
    workspace.mkdir(parents=True, exist_ok=True)
    yield workspace
    # 清理测试文件（可选）
    # import shutil
    # shutil.rmtree(workspace)


@pytest.fixture
def sample_request():
    """示例请求"""
    return "创建一个 FastAPI CRUD 项目，包含用户模型的增删改查功能"


@pytest.fixture
def sample_files():
    """示例文件列表"""
    return [
        "app/main.py",
        "app/models.py",
        "app/schemas.py",
        "app/crud.py",
        "requirements.txt",
    ]
