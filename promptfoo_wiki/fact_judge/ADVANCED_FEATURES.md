# Fact Judge 高级功能指南

## 概述

本指南介绍Fact Judge系统的高级功能，包括自定义配置、扩展选项和最佳实践。这些功能可以帮助您根据特定需求定制评估系统。

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