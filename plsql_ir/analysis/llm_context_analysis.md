# PLSQL Extractor - LLM上下文分析

## 分析背景

目标: 测试 samples/ 中的SQL文件提取后生成JSON，评估JSON+提示词 给LLM生成wiki是否会超出上下文或超慢。

## 测试环境

- LLM: ollama+gpt-oss:120b
- max_tokens: 40960

## 样本文件大小分析

### 原始SQL文件 (Top 5)

| 文件 | 大小 | 估算Tokens |
|-----|------|-----------|
| ZLBSKCALMAIN.SQL | 453.6KB | ~348,375 |
| ZLBSKCALMSIN.SQL | 419.8KB | ~322,378 |
| ZLBSKCALPACK.SQL | 385.2KB | ~295,804 |
| ZLBSKCALMKDM.SQL | 372.7KB | ~286,236 |
| ZLBSKCALMKAI.SQL | 346.7KB | ~266,258 |

**所有大文件都远超max_tokens限制**

### 提取后JSON (完整版)

| 文件 | 大小 | 估算Tokens | 状态 |
|-----|------|-----------|------|
| ZLBSKCALKWFUTU.SQL.json | 70.6KB | ~54,254 | ❌ 超限 |

### 精简版JSON (优化后)

| 文件 | 大小 | 估算Tokens | 状态 |
|-----|------|-----------|------|
| ZLBSKCALKWFUTU_light.json | 5.6KB | ~4,171 | ✅ OK |

**压缩率: 92%**

## 精简版JSON结构

```json
{
  "identifier": {"name": "...", "type": "..."},
  "parameters": [...],        // 限前10个
  "constants": [...],          // 限20个  
  "variables": [...],         // 限30个
  "sql_summary": {
    "SELECT_count": N,
    "INSERT_count": M,
    "UPDATE_count": X,
    "DELETE_count": Y
  },
  "cursors": {...},
  "execution_flow": "...",    // 限200字符
  "exception_handling": {...}
}
```

## LLM处理估算

### 完整JSON (不可行)
- JSON: ~54,000 tokens
- Prompt: ~500 tokens
- **总计: ~54,500 tokens** ❌ 超限 (40,960)

### 精简JSON (可行)
- JSON: ~4,200 tokens  
- Prompt: ~500 tokens
- **总计: ~4,700 tokens** ✅ OK

### 处理速度
- 完整JSON: 超慢/超时
- 精简JSON: **几秒内完成** ✅

## 实施建议

### 1. 文件大小判断
- **小文件** (<30KB): 使用完整JSON
- **大文件** (≥30KB): 使用精简JSON
- **超大文件** (≥100KB): 按内部子程序chunk处理

### 2. 精简策略
- parameters: 保留前10个
- constants: 保留前20个
- variables: 保留前30个
- SQL: 只保留数量统计，不保留完整语句
- execution_flow: 截断至200字符

### 3. 输出文件命名
- 完整版: `filename.SQL.json`
- 精简版: `filename.SQL_light.json`

### 4. 后续优化方向
- 分块处理大文件的子程序/函数
- 流式处理避免内存溢出
- 按需提取(只提取wiki需要的字段)

## 结论

✅ 使用精简JSON方案可以：
1. 避免超出max_tokens限制
2. 大幅提升LLM处理速度
3. 保留核心业务信息供wiki生成使用
