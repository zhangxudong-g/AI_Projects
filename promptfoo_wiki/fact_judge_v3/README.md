# Engineering Judge v3

Engineering Judge v3 是一个基于 promptfoo 框架构建的工程导向Wiki质量评估系统，专门用于评估代码解释性文档（如Wiki）的工程价值和风险。该系统通过多阶段评估流程，自动化地判断生成的代码解释文档是否提供了有价值的工程见解，同时保持合理的准确性。

## 特性

- 四阶段评估流程（包括前置提取事实、结构覆盖判断、解释对齐判断和工程判断）
- 支持多种编程语言（Python、Java、SQL等）
- 基于大语言模型的智能评估
- 重点关注工程价值和合理抽象
- 可定制的评估标准和评分规则

## 重构背景

与传统的 Fact Judge 系统不同，Engineering Judge v3 专注于评估解释性文档的工程价值，而非严格的事实一致性。其设计目标是判断"这份文档是否提供了有价值的工程见解，同时保持合理的准确性？"，而不是"是否100%覆盖了代码中的每一个元素？"。

## 评估维度

- **理解支持（Comprehension Support）**：是否帮助新接手开发者建立认知模型
- **工程实用性（Engineering Usefulness）**：是否提供实用的工程价值
- **解释合理性（Explanation Reasonableness）**：抽象和解释是否合理且基于代码
- **抽象质量（Abstraction Quality）**：抽象层级是否适当
- **伪造风险（Fabrication Risk）**：是否存在编造不存在的元素或行为

## 依赖

项目依赖列在 `requirements.txt` 文件中：

- `ollama`：用于与本地大语言模型交互
- `promptfoo`：用于运行多阶段评估流程
- `PyYAML`：用于解析YAML配置文件
- `javalang`：用于Java代码解析（可选）
- `sqlparse`：用于SQL代码解析（可选）
- `python-dotenv`：用于环境变量管理（可选）

## 安装

1. 安装依赖：

   ```bash
   pip install -r requirements.txt
   ```

2. 安装 promptfoo：

   ```bash
   npm install -g promptfoo
   ```

3. 设置 Ollama 并拉取所需模型

## 使用

详情请参阅 [USER_GUIDE.md](USER_GUIDE.md)。

## 项目结构

- `stage0_pre_extractor.py`：前置提取事实阶段
- `stage1_fact_extractor.yaml`：第一阶段配置文件（结构覆盖判断）
- `stage1_5_explanation_alignment.yaml`：第一阶段半配置文件（解释对齐判断）
- `stage2_explanatory_judge.yaml`：第二阶段配置文件（工程判断）
- `stage3_score.py`：第三阶段评分脚本（工程价值评分）
- `run_single_case_pipeline.py`：单案例运行管道
- `run_multi_cases.py`：多案例批量运行（包含结果可视化功能）
- `cases.yaml`：测试案例配置文件

## 新增功能

### 结果可视化

新增了结果可视化功能，能够将评估结果输出为Markdown表格格式，包含Case ID、文件名、结果、分数和详细信息。详细信息使用可折叠的HTML元素展示`final_score.json`中的关键信息。

### 命令行参数支持

`run_multi_cases.py` 现在支持命令行参数：
- `--cases-yaml`：指定测试案例配置文件路径
- `--base-output`：指定基础输出目录