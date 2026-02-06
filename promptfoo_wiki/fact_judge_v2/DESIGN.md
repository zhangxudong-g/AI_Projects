
---

# Engineering Judge v2 重构设计文档（已完成）

## 重构状态

**状态：已完成**

本设计文档中提出的所有重构目标均已实现，Engineering Judge v2 系统已按设计要求完成重构。

## 二次重构状态

**状态：已完成**

根据 DESIGN_v2.md 文档，Engineering Judge v2 系统已按设计要求完成二次重构，包括：
- Stage 1 重构：Structural Coverage Judge
- 新增 Stage 1.5：Explanation Alignment Judge
- Stage 2 重构：Engineering Judge v2
- Stage 3 重构：Scoring v2（去硬 FAIL）

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
Stage 1: Fact Extractor（保持不变）
Stage 2: Engineering Explanation Judge（核心重构）
Stage 3: Risk-aware Scoring & Decision
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

#### 4.2.1 Interpretation Reasonableness（解释合理性）

**问题定义：**

> 一个理性工程师，在阅读源码后，是否“有可能”写出这样的解释？

**取值：**

* HIGH：大部分解释可从命名 / 结构 / 调用关系中合理推断
* MEDIUM：存在经验性解释，但不危险
* LOW：大量主观臆测或脑补

---

#### 4.2.2 Engineering Risk Level（工程风险等级）【核心维度】

**问题定义：**

> 如果开发者相信这份 Wiki，是否可能：
>
> * 修改错误的层
> * 误解职责边界
> * 做出错误的工程决策？

**取值：**

* LOW：即使部分不准确，也不影响修改决策
* MEDIUM：可能误解实现细节，需要频繁回看代码
* HIGH：极有可能导致错误修改（**FAIL 条件**）

---

#### 4.2.3 Boundary Adherence（层级与职责边界）

**问题定义：**

> Wiki 是否清楚区分了不同 Artifact Type 的职责？

**判定维度示例：**

* Controller 是否被描述为业务处理层？
* Service 是否被描述为流程编排器？
* Repository 是否被赋予领域语义？
* DTO / View 是否被描述为行为对象？

**取值：**

* GOOD：边界清晰
* WEAK：轻微越界
* BAD：严重职责混乱（**FAIL 条件**）

---

#### 4.2.4 Usefulness（实用性）

**问题定义：**

> 这份 Wiki 是否真的帮助工程师理解代码？

**取值：**

* HIGH：显著提升理解效率
* MEDIUM：有帮助，但需频繁查代码
* LOW：信息噪音大，价值有限

---

### 4.3 Stage 2 输出格式（JSON）

```json
{
  "interpretation_reasonableness": "HIGH | MEDIUM | LOW",
  "engineering_risk_level": "LOW | MEDIUM | HIGH",
  "boundary_adherence": "GOOD | WEAK | BAD",
  "usefulness_level": "HIGH | MEDIUM | LOW",
  "summary": "Concise explanation of reasoning and risk."
}
```

---

### 4.4 Stage 2 的 FAIL 判定规则（硬约束）

```text
FAIL if:
- engineering_risk_level == HIGH
OR
- boundary_adherence == BAD
```

其余情况均允许 PASS（可低分）。

---

## 5. Artifact Type 的解释边界（Stage 2 内部规则）

### 5.1 Controller

允许：

* 高层请求处理意图
* Service 委托关系

禁止（高风险）：

* 业务规则
* 校验逻辑
* UI / 分页 / 会话状态细节
* 精确执行顺序

---

### 5.2 Service

允许：

* 服务的系统角色
* DAO / Repository 依赖关系

禁止（高风险）：

* 业务流程分支
* 错误处理策略
* 事务 / 回滚语义

---

### 5.3 Repository

允许：

* 数据访问目的
* 方法命名意图

禁止（高风险）：

* ORM / Mapper 框架假设
* CRUD 语义总结
* 领域模型解释

---

### 5.4 DTO / View

允许：

* 数据语义分组

禁止（高风险）：

* 行为描述
* 使用场景
* 转换规则

---

### 5.5 SQL

允许：

* 脚本整体目的
* 数据流方向（基于 SQL 结构）

禁止（高风险）：

* 业务含义推断
* 错误处理 / 事务策略（若未显式存在）

---

## 6. Stage 3：Risk-aware Scoring 设计

### 6.1 新评分逻辑（建议）

```python
if engineering_risk_level == "HIGH" or boundary_adherence == "BAD":
    final_score = 0
    result = "FAIL"
else:
    final_score = (
        usefulness_score +           # 实用性，满分40分
        reasonableness_score +       # 解释合理性，满分30分
        boundary_score              # 边界遵循，满分30分
    )
    # 其中各单项分数根据评级映射：
    # usefulness: HIGH(40) | MEDIUM(25) | LOW(10)
    # interpretation_reasonableness: HIGH(30) | MEDIUM(20) | LOW(5)
    # boundary_adherence: GOOD(30) | WEAK(15) | BAD(0)
```

> 注：总分为100分，确保最高分可达100分。

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

 