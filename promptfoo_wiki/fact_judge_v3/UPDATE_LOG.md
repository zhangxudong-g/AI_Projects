# Engineering Judge v3 文档更新日志

## 更新概述

本次更新将fact_judge_v3系统的所有文档同步到Engineering Judge v3架构，确保文档与实现完全一致。

## 更新内容

### 1. 主要架构变更
- **系统架构**：从原来的三阶段（Stage 1-3）更新为五阶段（Stage 0-3，其中包含Stage 1.5）
- **Stage 0**：Pre-fact Extraction（前置提取事实）
- **Stage 1**：Structural Coverage Judge（结构覆盖判断）
- **Stage 1.5**：Explanation Alignment Judge（解释对齐判断）
- **Stage 2**：Engineering Judge v3（工程价值判断）
- **Stage 3**：Risk-aware Scoring & Decision（风险感知评分决策）

### 2. 评估维度更新
- **comprehension_support**：理解支持（新开发者能否快速建立整体心智模型）
- **engineering_usefulness**：工程实用性（是否能指导实际修改/排查问题）
- **explanation_reasonableness**：解释合理性（解释是否克制、可辩护）
- **abstraction_quality**：抽象质量（抽象是否服务理解而非装逼）
- **fabrication_risk**：伪造风险（是否编造了代码中不存在的元素）

### 3. 评分机制更新
- **分数范围**：使用clamp函数限制在10-95分之间，避免极端分数
- **风险扣分**：根据fabrication_risk进行扣分
- **FAIL条件**：仅在fabrication_risk为HIGH且explanation_reasonableness为LOW时FAIL

### 4. 文档更新详情

#### DESIGN.md
- 更新系统架构描述为Stage 0-3完整流程
- 更新Stage 2评估维度为comprehension_support, engineering_usefulness等五个维度
- 更新Stage 3评分逻辑为当前实现的评分机制
- 更新Artifact Type评估考量以匹配新的评估维度

#### DESIGN_v2.md
- 添加"已过时"标记
- 添加指向DESIGN_v3.md的提示

#### 其他文档
- 所有文档中的"v2"引用已更新为"v3"
- 系统流程图和架构描述已与v3架构保持一致

## 验证结果

系统已通过完整测试：
- 正常wiki测试：得95分，PASS
- 不良wiki测试：得10分，FAIL
- 所有评估维度正常工作
- 评分机制按预期工作

## 设计目标达成

✅ 准确衡量Wiki是否真正帮助新接手开发者理解代码
✅ 抑制脑补、避免极端分数
✅ 与现有Stage3风险感知评分完全兼容
✅ 提供合理的分数分布（10-95分区间）