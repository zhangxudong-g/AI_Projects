# Engineering Fact Judge v3 详细流程图文档

## 系统概述

Engineering Fact Judge v3 是一个多阶段评估系统，专门用于评估代码解释性文档的工程价值和风险。该系统通过五个阶段的评估流程，确保生成的文档既准确又有用。

## 详细流程图

```mermaid
graph TD
    A[开始] --> B[输入: 源代码和Wiki文档]
    B --> C[Stage 0: 前置提取事实（工程wiki级别）]
    C --> D[提取工程级锚点和事实，为后续评估提供上下文]
    D --> E[Stage 1: 结构覆盖判断]
    E --> F[判断Wiki是否严重脱离代码结构，评估核心工程角色覆盖]
    F --> G[Stage 1.5: 解释对齐判断]
    G --> H[判断解释是否来自代码、合理抽象、无编造]
    H --> I[Stage 2: 工程判断v3]
    I --> J[评估理解支持、工程实用性、解释合理性、抽象质量、伪造风险]
    J --> K[Stage 3: 工程价值评分]
    K --> L[基于工程价值的PASS/FAIL判定]
    L --> M[输出: 评估结果和最终得分]
    M --> N[生成报告和可视化结果]

    C -.-> O[prepare_engineering_facts函数]
    E -.-> P[stage1_fact_extractor.yaml]
    G -.-> Q[stage1_5_explanation_alignment.yaml]
    I -.-> R[stage2_explanatory_judge.yaml]
    K -.-> S[stage3_score.py]

    %% 错误处理路径
    E --> E_ERR{Stage 1 错误?}
    E_ERR -->|是| E_ERROR[记录错误，标记为失败]
    E_ERR -->|否| G
    G --> G_ERR{Stage 1.5 错误?}
    G_ERR -->|是| G_ERROR[记录错误，标记为失败]
    G_ERR -->|否| I
    I --> I_ERR{Stage 2 错误?}
    I_ERR -->|是| I_ERROR[记录错误，标记为失败]
    I_ERR -->|否| K
    K --> K_ERR{Stage 3 错误?}
    K_ERR -->|是| K_ERROR[记录错误，标记为失败]
    K_ERR -->|否| L

    %% 数据流向
    B -.-> B_DATA[(源代码, Wiki文档)]
    C -.-> C_DATA[(工程事实)]
    E -.-> E_DATA[(结构覆盖结果)]
    G -.-> G_DATA[(解释对齐结果)]
    I -.-> I_DATA[(工程判断结果)]
    K -.-> K_DATA[(最终评分)]

    %% 回归测试
    N --> REG[回归测试验证]
    REG --> REG_CHECK{符合预期?}
    REG_CHECK -->|是| DONE[完成]
    REG_CHECK -->|否| FIX[修复并重新测试]
    FIX --> REG