
---

# Engineering Judge v3 重构设计文档（已完成）

## 重构状态

**状态：已完成**

本设计文档中提出的所有重构目标均已实现，Engineering Judge v3 系统已按设计要求完成重构。

## 三次重构状态

**状态：已完成**

根据 DESIGN_v3.md 文档，Engineering Judge v3 系统已按设计要求完成三次重构，包括：
- Stage 1 重构：Structural Coverage Judge
- 新增 Stage 1.5：Explanation Alignment Judge
- Stage 2 重构：Engineering Judge v3
- Stage 3 重构：Scoring v3（去硬 FAIL，分数范围10-95）

## 1. 背景与问题陈述

### 1.1 当前系统现状

当前 Wiki 生成系统的设计目标是：

* 面向 **新接手模块的开发者**
* 提供 **解释型 / onboarding 型技术文档**
* 允许：

  * 设计动机
  * 工程上下文
  * 高层流程说明
  * Mermaid 图示辅助理解

但现有 Judge 系统（以 Fact Judge / Soft Judge 为核心）的设计目标是：

* 判断 Wiki 是否 **严格忠于源码中的可验证事实**
* 严格禁止：

  * 推断性解释
  * 行为级流程描述
  * 设计动机与权衡

### 1.2 核心矛盾

> **Wiki 的生成目标 = 解释与理解
> Judge 的判定目标 = 事实一致性**

这导致系统出现结构性不一致：

* Wiki 写得越“像人类工程师”
* Judge 判得越严格、分数越低
* Controller / Service / SQL 等文件系统性 FAIL

该问题并非 prompt 质量问题，而是 **系统设计目标不一致**。

---

## 2. 重构目标（Design Goals）

### 2.1 总体目标

> **重构 Judge 系统，使其与“解释型 Wiki”的生成哲学一致。**

Judge 的核心问题应从：

> “这是不是 100% 事实？”

转变为：

> **“这种解释，会不会误导工程师做出错误修改？”**

### 2.2 非目标（Non-Goals）

本次重构 **不追求**：

* 原子级 fact correctness
* 枚举式覆盖率
* 完全禁止推断

Fact Judge 可作为 **独立模式** 保留，但不再作为默认 Judge。

---

## 3. 新 Judge 系统整体架构

### 3.1 重构后的 Stage 定义

```text
Stage 0: Pre-fact Extraction（前置提取事实）
Stage 1: Structural Coverage Judge（结构覆盖判断）
Stage 1.5: Explanation Alignment Judge（解释对齐判断）
Stage 2: Engineering Judge v3（工程价值判断）
Stage 3: Risk-aware Scoring & Decision（风险感知评分决策）
```

---

## 4. Stage 2：Engineering Explanation Judge

### 4.1 Stage 2 的角色定义

Stage 2 的角色不再是“事实裁判”，而是：

> **工程解释安全裁判（Engineering Explanation Safety Judge）**

它评估的是：

* 解释是否合理
* 是否存在工程风险
* 是否破坏了代码层级与职责边界

---

### 4.2 Stage 2 的核心评估维度

#### 4.2.1 Comprehension Support（理解支持）

**问题定义：**

> 新开发者能否快速建立整体心智模型？

**取值：**

* HIGH：知道"这个文件存在的意义"
* MEDIUM：知道流程，但不清楚设计动机
* LOW：只能当注释看

---

#### 4.2.2 Engineering Usefulness（工程实用性）【核心维度】

**问题定义：**

> 是否能指导实际修改/排查问题？

**取值：**

* HIGH：明确指出关键分支、风险点
* MEDIUM：只能用于阅读理解
* LOW：工程上几乎不可用

---

#### 4.2.3 Explanation Reasonableness（解释合理性）

**问题定义：**

> 解释是否克制、可辩护？

**取值：**

* HIGH：解释与代码强一致
* MEDIUM：有合理抽象，但略模糊
* LOW：解释跳跃、结论先行

---

#### 4.2.4 Abstraction Quality（抽象质量）

**问题定义：**

> 抽象是否服务理解而非装逼？

**取值：**

* GOOD：抽象层级恰好
* OK：略偏高或偏低
* POOR：要么复述代码，要么空谈架构

---

#### 4.2.5 Fabrication Risk（伪造风险）

**问题定义：**

> 是否编造了代码中不存在的元素？

**取值：**

* LOW：最小化伪造风险
* MEDIUM：一些潜在伪造元素
* HIGH：显著伪造非现存元素

---

### 4.3 Stage 2 输出格式（JSON）

```json
{
  "comprehension_support": "HIGH | MEDIUM | LOW",
  "engineering_usefulness": "HIGH | MEDIUM | LOW",
  "explanation_reasonableness": "HIGH | MEDIUM | LOW",
  "abstraction_quality": "GOOD | OK | POOR",
  "fabrication_risk": "LOW | MEDIUM | HIGH",
  "summary": "Concise engineering assessment"
}
```

---

### 4.4 Stage 2 的 FAIL 判定规则（硬约束）

```text
FAIL if:
- fabrication_risk == HIGH
AND
- explanation_reasonableness == LOW
```

其余情况均允许 PASS（可低分），但会根据风险进行扣分。

---

## 5. Artifact Type 的评估考量（Stage 2 评估要素）

### 5.1 Comprehension Support（理解支持）针对不同Artifact Type

**Controller:**

* HIGH: 清楚说明请求处理目的和业务入口点
* MEDIUM: 描述了流程但缺少设计动机
* LOW: 仅列举方法名称

**Service:**

* HIGH: 阐明服务在整个系统中的角色和职责
* MEDIUM: 描述了功能但缺少上下文
* LOW: 仅复述代码逻辑

**Repository/DAO:**

* HIGH: 说明数据访问模式和用途
* MEDIUM: 列出操作但缺少目的说明
* LOW: 仅描述技术实现

---

### 5.2 Engineering Usefulness（工程实用性）针对不同Artifact Type

**Controller:**

* HIGH: 指出关键分支、安全检查点、外部依赖
* MEDIUM: 描述一般流程
* LOW: 仅技术细节

**Service:**

* HIGH: 标识事务边界、性能考虑点、错误处理策略
* MEDIUM: 说明功能组合方式
* LOW: 仅方法职责

**Repository/DAO:**

* HIGH: 说明查询复杂度、缓存策略、并发考虑
* MEDIUM: 描述数据关系
* LOW: 仅CRUD操作

---

### 5.3 Explanation Reasonableness（解释合理性）通用准则

* HIGH: 所有解释都能追溯到代码结构或注释
* MEDIUM: 有合理推断，但明确标注为"推测/可能"
* LOW: 把代码行为描述为"业务规则"

---

### 5.4 Abstraction Quality（抽象质量）评估标准

* GOOD: 抽象层级恰好，服务于理解
* OK: 抽象略偏高或偏低
* POOR: 要么复述代码，要么空谈架构

---

### 5.5 Fabrication Risk（伪造风险）检测要点

* LOW: 最小化虚构元素，严格基于代码
* MEDIUM: 一些合理的业务推断
* HIGH: 发明代码中不存在的组件、流程或规则

## 6. Stage 3：Risk-aware Scoring 设计

### 6.1 新评分逻辑（建议）

```python
# 各项权重分配（总分100分）
usefulness_points = 35  # comprehension_support和engineering_usefulness各占一部分
comprehension_points = 25
explanation_reasonableness_points = 20
abstraction_quality_points = 20

# 分数映射
comprehension_scores = {
    "HIGH": 25,
    "MEDIUM": 15,
    "LOW": 5,
}

usefulness_scores = {
    "HIGH": 35,
    "MEDIUM": 20,
    "LOW": 5,
}

explanation_reasonableness_scores = {
    "HIGH": 20,
    "MEDIUM": 12,
    "LOW": 4,
}

abstraction_quality_scores = {
    "GOOD": 20,
    "OK": 12,
    "POOR": 4,
}

# 计算基础分数
score = comprehension_scores.get(comprehension_support, 5) + \
        usefulness_scores.get(engineering_usefulness, 5) + \
        explanation_reasonableness_scores.get(explanation_reasonableness, 4) + \
        abstraction_quality_scores.get(abstraction_quality, 4)

# 风险扣分
risk_penalty = 0
if fabrication_risk == "HIGH":
    risk_penalty = 40
elif fabrication_risk == "MEDIUM":
    risk_penalty = 20
# LOW 风险不扣分

# 应用风险扣分，并使用clamp防止分数过低或过高
final_score_value = clamp(score - risk_penalty, min_v=10, max_v=95)  # 确保分数在10-95范围内

# FAIL 条件（极小化）：只有在高风险且解释不合理的情况下才FAIL
if fabrication_risk == "HIGH" and explanation_reasonableness == "LOW":
    result = "FAIL"
else:
    result = "PASS"
```

> 注：总分为100分，但使用clamp函数将分数限制在10-95范围内，确保系统不会出现极端分数。

---

## 7. 设计收益总结

### 7.1 一致性收益

* Wiki 生成目标 ≈ Judge 判定目标
* 消除“写得越好，分越低”的系统内耗

### 7.2 工程价值

* Judge 行为更接近人类 Tech Lead
* Controller / Service 不再被系统性误杀
* Repo / DTO 仍保持严格

---

## 8. 后续扩展方向（可选）

* 同时支持：

  * Fact Wiki + Fact Judge
  * Explanation Wiki + Explanation Judge
* 双 Judge 结果并行展示
* Wiki 自动拆分为「事实区 / 解释区」

 