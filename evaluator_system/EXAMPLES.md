# V1 评测系统使用示例

## 示例1：基本使用

以下是如何使用评测系统的基本示例：

### 输入文件

facts.json:
```json
{
  "facts": [
    {
      "id": "method:changeHogosyaJoho",
      "kind": "method",
      "role": "controller",
      "calls": ["AuthService.checkPermission", "HogosyaService.update"],
      "writes": ["HogosyaEntity"],
      "annotations": ["@Transactional"],
      "conditions": ["hogosyaId != null"]
    }
  ]
}
```

wiki.json:
```json
{
  "method": "changeHogosyaJoho",
  "claims": [
    { "text": "更新监护人信息", "fact_refs": ["writes:HogosyaEntity"] },
    { "text": "更新前进行权限校验", "fact_refs": ["calls:AuthService.checkPermission"] },
    { "text": "使用事务处理", "fact_refs": ["annotations:@Transactional"] }
  ]
}
```

### 运行评测

```bash
python src/cli.py --facts examples/facts_basic.json --wiki examples/wiki_basic.json --out result.json
```

### 输出结果

result.json:
```json
{
  "metrics": {
    "faithfulness": 1.0,
    "hallucination_rate": 0.0,
    "key_fact_recall": 1.0,
    "redundancy_rate": 0.0
  },
  "violations": [],
  "pass": true,
  "thresholds": {
    "faithfulness": 0.95,
    "hallucination_rate": 0.0,
    "key_fact_recall": 0.85,
    "redundancy_rate": 0.15
  }
}
```

## 示例2：检测幻觉

当Wiki包含没有事实支持的声明时，评测系统会检测到幻觉：

wiki_with_hallucination.json:
```json
{
  "method": "changeHogosyaJoho",
  "claims": [
    { "text": "提升系统整体性能", "fact_refs": [] },  // 没有事实引用，且包含越权推断
    { "text": "确保数据一致性", "fact_refs": [] }   // 没有事实引用，且包含越权推断
  ]
}
```

运行评测后，输出将包含违规信息：
```json
{
  "metrics": {
    "faithfulness": 0.0,
    "hallucination_rate": 1.0,
    "key_fact_recall": 0.0,
    "redundancy_rate": 0.0
  },
  "violations": [
    {
      "claim": "提升系统整体性能",
      "reason": "Claim缺少fact_ref",
      "violation_type": "missing_fact"
    },
    {
      "claim": "提升系统整体性能",
      "reason": "检测到越权推断关键词: 提升性能",
      "violation_type": "over_inference"
    },
    {
      "claim": "确保数据一致性",
      "reason": "Claim缺少fact_ref",
      "violation_type": "missing_fact"
    },
    {
      "claim": "确保数据一致性",
      "reason": "检测到越权推断关键词: 确保",
      "violation_type": "over_inference"
    }
  ],
  "pass": false
}
```

## 示例3：自定义阈值

您可以使用自定义阈值运行评测：

```bash
python src/cli.py \
  --facts examples/facts_basic.json \
  --wiki examples/wiki_basic.json \
  --out result.json \
  --threshold-faithfulness 0.9 \
  --threshold-hallucination 0.05 \
  --threshold-recall 0.8 \
  --threshold-redundancy 0.2
```

## 示例4：与Promptfoo集成

评测系统可以与Promptfoo集成进行回归测试：

```yaml
# promptfoo_config.yaml
tests:
  - description: "测试基本功能"
    vars:
      facts_file: "./examples/facts_basic.json"
      wiki_file: "./examples/wiki_basic.json"
    provider: 
      id: "exec:python src/v1_evaluator.py --facts {{facts_file}} --wiki {{wiki_file}} --out /tmp/result.json && cat /tmp/result.json"
    assert:
      - type: javascript
        value: |
          const result = JSON.parse(output);
          return result.pass === true;
        message: "评测未通过"
```

运行Promptfoo测试：
```bash
promptfoo eval
```

## 示例5：编程方式使用

您也可以在Python代码中直接使用评测系统：

```python
from src.v1_evaluator import V1Evaluator

# 创建评测器实例
evaluator = V1Evaluator()

# 从文件评测
result = evaluator.evaluate_from_files('examples/facts_basic.json', 'examples/wiki_basic.json')

print(f"评测通过: {result.pass_evaluation}")
print(f"信仰度: {result.metrics['faithfulness']}")
print(f"幻觉率: {result.metrics['hallucination_rate']}")

if result.violations:
    print(f"发现 {len(result.violations)} 个违规:")
    for violation in result.violations:
        print(f"  - '{violation.claim}' ({violation.violation_type.value}): {violation.reason}")
```