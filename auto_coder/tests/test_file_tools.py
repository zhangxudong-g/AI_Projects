"""测试文件工具"""

import pytest
from pathlib import Path

from app.tools.file_tools import (
    write_file,
    read_file,
    list_files,
    file_exists,
    delete_file,
    create_directory,
    _get_workspace_root,
)


class TestFileTools:
    """文件工具测试类"""
    
    def test_write_and_read_file(self, test_workspace):
        """测试写入和读取文件"""
        test_file = "test_hello.txt"
        content = "Hello, AutoCoder!"
        
        # 写入文件
        write_result = write_file(test_file, content)
        assert write_result["success"] is True
        assert write_result["path"] == test_file
        
        # 读取文件
        read_result = read_file(test_file)
        assert read_result["success"] is True
        assert read_result["content"] == content
    
    def test_read_nonexistent_file(self):
        """测试读取不存在的文件"""
        result = read_file("nonexistent_file.txt")
        assert result["success"] is False
        assert "不存在" in result["message"]
    
    def test_list_files(self, test_workspace):
        """测试列出文件"""
        # 创建测试文件
        for i in range(3):
            write_file(f"test_file_{i}.txt", f"content {i}")
        
        # 列出文件
        result = list_files(".")
        assert result["success"] is True
        assert result["count"] >= 3
        
        # 清理
        for i in range(3):
            delete_file(f"test_file_{i}.txt")
    
    def test_file_exists(self, test_workspace):
        """测试文件存在检查"""
        test_file = "test_exists.txt"
        
        # 文件不存在
        result = file_exists(test_file)
        assert result["success"] is True
        assert result["exists"] is False
        
        # 创建文件后
        write_file(test_file, "content")
        result = file_exists(test_file)
        assert result["exists"] is True
        
        # 清理
        delete_file(test_file)
    
    def test_create_directory(self, test_workspace):
        """测试创建目录"""
        test_dir = "test_dir/subdir"
        
        result = create_directory(test_dir)
        assert result["success"] is True
        
        # 验证目录存在
        workspace = _get_workspace_root()
        assert (workspace / test_dir).exists()
    
    def test_delete_file(self, test_workspace):
        """测试删除文件"""
        test_file = "test_delete.txt"
        
        # 创建文件
        write_file(test_file, "content")
        
        # 删除文件
        result = delete_file(test_file)
        assert result["success"] is True
        
        # 验证文件不存在
        result = file_exists(test_file)
        assert result["exists"] is False
    
    def test_safe_path_security(self):
        """测试路径安全"""
        # 尝试目录穿越应该被阻止
        with pytest.raises(ValueError, match="必须在工作空间内"):
            from app.tools.file_tools import _safe_path
            _safe_path("../../etc/passwd")
    
    def test_write_file_with_nested_path(self, test_workspace):
        """测试写入嵌套路径文件"""
        nested_file = "nested/path/to/file.txt"
        content = "Nested content"
        
        result = write_file(nested_file, content)
        assert result["success"] is True
        
        # 验证文件内容
        read_result = read_file(nested_file)
        assert read_result["content"] == content
        
        # 清理
        delete_file(nested_file)
