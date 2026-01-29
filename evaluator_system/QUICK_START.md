# V1 评测系统 - 快速入门指南

## 概述

V1 评测系统用于验证 Wiki 是否忠实转述已解析事实，检测幻觉、越权推断与事实遗漏问题。

## 快速开始

### 1. 最简单的评估方式

如果您有源代码文件和MD格式的Wiki文档，使用简化版工具：

#### 方式1：指定输出文件
```bash
python simple_evaluator.py --code my_source.py --wiki-md my_wiki.md --output result.json --lang python
```

#### 方式2：自动命名（推荐）
```bash
python simple_evaluator.py --code my_source.py --wiki-md my_wiki.md --lang python
```

默认会将结果保存到 `results/{code_filename}_evaluation.json`

### 2. 评估示例

假设您有以下文件：

**user_service.py**:
```python
def authenticate_user(username, password):
    if not validate(username, password):
        raise AuthError("认证失败")
    return True
```

**user_service.md**:
```markdown
# authenticate_user
* 调用validate验证用户名密码
* 当验证失败时抛出AuthError异常
```

运行评估：
```bash
python simple_evaluator.py --code user_service.py --wiki-md user_service.md --output result.json --lang python --verbose
```

## 使用场景推荐

| 场景 | 推荐工具 | 命令示例 |
|------|----------|----------|
| 单文件快速评估（指定输出） | simple_evaluator.py | `python simple_evaluator.py --code src.py --wiki-md wiki.md --out result.json` |
| 单文件快速评估（自动命名） | simple_evaluator.py | `python simple_evaluator.py --code src.py --wiki-md wiki.md` |
| 批量处理项目 | batch_processor.py | `python src/batch_processor.py --source-dir src/ --wiki-dir docs/ --out-dir facts/` |
| 标准评估 | cli.py | `python src/cli.py --facts facts.json --wiki wiki.json --out result.json` |

## 评估指标

- **faithfulness (忠实度)**: 声明准确性的比例
- **hallucination_rate (幻觉率)**: 虚构内容的比例
- **key_fact_recall (关键事实召回率)**: 覆盖关键事实的比例
- **redundancy_rate (冗余率)**: 冗余内容的比例

## 结果解读

- `pass: true` - 评估通过
- `pass: false` - 评估未通过，需要查看violations了解问题

常见问题：
- `Claim缺少fact_ref` - Wiki中的声明没有引用代码中的事实
- `语义不对齐` - 声明与事实类型不匹配
- `越权推断` - 包含了代码中没有的推测性内容

## 下一步

- 查看 `SIMPLE_EVALUATOR_USAGE.md` 了解简化版工具详情
- 查看 `V1_EVALUATOR_GUIDE.md` 了解详细使用指南
- 查看 `EXAMPLES.md` 了解具体示例