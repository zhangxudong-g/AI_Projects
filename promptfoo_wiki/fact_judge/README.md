# Fact Judge

Fact Judge 是一个基于 promptfoo 框架构建的事实判断系统，专门用于评估代码文档（如Wiki）与源代码的一致性、准确性和完整性。该系统通过多阶段评估流程，自动化地判断生成的代码文档是否准确反映了源代码的功能和结构。

## 特性

- 四阶段评估流程（包括前置提取事实、事实提取、软性判断和最终评分）
- 支持多种编程语言（Python、Java、SQL等）
- 基于大语言模型的智能评估
- 可定制的评估标准和评分规则

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
- `stage1_fact_extractor.yaml`：第一阶段配置文件
- `stage2_soft_judge.yaml`：第二阶段配置文件
- `stage3_score.py`：第三阶段评分脚本
- `run_single_case_pipeline.py`：单案例运行管道
- `run_multi_cases.py`：多案例批量运行
- `cases.yaml`：测试案例配置文件