# Wiki Judges - 文档质量评估系统

这是一个基于 promptfoo 的三阶段文档质量评估系统，用于评估项目文档与源代码的一致性。

## 系统架构

### 三个评估阶段

1. **Stage 1: Fact Extractor**
   - 从 Wiki 文档中抽取可由源代码验证的事实
   - 判断事实与源码的一致性（supported/contradicted/unverifiable）

2. **Stage 2: Soft Judge**
   - 对事实抽取结果进行质量评分
   - 评估准确性、完整性和证据质量

3. **Stage 3: Hard Judge**
   - 基于前两阶段结果做出接受/拒绝决策
   - 判断文档是否达到工程可接受标准

## 目录结构

```
wiki_judges/
├─ prompts/                 # 提示词模板
│  ├─ stage1_fact_extractor.txt
│  ├─ stage2_soft_judge.txt
│  └─ stage3_hard_judge.txt
├─ templates/              # promptfoo 配置模板
│  ├─ stage1.single.yaml
│  ├─ stage2.single.yaml
│  └─ stage3.single.yaml
├─ pipeline/               # 执行管道
│  ├─ run_pipeline.py      # 主执行脚本
│  └─ test_pipeline.py     # 测试执行脚本
├─ output/                 # 输出结果
│  ├─ stage1/             # 第一阶段输出
│  ├─ stage2/             # 第二阶段输出
│  └─ stage3/             # 第三阶段输出
├─ sample_data/            # 示例数据
│  ├─ src/                # 示例源代码
│  └─ wiki/               # 示例文档
└─ .tmp/                   # 临时配置文件
```

## 使用方法

### 安装依赖

```bash
npm install -g promptfoo
```

### 运行评估管道

```bash
cd D:\AI_Projects\promptfoo_wiki\wiki_judges
python pipeline/run_pipeline.py
```

### 测试运行

系统包含一个测试版本，可以在没有安装 promptfoo 的情况下验证代码逻辑：

```bash
cd D:\AI_Projects\promptfoo_wiki\wiki_judges
python pipeline/test_pipeline.py
```

## 特性

- ✅ 外层循环处理多个案例
- ✅ 每个 case 独立产物
- ✅ 每个 stage 一个独立 JSON
- ✅ stage1 → stage2 → stage3 串联
- ✅ 失败可重跑单文件
- ✅ 不把所有结果糊在一个 json 里
- ✅ 支持多种编程语言
- ✅ 可扩展的评估标准