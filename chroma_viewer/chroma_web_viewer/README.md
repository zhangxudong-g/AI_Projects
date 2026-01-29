# ChromaDB Web 查看器

这是一个基于Web的ChromaDB查看工具，允许用户通过前端界面设置数据库目录来查看和搜索ChromaDB中的数据。

## 功能特性

- 通过前端界面设置ChromaDB路径
- 查看数据库中的所有集合
- 浏览集合中的文档内容
- 搜索功能，支持语义搜索
- 显示文档元数据和相似度分数
- 响应式用户界面

## 安装要求

- Python 3.7+
- Flask
- ChromaDB

## 安装步骤

1. 克隆或下载此项目
2. 安装依赖：
   ```bash
   pip install -r requirements.txt
   ```
   
   或者分别安装：
   ```bash
   pip install Flask chromadb
   ```

## 运行应用

```bash
python app.py
```

应用将在 `http://localhost:5000` 上运行。

## 使用方法

1. 在"数据库路径"字段中输入ChromaDB的路径
2. （可选）指定集合名称（默认为"code_symbols"）
3. 设置要显示的文档数量限制
4. 点击"查看数据"按钮来浏览数据库内容
5. 要搜索特定内容，在"搜索查询"字段中输入查询词，然后点击"搜索数据"

## API 接口

- `GET /` - 主页面
- `POST /api/view` - 查看数据库内容
- `POST /api/search` - 搜索数据库内容

## 文件结构

```
chroma_web_viewer/
│
├── app.py                 # Flask后端应用
├── requirements.txt       # 项目依赖
├── static/
│   ├── styles.css         # CSS样式
│   └── script.js          # JavaScript逻辑
└── templates/
    └── index.html         # 主页面模板
```

## 注意事项

- 确保提供的数据库路径是有效的，并且包含ChromaDB数据
- 搜索功能基于语义相似性，而非关键词匹配
- 应用会在控制台输出调试信息