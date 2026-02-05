# Fact Judge 系统流程图

## 整体架构流程

```mermaid
graph TD
    A[开始] --> B[输入: 源代码和Wiki文档]
    B --> C[Stage 1: 事实提取]
    C --> D[提取覆盖率、正确性、幻觉、有用性事实]
    D --> E[Stage 2: 软性判断]
    E --> F[评估整体质量: 覆盖率级别、正确性级别<br/>幻觉级别、有用性级别]
    F --> G[Stage 3: 最终评分]
    G --> H[计算最终分数和PASS/FAIL判定]
    H --> I[输出: 评估结果]

    C -.-> J[stage1_fact_extractor.yaml]
    E -.-> K[stage2_soft_judge.yaml]
    G -.-> L[stage3_score.py]


```

### 文本流程说明

1. **开始** → **输入**: 接收源代码和Wiki文档作为输入
2. **输入** → **Stage 1**: 执行事实提取阶段
3. **Stage 1** → **提取事实**: 从源代码和文档中提取覆盖率、正确性、幻觉、有用性事实
4. **提取事实** → **Stage 2**: 执行软性判断阶段
5. **Stage 2** → **评估质量**: 评估整体质量，包括覆盖率级别、正确性级别、幻觉级别、有用性级别
6. **评估质量** → **Stage 3**: 执行最终评分阶段
7. **Stage 3** → **计算分数**: 计算最终分数和PASS/FAIL判定
8. **计算分数** → **输出**: 输出评估结果

## 详细组件交互图

```mermaid
graph TB
    subgraph "输入层"
        A1[源代码文件]
        A2[Wiki文档]
    end

    subgraph "Stage 1: 事实提取"
        B1[stage1_fact_extractor.yaml]
        B2[promptfoo eval]
        B3[extract.py - 提取JSON]
    end

    subgraph "Stage 2: 软性判断"
        C1[stage2_soft_judge.yaml]
        C2[promptfoo eval]
        C3[extract.py - 提取JSON]
    end

    subgraph "Stage 3: 最终评分"
        D1[stage3_score.py]
        D2[综合评分算法]
    end

    subgraph "输出层"
        E1[评估结果]
        E2[最终分数]
        E3[PASS/FAIL判定]
    end

    A1 --> B1
    A2 --> B1
    B1 --> B2
    B2 --> B3
    B3 --> C1
    C1 --> C2
    C2 --> C3
    C3 --> D1
    D1 --> D2
    D2 --> E1
    D2 --> E2
    D2 --> E3


```

### 组件交互文本说明

- **输入层**: 提供源代码文件和Wiki文档
- **Stage 1**: 使用stage1_fact_extractor.yaml配置文件，通过promptfoo eval执行事实提取，然后使用extract.py提取JSON格式结果
- **Stage 2**: 使用stage2_soft_judge.yaml配置文件，接收Stage 1的JSON结果，通过promptfoo eval执行软性判断，再使用extract.py提取JSON格式结果
- **Stage 3**: 使用stage3_score.py脚本，接收Stage 2的JSON结果，通过综合评分算法计算最终结果
- **输出层**: 生成评估结果、最终分数和PASS/FAIL判定

## 脚本执行流程

```mermaid
sequenceDiagram
    participant User
    participant run_multi_cases as run_multi_cases.py
    participant run_single_case as run_single_case_pipeline.py
    participant stage1 as Stage 1 (Fact Extractor)
    participant stage2 as Stage 2 (Soft Judge)
    participant stage3 as Stage 3 (Final Scoring)
    participant formatter as 结果格式化器

    User->>run_multi_cases: 执行批量评估
    run_multi_cases->>run_single_case: 处理单个案例
    run_single_case->>stage1: 执行事实提取
    stage1-->>run_single_case: 返回提取结果
    run_single_case->>stage2: 执行软性判断
    stage2-->>run_single_case: 返回判断结果
    run_single_case->>stage3: 执行最终评分
    stage3-->>run_single_case: 返回最终结果
    run_single_case-->>run_multi_cases: 返回案例结果
    run_multi_cases->>formatter: 格式化结果为Markdown表格
    formatter-->>run_multi_cases: 返回格式化结果
    run_multi_cases-->>User: 返回所有案例结果及表格
```

### 脚本执行文本说明

1. 用户执行run_multi_cases.py脚本启动批量评估
2. run_multi_cases.py脚本读取cases.yaml配置文件，逐个处理每个案例
3. 对于每个案例，调用run_single_case_pipeline.py脚本处理单个案例
4. run_single_case_pipeline.py脚本依次执行：
   - 调用Stage 1 (Fact Extractor) 进行事实提取
   - 接收Stage 1返回结果后，调用Stage 2 (Soft Judge) 进行软性判断
   - 接收Stage 2返回结果后，调用Stage 3 (Final Scoring) 进行最终评分
5. run_single_case_pipeline.py将最终结果返回给run_multi_cases.py
6. run_multi_cases.py收集所有案例结果后，调用结果格式化器生成Markdown表格
7. run_multi_cases.py返回所有案例结果和格式化的表格给用户

## 新增功能流程图

### 前置提取事实（工程wiki级别）流程

```mermaid
graph TD
    A[开始] --> B[输入: 工程项目路径]
    B --> C[扫描项目结构]
    C --> D[识别项目文件和模块]
    D --> E[分析模块间关系]
    E --> F[提取架构特征]
    F --> G[识别设计模式]
    G --> H[生成项目上下文信息]
    H --> I[输出: 工程级事实JSON]

    style A fill:#ffffff
    style B fill:#f8f9fa
    style C fill:#fff3e0
    style D fill:#fff8e1
    style E fill:#e8f5e8
    style F fill:#f1f8e9
    style G fill:#e3f2fd
    style H fill:#e1f5fe
    style I fill:#fafafa
```

### 前置提取与评估流程整合

```mermaid
graph LR
    A[前置提取事实] --> B[项目结构分析]
    B --> C[模块关系提取]
    C --> D[上下文信息生成]
    D --> E[传统三阶段评估]
    E --> F[融合工程级上下文]
    F --> G[最终评估结果]

    style A fill:#e3f2fd
    style D fill:#fff3e0
    style E fill:#e8f5e8
    style G fill:#f1f8e9
```

### 工程级评估流程

```mermaid
sequenceDiagram
    participant User
    participant PreExtractor as pre_extract_facts.py
    participant ProjectAnalyzer as 项目分析器
    participant ContextBuilder as 上下文构建器
    participant Evaluator as 评估器

    User->>PreExtractor: 提供项目路径
    PreExtractor->>ProjectAnalyzer: 扫描项目结构
    ProjectAnalyzer->>ContextBuilder: 提取模块关系
    ContextBuilder->>PreExtractor: 生成上下文信息
    PreExtractor-->>User: 返回工程级事实
    User->>Evaluator: 执行评估（带上下文）
    Evaluator-->>User: 返回最终评估结果
```

### 结果可视化流程

```mermaid
graph TD
    A[开始] --> B[批量评估完成]
    B --> C[收集所有案例结果]
    C --> D[读取每个案例的final_score.json]
    D --> E[提取关键信息]
    E --> F[Summary<br/>Coverage Level<br/>Usefulness Level<br/>Correctness Level<br/>Hallucination Level<br/>Coverage Rate]
    F --> G[格式化为平铺显示]
    G --> H[生成可折叠HTML元素]
    H --> I[创建Markdown表格]
    I --> J[Case ID | 文件名 | 结果 | 分数 | 详情]
    J --> K[保存为final_results_table-[timestamp].md]
    K --> L[输出完成]

    style A fill:#e3f2fd
    style B fill:#e8f5e8
    style C fill:#f1f8e9
    style D fill:#e8f5e8
    style E fill:#f1f8e9
    style F fill:#e3f2fd
    style G fill:#e8f5e8
    style H fill:#f1f8e9
    style I fill:#e8f5e8
    style J fill:#f1f8e9
    style K fill:#e3f2fd
    style L fill:#f1f8e9
```

### 结果可视化序列图

```mermaid
sequenceDiagram
    participant User
    participant BatchRunner as run_multi_cases.py
    participant ResultsCollector as 结果收集器
    participant Formatter as format_results_with_llm函数
    participant JsonReader as JSON读取器
    participant HtmlGenerator as HTML生成器
    participant MdWriter as Markdown写入器

    User->>BatchRunner: 执行批量评估
    BatchRunner->>ResultsCollector: 收集所有案例结果
    ResultsCollector->>BatchRunner: 返回结果列表
    BatchRunner->>Formatter: 调用format_results_with_llm
    Formatter->>JsonReader: 读取每个案例的final_score.json
    JsonReader-->>Formatter: 返回JSON数据
    Formatter->>HtmlGenerator: 生成可折叠HTML元素
    HtmlGenerator-->>Formatter: 返回HTML字符串
    Formatter->>MdWriter: 创建Markdown表格并写入文件
    MdWriter-->>Formatter: 返回文件路径
    Formatter-->>BatchRunner: 返回格式化结果
    BatchRunner-->>User: 返回所有结果及表格文件路径
```