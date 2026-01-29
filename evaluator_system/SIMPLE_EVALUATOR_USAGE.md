# 简化版评估工具使用说明

## 概述

简化版评估工具可以直接从源码文件和MD格式的Wiki文档进行评估，无需预先生成facts.json文件，一步到位完成整个评估流程。

## 使用方法

### 命令行使用

#### 方式1：指定输出文件路径
```bash
python simple_evaluator.py --code my_source.py --wiki-md my_wiki.md --output result.json --lang python
```

#### 方式2：自动命名（推荐）
```bash
python simple_evaluator.py --code my_source.py --wiki-md my_wiki.md --lang python
```
默认会将结果保存到 `results/{code_filename}_evaluation.json`

选项：
- `--code`: 源代码文件路径 (必需)
- `--wiki-md`: MD格式的Wiki文档路径 (必需)
- `--output`: 输出结果文件路径 (可选，如果不指定，则保存到results目录并以代码文件名命名)
- `--results-dir`: 结果保存目录 (默认: results)
- `--lang`: 代码语言 (python/java，默认python)
- `--verbose`: 显示详细输出

### 示例

```bash
# 评估Python文件
python simple_evaluator.py --code src/user_service.py --wiki-md docs/user_service.md --output results/user_evaluation.json --lang python --verbose

# 评估Java文件
python simple_evaluator.py --code src/UserService.java --wiki-md docs/user_service.md --output results/user_evaluation.json --lang java
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
  "summary": {
    "file": "user_service.py",
    "total_claims": 10,
    "matched_facts": 8,
    "unmatched_claims": 2
  }
}
```

## 工作流程

1. **解析源码**: 从源代码文件中提取事实
2. **处理Wiki**: 从MD格式的Wiki文档中提取claims并智能匹配代码事实
3. **执行评估**: 使用V1评测系统评估代码和Wiki的一致性
4. **生成报告**: 输出详细的评估结果

## 优势

- **简化流程**: 一步完成评估，无需中间步骤
- **智能匹配**: 自动匹配代码事实和Wiki声明
- **支持多种语言**: Python、Java等
- **详细报告**: 提供完整的评估指标和摘要信息

## 适用场景

- 快速评估单个文件对（源码+Wiki）
- CI/CD中的自动化检查
- 交互式调试和验证