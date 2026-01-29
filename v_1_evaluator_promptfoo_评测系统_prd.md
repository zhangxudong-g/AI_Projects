# 产品需求文档（PRD）

## 1. 背景与目标

### 1.1 背景
在代码 Wiki 自动生成系统中，LLM 容易出现幻觉、越权推断与事实遗漏。为保障生成文档的**工程可用性、可审计性与可回归性**，需要一个**独立、自动化、可 CI 集成**的评测系统，对“事实 → 表述（V1 层）”进行严格校验。

### 1.2 目标
- 构建 **V1 层评测系统**，验证 Wiki 是否忠实转述已解析事实（Fact Graph / SemanticUnit）。
- **零幻觉**为硬门槛，提供量化指标与 Pass/Fail 判定。
- 与 **Promptfoo** 集成，实现多模型/多 Prompt 的自动回归评测。

### 1.3 非目标
- 不解析源码、不做 V0（事实抽取）正确性评估。
- 不进行跨文件/跨系统推理（V2+）。
- 不依赖 LLM 作为主判官（仅可选辅助）。

---

## 2. 用户与使用场景

### 2.1 目标用户
- 平台工程师（评测与 CI）
- 文档生成系统研发工程师
- 技术负责人（质量把关）

### 2.2 使用场景
1. PR 提交触发 CI，自动评测 Wiki 质量。
2. 对比不同模型/Prompt 的文档忠实度。
3. 质量回归：防止引入幻觉。

---

## 3. 术语与定义
- **Fact Graph / SemanticUnit**：V0 层输出的结构化事实集合。
- **Claim**：Wiki 中的一条事实性表述。
- **fact_ref**：Claim 指向事实的引用标识。
- **V1 评测**：验证 Claim 是否被事实支持、无越权推断。

---

## 4. 需求概览

### 4.1 功能需求（Must）
- F1：校验 Claim 是否包含合法 fact_ref。
- F2：校验 Claim 与 Fact 的语义对齐（调用/写入/注解等）。
- F3：检测越权推断（意图/目的/效果性描述）。
- F4：关键事实覆盖率（Key Fact Recall）。
- F5：冗余与噪声检测。
- F6：输出量化指标与 Pass/Fail。
- F7：CLI 可独立运行。
- F8：与 Promptfoo 集成，支持 CI。

### 4.2 非功能需求（Must）
- N1：Python 3.10+。
- N2：不依赖数据库。
- N3：单次评测 < 1s（中等规模 JSON）。
- N4：可扩展规则集。

---

## 5. 输入与输出规范

### 5.1 输入一：facts.json
```json
{
  "facts": [
    {
      "id": "method:changeHogosyaJoho",
      "kind": "method",
      "role": "controller",
      "calls": ["AuthService.checkPermission", "HogosyaService.update"],
      "writes": ["HogosyaEntity"],
      "annotations": ["@Transactional"],
      "conditions": ["hogosyaId != null"]
    }
  ]
}
```

### 5.2 输入二：wiki.json
```json
{
  "method": "changeHogosyaJoho",
  "claims": [
    { "text": "更新监护人信息", "fact_refs": ["writes:HogosyaEntity"] },
    { "text": "更新前进行权限校验", "fact_refs": ["calls:AuthService.checkPermission"] }
  ]
}
```

### 5.3 输出：evaluation_result.json
```json
{
  "metrics": {
    "faithfulness": 0.96,
    "hallucination_rate": 0.0,
    "key_fact_recall": 0.85,
    "redundancy_rate": 0.1
  },
  "violations": [
    { "claim": "xxx", "reason": "over_inference | missing_fact | invalid_ref" }
  ],
  "pass": true
}
```

---

## 6. 核心规则（V1）

### 6.1 Fact Reference Integrity
- 每条 Claim 必须有 ≥1 个 fact_ref。
- fact_ref 必须存在于 facts.json。

### 6.2 Claim–Fact Alignment
- calls → 仅允许“调用”表述。
- writes → 仅允许“写入/更新”。
- annotations → 仅允许“声明/开启”。
- 禁止语义增强。

### 6.3 No Over-Inference
- 禁止出现目的/效果/保证类表述。
- 黑名单词示例：确保、保证、防止、避免、提升性能。

### 6.4 Key Fact Recall
- calls / writes / annotations 为关键事实。
- Wiki 至少覆盖一次。

### 6.5 Redundancy Detection
- 无事实增量的空洞描述判为冗余。

---

## 7. 指标与阈值

| 指标 | 说明 | 阈值 |
|---|---|---|
| Faithfulness | 合法 Claim 占比 | ≥95% |
| Hallucination Rate | 幻觉比例 | **0%** |
| Key Fact Recall | 关键事实覆盖 | ≥85% |
| Redundancy Rate | 冗余比例 | ≤15% |

Pass 条件：全部阈值满足。

---

## 8. 系统架构

```
LLM → wiki.json
           ↓
facts.json → V1 Evaluator → evaluation_result.json
           ↓
        Promptfoo → 报告 / CI
```

---

## 9. CLI 与 Promptfoo 集成

### 9.1 CLI
```bash
python cli.py --facts facts.json --wiki wiki.json --out evaluation_result.json
```

### 9.2 Promptfoo
- 负责：模型调用、用例编排、结果聚合。
- 断言：基于 `pass == true`。

---

## 10. 风险与对策

| 风险 | 对策 |
|---|---|
| 规则过严导致低 Recall | 分级 Key Fact |
| 语言多样性 | 同义词映射表 |
| JSON 质量不稳 | Loader 严格校验 |

---

## 11. 里程碑

- M1：规则引擎 & CLI（1 周）
- M2：Promptfoo 集成（1 周）
- M3：CI 接入与回归（1 周）

---

## 12. 验收标准
- 可独立运行并稳定输出结果。
- CI 可阻断不合格 Wiki。
- 连续回归测试零幻觉。

