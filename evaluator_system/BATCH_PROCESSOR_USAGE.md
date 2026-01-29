# 批量处理工具使用说明

## 功能概述

批量处理工具可以从源码目录和对应的Wiki MD目录中批量提取事实，并可选择性地对代码和Wiki进行一致性评估。

## 目录结构要求

```
project/
├── source_code/          # 源码目录
│   ├── controller.py
│   ├── service.java
│   └── utils.js
├── wiki_docs/            # Wiki文档目录（MD格式）
│   ├── controller.md
│   ├── service.md
│   └── utils.md
└── output/
    ├── facts/            # 提取的事实文件输出目录
    │   ├── controller_facts.json
    │   ├── service_facts.json
    │   └── utils_facts.json
    └── evaluations/      # 评估结果输出目录（可选）
        ├── controller_evaluation.json
        ├── service_evaluation.json
        └── utils_evaluation.json
```

## 使用方法

### 命令行使用

```bash
python src/batch_processor.py --source-dir source_code/ --wiki-dir wiki_docs/ --output-dir output/facts/
```

选项：
- `--source-dir`: 源码目录路径 (必需)
- `--wiki-dir`: Wiki目录路径 (必需)
- `--output-dir`: 输出facts目录路径 (必需)
- `--eval-output-dir`: 评估结果输出目录 (可选)
- `--verbose`: 显示详细输出

### 完整示例

```bash
# 仅提取事实
python src/batch_processor.py --source-dir ./my_source_code --wiki-dir ./my_wiki_docs --output-dir ./output/facts --verbose

# 提取事实并进行评估
python src/batch_processor.py --source-dir ./my_source_code --wiki-dir ./my_wiki_docs --output-dir ./output/facts --eval-output-dir ./output/evaluations --verbose
```

## 支持的文件格式

### 源码文件
- Python (.py)
- Java (.java)
- JavaScript (.js)
- TypeScript (.ts)
- C++ (.cpp)
- C (.c)
- Go (.go)
- Rust (.rs)

### Wiki文档
- Markdown (.md)

## 输出文件格式

### 事实文件 (facts/*.json)
```json
{
  "facts": [
    {
      "id": "method:methodName",
      "kind": "method",
      "name": "methodName",
      "calls": ["Service.methodCall"],
      "writes": ["Entity.property"],
      "annotations": ["@Annotation"],
      "conditions": ["condition"]
    }
  ]
}
```

### 评估结果文件 (evaluations/*.json)
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

## 工作流程

1. **文件匹配**: 工具会自动匹配源码目录和Wiki目录中同名的文件（忽略扩展名）
2. **事实提取**: 从源码文件中提取函数/方法定义、调用关系、注解、条件语句等事实
3. **Wiki转换**: 将MD格式的Wiki文档转换为JSON格式，并智能匹配代码中的事实
4. **一致性评估**: （可选）使用V1评测系统评估代码和Wiki的一致性
5. **结果输出**: 将提取的事实和评估结果保存到指定目录

## 注意事项

- 源码文件和Wiki文件必须同名（扩展名除外）
- 工具会递归搜索子目录中的文件
- 评估过程中会自动创建输出目录
- 如果Wiki文档中包含代码块，会被跳过不作为claims处理

## 推荐用法

- **批量处理**: 使用 `batch_processor.py` 处理整个项目目录
- **单文件评估**: 推荐使用 `simple_evaluator.py` 进行单个文件对的快速评估
- **高级定制**: 使用 `code_to_wiki_evaluator.py` 进行更精细的控制