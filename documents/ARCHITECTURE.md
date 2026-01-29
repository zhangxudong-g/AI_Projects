# AI Projects 总体架构说明

## 项目概述
AI Projects 是一个包含多个AI相关工具和系统的综合项目集，主要包括Chroma数据库查看器和服务器监控系统。

## 项目结构
```
AI_Projects/
├── chroma_viewer/          # Chroma向量数据库查看器
│   ├── ARCHITECTURE.md     # Chroma Viewer架构说明
│   ├── view_chroma_db.py   # 主要的数据库查看器脚本
│   ├── create_test_db.py   # 创建测试数据库的脚本
│   ├── test_connection.py  # 测试数据库连接的脚本
│   ├── chroma_web_viewer/  # Web界面查看器
│   └── ...
├── server_monitor/         # 服务器监控系统
│   ├── ARCHITECTURE.md     # Server Monitor架构说明
│   ├── main.py             # 应用程序主入口点
│   ├── monitor.py          # 核心监控逻辑
│   ├── config.py           # 配置管理模块
│   ├── static/             # 静态资源文件
│   ├── templates/          # HTML模板
│   └── ...
├── .gitignore              # Git忽略文件配置
└── ARCHITECTURE.md         # 总体架构说明（当前文件）
```

## 子项目说明

### 1. Chroma Viewer
一个用于查看和管理 Chroma 向量数据库的工具，主要用于AI和机器学习项目中的向量数据管理。

#### 主要功能
- 连接到Chroma数据库实例
- 查看集合和嵌入数据
- 显示元数据和文档内容
- 提供Web界面进行可视化操作

#### 技术栈
- Python
- ChromaDB
- Flask/FastAPI

### 2. Server Monitor
一个全面的服务器监控系统，提供系统资源监控、API接口、通知等功能。

#### 主要功能
- 实时系统资源监控（CPU、内存、磁盘、网络等）
- RESTful API接口
- 多种通知方式
- 可扩展插件系统
- Web管理界面

#### 技术栈
- Python
- Flask
- SQLAlchemy
- SQLite

## 设计原则
1. 模块化设计：各子项目独立，便于单独开发和维护
2. 可扩展性：通过插件系统和API支持功能扩展
3. 易用性：提供直观的Web界面和清晰的文档
4. 可配置性：支持灵活的配置选项

## 开发指南
1. 每个子项目都有自己的依赖管理
2. 使用统一的配置文件格式
3. 遵循Python编码规范
4. 提供完整的文档和示例