# V1 评测系统 - 项目概述

## 项目背景

在代码 Wiki 自动生成系统中，LLM 容易出现幻觉、越权推断与事实遗漏。为保障生成文档的**工程可用性、可审计性与可回归性**，需要一个**独立、自动化、可 CI 集成**的评测系统，对"事实 → 表述（V1 层）"进行严格校验。

## 系统目标

- 构建 **V1 层评测系统**，验证 Wiki 是否忠实转述已解析事实（Fact Graph / SemanticUnit）。
- **零幻觉**为硬门槛，提供量化指标与 Pass/Fail 判定。
- 与 **Promptfoo** 集成，实现多模型/多 Prompt 的自动回归评测。

## 核心功能

### 1. 事实引用完整性校验 (F1)
- 每条 Claim 必须有 ≥1 个 fact_ref
- fact_ref 必须存在于 facts.json

### 2. 声明-事实对齐校验 (F2)
- calls → 仅允许"调用"表述
- writes → 仅允许"写入/更新"
- annotations → 仅允许"声明/标注"
- 禁止语义增强

### 3. 越权推断检测 (F3)
- 禁止出现目的/效果/保证类表述
- 黑名单词示例：确保、保证、防止、避免、提升性能

### 4. 关键事实覆盖率 (F4)
- calls / writes / annotations 为关键事实
- Wiki 至少覆盖一次

### 5. 冗余与噪声检测 (F5)
- 无事实增量的空洞描述判为冗余

## 评测指标

| 指标 | 说明 | 阈值 |
|------|------|------|
| Faithfulness | 合法 Claim 占比 | ≥95% |
| Hallucination Rate | 幻觉比例 | **0%** |
| Key Fact Recall | 关键事实覆盖 | ≥85% |
| Redundancy Rate | 冗余比例 | ≤15% |

## 系统架构

```
LLM → wiki.json
           ↓
facts.json → V1 Evaluator → evaluation_result.json
           ↓
        Promptfoo → 报告 / CI
```

## 项目结构

```
evaluator_system/
├── src/                    # 源代码
│   ├── v1_evaluator.py     # 核心评测引擎
│   ├── io_handler.py       # 输入输出处理
│   ├── cli.py             # 命令行接口
│   └── __init__.py
├── tests/                 # 测试用例
│   └── test_evaluator.py
├── examples/              # 示例文件
│   ├── facts_basic.json
│   ├── wiki_basic.json
│   └── ...
├── README.md             # 主要文档
├── EXAMPLES.md           # 使用示例
├── promptfoo_config.yaml # Promptfoo集成配置
├── setup.py              # 安装配置
└── requirements.txt      # 依赖项
```

## 使用场景

1. **CI/CD集成**：PR 提交触发自动评测 Wiki 质量
2. **模型对比**：对比不同模型/Prompt 的文档忠实度
3. **质量回归**：防止引入幻觉和错误

## 开发计划

- **已完成**：规则引擎 & CLI（第1周）
- **已完成**：Promptfoo 集成（第2周）
- **已完成**：测试与文档（第3周）

## 技术特性

- **Python 3.10+**：现代Python版本支持
- **无数据库依赖**：纯文件处理
- **高性能**：单次评测 < 1s（中等规模 JSON）
- **可扩展**：模块化设计，易于添加新规则
- **CI友好**：支持自动化集成

## 未来扩展

- 更复杂的语义理解能力
- 多语言支持
- 更丰富的评测指标
- Web界面可视化