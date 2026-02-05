# Engineering Explanation Judge 快速入门指南

## 概述

Engineering Explanation Judge是一个基于promptfoo框架构建的工程解释安全判断系统，专门用于评估代码解释性文档（如Wiki）的安全性和合理性。本指南将帮助您快速安装、配置和运行Engineering Explanation Judge系统。

## 环境准备

### 系统要求

- Python 3.8 或更高版本
- Node.js 和 npm
- Ollama（用于运行本地大语言模型）

### 安装依赖

1. **安装Python依赖**
   ```bash
   pip install pyyaml
   ```

2. **安装Node.js依赖**
   ```bash
   npm install -g promptfoo
   ```

3. **设置Ollama**
   - 下载并安装Ollama
   - 启动Ollama服务
   - 拉取所需模型（例如：`ollama pull gpt-oss:120b`）

## 快速配置

### 1. 准备测试数据

将您的源代码和对应的Wiki文档放入`data`目录中，例如：

```
data/
├── my_source.py
└── my_source.md
```

### 2. 配置测试案例

编辑`cases.yaml`文件，添加您的测试案例：

```yaml
cases:
  - id: quick_start_example
    vars:
      source_code: data/my_source.py
      wiki_md: data/my_source.md
```

### 3. 验证配置

确保配置文件格式正确，路径存在。

## 快速运行

### 运行单个案例

```bash
python run_single_case_pipeline.py
```

或者在Python代码中：

```python
from run_single_case_pipeline import run_single_case

result = run_single_case(
    case_id="quick_start_example",
    vars_cfg={
        "source_code": "data/my_source.py",
        "wiki_md": "data/my_source.md"
    },
    output_dir="output/quick_start_example"
)

print(f"最终得分: {result['final_score']}")
print(f"评估结果: {result['result']}")
```

### 运行多个案例

```bash
python run_multi_cases.py
```

系统将处理`cases.yaml`中的所有案例。

或者使用命令行参数指定配置文件和输出目录：

```bash
python run_multi_cases.py --cases-yaml my_cases.yaml --base-output my_output
```

### 查看结果

评估结果将保存在指定的输出目录中：

- `stage1.json`：第一阶段事实提取结果
- `stage1_result.json`：提取的事实数据
- `stage2.json`：第二阶段软性判断结果
- `final_score.json`：最终评分结果
- `final_results-[timestamp].yaml`：批量运行的汇总结果
- `final_results_table-[timestamp].md`：格式化的Markdown表格结果

### 结果可视化

系统会自动生成Markdown格式的表格结果，包含以下列：
- **Case ID**：测试案例的唯一标识符
- **文件名**：输入源代码文件名
- **结果**：PASS/FAIL状态
- **分数**：最终得分
- **详情**：包含Summary、Coverage Level、Usefulness Level、Correctness Level、Hallucination Level和Coverage Rate的可折叠详细信息

## 理解结果

### 评分说明

- **最终得分**：0-100分，分数越高表示文档质量越好
- **评估结果**：PASS/FAIL，根据设定的标准判断
- **详细信息**：包含覆盖率、正确性、幻觉、有用性等维度的评估

### 结果解读

- **高分（80-100分）**：文档与源代码高度一致，质量优秀
- **中等分数（60-79分）**：文档基本准确，但有改进空间
- **低分（低于60分）**：文档存在较多问题，需要修正

## 前置提取事实功能（工程wiki级别）

### 功能简介

Fact Judge新增了前置提取事实功能，专门用于工程wiki级别的事实提取。该功能可以在详细评估之前，对整个工程项目进行高层次的分析。

### 快速使用

运行前置提取功能：

```bash
python pre_extract_facts.py --project-path /path/to/your/project --output-dir output/pre_extraction
```

此功能将分析整个项目，提取项目结构、模块关系、依赖关系等关键信息。

### 输出内容

前置提取功能会生成包含以下信息的JSON文件：

- 项目结构信息
- 模块间关系
- 关键实体列表
- 依赖关系图
- 设计模式识别
- 架构特征提取

这些信息可以为后续的详细评估提供丰富的上下文。

## 自定义配置

### 更换模型

在`stage1_fact_extractor.yaml`和`stage2_soft_judge.yaml`中修改模型配置：

```yaml
providers:
  - id: openai/gpt-4  # 更换为其他模型
    config:
      temperature: 0
      top_p: 1
```

### 调整评估标准

修改YAML配置文件中的提示词，以适应您的特定需求。

## 常见问题

### Q: 评估过程中出现错误怎么办？

A: 检查以下几点：
- 确保所有依赖项已正确安装
- 确保Ollama服务正在运行
- 检查文件路径是否正确
- 查看错误日志获取详细信息

### Q: 评估时间过长怎么办？

A: 可以尝试：
- 使用更快的模型
- 减少输入文档的大小
- 检查系统资源是否充足

## 下一步

完成快速入门后，您可以：

1. 阅读完整的[用户使用文档](USER_GUIDE.md)，了解更多功能
2. 查看[高级功能指南](ADVANCED_FEATURES.md)，学习自定义配置
3. 参考[流程图文档](FLOWCHART.md)，深入了解系统架构
4. 在实际项目中应用Fact Judge系统