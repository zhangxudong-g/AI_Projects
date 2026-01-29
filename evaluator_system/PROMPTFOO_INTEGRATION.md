# V1 评测系统与Promptfoo集成指南

## 概述

根据PRD设计，V1评测系统与Promptfoo集成，用于多模型/多Prompt的自动回归评测。集成的目标是：
- 实现多模型对比评测
- 支持多Prompt回归测试
- CI/CD集成与质量门控

## Promptfoo配置

### 1. 基础配置文件 (promptfoo_config.yaml)

```yaml
# promptfoo_config.yaml
version: "2"

# 默认测试配置
defaultTest:
  options:
    # 设置评估指标
    assert:
      - type: javascript
        value: |
          const result = JSON.parse(output);
          return result.pass === true;
        message: "评测未通过 - 文档不符合忠实度要求"

# 测试用例定义
tests:
  # 测试用例1：基本功能测试
  - description: "测试基本功能 - 正确引用事实"
    vars:
      facts_file: "./examples/facts_basic.json"
      wiki_file: "./examples/wiki_basic.json"
    provider: 
      id: "exec:python src/v1_evaluator.py --facts {{facts_file}} --wiki {{wiki_file}} --out /tmp/result.json && cat /tmp/result.json"
    assert:
      - type: javascript
        value: |
          const result = JSON.parse(output);
          return result.pass === true && result.metrics.faithfulness >= 0.95;
        message: "基本功能测试失败"

  # 测试用例2：检测幻觉
  - description: "测试幻觉检测 - 包含越权推断的文档"
    vars:
      facts_file: "./examples/facts_no_call.json"  # 不包含调用信息的事实
      wiki_file: "./examples/wiki_with_over_inference.json"  # 包含越权推断的文档
    provider:
      id: "exec:python src/v1_evaluator.py --facts {{facts_file}} --wiki {{wiki_file}} --out /tmp/result.json && cat /tmp/result.json"
    assert:
      - type: javascript
        value: |
          const result = JSON.parse(output);
          return result.pass === false && result.metrics.hallucination_rate > 0;
        message: "未能正确检测到幻觉"

  # 测试用例3：关键事实覆盖率
  - description: "测试关键事实覆盖率"
    vars:
      facts_file: "./examples/facts_with_calls_writes.json"
      wiki_file: "./examples/wiki_partial_coverage.json"
    provider:
      id: "exec:python src/v1_evaluator.py --facts {{facts_file}} --wiki {{wiki_file}} --out /tmp/result.json && cat /tmp/result.json"
    assert:
      - type: javascript
        value: |
          const result = JSON.parse(output);
          return result.metrics.key_fact_recall < 0.85;
        message: "关键事实覆盖率计算不正确"

# 提示模板（用于生成Wiki文档的测试）
prompts:
  - |
    基于以下代码生成文档：
    {{code}}
    
    请生成一个JSON格式的Wiki文档，格式如下：
    {
      "method": "method_name",
      "claims": [
        { "text": "描述", "fact_refs": ["calls:service.method"] }
      ]
    }

# 模型提供商（用于生成Wiki文档）
providers:
  - id: "openai:gpt-4o"
    config:
      temperature: 0.1
  - id: "openai:gpt-3.5-turbo"
    config:
      temperature: 0.1
  - id: "anthropic:claude-3-opus"
    config:
      temperature: 0.1

# 评估配置
evaluateOptions:
  maxConcurrency: 1  # 限制并发数，避免API超限
  showProgressBar: true
```

### 2. 高级配置文件 (advanced_promptfoo_config.yaml)

```yaml
# advanced_promptfoo_config.yaml
version: "2"

# 自定义阈值测试
defaultTest:
  options:
    assert:
      - type: javascript
        value: |
          const result = JSON.parse(output);
          return result.pass === true;
        message: "评测未通过"

# 多维度测试用例
tests:
  # 详细指标测试
  - description: "详细指标测试"
    vars:
      facts_file: "./examples/facts_complete.json"
      wiki_file: "./examples/wiki_complete.json"
    provider: 
      id: "exec:python src/v1_evaluator.py --facts {{facts_file}} --wiki {{wiki_file}} --out /tmp/result.json && cat /tmp/result.json"
    assert:
      - type: javascript
        value: |
          const result = JSON.parse(output);
          return result.metrics.faithfulness >= 0.95 &&
                 result.metrics.hallucination_rate <= 0.0 &&
                 result.metrics.key_fact_recall >= 0.85 &&
                 result.metrics.redundancy_rate <= 0.15;
        message: "指标测试失败"
      - type: javascript
        value: |
          const result = JSON.parse(output);
          return result.violations.length === 0;
        message: "存在违规"

  # 边界情况测试
  - description: "边界情况测试 - 空文档"
    vars:
      facts_file: "./examples/facts_basic.json"
      wiki_file: "./examples/wiki_empty.json"
    provider:
      id: "exec:python src/v1_evaluator.py --facts {{facts_file}} --wiki {{wiki_file}} --out /tmp/result.json && cat /tmp/result.json"
    assert:
      - type: javascript
        value: |
          const result = JSON.parse(output);
          return result.metrics.key_fact_recall === 0.0;
        message: "空文档测试失败"

# 多模型对比测试
providers:
  - id: "openai:gpt-4o"
    config:
      temperature: 0.1
  - id: "openai:gpt-3.5-turbo"
    config:
      temperature: 0.1
  - id: "anthropic:claude-3-opus"
    config:
      temperature: 0.1
  - id: "ollama:llama3"
    config:
      temperature: 0.1

prompts:
  - |
    请基于以下代码生成详细的技术文档：
    {{code}}
    
    文档应包含：
    1. 函数功能描述
    2. 参数说明
    3. 返回值说明
    4. 异常处理
    5. 调用的外部服务
    
    输出格式为JSON：
    {
      "method": "function_name",
      "claims": [
        { "text": "描述", "fact_refs": ["calls:service.method"] }
      ]
    }

evaluateOptions:
  maxConcurrency: 2
  showProgressBar: true
  includeProvider: ["openai:gpt-4o", "openai:gpt-3.5-turbo"]
  includePrompts: [0]
```

## 使用方法

### 1. 基础使用

```bash
# 运行基础测试
promptfoo eval

# 指定配置文件
promptfoo eval --config promptfoo_config.yaml

# 指定特定测试
promptfoo eval --test patterns "基本功能测试"
```

### 2. 多模型对比

```bash
# 对比不同模型生成的Wiki质量
promptfoo eval --table --grader openai:gpt-4o

# 生成对比报告
promptfoo eval --output results/comparison_report.csv
```

### 3. CI/CD集成

在CI/CD流水线中添加质量门控：

```bash
#!/bin/bash
# ci_check.sh

# 运行评测
promptfoo eval --config promptfoo_config.yaml

# 检查退出码
if [ $? -eq 0 ]; then
  echo "评测通过，允许合并"
  exit 0
else
  echo "评测失败，阻止合并"
  exit 1
fi
```

### 4. 回归测试

```bash
# 运行回归测试
promptfoo eval --config advanced_promptfoo_config.yaml

# 生成回归报告
promptfoo eval --output regression_report.html
```

## 实际应用示例

### 1. 模型性能对比

创建一个模型对比测试：

```yaml
# model_comparison.yaml
tests:
  - description: "GPT-4 vs Claude-3 幻觉检测对比"
    vars:
      code: |
        def transfer_money(from_account, to_account, amount):
            if from_account.balance >= amount:
                from_account.balance -= amount
                to_account.balance += amount
                return True
            return False
    prompts:
      - |
        基于以下代码生成文档，重点关注安全性：
        {{code}}
        
        JSON格式输出：
        {
          "method": "transfer_money",
          "claims": [
            { "text": "描述", "fact_refs": ["writes:account.balance"] }
          ]
        }
    providers:
      - id: "openai:gpt-4o"
      - id: "anthropic:claude-3-opus"
    provider: 
      id: "exec:python simple_evaluator.py --code /tmp/code.py --wiki-md /tmp/wiki.md --output /tmp/result.json && cat /tmp/result.json"
    assert:
      - type: javascript
        value: |
          const result = JSON.parse(output);
          return result.metrics.hallucination_rate === 0.0;
        message: "检测到幻觉"
```

### 2. Prompt优化测试

```yaml
# prompt_optimization.yaml
prompts:
  - |
    基于代码生成文档：
    {{code}}
    
    JSON格式输出
  - |
    详细分析代码并生成技术文档：
    {{code}}
    
    严格按照JSON格式输出
  - |
    请仔细分析以下代码，生成准确的技术文档：
    {{code}}
    
    输出格式：
    {
      "method": "...",
      "claims": [...]
    }

tests:
  - description: "不同Prompt的准确性对比"
    vars:
      code: "..."  # 你的代码
    provider: 
      id: "exec:python simple_evaluator.py --code /tmp/code.py --wiki-md /tmp/wiki.md --output /tmp/result.json && cat /tmp/result.json"
    assert:
      - type: javascript
        value: |
          const result = JSON.parse(output);
          return result.metrics.faithfulness >= 0.95;
        message: "忠实度不足"
```

## 报告与分析

### 1. 生成HTML报告

```bash
promptfoo eval --output report.html
```

### 2. 生成CSV报告

```bash
promptfoo eval --output results.csv --table
```

### 3. 查看详细分析

```bash
promptfoo view  # 在浏览器中查看详细结果
```

## 最佳实践

1. **测试用例设计**：包含正常情况、边界情况和异常情况
2. **阈值设置**：根据业务需求调整评估阈值
3. **并发控制**：合理设置并发数避免API超限
4. **持续监控**：定期运行回归测试监控模型性能变化
5. **结果分析**：关注违规详情，持续优化Prompt和模型

通过这种集成方式，您可以充分利用Promptfoo的强大功能来管理和运行V1评测系统的测试，实现多模型/多Prompt的自动回归评测。