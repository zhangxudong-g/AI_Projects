# AI Chat App

基于 Flutter + Riverpod 开发的 AI 对话应用，支持 Ollama 本地部署的 AI 模型。

## 功能特性

### 1. AI 对话
- ✅ 流式输出（逐字显示）
- ✅ Markdown 渲染
- ✅ 代码高亮
- ✅ 一键复制消息

### 2. 文档生成
- ✅ 多种文档类型（文章、报告、邮件、代码、诗歌等）
- ✅ 自定义生成要求
- ✅ 实时预览

### 3. 历史记录
- ✅ 对话历史列表
- ✅ 按日期分组
- ✅ 搜索功能
- ✅ 删除对话

### 4. 用户登录
- ✅ 登录/登出
- ✅ 用户信息展示

### 5. 设置
- ✅ 模型选择
- ✅ API 地址配置
- ✅ 流式输出开关
- ✅ 深色模式

## 技术栈

- **框架**: Flutter 3.x
- **状态管理**: Riverpod 2.x
- **HTTP 客户端**: http / dio
- **Markdown 渲染**: flutter_markdown
- **代码高亮**: highlight
- **本地存储**: shared_preferences

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── models/
│   └── message.dart          # 数据模型（消息、对话、用户）
├── services/
│   ├── chat_service.dart     # AI API 服务
│   └── auth_service.dart     # 认证服务
├── providers/
│   └── chat_provider.dart    # Riverpod 状态管理
├── screens/
│   ├── login_page.dart       # 登录页
│   ├── main_page.dart        # 主页面（底部导航）
│   ├── chat_page.dart        # 对话页
│   ├── document_page.dart    # 文档生成页
│   ├── history_page.dart     # 历史记录页
│   └── setting_page.dart     # 设置页
├── widgets/
│   └── message_bubble.dart   # 消息气泡组件
└── utils/
    └── api_config.dart       # API 配置
```

## API 配置

默认 Ollama API 地址：
```
http://133.238.28.90:51434
```

API 端点：
- `POST /api/chat` - 聊天
- `POST /api/generate` - 文档生成
- `GET /api/history` - 获取历史
- `GET /api/tags` - 获取模型列表

## 运行项目

### Windows

双击运行：
```
run_chrome.bat
```

或在 PowerShell 中：
```powershell
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
flutter run -d chrome
```

### 其他平台

```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run -d chrome

# 或运行 Android 版
flutter run

# 或运行 Windows 版
flutter run -d windows
```

## 消息结构

### UserMessage
```dart
{
  "id": "消息 ID",
  "content": "消息内容",
  "timestamp": "时间戳",
  "role": "user"
}
```

### AssistantMessage
```dart
{
  "id": "消息 ID",
  "content": "消息内容",
  "timestamp": "时间戳",
  "role": "assistant",
  "isStreaming": false
}
```

## ChatController 方法

- `sendMessage(String content)` - 发送消息（非流式）
- `streamMessage(String content)` - 发送消息（流式）
- `cancelMessage()` - 取消流式消息
- `clearConversation()` - 清除对话
- `loadModels()` - 加载可用模型

## License

MIT License
