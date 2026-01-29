# V1 评测系统使用指南

## 概述

V1 评测系统是一个专门用于验证 Wiki 是否忠实转述已解析事实的自动化评测工具。它旨在检测 LLM 生成的文档中的幻觉、越权推断和事实遗漏问题。

## 系统架构

```
LLM → wiki.json
           ↓
facts.json → V1 Evaluator → evaluation_result.json
           ↓
        Promptfoo → 报告 / CI
```

## 输入格式

### facts.json
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

### wiki.json
```json
{
  "method": "changeHogosyaJoho",
  "claims": [
    { "text": "调用AuthService.checkPermission", "fact_refs": ["calls:AuthService.checkPermission"] },
    { "text": "写入HogosyaEntity实体", "fact_refs": ["writes:HogosyaEntity"] }
  ]
}
```

## 输出格式

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
  "pass": true,
  "thresholds": {
    "faithfulness": 0.95,
    "hallucination_rate": 0.0,
    "key_fact_recall": 0.85,
    "redundancy_rate": 0.15
  }
}
```

## 评测规则详解

### 1. 事实引用完整性 (F1)
- 每条 Claim 必须有 ≥1 个 fact_ref
- fact_ref 必须存在于 facts.json
- **示例**：
  - ✅ `"fact_refs": ["calls:AuthService.checkPermission"]`
  - ❌ `"fact_refs": []` (缺少引用)
  - ❌ `"fact_refs": ["invalid_ref"]` (无效引用)

### 2. 声明-事实对齐 (F2)
- calls → 仅允许"调用"、"执行"、"启动"、"触发"、"发起"、"进行"、"校验"等表述
- writes → 仅允许"写入"、"更新"、"修改"、"保存"、"存储"、"变更"等表述
- annotations → 仅允许"声明"、"标注"、"标记"、"注解"、"添加"、"使用"等表述
- conditions → 仅允许"条件"、"判断"、"检查"、"验证"、"当"、"时执行"等表述
- **示例**：
  - ✅ "调用AuthService.checkPermission" (与calls对齐)
  - ❌ "确保AuthService.checkPermission" (语义不对齐)

### 3. 无越权推断 (F3)
- 禁止出现目的/效果/保证类表述
- 黑名单词示例：确保、保证、防止、避免、提升性能、优化、改进、提高、增强、加强、实现、达到、完成、解决、满足、符合、适应、应对、管理、控制
- **示例**：
  - ❌ "确保数据安全" (包含"确保")
  - ❌ "提升系统性能" (包含"提升性能")
  - ✅ "调用权限检查服务" (正常描述)

### 4. 关键事实召回 (F4)
- calls / writes / annotations / conditions 为关键事实
- Wiki 至少覆盖一次
- **计算公式**：召回率 = 被引用的关键事/总关键事实数

### 5. 冗余检测 (F5)
- 无事实增量的空洞描述判为冗余
- 文本过短且无事实引用的内容判为冗余
- **示例**：
  - ❌ "这个方法很好" (无事实引用，内容空洞)
  - ✅ "调用AuthService.checkPermission" (有事实引用)

## 指标与阈值

| 指标 | 说明 | 默认阈值 | 通过条件 |
|------|------|----------|----------|
| Faithfulness | 合法 Claim 占比 | ≥95% | 通过 |
| Hallucination Rate | 幻觉比例 | **0%** | 通过 |
| Key Fact Recall | 关键事实覆盖 | ≥85% | 通过 |
| Redundancy Rate | 冗余比例 | ≤15% | 通过 |

## 使用方法

### 命令行使用

```bash
python src/cli.py --facts examples/facts_basic.json --wiki examples/wiki_basic.json --out result.json
```

选项：
- `--facts`: facts.json 文件路径 (必需)
- `--wiki`: wiki.json 文件路径 (必需)
- `--out`: 输出结果文件路径 (必需)
- `--verbose`: 显示详细输出
- `--threshold-faithfulness`: 信仰度阈值 (默认: 0.95)
- `--threshold-hallucination`: 幻觉率阈值 (默认: 0.0)
- `--threshold-recall`: 关键事实召回率阈值 (默认: 0.85)
- `--threshold-redundancy`: 冗余率阈值 (默认: 0.15)

### 直接使用 Python 模块

```python
from src.v1_evaluator import V1Evaluator

evaluator = V1Evaluator()
result = evaluator.evaluate_from_files('examples/facts_basic.json', 'examples/wiki_basic.json')

print(f"评测通过: {result.pass_evaluation}")
print(f"信仰度: {result.metrics['faithfulness']}")
print(f"幻觉率: {result.metrics['hallucination_rate']}")
```

## 示例分析

### 示例1：完美匹配
- **输入**: 完整覆盖所有事实的Wiki
- **输出**: 所有指标均为1.0，无违规，评测通过
- **结果**: `{"pass": true, "metrics": {"faithfulness": 1.0, "hallucination_rate": 0.0, "key_fact_recall": 1.0, "redundancy_rate": 0.0}}`

### 示例2：存在幻觉
- **输入**: 包含越权推断的Wiki
- **输出**: 检测到违规，幻觉率>0，评测失败
- **结果**: `{"pass": false, "violations": [{"claim": "确保数据安全", "reason": "检测到越权推断关键词: 确保", "violation_type": "over_inference"}]}`

### 示例3：部分覆盖
- **输入**: 只覆盖部分事实的Wiki
- **输出**: 关键事实召回率<1.0，但无其他问题
- **结果**: 根据阈值决定是否通过

## 常见问题解答

### Q: 为什么我的评测没有通过？
A: 检查以下几个方面：
1. 是否有声明缺少fact_refs？
2. 是否包含越权推断关键词？
3. 是否存在语义不对齐？
4. 关键事实召回率是否低于阈值？

### Q: 如何提高评测分数？
A: 
1. 确保每个声明都有对应的fact_refs
2. 避免使用越权推断关键词
3. 确保声明文本与事实类型语义对齐
4. 尽可能覆盖所有关键事实

### Q: 如何自定义阈值？
A: 使用命令行参数或在代码中调整阈值，例如：
```bash
python src/cli.py --facts examples/facts_basic.json --wiki examples/wiki_basic.json --out result.json --threshold-recall 0.7
```

## 与CI/CD集成

在CI环境中，可以使用以下命令：
```bash
python src/cli.py --facts $FACTS_FILE --wiki $WIKI_FILE --out result.json
if [ $? -ne 0 ]; then
  echo "评测失败，阻止合并"
  exit 1
fi
```

## 推荐的使用方式

根据不同的使用场景，我们推荐以下使用方式：

- **标准评估**: 当您已有facts.json和wiki.json时，使用 `src/cli.py`
- **单文件快速评估**: 当您有源码和MD格式的Wiki时，推荐使用 `simple_evaluator.py` (最简单)
- **批量处理**: 当您需要处理整个项目目录时，使用 `src/batch_processor.py`
- **高级定制**: 当您需要更多控制选项时，使用 `src/code_to_wiki_evaluator.py`

## 与Promptfoo集成

系统提供了与 Promptfoo 的集成，可以用于回归测试：
```bash
promptfoo eval
```

## 扩展性

系统采用模块化设计，可以轻松添加新的评测规则：
1. 在V1Evaluator类中添加新的规则方法
2. 在evaluate方法中调用新规则
3. 更新相应的指标计算逻辑