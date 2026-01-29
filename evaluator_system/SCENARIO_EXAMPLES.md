# V1 评测系统 - 场景示例

## 场景1：高质量Wiki（通过评测）

### facts.json
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

### wiki.json
```json
{
  "method": "changeHogosyaJoho",
  "claims": [
    { "text": "调用AuthService.checkPermission", "fact_refs": ["calls:AuthService.checkPermission"] },
    { "text": "调用HogosyaService.update", "fact_refs": ["calls:HogosyaService.update"] },
    { "text": "写入HogosyaEntity实体", "fact_refs": ["writes:HogosyaEntity"] },
    { "text": "使用@Transactional注解", "fact_refs": ["annotations:@Transactional"] },
    { "text": "当hogosyaId不为null时执行", "fact_refs": ["conditions:hogosyaId != null"] }
  ]
}
```

### 评测结果
```json
{
  "metrics": {
    "faithfulness": 1.0,
    "hallucination_rate": 0.0,
    "key_fact_recall": 1.0,
    "redundancy_rate": 0.0
  },
  "violations": [],
  "pass": true
}
```

## 场景2：包含幻觉的Wiki（评测失败）

### wiki_with_hallucination.json
```json
{
  "method": "changeHogosyaJoho",
  "claims": [
    { "text": "调用AuthService.checkPermission", "fact_refs": ["calls:AuthService.checkPermission"] },
    { "text": "确保数据安全性", "fact_refs": [] },
    { "text": "提升系统整体性能", "fact_refs": [] },
    { "text": "写入HogosyaEntity实体", "fact_refs": ["writes:HogosyaEntity"] }
  ]
}
```

### 评测结果
```json
{
  "metrics": {
    "faithfulness": 0.5,
    "hallucination_rate": 0.5,
    "key_fact_recall": 0.5,
    "redundancy_rate": 0.0
  },
  "violations": [
    {
      "claim": "确保数据安全性",
      "reason": "Claim缺少fact_ref",
      "violation_type": "missing_fact"
    },
    {
      "claim": "确保数据安全性",
      "reason": "检测到越权推断关键词: 确保",
      "violation_type": "over_inference"
    },
    {
      "claim": "提升系统整体性能",
      "reason": "Claim缺少fact_ref",
      "violation_type": "missing_fact"
    },
    {
      "claim": "提升系统整体性能",
      "reason": "检测到越权推断关键词: 提升性能",
      "violation_type": "over_inference"
    }
  ],
  "pass": false
}
```

## 场景3：语义不对齐的Wiki（评测失败）

### wiki_with_semantic_mismatch.json
```json
{
  "method": "changeHogosyaJoho",
  "claims": [
    { "text": "声明AuthService.checkPermission", "fact_refs": ["calls:AuthService.checkPermission"] },  // 语义不对齐
    { "text": "读取HogosyaEntity实体", "fact_refs": ["writes:HogosyaEntity"] }  // 语义不对齐
  ]
}
```

### 评测结果
```json
{
  "metrics": {
    "faithfulness": 0.0,
    "hallucination_rate": 0.0,
    "key_fact_recall": 0.5,
    "redundancy_rate": 0.0
  },
  "violations": [
    {
      "claim": "声明AuthService.checkPermission",
      "reason": "语义不对齐: calls 类型应包含对应语义词汇",
      "violation_type": "missing_fact"
    },
    {
      "claim": "读取HogosyaEntity实体",
      "reason": "语义不对齐: writes 类型应包含对应语义词汇",
      "violation_type": "missing_fact"
    }
  ],
  "pass": false
}
```

## 场景4：部分覆盖的Wiki（可能通过，取决于阈值）

### wiki_partial_coverage.json
```json
{
  "method": "changeHogosyaJoho",
  "claims": [
    { "text": "调用AuthService.checkPermission", "fact_refs": ["calls:AuthService.checkPermission"] }
  ]
}
```

### 评测结果（默认阈值下失败）
```json
{
  "metrics": {
    "faithfulness": 1.0,
    "hallucination_rate": 0.0,
    "key_fact_recall": 0.25,  // 只覆盖了4个关键事实中的1个
    "redundancy_rate": 0.0
  },
  "violations": [],
  "pass": false  // 因为key_fact_recall < 0.85阈值
}
```

## 场景5：包含冗余内容的Wiki

### wiki_with_redundancy.json
```json
{
  "method": "changeHogosyaJoho",
  "claims": [
    { "text": "调用AuthService.checkPermission", "fact_refs": ["calls:AuthService.checkPermission"] },
    { "text": "很好", "fact_refs": [] },
    { "text": "aaaaa", "fact_refs": [] }
  ]
}
```

### 评测结果
```json
{
  "metrics": {
    "faithfulness": 0.33,
    "hallucination_rate": 0.0,
    "key_fact_recall": 0.25,
    "redundancy_rate": 0.67
  },
  "violations": [
    {
      "claim": "很好",
      "reason": "文本过短且无事实引用，可能是冗余内容",
      "violation_type": "redundancy"
    },
    {
      "claim": "aaaaa",
      "reason": "文本字符种类过少，可能是冗余内容",
      "violation_type": "redundancy"
    }
  ],
  "pass": false
}
```

## 总结

V1 评测系统能够有效识别以下问题：
1. 缺少事实引用
2. 越权推断（使用禁止词汇）
3. 语义不对齐
4. 关键事实覆盖不足
5. 冗余内容

通过这些评测，可以确保Wiki文档忠实转述源码中的事实，避免幻觉和错误信息的产生。