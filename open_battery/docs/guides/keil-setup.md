# Keil uVision 环境搭建

## 简介

Keil uVision 是 8051/ARM 微控制器的专用开发 IDE，本项目用它编译 SH68F06 固件。**仅支持 Windows**，Mac 需通过虚拟机运行。

## Mac 环境方案

### 推荐方案：Parallels Desktop + Windows

```bash
# 安装 Parallels Desktop (付费，性能最好，USB 直通烧录)
# 或 VMware Fusion / VirtualBox (免费)
# 在虚拟机中安装 Windows 10/11 + Keil uVision
```

### 推荐工作流

```
Mac (VS Code + Arduino 模拟器)  ←代码/HEX→  Windows VM (Keil 编译烧录)
```

Mac 上编辑代码和调试 IIC，Windows 虚拟机中编译和烧录。

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| F7 | 编译项目 |
| Ctrl+F7 | 编译当前文件 |
| F5 | 开始调试 |
| F9 | 设置/取消断点 |
| F10 | 单步跳过 |
| F11 | 单步进入 |

## 项目组织最佳实践

### 推荐目录结构

```
project/
├── prj/
│   ├── test_tmr1.uvproj       # Keil 工程文件
│   └── Output/                 # 编译产物统一放这里
├── src/                        # 应用代码
├── drivers/                    # 自写驱动
├── vendor/                     # 厂商库（本地化，不引用外部路径）
└── include/                    # 公共头文件
```

### 关键原则

| 原则 | 说明 |
|------|------|
| **自包含** | 所有源文件在项目目录内，不依赖外部路径 |
| **编译产物隔离** | hex/lst/map 统一放 `Output/` |
| **厂商库本地化** | 拷贝到项目内，不引用外部目录 |
| **代码分离** | 你的代码和厂商代码分开，便于升级 |

### 输出目录设置

```
Options for Target → Output → Select Folder for Objects → ./Output
Options for Target → Listing → Select Folder for Listing Files → ./Output
```

### 本项目现状

| 问题 | 改进 |
|------|------|
| 72 个 hex 堆在 prj/ | 设置输出到 `prj/Output/`，清理旧文件 |
| 厂商库外部引用已断链 | 拷贝到 `vendor/` 下，Keil 中重新引用 |
| 缺少 .gitignore | 添加下方模板 |

## .gitignore 模板

```gitignore
# Keil 编译产物
*.hex
*.lst
*.map
*.obj
*.o
*.d
*.axf
*.i
*.crf
*.dep
*.bak
__Previews/
Output/
RTE/
```

## 常见问题

| 问题 | 解决方法 |
|------|---------|
| 编译出错 | 检查编译器路径、头文件包含路径、芯片选择 |
| 烧录失败 | 确认烧录器驱动和 USB 连接 |
| 外部路径断链 | 厂商库拷贝到项目内，重新添加文件引用 |
| hex 文件堆积 | 设置 Output 目录，定期清理 |
