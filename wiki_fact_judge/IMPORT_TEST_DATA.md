# 测试数据导入工具

## 功能说明

该脚本用于从 `test/` 目录自动导入测试数据到系统的 case 中。

## 目录结构

```
test/
├── code/           # 源代码文件目录
│   ├── java/       # Java 代码
│   │   └── *.java
│   └── plsql/      # PL/SQL 代码
│       └── *.SQL
└── wiki/           # Wiki 文档目录
    ├── java/       # Java 文档
    │   └── *.java.md
    └── plsql/      # PL/SQL 文档
        └── *.SQL.md
```

## 使用方法

### 试运行（不实际导入）

```bash
python import_test_data.py --dry-run
```

### 实际导入

```bash
python import_test_data.py
```

### 只导入指定语言

```bash
# 只导入 Java 文件
python import_test_data.py --language java

# 只导入 PL/SQL 文件  
python import_test_data.py --language plsql
```

## 工作原理

1. **扫描目录**：遍历 `test/code` 和 `test/wiki` 目录（包括子目录）
2. **匹配文件**：根据文件名（不含扩展名）匹配代码和 wiki 文档对
   - Java: `Controller_xxx.java` 匹配 `Controller_xxx.java.md`
   - PL/SQL: `GKBFKGZSHNT.SQL` 匹配 `GKBFKGZSHNT.SQL.md`
3. **检测语言**：根据子目录名（java/plsql）自动检测语言类型
4. **创建 Case**：
   - 为每对匹配的文件生成唯一的 `case_id`
   - 复制文件到 `data/cases/{case_id}/` 目录
   - Java 源文件保存为 `source_code.java`
   - PL/SQL 源文件保存为 `source_code.sql`
   - Wiki 文档统一保存为 `wiki.md`
   - 在数据库中创建 Case 记录

## 导入的 Case 数据

每个导入的 Case 包含：
- `case_id`: 唯一标识符（格式：`case_xxxxxxxx`）
- `name`: 文件名
- `source_code_path`: 源代码文件路径
- `wiki_path`: Wiki 文档路径
- `yaml_path`: YAML 配置文件路径（可选）

### Java Case 示例

```json
{
  "case_id": "case_2458b0d7",
  "name": "Controller_GakureiboPrintOutController.java",
  "source_code_path": "data/cases/case_2458b0d7/source_code.java",
  "wiki_path": "data/cases/case_2458b0d7/wiki.md"
}
```

### PL/SQL Case 示例

```json
{
  "case_id": "case_84fe5822",
  "name": "GKBFKGZSHNT.SQL",
  "source_code_path": "data/cases/case_84fe5822/source_code.sql",
  "wiki_path": "data/cases/case_84fe5822/wiki.md"
}
```

## 示例输出

```
============================================================
测试数据导入工具
============================================================
项目根目录：D:\AI_Projects\wiki_fact_judge
测试数据目录：D:\AI_Projects\wiki_fact_judge\test
目标目录：D:\AI_Projects\wiki_fact_judge\data\cases
支持的语言：java, plsql, py, js, ts, sql

准备导入数据...

正在扫描 test 目录...
  扫描 code 目录：找到 20 个代码文件
  扫描 wiki 目录：找到 20 个 wiki 文件

找到 20 对匹配的文件:
  - java: 10 个
  - sql: 10 个

[1/20] 处理：Controller_GakureiboPrintOutController.java [java]
  子目录：java
  代码：D:\AI_Projects\wiki_fact_judge\test\code\java\Controller_GakureiboPrintOutController.java
  Wiki: D:\AI_Projects\wiki_fact_judge\test\wiki\java\Controller_GakureiboPrintOutController.java.md
  [OK] 已创建 case_id: case_2458b0d7
    名称：Controller_GakureiboPrintOutController.java
    语言：java
    代码路径：data\cases\case_2458b0d7\source_code.java
    Wiki 路径：data\cases\case_2458b0d7\wiki.md

...

============================================================
导入完成！
  找到匹配文件：20 对
  成功导入：20 个 case

  按语言统计:
    - java: 10 个
    - plsql: 10 个
============================================================
```

## 注意事项

1. 导入的 Case 数据会保存到 SQLite 数据库（`backend/judge.db`）
2. 文件会被复制到 `data/cases/` 目录
3. 重复运行会创建新的 Case 记录（不会覆盖已有数据）
4. 文件名匹配规则：代码文件和 wiki 文档的文件名（不含扩展名）必须相同
5. 子目录必须匹配：`code/java` 匹配 `wiki/java`，`code/plsql` 匹配 `wiki/plsql`

## 验证导入结果

导入完成后，可以通过 API 验证：

```bash
# 获取所有 Case 列表
curl http://localhost:8000/cases/

# 获取单个 Case 详情
curl http://localhost:8000/cases/case_2458b0d7

# 查看导入的 Case 总数
curl http://localhost:8000/cases/ | python -m json.tool | findstr /C:"case_id" | find /C "case_"
```

## 支持的语言

| 语言 | 子目录 | 源文件扩展名 | Wiki 扩展名 |
|------|--------|-------------|------------|
| Java | java | .java | .java.md |
| PL/SQL | plsql | .SQL | .SQL.md |
| Python | py | .py | .py.md |
| JavaScript | js | .js | .js.md |
| TypeScript | ts | .ts | .ts.md |
| SQL | sql | .sql | .sql.md |
