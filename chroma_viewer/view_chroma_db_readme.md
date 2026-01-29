# ChromaDB 查看工具

这是一个用于查看 Code Wiki 项目中存储在 ChromaDB 中的代码符号信息的实用工具。

## 功能特性

- 列出所有 Code Wiki 项目
- 查看特定项目的 ChromaDB 内容
- 搜索 ChromaDB 中的代码符号
- 显示文档内容和元数据
- 显示相似度分数

## 使用方法

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

## 输出说明

- `[COLLECTION]`: 显示可用的集合
- `[STATS]`: 显示集合统计信息
- `[PREVIEW]`: 显示文档预览
- `[DOC]`: 显示文档内容
- `[META]`: 显示元数据
- `[SEARCH]`: 显示搜索结果
- `[SIMILARITY]`: 显示相似度分数

## 注意事项

- 项目依赖于 uv 包管理器来运行
- 工具会自动检测项目中的 chroma_store 目录
- 搜索功能基于语义相似性，而非关键词匹配
- 如果集合为空，则无法执行搜索操作