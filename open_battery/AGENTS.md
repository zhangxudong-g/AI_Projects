# open_battery

mini-Lite 移动电源固件项目 (SH68F06 8051内核)。

## 项目结构

| 目录 | 用途 |
|------|------|
| `mini-lite/` | 主固件 (Keil uVision 项目) |
| `demo/TMR1_111/` | 固件变体 |
| `arduino_iic_simulator/` | SW6301/SW6303 芯片模拟器 (Arduino) |
| `docs/` | 数据手册、开发指南 |

## 开发工具

- **固件编译**: Keil uVision (`mini-lite/prj/mini_lite.uvproj`)
- **模拟器开发**: Arduino IDE (`arduino_iic_simulator.ino`)
- **代码分析**: Serena (C++ 语言服务器)

## 芯片架构

| 芯片 | 功能 | IIC 地址 |
|------|------|----------|
| SW6301 | 升压输出IC | 0x14B (10位) |
| SW6303 | 充电管理IC | 0x23 |
| SH68F06 | 主控MCU | - |

## 关键约束

- **无构建命令**: 固件通过 Keil uVision 编译，无命令行构建
- **无测试框架**: 嵌入式项目，无自动化测试
- **编码注意**: 部分文件 (如 `main.h`) 使用 ISO-8859 编码
- **硬件依赖**: 固件运行在真实 SH68F06 硬件或 Arduino 模拟器上

详细开发说明见 `CLAUDE.md` 和 `docs/guides/` 目录。
