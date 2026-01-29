# Chroma Viewer 架构说明

## 项目概述
Chroma Viewer 是一个用于查看和管理 Chroma 向量数据库的工具。

## 项目结构
```
chroma_viewer/
├── view_chroma_db.py        # 主要的数据库查看器脚本
├── create_test_db.py       # 创建测试数据库的脚本
├── test_connection.py      # 测试数据库连接的脚本
├── view_chroma_db_readme.md # 查看器使用说明
├── AGENTS.md               # 智能代理相关说明
├── chroma_env/             # Python虚拟环境
├── chroma_web_viewer/      # Web界面查看器
├── test_chroma_db/         # 测试数据库目录
├── test_new_db/            # 新测试数据库目录
└── QWEN.md                 # 项目相关的AI助手配置
```

## 核心组件

### 1. view_chroma_db.py
- 主要功能：连接到Chroma数据库并显示其中的集合和嵌入数据
- 支持功能：
  - 连接到本地或远程Chroma实例
  - 列出所有集合
  - 显示集合中的条目数量
  - 显示嵌入向量的维度信息
  - 展示元数据和文档内容

### 2. create_test_db.py
- 主要功能：创建用于测试的Chroma数据库
- 包含示例数据用于验证查看器功能

### 3. test_connection.py
- 主要功能：测试与Chroma数据库的连接性

### 4. chroma_web_viewer/
- Web界面组件，提供图形化方式查看Chroma数据库

## 技术栈
- Python
- ChromaDB
- Flask/FastAPI (用于Web界面)
- 嵌入模型相关库