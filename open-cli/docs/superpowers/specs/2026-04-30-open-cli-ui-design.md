# open-cli UI 2.0 设计方案

**日期:** 2026-04-30
**版本:** 0.1.0

## 概述

对 open-cli 的命令行界面进行全面改进，参考 gh、fzf、gemini-cli 等优秀 CLI 工具的最佳实践，打造一个功能丰富、用户体验优秀的 AI 编程助手。

## 目标

1. 增强提示符显示更多信息（目录、Git 分支、API 状态）
2. 支持 Markdown 渲染（代码高亮、表格、列表）
3. 添加键盘快捷键支持（vim/emacs 风格）
4. 实现交互式选择器
5. 添加分页和进度显示
6. 显示 API 状态栏

## 设计细节

### 1. 增强提示符 (Rich Prompt)

**目标效果:**
```
┌─[opencli]─[~/projects/open-cli]─[main]─❯
│ API: ●Connected  │  Tokens: 1,234  │  Session: a1b2c3d4
└──────────────────────────────────────────────────
>
```

**实现要点:**
- 顶部边框显示项目信息
- Git 分支名称
- API 连接状态指示器 (● Connected / ○ Disconnected)
- Token 使用量统计
- 当前会话 ID

**文件:** `cli.py` - 修改 `get_prompt()` 方法

### 2. Markdown 渲染

**目标效果:**
```
┌──────────────────────────────────────────────────┐
│ # 项目结构                                         │
│                                                   │
│ 文件     | 大小  | 说明                           │
│ -------- | ------ | ----                          │
│ cli.py   | 12KB  | 主入口                         │
│ core/    | <DIR> | 核心模块                       │
│                                                       │
│ ```python                                         │
│ def main():                                       │
│     print("hello")                                │
│ ```                                               │
└──────────────────────────────────────────────────┘
```

**实现要点:**
- 标题层级渲染
- 表格格式化
- 代码块语法高亮 (使用 Pygments)
- 链接高亮

**依赖:** `markdown`, `Pygments`

**文件:** 新建 `core/renderer.py`

### 3. 键盘快捷键

| 快捷键 | 功能 | 实现 |
|--------|------|------|
| `Ctrl+C` | 中断 AI 生成 | Signal handler |
| `Ctrl+L` | 清屏 | `os.system('cls'/'clear')` |
| `Ctrl+U` | 删除当前行 | readline |
| `Ctrl+R` | 搜索历史 | readline history |
| `↑/↓` | 浏览历史 | readline |
| `Tab` | 自动补全 | readline |

**文件:** `cli.py` - 修改 `run()` 方法

### 4. 交互式选择器

**目标效果:**
```
? 选择操作:
  ▸ ○ 读取文件
    ○ 写入文件
    ○ 执行命令
    ○ Git 操作

使用 ↑↓ 导航，Enter 确认，Ctrl+C 取消
```

**实现要点:**
- 使用 curses/blessed 实现
- 支持鼠标点击
- 模糊搜索过滤

**依赖:** `blessed` 或 `curses`

**文件:** 新建 `core/selector.py`

### 5. 分页和进度

**目标效果:**
```
$ 按空格下一页，q 退出

[--- 第 1/5 页 ---]
...内容...
```

**实现要点:**
- 长输出自动检测
- 集成 `less` 或内置分页
- 显示进度百分比

**文件:** 新建 `core/pager.py`

### 6. API 状态栏

**目标效果:**
```
┌──────────────────────────────────────────────────┐
│ ● Ready  │  ⏱ 0.3s  │  💬 1,234 tokens  │  💾 │
└──────────────────────────────────────────────────┘
```

**实现要点:**
- 底部状态栏
- 响应时间统计
- Token 计数
- 内存使用

**文件:** `cli.py` - 修改输出逻辑

## 技术架构

```
cli.py
├── RichPrompt      # 增强提示符
├── MarkdownRenderer # Markdown 渲染
├── KeyBindings     # 键盘快捷键
├── InteractiveSelector # 交互式选择
├── Pager           # 分页器
└── StatusBar       # 状态栏
```

## 依赖

```toml
# pyproject.toml
dependencies = [
    "anthropic>=0.25.0",
    "pyyaml>=6.0",
    "markdown>=3.0",
    "Pygments>=2.0",
    "blessed>=1.0",  # 跨平台终端UI
]
```

## 实施顺序

1. **Phase 1: 基础增强** (1天)
   - 增强提示符
   - 键盘快捷键 (Ctrl+C, Ctrl+L)
   - 简单 Markdown 渲染

2. **Phase 2: 交互增强** (1天)
   - 交互式选择器
   - 历史搜索 (Ctrl+R)
   - 分页器

3. **Phase 3: 状态和优化** (0.5天)
   - API 状态栏
   - Token 统计
   - 代码高亮优化

## 兼容性

- Python 3.8+
- Windows (PowerShell/cmd)
- macOS (Terminal)
- Linux (xterm)

## 风险和缓解

| 风险 | 缓解 |
|------|------|
| blessed 依赖复杂 | 可以回退到纯 readline 实现 |
| Windows 编码问题 | 继续使用现有的编码处理方案 |
| 性能影响 | 渲染使用增量更新 |

## 成功标准

1. 所有键盘快捷键正常工作
2. Markdown 渲染正确显示
3. 分页功能可用
4. 状态栏显示准确
5. 向后兼容非交互模式
6. 测试覆盖率 > 80%
