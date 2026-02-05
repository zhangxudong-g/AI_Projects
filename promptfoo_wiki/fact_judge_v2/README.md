# Engineering Explanation Judge

Engineering Explanation Judge 是一个基于 promptfoo 框架构建的工程解释安全判断系统，专门用于评估代码解释性文档（如Wiki）的安全性和合理性。该系统通过多阶段评估流程，自动化地判断生成的代码解释文档是否安全可靠，不会误导工程师做出错误的修改决策。

## 特性

- 三阶段评估流程（包括前置提取事实、工程解释安全判断和风险感知评分）
- 支持多种编程语言（Python、Java、SQL等）
- 基于大语言模型的智能评估
- 重点关注工程风险和职责边界
- 可定制的评估标准和评分规则

## 重构背景

与传统的 Fact Judge 系统不同，Engineering Explanation Judge 专注于评估解释性文档的安全性，而非严格的事实一致性。其设计目标是判断"这种解释，会不会误导工程师做出错误修改？"，而不是"这是不是 100% 事实？"。

## 评估维度

- **解释合理性（Interpretation Reasonableness）**：解释是否合理，是否可从源码中推断
- **工程风险等级（Engineering Risk Level）**：是否可能导致错误的工程决策（核心维度）
- **边界遵循（Boundary Adherence）**：是否遵守层级与职责边界
- **实用性（Usefulness）**：是否真正帮助工程师理解代码

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
- `stage1_fact_extractor.yaml`：第一阶段配置文件（保持不变）
- `stage2_explanatory_judge.yaml`：第二阶段配置文件（工程解释安全判断）
- `stage3_score.py`：第三阶段评分脚本（风险感知评分）
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