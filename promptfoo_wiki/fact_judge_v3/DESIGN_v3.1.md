好，这里给你一份**可以直接丢给 qwen-coder 开工的「修改设计文档」**。
这不是解释文，而是**工程指令级文档**，目标非常明确：
👉 **修到 adversarial regression 全绿，并且以后不再被“合理但错误的 wiki”骗分。**

你可以原样复制给 qwen-coder。

---

# Engineering Judge v3 → v3.1 → v3.2

## Stage2 + Final Score + 结果展示 修改设计文档

---

## 1. 修改背景（Why）

当前 Engineering Judge v3 在以下场景存在系统性问题：

1. **Architecture Fabrication（架构级脑补）**

   * Wiki 引入源码中不存在的架构层级、职责划分、调用关系
   * 但因“听起来合理”，Stage2 往往给出 `MEDIUM / MEDIUM`
   * 导致 final_score 落在 50–60，**未被严格惩罚**

2. **Abstraction Mismatch（抽象失配）**

   * 描述是“真的”，但抽象层级无法支持工程修改
   * 当前仍可能打到 60+，与工程实际不符

本次修改目标：
**把“工程不可接受”的情况，写成系统级硬约束（Law），而不是评分倾向。**

---

## 2. 设计目标（Goals）

### 2.1 行为目标

| 场景              | 系统行为           |
| --------------- | -------------- |
| 架构级 Fabrication | 必须判为高风险 + 低合理性 |
| 抽象失配            | 分数必须被封顶        |
| Regression Case | 全部稳定通过         |
| 正常高质量 Wiki      | 分数分布不受破坏       |

---

### 2.2 非目标（Non-Goals）

* ❌ 不追求更复杂的 NLP 判断
* ❌ 不依赖 summary 文本解析
* ❌ 不引入额外 stage

---

## 3. Stage2 输出结构调整（Schema v3.1）

### 3.1 新增字段（强制）

```json
fabrication_type
```

### 3.2 完整 Stage2 输出 Schema

```json
{
  "comprehension_support": "HIGH | MEDIUM | LOW",
  "engineering_usefulness": "HIGH | MEDIUM | LOW",
  "explanation_reasonableness": "HIGH | MEDIUM | LOW",
  "abstraction_quality": "GOOD | OK | POOR",
  "fabrication_risk": "LOW | MEDIUM | HIGH",
  "fabrication_type": "NONE | ARCHITECTURAL | LOCAL | TERMINOLOGY",
  "summary": "string"
}
```

### 3.3 fabrication_type 定义

| 值             | 含义                  |
| ------------- | ------------------- |
| NONE          | 无 fabrication       |
| ARCHITECTURAL | 引入源码中不存在的架构、职责、调用关系 |
| LOCAL         | 局部逻辑、字段、行为的脑补       |
| TERMINOLOGY   | 虚构术语、概念名            |

---

## 4. Stage2 Prompt 修改要求（关键）

### 4.1 新增强制规则段（必须原样实现）

```text
============================================================
CRITICAL FABRICATION RULES (MANDATORY)
============================================================

You MUST explicitly identify fabrication types.

1. ARCHITECTURAL FABRICATION
If the wiki introduces ANY architectural layers, system roles,
module responsibilities, execution flows, or interactions
that are NOT explicitly present in the source code,
you MUST classify it as ARCHITECTURAL FABRICATION.

In this case, you MUST output:
- explanation_reasonableness = LOW
- fabrication_risk = HIGH
- fabrication_type = ARCHITECTURAL

This rule applies EVEN IF the explanation sounds reasonable
or follows common industry practices.

2. ABSTRACTION MISMATCH
If the explanation is factually correct but uses an abstraction
level that does NOT directly support safe modification or debugging,
you MUST classify abstraction_quality as OK or POOR.

============================================================
OUTPUT REQUIREMENTS
============================================================

You MUST include:
- fabrication_type: one of [NONE, ARCHITECTURAL, LOCAL, TERMINOLOGY]
```

### 4.2 设计原则（供 coder 理解）

* Stage2 的职责是 **“定性判罪”**
* final_score 的职责是 **“依法量刑”**
* 不允许 Stage2 用“合理性”掩盖 fabrication

---

## 5. Final Score 层修改（核心逻辑）

### 5.1 新增「法律覆盖层」（Hard Override）

#### Law 1：Architecture Fabrication 硬覆盖

**规则：**

> 只要 `fabrication_type == ARCHITECTURAL`
> 不管 Stage2 其它字段是什么，必须强制重写判断。

**实现要求：**

```python
if fabrication_type == "ARCHITECTURAL":
    explanation_reasonableness = "LOW"
    fabrication_risk = "HIGH"
```

---

### 5.2 抽象失配的「分数封顶」

#### Law 2：Abstraction Mismatch Cap

**适用条件：**

```text
explanation_reasonableness == HIGH
AND fabrication_risk == LOW
AND abstraction_quality in [OK, POOR]
```

**效果：**

```text
final_score ≤ 50
```

**实现要求：**

```python
final_score_value = min(final_score_value, 50)
```

---

## 6. Final Score 行为规范（结果语义）

| 分数区间  | 含义（对用户）         |
| ----- | --------------- |
| ≥ 90  | 可作为主要参考文档       |
| 70–89 | 可用于理解与修改，需关注风险点 |
| 50–69 | 仅供理解结构，修改需对照源码  |
| 40–49 | 不建议用于修改         |
| < 40  | 不可信             |

⚠️ Architecture Fabrication 必须落入 `< 40` 或直接 FAIL

---

## 7. Regression Case 对齐说明

### 7.1 AT_01_arch_fabrication

**期望：**

```text
fabrication_type = ARCHITECTURAL
explanation_reasonableness = LOW
fabrication_risk = HIGH
score ∈ [0, 40]
```

---

### 7.2 AT_06_abstraction_mismatch

**期望：**

```text
fabrication_type = NONE
explanation_reasonableness = HIGH
fabrication_risk = LOW
abstraction_quality = OK | POOR
score ≤ 50
```

---

## 8. 实施 Checklist（给 qwen-coder）

* [ ] Stage2 Prompt 加入 CRITICAL FABRICATION RULES
* [ ] Stage2 输出增加 fabrication_type
* [ ] final_score 增加 Law 1（硬覆盖）
* [ ] final_score 增加 Law 2（封顶）
* [ ] 跑 adversarial regression，确保全绿
* [ ] 确认现有高分 case 不受影响

---

## 9. 用户体验优化扩展（v3.2）

### 9.1 工程建议优先显示

**设计目标**：将最重要的工程建议直接展示给用户，提升用户体验

**实现要求**：
- 在结果表格的摘要部分，直接显示推荐操作内容，而非"Recommended Action: XXX"格式
- 详情部分不再重复显示推荐操作，避免与标题重复
- 确保用户可以第一时间看到最重要的工程建议

**技术实现**：
```python
# 在 _format_details 函数中
compact_info = f"{recommended_action[:50]}{'...' if len(str(recommended_action)) > 50 else ''}"
```

### 9.2 HTML 格式报告功能

**设计目标**：提供可直接在浏览器中查看的格式化报告

**实现要求**：
- 生成的 HTML 文件可直接在浏览器中打开
- 采用现代化的 CSS 样式，适配不同屏幕尺寸
- 使用 `<details>` 和 `<summary>` 标签实现可折叠的详情查看
- PASS/FAIL 状态使用不同颜色标识

**技术实现**：
```python
# 新增 format_results_to_html 函数
def format_results_to_html(case_results, cases_config, base_output: str = "output"):
    # 生成完整的HTML页面，包含CSS样式和表格
```

---

## 10. 版本结论

完成以上修改后：

* Engineering Judge 从「评分器」
* 升级为「**工程事实裁判 + 法律执行器 + 用户体验优化器**」

这是 **v3 → v3.1 → v3.2** 的演进过程。

