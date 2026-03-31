# AI Projects

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![Flutter 3.x](https://img.shields.io/badge/flutter-3.x-blue.svg)](https://flutter.dev)

🤖 **AI 驱动的项目集合** - 包含自动代码生成、智能聊天、事实判断等多个 AI 应用

---

## 📁 项目目录

- **[AutoCoder](#autocoder)** - 自动写代码的 DeepAgents 系统
- **[AI Chat App](#ai-chat-app)** - Flutter 跨平台 AI 聊天应用
- **[Wiki Fact Judge](#wiki-fact-judge)** - 维基百科事实判断系统

---

## 🚀 AutoCoder - 自动代码生成系统

**基于 LangChain + LangGraph 的多 Agent 代码生成系统**

### ✨ 特性

- 🤖 **多 Agent 协作**: Planner/Coder/Tester/Fixer 四个 Agent 协同工作
- 🔄 **自动错误修复**: 运行测试并自动修复代码错误
- 📝 **流式输出**: 支持 SSE 实时显示执行过程
- 🔧 **模型可替换**: 支持 OpenAI / Ollama 等多种模型
- 🛡️ **安全执行**: 命令白名单 + 文件沙盒机制

### 🛠️ 技术栈

- **后端**: FastAPI + Python 3.11+
- **Agent 框架**: LangChain + LangGraph
- **模型**: Ollama (nemotron-3-super:120b 等)

### 📦 快速开始

```bash
# 安装依赖
cd auto_coder
pip install -r requirements.txt

# 交互式使用（推荐）
python run_interactive.py

# 或命令行生成
python cli.py "创建一个 Flask Hello World 应用"

# 或启动 API 服务
python -m uvicorn app.main:app --port 8001
```

### 📖 使用示例

```bash
# 生成简单程序
python cli.py "用 Python 写一个猜数字游戏"

# 生成 Web 应用
python cli.py "创建 Flask 用户管理系统"

# 使用更快的模型
python cli.py "生成排序算法" --model smollm2:135m
```

### 📂 项目结构

```
auto_coder/
├── app/
│   ├── agents/      # 多 Agent 实现
│   ├── api/         # FastAPI 接口
│   ├── core/        # DeepAgent 核心
│   ├── tools/       # 工具系统
│   └── memory/      # 记忆存储
├── workspace/       # 生成的代码
├── cli.py           # 命令行工具
└── run_interactive.py # 交互式脚本
```

📖 [详细文档](auto_coder/README.md)

---

## 📱 AI Chat App - Flutter 聊天应用

**跨平台 AI 聊天应用，支持 Web/Android/iOS**

### ✨ 特性

- 🌍 **跨平台**: 一套代码，多端运行
- 💬 **AI 对话**: 集成多种 AI 模型
- 🎨 **Material 3**: 现代化 UI 设计
- 📦 **完整配置**: Android/Web 平台完整支持

### 🛠️ 技术栈

- **框架**: Flutter 3.x + Dart
- **UI**: Material Design 3
- **平台**: Web, Android, iOS

### 📦 快速开始

```bash
# 安装依赖
cd ai_chat_app
flutter pub get

# 运行 Web 版
flutter run -d chrome

# 运行 Android 版
flutter run -d android

# 或使用启动脚本
start.bat  # Windows
./start.sh # Linux/Mac
```

### 📂 项目结构

```
ai_chat_app/
├── lib/           # Dart 源代码
├── android/       # Android 配置
├── web/           # Web 配置
├── pubspec.yaml   # 项目配置
└── README.md      # 详细说明
```

📖 [详细文档](ai_chat_app/README.md)

---

## 🔍 Wiki Fact Judge - 事实判断系统

**基于维基百科的事实判断与验证系统**

### ✨ 特性

- 📊 **事实验证**: 自动验证陈述的真实性
- 🔗 **维基集成**: 与维基百科 API 深度集成
- 📈 **数据分析**: 支持批量数据处理和分析
- 🎯 **标签过滤**: 智能标签分类和过滤

### 🛠️ 技术栈

- **后端**: FastAPI + Python
- **前端**: TypeScript + React
- **数据**: 维基百科 API

### 📦 快速开始

```bash
# 安装依赖
cd wiki_fact_judge
pip install -r requirements.txt

# 启动服务
python start.py

# 或使用批处理
start.bat  # Windows
./start.sh # Linux/Mac
```

### 📂 项目结构

```
wiki_fact_judge/
├── backend/       # FastAPI 后端
├── frontend/      # React 前端
├── cli/           # 命令行工具
└── start.py       # 启动脚本
```

📖 [详细文档](wiki_fact_judge/README.md)

---

## 🌟 共同特性

### 🔧 统一工具

所有项目都包含：
- ✅ 完整的启动脚本（`.bat` / `.sh` / `.py`）
- ✅ 详细的使用文档
- ✅ 测试用例
- ✅ 环境配置示例

### 📚 文档

每个项目都包含：
- `README.md` - 项目说明
- `QUICKSTART.md` - 快速开始指南
- `USAGE.md` - 使用手册

---

## 🚀 快速导航

| 项目 | 语言 | 框架 | 状态 |
|------|------|------|------|
| [AutoCoder](auto_coder/) | Python | FastAPI + LangChain | ✅ 活跃开发 |
| [AI Chat App](ai_chat_app/) | Dart | Flutter | ✅ 活跃开发 |
| [Wiki Fact Judge](wiki_fact_judge/) | Python/TS | FastAPI + React | ✅ 活跃开发 |

---

## 📋 环境要求

### 通用要求

- Python 3.11+
- Git
- 稳定的网络连接

### 项目特定要求

**AutoCoder**
```bash
pip install -r auto_coder/requirements.txt
```

**AI Chat App**
```bash
flutter doctor  # 检查 Flutter 环境
flutter pub get
```

**Wiki Fact Judge**
```bash
pip install -r wiki_fact_judge/requirements.txt
```

---

## 🤝 贡献

欢迎贡献代码、报告问题或提出建议！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

---

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

---

## 📞 联系方式

- 📧 Email: your.email@example.com
- 💼 GitHub: [@zhangxudong-g](https://github.com/zhangxudong-g)
- 🌐 项目主页: https://github.com/zhangxudong-g/AI_Projects

---

## 🙏 致谢

感谢以下开源项目：

- [LangChain](https://github.com/langchain-ai/langchain)
- [LangGraph](https://github.com/langchain-ai/langgraph)
- [FastAPI](https://github.com/tiangolo/fastapi)
- [Flutter](https://github.com/flutter/flutter)
- [Ollama](https://github.com/ollama/ollama)

---

<div align="center">

**如果这个项目对你有帮助，请给一个 ⭐️ Star！**

Made with ❤️ by AI Projects Team

</div>
