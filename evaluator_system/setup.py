"""
V1 评测系统安装配置
"""

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

with open("requirements.txt", "r", encoding="utf-8") as fh:
    requirements = [line.strip() for line in fh if line.strip() and not line.startswith("#")]

setup(
    name="v1-evaluator",
    version="1.0.0",
    author="AI Assistant",
    author_email="ai@example.com",
    description="V1 评测系统 - 验证 Wiki 是否忠实转述已解析事实",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/yourusername/v1-evaluator",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
    ],
    python_requires=">=3.10",
    install_requires=requirements,
    entry_points={
        "console_scripts": [
            "v1-evaluator=src.cli:main",
        ],
    },
)