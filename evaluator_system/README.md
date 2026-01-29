# V1 评测系统

## 概述

V1 评测系统是一个专门用于验证 Wiki 是否忠实转述已解析事实的自动化评测工具。它旨在检测 LLM 生成的文档中的幻觉、越权推断和事实遗漏问题。

## 特性

- **零幻觉检测**：严格检测文档中的幻觉内容
- **事实引用验证**：验证每个声明都有对应的事实支持
- **语义对齐检查**：确保声明与事实在语义上对齐
- **关键事实覆盖率**：计算关键事实的覆盖情况
- **冗余检测**：识别文档中的冗余内容
- **量化指标**：提供 faithfulness、hallucination_rate、key_fact_recall、redundancy_rate 等指标
- **Promptfoo 集成**：支持多模型/多 Prompt 的自动回归评测

## 安装

```bash
# 克隆项目
git clone <repository-url>
cd evaluator_system

# 确保 Python 3.10+
python --version
```

## 使用方法

### 命令行使用

#### 1. 标准使用（已有facts.json和wiki.json）

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

#### 2. 从代码文件评估（仅有源代码和Wiki文档）

如果您只有源代码文件和对应的Wiki文档（而非facts.json），可以使用以下命令：

```bash
python src/code_to_wiki_evaluator.py --code my_source_code.py --wiki my_wiki.json --output result.json --lang python
```

选项：
- `--code`: 源代码文件路径 (必需)
- `--wiki`: wiki.json 文件路径 (必需)
- `--output`: 输出结果文件路径 (必需)
- `--lang`: 代码语言 (python/java)
- `--verbose`: 显示详细输出

此命令将：
1. 自动从源代码中提取事实
2. 使用提取的事实评估Wiki文档
3. 生成评估结果

#### 3. 简化版评估（最简单的方式）

对于最简单的使用场景，您可以直接使用源代码和MD格式的Wiki文档进行评估：

##### 方式1：指定输出文件路径
```bash
python simple_evaluator.py --code my_source_code.py --wiki-md my_wiki.md --output result.json --lang python
```

##### 方式2：自动命名（推荐）
```bash
python simple_evaluator.py --code my_source_code.py --wiki-md my_wiki.md --lang python
```

默认会将结果保存到 `results/{code_filename}_evaluation.json`

选项：
- `--code`: 源代码文件路径 (必需)
- `--wiki-md`: MD格式的Wiki文档路径 (必需)
- `--output`: 输出结果文件路径 (可选，如果不指定，则保存到results目录并以代码文件名命名)
- `--results-dir`: 结果保存目录 (默认: results)
- `--lang`: 代码语言 (python/java)
- `--verbose`: 显示详细输出

这是最简化的评估方式，一步完成整个流程。

### 直接使用 Python 模块

```python
from src.v1_evaluator import V1Evaluator

evaluator = V1Evaluator()
result = evaluator.evaluate_from_files('examples/facts_basic.json', 'examples/wiki_basic.json')

print(f"评测通过: {result.pass_evaluation}")
print(f"信仰度: {result.metrics['faithfulness']}")
print(f"幻觉率: {result.metrics['hallucination_rate']}")
```

### 从代码文件进行评估

```python
from src.code_to_wiki_evaluator import main as evaluate_code_and_wiki

# 使用命令行参数
import sys
sys.argv = ['code_to_wiki_evaluator.py',
            '--code', 'my_source_code.py',
            '--wiki', 'my_wiki.json',
            '--output', 'result.json',
            '--lang', 'python']

evaluate_code_and_wiki()
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
    { "text": "更新监护人信息", "fact_refs": ["writes:HogosyaEntity"] },
    { "text": "更新前进行权限校验", "fact_refs": ["calls:AuthService.checkPermission"] }
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

## Promptfoo 集成

系统提供了与 Promptfoo 的深度集成，可以用于多模型/多Prompt的自动回归测试：

```bash
# 安装 promptfoo
npm install -g promptfoo

# 运行评测
promptfoo eval
```

详细集成指南请参见 `PROMPTFOO_INTEGRATION.md`。

## 评测规则

### 1. 事实引用完整性
- 每条 Claim 必须有 ≥1 个 fact_ref
- fact_ref 必须存在于 facts.json

### 2. 声明-事实对齐
- calls → 仅允许"调用"表述
- writes → 仅允许"写入/更新"
- annotations → 仅允许"声明/标注"
- 禁止语义增强

### 3. 无越权推断
- 禁止出现目的/效果/保证类表述
- 黑名单词示例：确保、保证、防止、避免、提升性能

### 4. 关键事实召回
- calls / writes / annotations 为关键事实
- Wiki 至少覆盖一次

### 5. 冗余检测
- 无事实增量的空洞描述判为冗余

## 指标与阈值

| 指标 | 说明 | 默认阈值 |
|------|------|----------|
| Faithfulness | 合法 Claim 占比 | ≥95% |
| Hallucination Rate | 幻觉比例 | **0%** |
| Key Fact Recall | 关键事实覆盖 | ≥85% |
| Redundancy Rate | 冗余比例 | ≤15% |

## 开发

### 运行测试

```bash
python -m pytest tests/
```

### 添加新规则

要添加新的评测规则，请在 `V1Evaluator` 类中添加相应的方法，并在 `evaluate` 方法中调用它。

## 快速开始

对于新用户，建议从快速入门指南开始：
```bash
# 最简单的评估方式
python simple_evaluator.py --code my_source.py --wiki-md my_wiki.md --output result.json --lang python
```

查看 `QUICK_START.md` 获取详细入门指导。

## 文档导航

- **QUICK_START.md**: 快速入门指南
- **README.md**: 项目概述和基本使用方法
- **PROJECT_OVERVIEW.md**: 项目背景、目标和技术特性
- **V1_EVALUATOR_GUIDE.md**: 详细使用指南和FAQ
- **EXAMPLES.md**: 具体使用示例
- **SCENARIO_EXAMPLES.md**: 不同场景下的评测示例
- **CODING_TO_WIKI_EVALUATION.md**: 仅有源码和Wiki文档时的使用方法
- **BATCH_PROCESSOR_USAGE.md**: 批量处理工具使用说明
- **SIMPLE_EVALUATOR_USAGE.md**: 简化版评估工具使用说明
- **PROMPTFOO_INTEGRATION.md**: Promptfoo集成使用指南

## 许可证

MIT