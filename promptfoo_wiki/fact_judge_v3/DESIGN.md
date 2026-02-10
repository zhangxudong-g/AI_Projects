
---

# Wiki Engineering Judge v3（重构设计文档）

> 设计目标：
> **准确衡量 Wiki 是否真的“帮助新接手开发者理解代码”**，
> 同时 **抑制脑补、避免极端 0 / 100 分**，与现有 Stage3 风险感知评分完全兼容。

---

## 一、整体评估架构（与现有代码完全对齐）

```mermaid
flowchart LR
    A[Source Code] --> S0[Stage0<br/>Engineering Fact Pre-Extractor]
    B[Generated Wiki] --> S1

    S0 --> S1[Stage1<br/>Structural Coverage Judge]
    S1 --> S15[Stage1.5<br/>Explanation Alignment Judge]
    S15 --> S2[Stage2<br/>Engineering Judge v3]
    S2 --> S3[Stage3<br/>Risk-aware Final Scoring]

    S3 --> R[Final Score + PASS/FAIL]
```

你现在的 pipeline **不用动**，只需要：

* **重构 Stage2 的 judging 语义**
* **微调 Stage1 / 1.5 的关注点**
* **让 Stage3 不再出现极端分**

---

## 二、评估系统的“总原则”（非常重要）

### 1️⃣ Wiki 的评估不是“是否写得多”

而是：

> **新接手开发者，看完是否：**
>
> * 知道这个文件在干嘛
> * 知道为什么这么设计
> * 知道哪里不能乱改
> * 知道接下来要去看哪里

---

### 2️⃣ 评分是连续的，不是开关式

你现在的 `final_score()` 已经是**正确方向**：

* ❌ 不再有 Stage2 = FAIL 直接 0
* ✅ 风险只做扣分
* ✅ FAIL 只在“高风险 + 解释不合理”时出现

👉 所以 **Judge 的 prompt 不能再产出极端标签**。

---

## 三、Stage0：Engineering Fact Pre-Extractor（已正确，不动）

### 定位（你现在已经做对了）

* **只抽“代码里客观存在的工程锚点”**
* 不解释、不评价、不总结
* 是后续所有 judge 的“事实地基”

Stage0 输出本质是：

> 「**Wiki 不允许越界的边界集合**」

✔ 保留现状。

---

## 四、Stage1：Structural Coverage Judge（重构目标）

### 原始问题

以前 Stage1 容易变成：

> “有没有提到类 / 方法 / 表名”

但你的 Wiki 模板关注的是：

> **“新接手开发者最大的困惑是否被覆盖”**

---

### ✅ Stage1 v3 评估目标

> Wiki 是否**覆盖了“必须解释的工程结构点”**

而不是：

* 是否逐行解释
* 是否提到所有函数

---

### Stage1 输出结构（建议）

```json
{
  "coverage_level": "HIGH | MEDIUM | LOW",
  "covered_items": [
    {
      "anchor": "Controller.handleRequest",
      "why_important": "入口方法，决定业务主流程",
      "covered": true
    }
  ],
  "missing_critical_items": [
    {
      "anchor": "i_TENKAI_KBN flags",
      "impact": "控制大量条件分支，未解释会导致误修改"
    }
  ],
  "summary": "..."
}
```

### 判定逻辑（给 Judge 的明确指令）

* **HIGH**

  * 所有“高认知负担”的结构点都有解释
* **MEDIUM**

  * 主流程清楚，但关键条件 / 状态解释不足
* **LOW**

  * 只描述代码表面结构，无法支撑理解

⚠️ **禁止输出 PASS / FAIL**

---

## 五、Stage1.5：Explanation Alignment Judge（重构重点）

这是**防脑补的核心关卡**。

### 核心问题

> Wiki 中的解释，是否**严格受限于代码事实**？

---

### Stage1.5 评估维度（非常具体）

Judge **只看三件事**：

1. 是否**引入代码中不存在的概念**
2. 是否**夸大代码的职责**
3. 是否**推断未出现的业务规则**

---

### 输出结构（建议）

```json
{
  "alignment_level": "HIGH | MEDIUM | LOW",
  "fabrication_risk": "LOW | MEDIUM | HIGH",
  "issues": [
    {
      "type": "INVENTED_BEHAVIOR",
      "statement": "This controller ensures transactional consistency",
      "reason": "代码中无事务控制"
    }
  ],
  "summary": "..."
}
```

### Judge 明确规则

* **HIGH**

  * 所有解释都能追溯到代码结构或注释
* **MEDIUM**

  * 有合理推断，但明确标注为“推测 / 可能”
* **LOW**

  * 把“代码行为”说成“业务规则”

⚠️ **fabrication_risk 只在这里产生**

---

## 六、Stage2：Engineering Judge v3（核心重构）

这是你现在**最值得重构的一层**。

---

### Stage2 不再做“裁判”

而是做：

> **“工程价值评估器”**

---

### Stage2 v3 输入

* structural_coverage_results（Stage1）
* explanation_alignment_results（Stage1.5）
* wiki_md
* artifact_type

---

### Stage2 v3 输出（必须严格匹配 Stage3）

```json
{
  "comprehension_support": "HIGH | MEDIUM | LOW",
  "engineering_usefulness": "HIGH | MEDIUM | LOW",
  "explanation_reasonableness": "HIGH | MEDIUM | LOW",
  "abstraction_quality": "GOOD | OK | POOR",
  "fabrication_risk": "LOW | MEDIUM | HIGH",
  "summary": "..."
}
```

---

### 各维度**精确定义**（给 qwen-coder 的关键）

#### 1️⃣ comprehension_support

> 新开发者能否快速建立**整体心智模型**

* HIGH：读完知道“这个文件存在的意义”
* MEDIUM：知道流程，但不清楚设计动机
* LOW：只能当注释看

---

#### 2️⃣ engineering_usefulness

> 是否能**指导实际修改 / 排查问题**

* HIGH：明确指出关键分支、风险点
* MEDIUM：只能用于阅读理解
* LOW：工程上几乎不可用

---

#### 3️⃣ explanation_reasonableness

> 解释是否**克制、可辩护**

* HIGH：解释与代码强一致
* MEDIUM：有合理抽象，但略模糊
* LOW：解释跳跃、结论先行

---

#### 4️⃣ abstraction_quality

> 抽象是否**服务理解而非装逼**

* GOOD：抽象层级恰好
* OK：略偏高或偏低
* POOR：要么复述代码，要么空谈架构

---

#### 5️⃣ fabrication_risk

> **直接透传 Stage1.5 的结论**

---

## 七、Stage3：最终打分（你现在这版是对的）

你现在的 `final_score()`：

✔ 已经满足所有目标：

* 连续分布
* 风险扣分
* 极小 FAIL 面积
* 不会轻易 0 / 100

**唯一建议（可选）**：

```python
# 防止“全 LOW + MEDIUM 风险 = 0”
final_score_value = clamp(score - risk_penalty, min_v=10, max_v=95)
```

> 这样你会得到一个**工程上更好用的分布**

---

## 八、Engineering Judge v3.1 重要更新（2026年2月9日）

根据 DESIGN_v3.1.md 文档，Engineering Judge v3 系统已升级至 v3.1，主要改进包括：

### 1. 新增 fabrication_type 字段
在 Stage2 输出中添加了 `fabrication_type` 字段，用于明确标识伪造类型：
- `NONE`: 无伪造
- `ARCHITECTURAL`: 引入源码中不存在的架构、职责、调用关系
- `LOCAL`: 局部逻辑、字段、行为的脑补
- `TERMINOLOGY`: 虚构术语、概念名

### 2. 强制规则（Laws）
#### Law 1：Architecture Fabrication 硬覆盖
当 `fabrication_type == "ARCHITECTURAL"` 时，强制设置：
- `explanation_reasonableness = "LOW"`
- `fabrication_risk = "HIGH"`

#### Law 2：Abstraction Mismatch 分数封顶
当满足以下条件时，最终分数 ≤ 50：
- `explanation_reasonableness == "HIGH"`
- `fabrication_risk == "LOW"`
- `abstraction_quality` in ["OK", "POOR"]

### 3. Stage2 Prompt 增强
添加了 CRITICAL FABRICATION RULES，特别强调：
- 对架构级伪造的严格识别
- 对抽象失配的明确区分

### 4. 工程操作建议
系统现在会根据最终分数映射到具体的工程操作建议：
- ≥ 90: 可作为主要参考文档
- 70–89: 可用于理解与修改，需关注风险点
- 50–69: 仅供理解结构，修改需对照源码
- 40–49: 不建议用于修改
- < 40: 不可信

## 十、Engineering Judge v3.2 重要更新（2026年2月10日）

Engineering Judge v3 系统进一步升级至 v3.2，主要改进包括用户体验优化和功能扩展：

### 1. 工程建议优先显示优化
根据用户反馈，对结果展示进行了重要优化：
- **工程建议作为主要展示点**：在结果表格的摘要部分，直接显示推荐操作内容，而非"Recommended Action: XXX"格式
- **消除冗余信息**：详情部分不再重复显示推荐操作，避免与标题重复
- **提升用户体验**：用户可以第一时间看到最重要的工程建议，无需展开详情

### 2. HTML 格式报告功能
新增了 HTML 格式的结果报告功能：
- **直接浏览器查看**：生成的 HTML 文件可直接在浏览器中打开，无需额外转换
- **响应式设计**：采用现代化的 CSS 样式，适配不同屏幕尺寸
- **交互式详情**：使用 `<details>` 和 `<summary>` 标签实现可折叠的详情查看
- **状态可视化**：PASS/FAIL 状态使用不同颜色标识，便于快速识别

### 3. PL/SQL 测试用例扩展
为支持更广泛的数据库代码评估，新增了 PL/SQL 测试用例：
- **SQL 文件 UTF-8 转换**：支持将原始 SQL 文件转换为 UTF-8 编码
- **多类型覆盖**：测试用例覆盖 Functions、Procedures、Packages、Tables、Views、Package Bodies 等多种 PL/SQL 对象类型
- **对比测试支持**：支持不同 AI 模型（如 Kimi）生成文档的对比评估

## 十一、最终效果（你将得到什么）

* Wiki 写得烂 → **20~40**
* 勉强能用 → **50~65**
* 工程友好 → **70~85**
* 教科书级 → **90 左右**
* ❌ 几乎不会再出现：

  * 动不动 0
  * 随便 100

---
 
