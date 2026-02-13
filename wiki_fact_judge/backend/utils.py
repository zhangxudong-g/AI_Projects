"""
通用文件验证和处理工具
"""
import os
from fastapi import UploadFile, HTTPException
from pathlib import Path
import re

# 定义允许的文件扩展名
ALLOWED_EXTENSIONS = {
    '.txt', '.js', '.ts', '.jsx', '.tsx', '.py', '.java',
    '.cpp', '.c', '.h', '.cs', '.go', '.rs', '.rb', '.php',
    '.html', '.css', '.json', '.yaml', '.yml', '.md', '.sql', '.plsql'
}

# 定义最大文件大小 (10MB)
MAX_FILE_SIZE = 10 * 1024 * 1024


def validate_file_extension(filename: str) -> bool:
    """验证文件扩展名"""
    _, ext = os.path.splitext(filename.lower())
    return ext in ALLOWED_EXTENSIONS


def sanitize_filename(filename: str) -> str:
    """清理文件名，防止路径遍历攻击"""
    # 移除路径分隔符以防止路径遍历
    filename = filename.replace('/', '_').replace('\\', '_')
    # 确保文件名不包含其他潜在危险字符
    # 只保留字母、数字、下划线、连字符和点号
    sanitized = re.sub(r'[^\w\-_.]', '_', filename)
    return sanitized


def validate_file_size(file: UploadFile) -> bool:
    """验证文件大小"""
    # 读取文件内容以检查大小
    file.file.seek(0, 2)  # 移动到文件末尾
    size = file.file.tell()
    file.file.seek(0)  # 重置文件指针到开头
    return size <= MAX_FILE_SIZE


def save_uploaded_file(upload_file: UploadFile, destination_path: str) -> str:
    """保存上传的文件并返回存储路径"""
    # 验证文件扩展名
    if not validate_file_extension(upload_file.filename):
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid file type: {upload_file.filename}. Allowed types: {', '.join(ALLOWED_EXTENSIONS)}"
        )

    # 验证文件大小
    if not validate_file_size(upload_file):
        raise HTTPException(
            status_code=400, 
            detail=f"File {upload_file.filename} exceeds size limit of {MAX_FILE_SIZE/(1024*1024)}MB"
        )

    # 清理文件名以防止路径遍历
    clean_filename = sanitize_filename(upload_file.filename)
    full_path = str(Path(destination_path) / clean_filename)
    
    with open(full_path, "wb") as buffer:
        buffer.write(upload_file.file.read())
    
    return full_path