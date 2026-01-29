# 从代码文件评估Wiki质量

如果您只有代码文件和对应的Wiki文档（而非facts.json），可以使用以下工具链：

## 1. 从代码中提取事实

使用代码解析器从源代码中提取事实：

```bash
python src/code_parser.py --input examples/sample_source_code.py --output extracted_facts.json --lang python
```

选项：
- `--input`: 源代码文件路径
- `--output`: 输出JSON文件路径
- `--lang`: 代码语言 (python/java)

## 2. 使用V1评测系统评估

然后使用提取的事实和Wiki文档进行评估：

```bash
python src/v1_evaluator.py --facts extracted_facts.json --wiki examples/wiki_basic.json --out evaluation_result.json
```

## 3. 一键评估

或者使用一体化工具直接评估：

```bash
python src/code_to_wiki_evaluator.py --code examples/sample_source_code.py --wiki examples/wiki_basic.json --output evaluation_result.json --lang python
```

选项：
- `--code`: 源代码文件路径
- `--wiki`: Wiki文档JSON文件路径
- `--output`: 输出结果文件路径
- `--lang`: 代码语言 (python/java)
- `--verbose`: 显示详细输出

## 示例

假设您有一个Python文件 `my_controller.py` 和对应的Wiki文档 `my_wiki.json`：

```bash
python src/code_to_wiki_evaluator.py --code my_controller.py --wiki my_wiki.json --output result.json --lang python --verbose
```

这将：
1. 解析 `my_controller.py` 并提取其中的事实
2. 使用提取的事实评估 `my_wiki.json`
3. 将评估结果保存到 `result.json`

## 重要说明

代码解析器会根据实际代码内容提取事实，因此Wiki文档中的fact_refs需要与解析器提取的事实相匹配。例如：

- 如果代码中是 `self.auth_service.checkPermission()`，那么Wiki中应该是 `"fact_refs": ["calls:self.auth_service.checkPermission"]`
- 如果代码中是 `@transaction.atomic` 注解，那么Wiki中应该是 `"fact_refs": ["annotations:@transaction.atomic"]`

## 支持的代码语言

目前支持：
- Python (使用AST解析)
- Java (使用正则表达式解析)

## 输出格式

输出结果与标准V1评测系统相同：

```json
{
  "metrics": {
    "faithfulness": 0.96,
    "hallucination_rate": 0.0,
    "key_fact_recall": 0.85,
    "redundancy_rate": 0.1
  },
  "violations": [
    { "claim": "xxx", "reason": "over_inference | missing_fact | invalid_ref", "violation_type": "over_inference" }
  ],
  "pass": true
}
```

## 工作原理

1. **代码解析**: 从源代码中提取函数/方法定义、调用关系、注解、条件语句等
2. **事实生成**: 将提取的信息转换为facts.json格式
3. **评估**: 使用V1评测系统比较Wiki文档与提取的事实
4. **报告**: 生成详细的评估报告，指出不一致之处