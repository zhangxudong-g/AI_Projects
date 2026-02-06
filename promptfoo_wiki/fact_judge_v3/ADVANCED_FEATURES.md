# Engineering Judge v3 高级功能指南

## 概述

本指南介绍Engineering Judge v3系统的高级功能，包括自定义配置、扩展选项和最佳实践。这些功能可以帮助您根据特定需求定制评估系统。

## 前置提取事实（工程wiki级别）

### 功能概述

前置提取事实功能是Fact Judge系统的一个重要扩展，专门用于在详细评估之前对整个工程项目进行高层次的事实提取和分析。该功能能够：

- 分析整个项目结构，而非单个文件
- 提取模块间的关系和依赖
- 识别项目的设计模式和架构特征
- 为后续的详细评估提供上下文信息

### 配置选项

#### pre_extraction_config.yaml

```yaml
# 前置提取配置文件
extraction_settings:
  max_depth: 5                    # 分析的最大深度
  include_tests: false            # 是否包含测试文件
  file_patterns:                  # 要分析的文件模式
    - "**/*.py"
    - "**/*.js"
    - "**/*.java"
    - "**/*.ts"
  exclusions:                     # 要排除的文件或目录
    - "**/node_modules/**"
    - "**/__pycache__/**"
    - "**/.git/**"
  analyze_dependencies: true      # 是否分析依赖关系
  extract_architecture: true      # 是否提取架构信息
  identify_patterns: true         # 是否识别设计模式
```

## 工程判断v3高级功能

### 功能概述

工程判断v3（Engineering Judge v3）是Fact Judge系统的一个重要扩展，专门用于评估解释性文档的工程价值，而非严格的事实一致性。该功能能够：

- 评估理解支持（Comprehension Support）- 是否帮助新接手开发者建立认知模型
- 评估工程实用性（Engineering Usefulness）- 是否提供实用的工程价值
- 评估解释合理性（Explanation Reasonableness）- 抽象和解释是否合理且基于代码
- 评估抽象质量（Abstraction Quality）- 抽象层级是否适当
- 评估伪造风险（Fabrication Risk）- 是否存在编造不存在的元素或行为

### 配置选项

#### stage2_explanatory_judge.yaml

```yaml
providers:
  - id: ollama:gpt-oss:120b
    config:
      temperature: 0
      top_p: 1

prompts:
  - |
    You are an ENGINEERING EXPLANATION SAFETY JUDGE.
    [详细配置请参考实际文件内容]

tests:
  - name: Stage2 Engineering Explanation Judge
    assert:
      - type: contains-json
```

### FAIL 条件配置

系统有明确的 FAIL 判定规则（极小化）：

- 仅当 fabrication_risk == "HIGH" 且 explanation_reasonableness == "LOW" 时，才会 FAIL

这与之前的硬性FAIL不同，现在采用风险扣分机制，工程价值可以抵消中等风险。

### 使用高级选项

#### 命令行参数

```bash
python pre_extract_facts.py \
  --project-path /path/to/project \
  --output-dir output/pre_extraction \
  --config pre_extraction_config.yaml \
  --max-depth 3 \
  --include-tests
```

#### Python API

```python
from pre_extract_facts import extract_project_facts

# 高级配置选项
config = {
    'max_depth': 4,
    'include_tests': True,
    'analyze_dependencies': True,
    'extract_architecture': True,
    'identify_patterns': True
}

facts = extract_project_facts(
    project_path="/path/to/project",
    output_dir="output/pre_extraction",
    config=config
)
```

### 输出格式详解

前置提取功能生成的JSON输出包含以下结构：

```json
{
  "project_structure": {
    "root_path": "/path/to/project",
    "modules": [
      {
        "name": "module_name",
        "path": "relative/path/to/module",
        "type": "directory|file",
        "language": "python|javascript|java|...",
        "size": 1024
      }
    ],
    "dependencies": [
      {
        "source": "module_a",
        "target": "module_b",
        "type": "import|require|extend|implement",
        "strength": 0.8
      }
    ]
  },
  "architecture_features": {
    "patterns_identified": [
      {
        "pattern": "Singleton",
        "location": "path/to/file.py",
        "confidence": 0.9
      }
    ],
    "layers": [
      {
        "name": "data_layer",
        "components": ["db", "models"],
        "responsibilities": ["data_access", "persistence"]
      }
    ]
  },
  "context_summary": {
    "project_type": "web_application|library|framework",
    "primary_language": "python",
    "estimated_complexity": "medium",
    "key_components": ["auth", "database", "api"]
  }
}
```

### 与评估流程整合

前置提取的事实可以与传统的三阶段评估流程整合：

1. **上下文注入**：将提取的项目上下文注入到评估提示中
2. **关系分析**：利用模块关系改进评估准确性
3. **架构一致性**：检查文档是否反映项目的真实架构

### 性能优化

#### 大项目处理

对于大型项目，可以使用以下优化策略：

- **增量分析**：只分析发生变化的部分
- **并行处理**：使用多线程处理不同模块
- **缓存机制**：缓存中间结果避免重复计算

```python
# 增量分析示例
def incremental_extraction(project_path, last_analysis_timestamp):
    changed_files = get_changed_files_since(project_path, last_analysis_timestamp)
    return extract_facts_from_files(changed_files)
```

#### 内存管理

- 使用生成器处理大型文件列表
- 及时释放不需要的中间结果
- 实现对象池复用解析器实例

### 扩展开发

#### 自定义提取器

您可以开发自定义的事实提取器来满足特定需求：

```python
class CustomFactExtractor:
    def __init__(self, config):
        self.config = config

    def extract(self, project_path):
        # 实现自定义提取逻辑
        pass

    def merge_with_base_facts(self, base_facts, custom_facts):
        # 将自定义事实合并到基础事实中
        pass
```

#### 插件架构

前置提取功能支持插件架构，允许添加新的分析模块：

- **语言特定分析器**：针对特定编程语言的深度分析
- **架构模式识别器**：识别特定架构模式
- **依赖分析器**：高级依赖关系分析

## 最佳实践

### 工程级评估策略

1. **分层分析**：先进行高层分析，再深入细节
2. **上下文关联**：始终考虑文件在整个项目中的角色
3. **迭代改进**：根据前置提取结果调整详细评估策略
4. **结果验证**：交叉验证不同层次的分析结果

### 性能考量

- 对于超大项目，考虑分批处理
- 使用适当的采样策略
- 监控资源使用情况
- 调整分析深度以平衡准确性和性能

## 工程价值评分高级功能

### 功能概述

工程价值评分（Engineering Value Scoring）是第三阶段的核心功能，它根据工程判断v3的结果进行评分，重点关注工程价值而非传统的事实一致性。

### 配置选项

#### stage3_score.py

```python
def final_score(stage2: Dict[str, Any]) -> Dict[str, Any]:
    # FAIL 条件检查（硬约束）
    if engineering_risk_level == "HIGH" or boundary_adherence == "BAD":
        final_score_value = 0
        result = "FAIL"
    else:
        # 风险感知评分逻辑
        # 各项权重分配
        usefulness_weight = 0.4      # 实用性权重最高
        reasonableness_weight = 0.3  # 解释合理性权重次之
        boundary_weight = 0.2        # 边界遵循权重较低
        # coverage_weight = 0.1      # 覆盖率权重最低（可选）
```

### 评分权重配置

系统采用加权评分机制：

- 理解支持（comprehension_support）：根据评级映射
- 工程实用性（engineering_usefulness）：根据评级映射
- 解释合理性（explanation_reasonableness）：根据评级映射
- 抽象质量（abstraction_quality）：根据评级映射
- 总分：100 分

### FAIL 条件配置

与传统的评分系统不同，工程价值评分采用软风险加权机制：

- 仅当伪造风险为HIGH且解释合理性为LOW时，才会FAIL
- 其他情况采用风险扣分机制：
  - 伪造风险为HIGH时，扣除40分
  - 伪造风险为MEDIUM时，扣除20分
  - 伪造风险为LOW时，不扣分

这体现了"工程价值可以抵消中等风险"的原则。

## 结果可视化高级功能

### 功能概述

结果可视化功能是Engineering Explanation Judge系统的一项重要增强，能够将评估结果以Markdown表格格式输出，便于查看、分享和分析。该功能具有以下特点：

- **表格化展示**：将评估结果以标准Markdown表格形式呈现
- **多维度信息**：包含Case ID、文件名、结果、分数和详细信息
- **可折叠详情**：使用HTML的`<details>`和`<summary>`标签实现可折叠显示
- **平铺信息展示**：在详情中平铺显示`final_score.json`中的关键信息，包括解释合理性、工程风险等级、边界遵循和实用性

### 配置选项

#### 自定义输出格式

可以通过修改`run_multi_cases.py`中的`format_results_with_llm`函数来自定义输出格式：

```python
def customize_output_format(case_results, cases_config, base_output: str = "output"):
    # 自定义表格头部
    md_content = "# 自定义标题\n\n"
    md_content += "| 自定义列1 | 自定义列2 | 自定义列3 |\n"
    md_content += "|----------|----------|----------|\n"

    # 自定义每行内容
    for idx, result in enumerate(case_results):
        # 自定义处理逻辑
        pass

    return md_content
```

### 高级使用选项

#### 选择性显示字段

可以根据需要选择在详情中显示的字段：

```python
# 在format_results_with_llm函数中
# 从details中提取各个字段
comprehension_support = details_obj.get('comprehension_support', 'N/A')
engineering_usefulness = details_obj.get('engineering_usefulness', 'N/A')
explanation_reasonableness = details_obj.get('explanation_reasonableness', 'N/A')
abstraction_quality = details_obj.get('abstraction_quality', 'N/A')
fabrication_risk = details_obj.get('fabrication_risk', 'N/A')
# ... 其他字段

# 可以选择性地包含在flat_details中
flat_details = f"Summary: {summary}<br/>Comprehension Support: {comprehension_support}<br/>Engineering Usefulness: {engineering_usefulness}<br/>Explanation Reasonableness: {explanation_reasonableness}<br/>Abstraction Quality: {abstraction_quality}<br/>Fabrication Risk: {fabrication_risk}"
```

#### 自定义样式

可以为HTML元素添加自定义CSS样式：

```python
# 在details元素中添加样式
details = f'<details><summary style="cursor: pointer; font-weight: bold;">{compact_info}</summary><div style="padding: 10px; background-color: #f9f9f9;">{flat_details}</div></details>'
```

### 输出格式详解

生成的Markdown表格包含以下列：

- **Case ID**：测试案例的唯一标识符
- **文件名**：输入源代码文件名
- **结果**：PASS/FAIL状态
- **分数**：最终得分
- **详情**：包含Summary、理解支持（Comprehension Support）、工程实用性（Engineering Usefulness）、解释合理性（Explanation Reasonableness）、抽象质量（Abstraction Quality）和伪造风险（Fabrication Risk）的可折叠详细信息

### 与评估流程整合

结果可视化功能无缝集成到批量评估流程中：

1. **自动触发**：在`run_all_cases`函数执行完毕后自动调用
2. **数据收集**：收集所有案例的`final_score.json`内容，包括理解支持、工程实用性、解释合理性、抽象质量和伪造风险等新维度
3. **格式化输出**：将数据格式化为Markdown表格
4. **文件生成**：生成带时间戳的Markdown文件

### 性能优化

#### 大量案例处理

对于大量测试案例，可以使用以下优化策略：

- **分页显示**：将大量结果分页显示
- **异步处理**：异步生成表格内容
- **内存管理**：及时释放不需要的中间结果

#### 输出格式优化

- **压缩JSON**：在表格中显示压缩的JSON以减少文件大小
- **懒加载**：实现详情的懒加载以提高页面加载速度
- **缓存机制**：缓存生成的表格内容避免重复计算

### 扩展开发

#### 自定义可视化

您可以开发自定义的可视化功能来满足特定需求：

```python
class CustomResultVisualizer:
    def __init__(self, output_format="markdown"):
        self.output_format = output_format

    def visualize(self, case_results, cases_config, base_output):
        if self.output_format == "markdown":
            return self._to_markdown_table(case_results, cases_config, base_output)
        elif self.output_format == "html":
            return self._to_html_report(case_results, cases_config, base_output)
        # 其他格式...
```

#### 多格式输出

支持多种输出格式：

- **Markdown表格**：适用于GitHub、文档等
- **HTML报告**：更丰富的交互功能
- **CSV文件**：便于数据分析
- **JSON格式**：便于程序处理

### 最佳实践

#### 结果分析策略

1. **快速浏览**：使用表格快速定位高风险和低解释合理性案例
2. **详细分析**：展开详情查看理解支持、工程实用性、解释合理性、抽象质量和伪造风险等具体评估信息
3. **批量比较**：通过表格形式比较不同案例的表现
4. **工程价值评估**：重点关注理解支持和工程实用性指标

#### 报告生成

- 结合表格结果生成综合评估报告
- 添加图表和统计信息
- 提供改进建议和下一步行动