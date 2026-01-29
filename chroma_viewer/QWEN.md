# ChromaDB 查看工具项目说明

## 项目概述

这是一个用于查看 Code Wiki 项目中存储在 ChromaDB 中的代码符号信息的实用工具。该工具允许用户浏览、搜索和分析存储在 ChromaDB 向量数据库中的代码符号数据。

主要功能包括：
- 列出所有 Code Wiki 项目
- 查看特定项目的 ChromaDB 内容
- 搜索 ChromaDB 中的代码符号
- 显示文档内容和元数据
- 显示相似度分数

## 技术栈

- **Python**: 主要编程语言
- **ChromaDB**: 向量数据库用于存储代码符号信息
- **Argparse**: 用于命令行参数解析
- **JSON**: 用于数据处理

## 文件结构

- `view_chroma_db.py`: 主程序文件，包含查看和搜索 ChromaDB 的核心功能
- `view_chroma_db_readme.md`: 详细的使用说明文档

## 核心功能

### 1. 查看 ChromaDB 内容
- 连接到持久化 ChromaDB
- 列出所有可用集合
- 显示集合统计信息
- 预览文档内容和元数据

### 2. 搜索 ChromaDB 内容
- 基于语义相似性的搜索功能
- 显示搜索结果的相关度分数
- 支持限制返回结果数量

### 3. 项目管理
- 自动检测项目中的 chroma_store 目录
- 支持列出所有 Code Wiki 项目

## 使用方法

### 安装依赖
```bash
# 该项目使用 uv 包管理器
uv run python scripts/view_chroma_db.py ...
```

### 1. 列出所有项目
```bash
uv run python scripts/view_chroma_db.py --list-projects
```

### 2. 查看特定项目的 ChromaDB 内容
```bash
uv run python scripts/view_chroma_db.py --project <项目名称>
```

例如：
```bash
uv run python scripts/view_chroma_db.py --project agent3
```

### 3. 搜索 ChromaDB 内容
```bash
uv run python scripts/view_chroma_db.py --project <项目名称> --search <搜索词>
```

例如：
```bash
uv run python scripts/view_chroma_db.py --project agent3 --search "function"
```

### 4. 指定显示数量
```bash
uv run python scripts/view_chroma_db.py --project <项目名称> --limit <数量>
```

例如，只显示前3个文档：
```bash
uv run python scripts/view_chroma_db.py --project agent3 --limit 3
```

### 5. 使用自定义数据库路径
```bash
uv run python scripts/view_chroma_db.py --db-path <数据库路径>
```

## 参数说明

- `--list-projects`: 列出所有 Code Wiki 项目
- `--project`: 指定项目名称（会自动构建数据库路径）
- `--db-path`: 直接指定 ChromaDB 路径
- `--collection`: 指定集合名称（默认为 "code_symbols"）
- `--limit`: 限制显示的文档数量（默认为 5）
- `--search`: 搜索查询文本
- `-h`, `--help`: 显示帮助信息

## 输出格式

- `[COLLECTION]`: 显示可用的集合
- `[STATS]`: 显示集合统计信息
- `[PREVIEW]`: 显示文档预览
- `[DOC]`: 显示文档内容
- `[META]`: 显示元数据
- `[SEARCH]`: 显示搜索结果
- `[SIMILARITY]`: 显示相似度分数
- `[ERROR]`: 显示错误信息

## 开发约定

- 代码使用中文注释和输出信息
- 遵循 Python 编码规范
- 使用 argparse 进行命令行参数处理
- 错误处理采用 try-except 结构
- 函数设计遵循单一职责原则

## 注意事项

- 项目依赖于 uv 包管理器来运行
- 工具会自动检测项目中的 chroma_store 目录
- 搜索功能基于语义相似性，而非关键词匹配
- 如果集合为空，则无法执行搜索操作

## Qwen Added Memories
- 每次接受时候，更新当前内容，如果和之前的功能有差别，请修正。
