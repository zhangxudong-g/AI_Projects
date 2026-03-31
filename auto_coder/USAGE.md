# AutoCoder 使用指南

## 最快速的使用方式

### 1. 交互式生成（推荐）

```bash
cd D:\AI_Projects\auto_coder
python run_interactive.py
```

然后输入你的代码需求，例如：
- "创建一个 Hello World 程序"
- "生成一个 Python 计算器"
- "创建一个 FastAPI 用户管理 API"

### 2. 命令行工具

```bash
# 进入交互模式
python cli.py

# 或直接生成
python cli.py "创建一个 Flask Hello World 应用"

# 使用更快的模型
python cli.py "生成快速排序算法" --model smollm2:135m

# 使用更强的模型
python cli.py "设计一个完整的电商 API" --model nemotron-3-super:120b
```

### 3. API 服务

```bash
# 启动服务
python -m uvicorn app.main:app --reload --port 8001

# 在另一个终端测试
curl http://localhost:8001/health
```

## 可用模型

你的 Ollama 服务器 (http://133.238.28.90:51434) 提供以下模型：

| 模型 | 大小 | 速度 | 质量 | 适用场景 |
|------|------|------|------|----------|
| **smollm2:135m** | 0.25GB | ⚡⚡⚡ | ⭐⭐ | 快速测试、简单任务 |
| **gpt-oss:20b** | 12.85GB | ⚡⚡ | ⭐⭐⭐ | 日常编码 |
| **qwen3:32b** | 18.81GB | ⚡⚡ | ⭐⭐⭐⭐ | 复杂代码生成 |
| **qwen2.5vl:32b** | 19.71GB | ⚡⚡ | ⭐⭐⭐⭐ | 多模态任务 |
| **qwen3.5:122b-a10b** | 75.78GB | ⚡ | ⭐⭐⭐⭐⭐ | 高质量代码 |
| **nemotron-3-super:120b** | 80.86GB | ⚡ | ⭐⭐⭐⭐⭐ | 最佳质量（默认） |

## 使用示例

### 示例 1: 生成简单程序

```bash
python cli.py "用 Python 写一个猜数字游戏，包含随机数和用户输入"
```

### 示例 2: 生成 Web 应用

```bash
python cli.py "创建一个 Flask 博客系统，包含用户注册、登录、发布文章功能"
```

### 示例 3: 生成数据处理代码

```bash
python cli.py "用 pandas 分析 CSV 文件，统计销售数据并生成图表"
```

### 示例 4: 生成算法代码

```bash
python cli.py "实现二分查找、快速排序、归并排序，包含测试用例"
```

## 查看生成的文件

生成的文件保存在 `workspace/` 目录。

```bash
# 查看文件列表
python cli.py files

# 或在交互式中查看
python run_interactive.py
# 然后输入：files
```

## 常见问题

### Q: 生成速度慢怎么办？

A: 使用较小的模型：
```bash
python cli.py "你的需求" --model smollm2:135m
```

### Q: 生成失败怎么办？

A: 
1. 检查 Ollama 服务器是否运行：`curl http://133.238.28.90:51434/api/tags`
2. 尝试更简单的需求描述
3. 使用更强大的模型

### Q: 如何修改生成的代码？

A: 生成的文件在 `workspace/` 目录，可以直接用编辑器修改。

### Q: 可以连续生成多个文件吗？

A: 可以！使用交互模式：
```bash
python run_interactive.py
# 输入第一个需求
# 然后输入第二个需求
# ...
```

## 最佳实践

1. **需求描述要具体**
   - ❌ "写个网站"
   - ✅ "创建 Flask 用户管理系统，包含注册、登录、修改密码功能"

2. **分步生成复杂项目**
   - 先生成基础结构
   - 然后逐个功能生成

3. **选择合适的模型**
   - 简单任务：smollm2:135m
   - 日常编码：qwen3:32b
   - 复杂项目：nemotron-3-super:120b

4. **检查生成的代码**
   - 代码生成后务必审查
   - 运行测试确保正确

## 下一步

- 查看完整文档：`README.md`
- 查看示例测试：`tests/test_example_generation.py`
- 自定义配置：编辑 `.env` 文件
