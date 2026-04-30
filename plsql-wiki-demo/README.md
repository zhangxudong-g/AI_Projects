# PL/SQL Wiki Generator

纯 Python 实现的 PL/SQL 文档提取和 Wiki 生成工具。

## ✨ 特点

- **零外部依赖**：不需要 Java、ANTLR 或其他工具
- **纯 Python 实现**：使用正则表达式和状态机提取
- **轻量快速**：秒级解析大型 PL/SQL 文件
- **支持注释捕获**：自动提取代码中的文档注释
- **结构化输出**：生成 JSON 和 Markdown 两种格式

## 🚀 快速开始

### 1. 安装依赖

```bash
pip install -r requirements.txt
```

### 2. 运行 Demo

```bash
python main.py
```

这将解析 `test_sample.sql` 并生成：
- `output/structured.json` - 结构化数据
- `output/wiki.md` - Wiki 文档

### 3. 解析自定义文件

```bash
python main.py your_file.sql
```

### 4. 使用 LLM 生成增强文档（可选）

```bash
python main.py your_file.sql --llm
```

需要设置 `OPENAI_API_KEY` 环境变量。

## 📦 项目结构

```
plsql-wiki-demo/
├── plsql_extractor.py    # 核心提取器
├── main.py               # 主入口 + Wiki 生成
├── test_sample.sql       # 测试文件
├── setup_antlr.ps1       # 环境检查脚本
├── requirements.txt      # Python 依赖
├── output/               # 生成输出
│   ├── structured.json
│   └── wiki.md
└── README.md
```

## 📋 提取内容

支持提取以下 PL/SQL 元素：

| 元素 | 支持 |
|------|------|
| 包规范 (PACKAGE spec) | ✅ |
| 包体 (PACKAGE BODY) | ✅（跳过实现） |
| 函数 (FUNCTION) | ✅ |
| 过程 (PROCEDURE) | ✅ |
| 参数列表 | ✅ |
| 参数模式 (IN/OUT) | ✅ |
| 数据类型 | ✅ |
| 返回值类型 | ✅ |
| 注释 (Comments) | ✅ |

## 🛠️ API 使用

### 作为库使用

```python
from plsql_extractor import parse_plsql_file, parse_plsql_content

# 解析文件
result = parse_plsql_file('my_package.sql')

# 解析字符串
plsql_code = """
CREATE OR REPLACE PACKAGE my_pkg AS
    FUNCTION my_func(p_param IN VARCHAR2) RETURN NUMBER;
END my_pkg;
"""
result = parse_plsql_content(plsql_code)

print(result['summary'])
```

### 结构化数据格式

```json
{
  "source_objects": [
    {
      "type": "PACKAGE",
      "name": "USER_UTILS_PKG",
      "line": 10,
      "comment": "包注释...",
      "members": [
        {
          "type": "FUNCTION",
          "name": "validate_email",
          "line": 15,
          "comment": "函数注释...",
          "params": [
            {"name": "p_email", "mode": "IN", "datatype": "VARCHAR2"}
          ],
          "return_type": "BOOLEAN"
        }
      ]
    }
  ],
  "summary": {
    "packages": 1,
    "procedures": 2,
    "functions": 2
  }
}
```

## 🔧 故障排除

### Python 版本要求

需要 Python 3.8+

```bash
python --version
```

### 依赖安装失败

```bash
# 手动安装
pip install openai orjson
```

### 解析结果为空

- 确认 PL/SQL 文件格式正确
- 检查是否使用 `CREATE OR REPLACE PACKAGE` 语法
- 查看 `output/structured.json` 确认解析结果

## 📝 Wiki 输出示例

```markdown
# 📄 PL/SQL 文档

> 📦 包: 1 | ⚙️ 过程: 2 | 🔧 函数: 2

## 📦 包: `USER_UTILS_PKG`

### 成员列表

#### 🔧 `validate_email(IN p_email: VARCHAR2)` → `BOOLEAN`

#### ⚙️ `generate_user_id(IN p_prefix: VARCHAR2, OUT p_user_id: VARCHAR2)`
```

## 🤝 扩展

### 添加新的提取规则

编辑 `plsql_extractor.py`，在 `parse_content` 方法中添加新的正则匹配：

```python
# 示例：提取类型定义
type_match = re.match(r'TYPE\s+(\w+)\s+IS', line, re.IGNORECASE)
if type_match:
    # 处理类型定义
    pass
```

### 生成 Confluence 格式

在 `main.py` 中添加新的生成器函数：

```python
def generate_confluence_storage(data: dict) -> str:
    # 转换为 Confluence Storage Format
    pass
```

## 📄 License

MIT License
