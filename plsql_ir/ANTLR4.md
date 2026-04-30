# 🎯 Oracle PL/SQL 解析 + LLM 生成 Wiki 方案

## ✅ 方案可行性：**完全可行**

基于 antlr/grammars-v4 的 PL/SQL 语法 + 解析树提取 + LLM 生成 Wiki 是一个成熟的技术路径[[2]][[21]]。

---

## 📋 整体架构设计

```
┌─────────────────────────────────────────┐
│  📁 PL/SQL 源代码文件 (.sql/.pkb/.pks)   │
└────────────────┬────────────────────────┘
                 ▼
┌─────────────────────────────────────────┐
│  🔧 ANTLR4 解析层                        │
│  • PlSqlLexer.g4 + PlSqlParser.g4 [[2]] │
│  • 生成 Parse Tree / AST                │
│  • Visitor/Listener 提取结构化信息      │
└────────────────┬────────────────────────┘
                 ▼
┌─────────────────────────────────────────┐
│  🗂️ 结构化信息提取                       │
│  • 包/过程/函数定义                      │
│  • 参数列表、返回值、异常处理            │
│  • 表引用、变量声明、业务逻辑注释        │
└────────────────┬────────────────────────┘
                 ▼
┌─────────────────────────────────────────┐
│  🤖 LLM Prompt 构建                      │
│  • 模板化结构化数据 → Markdown           │
│  • 添加上下文约束 + 输出格式规范         │
└────────────────┬────────────────────────┘
                 ▼
┌─────────────────────────────────────────┐
│  📄 Wiki 文档输出                        │
│  • Markdown / Confluence / GitBook      │
│  • 支持增量更新 + 版本追踪               │
└─────────────────────────────────────────┘
```

---

## 🚀 分步执行方案

### 🔹 Step 1: 准备 PL/SQL 语法文件

```bash
# 克隆 grammars-v4 仓库
git clone https://github.com/antlr/grammars-v4.git
cd grammars-v4/sql/plsql

# 查看支持的生成目标
cat desc.xml
# <targets>Java;CSharp;Python3;Cpp;Go;Dart;TypeScript;...</targets>
```

📁 核心文件：
- `PlSqlLexer.g4` - 词法规则（关键字、标识符、字符串等）
- `PlSqlParser.g4` - 语法规则（10000+ 行，覆盖完整 PL/SQL 语法）[[2]]
- `examples/` - 测试用例，可用于验证解析效果

---

### 🔹 Step 2: 生成解析器代码（以 Python 为例）

```bash
# 安装依赖
pip install antlr4-python3-runtime

# 生成 Lexer 和 Parser
antlr4 -Dlanguage=Python3 -visitor -listener \
  PlSqlLexer.g4 PlSqlParser.g4

# 生成文件：
# • PlSqlLexer.py
# • PlSqlParser.py  
# • PlSqlParserVisitor.py  ← 重点使用这个
# • PlSqlParserListener.py
```

---

### 🔹 Step 3: 编写 Visitor 提取结构化信息

```python
# plsql_extractor.py
from antlr4 import *
from PlSqlLexer import PlSqlLexer
from PlSqlParser import PlSqlParser
from PlSqlParserVisitor import PlSqlParserVisitor

class PLSQLDocVisitor(PlSqlParserVisitor):
    """提取 PL/SQL 文档信息的 Visitor"""
    
    def __init__(self):
        self.procedures = []
        self.functions = []
        self.packages = []
        self.current_object = None
    
    def visitProcedure_spec(self, ctx: PlSqlParser.Procedure_specContext):
        """提取存储过程定义"""
        proc = {
            'name': ctx.procedure_name().getText(),
            'params': self._extract_params(ctx.parameter_list()),
            'source_line': ctx.start.line,
            'comment': self._extract_comment(ctx)
        }
        self.procedures.append(proc)
        return self.visitChildren(ctx)
    
    def visitFunction_spec(self, ctx: PlSqlParser.Function_specContext):
        """提取函数定义（含返回值）"""
        func = {
            'name': ctx.function_name().getText(),
            'params': self._extract_params(ctx.parameter_list()),
            'return_type': ctx.return_type().getText() if ctx.return_type() else None,
            'source_line': ctx.start.line,
            'comment': self._extract_comment(ctx)
        }
        self.functions.append(func)
        return self.visitChildren(ctx)
    
    def visitPackage_spec(self, ctx: PlSqlParser.Package_specContext):
        """提取包定义"""
        pkg = {
            'name': ctx.package_name().getText(),
            'members': [],  # 后续填充
            'comment': self._extract_comment(ctx)
        }
        self.packages.append(pkg)
        self.current_object = pkg
        return self.visitChildren(ctx)
    
    def _extract_params(self, param_list_ctx):
        """提取参数列表"""
        params = []
        if param_list_ctx:
            for param in param_list_ctx.parameter():
                params.append({
                    'name': param.parameter_name().getText(),
                    'mode': param.param_mode().getText() if param.param_mode() else 'IN',
                    'type': param.datatype().getText()
                })
        return params
    
    def _extract_comment(self, ctx):
        """提取前置注释（-- 或 /* */）"""
        # 实现逻辑：向上查找最近的注释令牌
        return ""  # 简化示例

    def get_structured_data(self):
        return {
            'packages': self.packages,
            'procedures': self.procedures,
            'functions': self.functions
        }
```

---

### 🔹 Step 4: 主解析流程

```python
# main.py
def parse_plsql_file(filepath: str) -> dict:
    """解析单个 PL/SQL 文件"""
    input_stream = FileStream(filepath, encoding='utf-8')
    lexer = PlSqlLexer(input_stream)
    token_stream = CommonTokenStream(lexer)
    parser = PlSqlParser(token_stream)
    
    # 关闭控制台错误输出（避免大量语法警告）
    parser.removeErrorListeners()
    
    # 解析入口：sql_script → unit_statement → ...
    tree = parser.sql_script()
    
    # 执行 Visitor 提取
    visitor = PLSQLDocVisitor()
    visitor.visit(tree)
    
    return visitor.get_structured_data()

# 批量处理
import glob
results = {}
for sql_file in glob.glob("src/**/*.pkb", recursive=True):
    results[sql_file] = parse_plsql_file(sql_file)
```

---

### 🔹 Step 5: 构建 LLM Prompt 生成 Wiki

```python
# wiki_generator.py
def build_llm_prompt(structured_data: dict) -> str:
    """构建面向 LLM 的 Prompt"""
    
    prompt = f"""你是一个专业的技术文档工程师。请根据以下 PL/SQL 代码结构信息，生成规范的 Wiki 文档。

## 输出要求
1. 使用 Markdown 格式
2. 包含：概述、参数说明、返回值、使用示例、注意事项
3. 技术术语保持英文，解释用中文
4. 不要编造代码中不存在的信息

## 代码结构信息
```json
{json.dumps(structured_data, ensure_ascii=False, indent=2)}
```

## 请生成文档：
"""
    return prompt

# 调用 LLM（以 OpenAI 为例）
import openai

def generate_wiki_with_llm(prompt: str, model="gpt-4o"):
    response = openai.ChatCompletion.create(
        model=model,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.3  # 降低随机性，保证文档一致性
    )
    return response.choices[0].message.content
```

---

### 🔹 Step 6: 输出示例（生成的 Wiki）

```markdown
# 📦 Package: USER_MANAGEMENT_PKG

> 用户管理相关功能包 | 最后更新: 2026-04-14

## 🔍 概述
提供用户创建、查询、权限分配等核心功能。

---

## 📋 过程/函数列表

### ➕ `create_user` (Procedure)

**功能**：创建新用户并初始化默认权限

**参数**：
| 参数名 | 模式 | 类型 | 说明 |
|--------|------|------|------|
| p_username | IN | VARCHAR2 | 用户名（唯一） |
| p_email | IN | VARCHAR2 | 邮箱地址 |
| p_role_id | IN | NUMBER | 角色ID，默认=2（普通用户） |
| p_user_id | OUT | NUMBER | 返回生成的用户ID |

**异常处理**：
- `DUP_VAL_ON_INDEX`: 用户名已存在
- `INVALID_EMAIL_FORMAT`: 邮箱格式校验失败（自定义）

**使用示例**：
```sql
DECLARE
  v_user_id NUMBER;
BEGIN
  USER_MANAGEMENT_PKG.create_user(
    p_username => 'zhangsan',
    p_email => 'zhangsan@example.com',
    p_user_id => v_user_id
  );
  DBMS_OUTPUT.PUT_LINE('Created user ID: ' || v_user_id);
END;
```

> 💡 **注意**：调用前需确保 `USER_SEQ` 序列已创建
```

---

## ⚠️ 关键注意事项

### 1️⃣ PL/SQL 语法复杂性
- Oracle PL/SQL 语法庞大，`PlSqlParser.g4` 有 10000+ 行[[2]]
- 建议**按需解析**：先聚焦 `procedure_spec` / `function_spec` / `package_spec`
- 使用 `parser.sql_script()` 作为入口，但可配置只解析特定单元

### 2️⃣ 注释提取技巧
```python
# ANTLR 默认不保留注释，需手动配置
lexer = PlSqlLexer(input_stream)
lexer.removeErrorListeners()
# 自定义 Token 过滤器保留 COMMENT 类型
```

### 3️⃣ 性能优化
- 大文件解析可能较慢，建议：
  - ✅ 按包/文件并行处理
  - ✅ 缓存解析结果（JSON/SQLite）
  - ✅ 增量解析：只处理变更文件

### 4️⃣ LLM 提示工程
```python
# 提升生成质量的关键技巧：
prompt += """
## 约束条件
- 如果参数类型是 TABLE%ROWTYPE，请说明"结构同 [表名] 表"
- 异常处理部分只列出代码中显式处理的 EXCEPTION
- 示例代码必须语法正确，可直接在 SQL Developer 执行
"""
```

---

## 🛠️ 推荐工具链

| 组件 | 推荐方案 | 说明 |
|------|---------|------|
| 解析框架 | ANTLR4 + Python3 | 开发效率高，调试方便 |
| 结构化存储 | SQLite / JSON | 轻量级，支持增量更新 |
| LLM 调用 | OpenAI API / 本地 LLM | 根据数据敏感性选择 |
| Wiki 输出 | MkDocs / VuePress | 支持版本管理 + 搜索 |
| 自动化 | GitHub Actions | 代码推送 → 自动解析 → 更新 Wiki |

---

## 🔄 进阶优化建议

1. **语义增强**：结合 Oracle 数据字典，自动补充表/字段说明
2. **调用关系分析**：通过 Visitor 跟踪 `procedure_call`，生成依赖图
3. **变更检测**：对比 AST 差异，只让 LLM 重写变更部分的文档
4. **多语言支持**：结构化数据 + LLM 可轻松生成中英双语文档

---

> 💡 **快速验证建议**：  
> 先用 `grammars-v4/sql/plsql/examples/` 中的测试文件跑通解析流程，确认 Parse Tree 结构符合预期，再扩展到真实业务代码[[2]]。
