# 测试数据导入工具

## 功能说明

该脚本用于从 `test/` 目录自动导入测试数据到系统的 case 中。

## 目录结构

```
test/
├── code/           # 源代码文件目录
│   ├── java/
│   └── plsql/
└── wiki/           # Wiki 文档目录
    ├── java/
    └── plsql/
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

## 工作原理

1. **扫描目录**：遍历 `test/code` 和 `test/wiki` 目录
2. **匹配文件**：根据文件名（不含扩展名）匹配代码和 wiki 文档对
3. **创建 Case**：
   - 为每对匹配的文件生成唯一的 `case_id`
   - 复制文件到 `data/cases/{case_id}/` 目录
   - 在数据库中创建 Case 记录

## 导入的 Case 数据

每个导入的 Case 包含：
- `case_id`: 唯一标识符（格式：`case_xxxxxxxx`）
- `name`: 文件名（如：`Controller_GakureiboPrintOutController.java`）
- `source_code_path`: 源代码文件路径（如：`data/cases/case_xxx/source_code.java`）
- `wiki_path`: Wiki 文档路径（如：`data/cases/case_xxx/wiki.md`）

## 示例输出

```
============================================================
测试数据导入工具
============================================================
项目根目录：D:\AI_Projects\wiki_fact_judge
测试数据目录：D:\AI_Projects\wiki_fact_judge\test
目标目录：D:\AI_Projects\wiki_fact_judge\data\cases

准备导入数据...

正在扫描 test 目录...
找到 10 对匹配的文件：

[1/10] 处理：Controller_GakureiboPrintOutController.java
  代码：D:\AI_Projects\wiki_fact_judge\test\code\java\Controller_GakureiboPrintOutController.java.md
  Wiki: D:\AI_Projects\wiki_fact_judge\test\wiki\java\Controller_GakureiboPrintOutController.java.md
  [OK] 已创建 case_id: case_e1e7397b
    名称：Controller_GakureiboPrintOutController.java
    代码路径：data\cases\case_e1e7397b\source_code.java
    Wiki 路径：data\cases\case_e1e7397b\wiki.md

...

============================================================
导入完成！
  找到匹配文件：10 对
  成功导入：10 个 case
============================================================
```

## 注意事项

1. 导入的 Case 数据会保存到 SQLite 数据库（`backend/judge.db`）
2. 文件会被复制到 `data/cases/` 目录
3. 重复运行会创建新的 Case 记录（不会覆盖已有数据）
4. 文件名匹配规则：代码文件和 wiki 文档的文件名（不含扩展名）必须相同

## 验证导入结果

导入完成后，可以通过 API 验证：

```bash
# 获取所有 Case 列表
curl http://localhost:8000/cases/

# 获取单个 Case 详情
curl http://localhost:8000/cases/case_e1e7397b
```
