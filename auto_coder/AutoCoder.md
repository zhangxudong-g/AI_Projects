你是一个资深软件工程师 + AI Agent 架构专家。

目标：构建一个“自动写代码的 DeepAgents 系统”，具备以下能力：

* 根据用户需求自动生成完整代码项目
* 支持多文件创建、修改、重构
* 支持运行代码并自动修复错误
* 支持任务拆解（Planner）
* 支持执行（Executor）
* 支持测试（Tester）
* 支持修复（Fixer）

技术要求：

* 后端：FastAPI
* Agent框架：LangChain + LangGraph + DeepAgents
* 支持流式输出（SSE）
* 模型可替换（OpenAI / Ollama）
* 使用 Python 3.11+

项目结构要求：

```
auto_coder/
├── app/
│   ├── main.py
│   ├── api/
│   │   └── agent.py
│   ├── agents/
│   │   ├── planner.py
│   │   ├── coder.py
│   │   ├── tester.py
│   │   └── fixer.py
│   ├── tools/
│   │   ├── file_tools.py
│   │   ├── shell_tools.py
│   │   └── git_tools.py
│   ├── core/
│   │   ├── deep_agent.py
│   │   └── graph.py
│   └── memory/
│       └── memory_store.py
├── workspace/
├── tests/
├── requirements.txt
└── README.md
```

功能要求：

1. DeepAgents核心：

* 实现 create_deep_agent 封装
* 支持长任务执行（多轮循环）
* 支持任务拆解（Planner）

2. 多Agent设计：

* Planner Agent：拆解任务
* Coder Agent：生成代码
* Tester Agent：运行测试
* Fixer Agent：修复错误

3. 工具系统：
   必须实现以下 tools：

* write_file(path, content)
* read_file(path)
* list_files(path)
* run_command(cmd)
* apply_patch(diff)

4. 执行流程：
   用户输入需求 →
   Planner拆任务 →
   Coder写代码 →
   Tester运行 →
   Fixer修复 →
   循环直到完成

5. FastAPI接口：

* POST /generate_code
* 支持流式返回执行过程
* 返回最终代码结果

6. Memory：

* 保存生成文件列表
* 保存错误日志
* 保存执行历史

7. 关键要求：

* 所有代码必须可运行
* 必须包含完整依赖
* 必须包含README（运行说明）
* 必须包含示例请求

输出要求：

* 一次性生成完整项目代码
* 每个文件完整内容
* 不要省略实现
* 不要写伪代码
* 保证可以直接运行

增强要求：

1. 代码必须遵循以下规范：

* 分层清晰（api / agents / tools / core）
* 使用类型注解（typing）
* 使用 Pydantic 定义数据结构

2. Agent必须具备：

* 可中断执行
* 错误重试机制
* 最大循环次数限制（防止死循环）

3. Tool调用必须安全：

* 禁止执行危险shell命令
* 文件操作限制在 workspace 目录

4. 日志系统：

* 输出每一步执行日志
* 支持调试模式

5. 可扩展性：

* 预留支持 Docker 执行环境
* 预留支持多模型切换

6. 测试：

* 至少包含一个完整测试用例
* 示例：生成一个 FastAPI CRUD 项目

请基于以上增强要求优化代码质量。


开始生成项目。
