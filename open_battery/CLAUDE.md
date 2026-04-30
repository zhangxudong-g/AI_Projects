# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

mini-Lite 移动电源固件项目，包含两个主要组件：

1. **Arduino IIC 模拟器** (`arduino_iic_simulator/`) - 模拟 SW6301/SW6303 芯片，供开发调试
2. **目标固件** (`demo/TMR1_111/`) - SH68F06 微控制器的实际固件

## 芯片架构

| 芯片 | 功能 | IIC 地址 |
|------|------|----------|
| SW6301 | 升压输出IC (Boost) | 0x14B |
| SW6303 | 充电管理IC (Charger) | 0x23 |
| SH68F06 | 主控MCU (8051内核) | - |

## 开发工具

- **模拟器开发**: Arduino IDE (打开 `arduino_iic_simulator.ino`)
- **固件开发**: Keil uVision (项目文件: `test_tmr1.uvproj`)
- **代码操作**: Serena (C++ 语言服务器，配置于 `.serena/`)

## 固件结构 (demo/)

```
TMR1_111/                          # 主固件
  src/
    main.c/h    - 主应用逻辑、IO初始化
    int.c       - 中断处理

  prj/
    IIC.c/h     - IIC通信驱动（含SW6301/SW6303操作）
    LED.c/h     - LED指示控制
    KEY.c/h     - 按键输入
    sys.c/h     - 系统函数
    sleep.c     - 功耗管理

user_com/                          # 通信模块（被主固件引用）
  user_com.c/h - 用户通信功能
  ↑ 被 main.c, int.c, sys.c 引用

.serena/                           # Serena 代码分析配置
  project.yml   - 项目配置
```

**依赖关系**：
- `user_com` 虽然目录独立，但被主固件代码引用
- 引用位置：`src/main.c`, `src/int.c`, `prj/sys.c`
- 可能是厂商提供的标准通信库，便于代码复用

### Pin 定义

| 功能 | Pin | 说明 |
|------|-----|------|
| LED1 | P16 | 电量指示1 |
| LED2 | P15 | 电量指示2 |
| LED3 | P14 | 电量指示3 |
| LED4 | P13 | 电量指示4 |
| DC_EN | P11 | 升压使能 |
| SDA | P10 | IIC数据 |
| SCL | P07 | IIC时钟 |
| 按键 | P00 | 电源按键 |

### LED 电量指示

| 电量范围 | LED1 | LED2 | LED3 | LED4 |
|---------|------|------|------|------|
| < 6.2V | 闪烁 | 0 | 0 | 0 |
| 6.2-6.6V | 1 | 0 | 0 | 0 |
| 6.6-7.2V | 1 | 1 | 0 | 0 |
| 7.2-7.8V | 1 | 1 | 1 | 0 |
| > 7.8V | 1 | 1 | 1 | 1 |

### 工作模式

- **充电模式**：插入输入电源时进入，LED 显示充电状态
- **放电模式**：按键触发或负载插入时进入，升压输出
- **睡眠模式**：低电量或无操作时进入，降低功耗
- **保护模式**：过温、过流、欠压时触发

## 寄存器定义 (SW6301)

| 地址 | 名称 | 说明 |
|------|------|------|
| 0x02 | OUTPUT_VOL | 输出电压 (0x4B=5V, 0x6B=9V, 0x7B=12V) |
| 0x03 | OUTPUT_CUR | 输出电流 (值×100mA) |
| 0x04 | STATUS | 状态寄存器 |

## 寄存器定义 (SW6303)

| 地址 | 名称 | 说明 |
|------|------|------|
| 0x20 | INPUT_VOL | 输入电压 (bit0=1 则为12.6V) |
| 0x21 | CHG_CUR | 充电电流 |
| 0x22 | STATUS | 充电状态 (0x01=充电中) |

## 构建命令

- **Arduino 模拟器**: 使用 Arduino IDE 上传
- **固件编译**: Keil uVision 中打开 `test_tmr1.uvproj` 并编译
- **Serena**: 项目已配置 CPP 语言服务器，可直接使用语义代码操作

## 硬件连接 (模拟器)

```
SH68F06 SDA ──► Arduino A4 (SDA)
SH68F06 SCL ──► Arduino A5 (SCL)
SH68F06 GND ──► Arduino GND
```

## 串口监控

- 波特率: 115200
- 命令: `help`, `status`, `stats`, `set <芯片> <寄存器> <值>`, `sim <事件>`

## 编码说明

- 大部分源文件使用 UTF-8 编码
- `main.h` 等部分文件使用 ISO-8859 编码（含中文注释）
- 编辑时注意保持原有编码，避免乱码

## 构建与调试流程

### Arduino 模拟器
```bash
# 1. 打开 Arduino IDE
# 2. 加载 arduino_iic_simulator/arduino_iic_simulator.ino
# 3. 选择开发板：Arduino Uno/Nano
# 4. 上传到 Arduino
# 5. 打开串口监视器 (115200 baud)
```

### 固件编译
```bash
# 1. 打开 Keil uVision
# 2. 加载项目: demo/TMR1_111/prj/test_tmr1.uvproj
# 3. 编译 (F7)
# 4. 输出 HEX 文件在 prj/ 目录
```

### Serena 代码操作
- 项目已激活 Serena，配置为 C++ 语言服务器
- 可使用语义搜索、符号查找等功能
- 配置文件：`demo/.serena/project.yml`

## IIC 通信说明

- SW6301 使用 10 位地址 (0x14B)，7 位格式为 0x0A
- SW6303 使用 7 位地址 (0x23)
- 软件模拟 IIC，通过 SDA/SCL GPIO 实现
- 通信函数：`IIC_Start()`, `IIC_Stop()`, `SendByte()`, `RcvByte()`

## 调试技巧

- 使用 Arduino 模拟器观察 IIC 通信
- 通过串口命令 `stats` 查看读写次数
- 使用 `sim overtemp` 等命令模拟异常情况
- Keil 仿真器可单步调试 SH68F06 固件

## 项目文档

详细文档位于 `docs/` 目录：

- **目录结构说明.md** - 完整的项目目录结构详解
- **Keil_uVision说明.md** - Keil uVision 开发工具使用指南
- **mini-Lite_开发指南.md** - Arduino 模拟器使用指南

## C51 编程规范

### 位操作
- SH68F06 是 8051 内核，支持强大的位操作功能
- 使用 `sbit` 定义位变量：`sbit LED1 = P1^6;`
- 位寻址区：20H-2FH（128位），支持直接位操作
- 常用位操作：`P1 |= 0x01;` (置位), `P1 &= ~0x01;` (复位)

### 中断处理
- 中断向量表位于 `03H` (INT0), `0BH` (T0), `1BH` (T1) 等
- 中断服务函数声明：`void INT0_Isr(void) interrupt 0`
- 中断优先级通过 IP 寄存器配置
- 注意中断现场保护和恢复（ACC、PSW 等）

### IIC 软件模拟时序

#### 时序参数
- SCL 频率：标准模式 100kHz，快速模式 400kHz
- 起始条件建立时间：tSU;STA ≥ 4.7µs (标准模式)
- 停止条件建立时间：tSU;STO ≥ 4.0µs (标准模式)
- 数据保持时间：tHD;DAT ≥ 0µs
- 数据建立时间：tSU;DAT ≥ 250ns

#### 通信函数
```c
void IIC_Start(void);   // 发送起始信号
void IIC_Stop(void);    // 发送停止信号
void SendByte(u8 dat);  // 发送一字节
u8 RcvByte(void);       // 接收一字节
```

#### 常见问题
- SW6301 使用 10 位地址（0x14B），需特殊处理
- 确保上拉电阻：SDA/SCL 需 4.7kΩ 上拉到 VCC
- 等待应答超时：发送后需检查 ACK，避免死循环

## 自我改进记录

- 2026-04-22: 添加 C51 编程规范和 IIC 时序参数
- 待办：初始化 Git 仓库进行版本控制

## 自我改进建议 (2026-04-22 复盘)

### 待办事项
- [ ] **S1**: 初始化 Git 仓库 - `git init` 并创建合适的 .gitignore
- [ ] **S2**: 创建项目记忆目录结构
- [ ] **I1**: 添加单元测试框架文档（Unity/CppUTest 针对嵌入式）
- [ ] **I2**: 创建故障排查指南章节
- [ ] **I3**: 添加硬件版本跟踪信息表

### 下次复盘重点
1. 验证 Git 仓库是否已初始化
2. 检查是否添加了测试相关文档
3. 评估故障排查指南的完整性
