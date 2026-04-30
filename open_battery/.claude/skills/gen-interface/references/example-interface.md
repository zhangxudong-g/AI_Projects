# 接口生成完整范例

本范例展示 vendor 驱动 → 业务接口的完整转换过程。假设有一个芯片 `XX123` 通过 IIC 通信，提供电压调节功能。

---

## 1. vendor 层（已有，只读）

### vendor/xx123.h（芯片厂家提供）

```c
#ifndef __XX123_H
#define __XX123_H

#include "config.h"
#include "iic_2.h"

/* 寄存器地址 — 这些常量不应泄漏到接口层 */
#define XX123_REG_OUTPUT_VOL   0x02
#define XX123_REG_OUTPUT_CUR   0x03
#define XX123_REG_STATUS       0x04
#define XX123_REG_ENABLE       0x05

/* 初始化 */
void XX123_INIT(void);
void XX123_SET_H(void);   /* 切到高位页面 */
void XX123_SET_L(void);   /* 切回低位页面 */

/* 读写操作 — 通过 config.h 中的全局变量 IIC_ADDRESS/IIC_DAT */
/* 由 iic_2.h 中的宏映射: XX123_IIC_READ() = IIC2_READ() */
#define XX123_IIC_READ()   IIC2_READ()
#define XX123_IIC_WRITE()  IIC2_WRITE()

/* 状态读取 */
unsigned char XX123_GET_STATUS(void);
unsigned int XX123_GET_VOUT(void);  /* 返回 ADC 值，需 ×10 得 mV */

/* 复位检测 */
void XX123_GET_RESET(void);

#endif
```

### vendor/iic_2.h（通信驱动）

```c
/* IIC 操作使用 config.h 中的全局变量:
 *   IIC_ADDRESS — 目标寄存器地址
 *   IIC_DAT     — 读写数据
 */
void IIC2_WRITE(void);  /* 写: 设置 IIC_ADDRESS 和 IIC_DAT 后调用 */
void IIC2_READ(void);   /* 读: 设置 IIC_ADDRESS 后调用, 结果在 IIC_DAT */
```

### vendor/config.h（全局变量）

```c
extern unsigned char IIC_ADDRESS;  /* 寄存器地址 */
extern unsigned char IIC_DAT;      /* 读写数据 */
```

---

## 2. 接口层（本次生成）

### voltage.h（业务接口头文件）

```c
/**
 * @file    voltage.h
 * @brief   电压输出控制接口
 * @note    封装 XX123 芯片操作，提供电压调节能力
 */

#ifndef __VOLTAGE_H
#define __VOLTAGE_H

/* === 预设电压值 === */
#define VOLTAGE_5V   5000
#define VOLTAGE_9V   9000
#define VOLTAGE_12V  12000

/* === 错误码 === */
#define VOLTAGE_OK         0
#define VOLTAGE_ERR_PARAM  (-1)
#define VOLTAGE_ERR_IIC    (-2)

/* === 接口函数 === */

/**
 * 电压模块初始化
 * @return VOLTAGE_OK=成功, VOLTAGE_ERR_IIC=通信失败
 * @note  阻塞, 耗时约50ms (芯片初始化, 含多次IIC操作)
 * @warning 不可在 ISR 中调用
 */
int voltage_init(void);

/**
 * 设置输出电压
 * @param mv  目标电压(mV): 5000/9000/12000 (芯片预设值)
 * @return VOLTAGE_OK=成功, VOLTAGE_ERR_PARAM=参数无效, VOLTAGE_ERR_IIC=通信失败
 * @note  阻塞, 耗时约1ms (IIC一次)
 * @warning 不可在 ISR 中调用
 * @pre   voltage_init() 已调用
 */
int voltage_set(unsigned int mv);

/**
 * 使能输出
 * @return VOLTAGE_OK=成功, VOLTAGE_ERR_IIC=通信失败
 * @note  阻塞, 耗时约1ms
 * @warning 不可在 ISR 中调用
 * @pre   voltage_init() 已调用
 */
int voltage_enable(void);

/**
 * 关闭输出
 * @return VOLTAGE_OK=成功
 * @note  非阻塞
 */
int voltage_disable(void);

/**
 * 获取当前输出电压
 * @return 输出电压(mV), 0=读取失败
 * @note  阻塞, 耗时约2ms (IIC两次)
 * @warning 不可在 ISR 中调用
 * @pre   voltage_init() 已调用
 */
unsigned int voltage_get_output(void);

/**
 * 获取芯片状态
 * @return 状态值, bit0=过温, bit1=过流, 0xFF=通信失败
 * @note  阻塞, 耗时约1ms
 */
unsigned char voltage_get_status(void);

/**
 * 复位检测和自动恢复
 * @note  检查芯片是否意外复位，若是则重新初始化
 *        应在主循环中定期调用 (建议100ms一次)
 */
void voltage_check_reset(void);

#endif
```

**注意**：
- `.h` 文件**没有** `#include "xx123.h"` 或 `#include "iic_2.h"` — vendor 头文件只在 `.c` 中引用
- `.h` 文件**没有** `IIC_ADDRESS`、`IIC_DAT` — 全局变量只在 `.c` 中使用
- `.h` 文件**没有** `0x02`、`0x03` 等寄存器地址常量 — 只在 `.c` 中定义
- 业务常量（VOLTAGE_5V 等）使用有意义的名称，不暴露寄存器值

### voltage.c（业务接口实现）

```c
/**
 * @file    voltage.c
 * @brief   电压输出控制实现
 */

#include "voltage.h"
#include "xx123.h"    /* vendor 层 — 只在 .c 中引用 */
#include "config.h"   /* IIC_ADDRESS, IIC_DAT */
#include "delay.h"

/* === 内部常量（寄存器映射，不暴露到 .h）=== */
#define REG_OUTPUT_VOL   0x02
#define REG_ENABLE       0x05

/* === 内部辅助函数 === */

/**
 * 写 XX123 寄存器
 */
static int write_reg(unsigned char addr, unsigned char data)
{
    IIC_ADDRESS = addr;
    IIC_DAT = data;
    XX123_IIC_WRITE();
    return VOLTAGE_OK;
}

/**
 * 读 XX123 寄存器
 */
static int read_reg(unsigned char addr, unsigned char *data)
{
    IIC_ADDRESS = addr;
    XX123_IIC_READ();
    *data = IIC_DAT;
    return VOLTAGE_OK;
}

/* === 公共接口实现 === */

int voltage_init(void)
{
    XX123_INIT();
    return VOLTAGE_OK;
}

int voltage_set(unsigned int mv)
{
    unsigned char reg_val;

    /* 参数校验 + 预设值映射 */
    switch (mv) {
        case VOLTAGE_5V:   reg_val = 0x4B; break;
        case VOLTAGE_9V:   reg_val = 0x6B; break;
        case VOLTAGE_12V:  reg_val = 0x7B; break;
        default:           return VOLTAGE_ERR_PARAM;
    }

    /* 需要高位页面才能访问输出电压寄存器 */
    XX123_SET_H();
    write_reg(REG_OUTPUT_VOL, reg_val);
    XX123_SET_L();

    return VOLTAGE_OK;
}

int voltage_enable(void)
{
    return write_reg(REG_ENABLE, 0x01);
}

int voltage_disable(void)
{
    return write_reg(REG_ENABLE, 0x00);
}

unsigned int voltage_get_output(void)
{
    unsigned char val;
    XX123_SET_H();
    read_reg(REG_OUTPUT_VOL, &val);
    XX123_SET_L();
    return (unsigned int)val * 100;  /* ADC 值转 mV */
}

unsigned char voltage_get_status(void)
{
    return XX123_GET_STATUS();
}

void voltage_check_reset(void)
{
    XX123_GET_RESET();
}
```

---

## 3. 规格文档

### docs/interfaces/voltage-spec.md

```markdown
# voltage 接口规格

## 模块概述
电压输出控制，封装 XX123 芯片的升压调节功能。

## 依赖
- vendor 层: XX123_INIT(), XX123_SET_H/L(), XX123_IIC_READ/WRITE(), XX123_GET_STATUS(), XX123_GET_RESET()
- 通信: IIC2 总线 (iic_2.h)
- 硬件资源: 无额外 GPIO

## 函数规格

### voltage_init

| 属性     | 值                                        |
|----------|-------------------------------------------|
| 签名     | int voltage_init(void)                    |
| 参数     | 无                                        |
| 返回值   | 0=成功, -2=IIC通信失败                    |
| ISR安全  | 否                                        |
| 阻塞     | 是, ~50ms (芯片初始化序列)                 |
| 前置条件 | 无                                        |
| 副作用   | 配置 XX123 所有寄存器                      |
| 测试     | Arduino 模拟器验证初始化 IIC 时序          |
| 备注     |                                          |

#### vendor 调用路径
voltage_init() → XX123_INIT() → (多次 XX123_IIC_WRITE)

### voltage_set

| 属性     | 值                                        |
|----------|-------------------------------------------|
| 签名     | int voltage_set(unsigned int mv)          |
| 参数     | mv: 5000/9000/12000 mV (芯片预设值)        |
| 返回值   | 0=成功, -1=参数无效, -2=IIC通信失败       |
| ISR安全  | 否                                        |
| 阻塞     | 是, ~1ms (一次 IIC 写 + 页面切换)          |
| 前置条件 | voltage_init() 已调用                      |
| 副作用   | 修改 XX123 OUTPUT_VOL 寄存器 (高位页面 0x02) |
| 测试     | 模拟器设置预设值后读回验证                  |
| 备注     | 预设映射: 5000mV→0x4B, 9000mV→0x6B, 12000mV→0x7B |

#### vendor 调用路径
voltage_set() → XX123_SET_H() → write_reg(0x02) → XX123_IIC_WRITE() → XX123_SET_L()

### voltage_enable

| 属性     | 值                                        |
|----------|-------------------------------------------|
| 签名     | int voltage_enable(void)                  |
| 参数     | 无                                        |
| 返回值   | 0=成功, -2=IIC通信失败                    |
| ISR安全  | 否                                        |
| 阻塞     | 是, ~1ms                                  |
| 前置条件 | voltage_init() 已调用                      |
| 副作用   | 修改 XX123 ENABLE 寄存器 (0x05) 置位      |
| 测试     | 模拟器验证使能后状态寄存器变化              |
| 备注     |                                          |

#### vendor 调用路径
voltage_enable() → write_reg(0x05, 0x01) → XX123_IIC_WRITE()

### voltage_disable

| 属性     | 值                                        |
|----------|-------------------------------------------|
| 签名     | int voltage_disable(void)                 |
| 参数     | 无                                        |
| 返回值   | 0=成功                                    |
| ISR安全  | 否 (含 IIC 操作)                          |
| 阻塞     | 是, ~1ms                                  |
| 前置条件 | voltage_init() 已调用                      |
| 副作用   | 清除 XX123 ENABLE 寄存器 (0x05)           |
| 测试     | 模拟器验证关闭后无输出                     |
| 备注     |                                          |

#### vendor 调用路径
voltage_disable() → write_reg(0x05, 0x00) → XX123_IIC_WRITE()

### voltage_get_output

| 属性     | 值                                        |
|----------|-------------------------------------------|
| 签名     | unsigned int voltage_get_output(void)     |
| 参数     | 无                                        |
| 返回值   | 输出电压(mV), 0=读取失败                   |
| ISR安全  | 否                                        |
| 阻塞     | 是, ~2ms (IIC两次 + 页面切换)             |
| 前置条件 | voltage_init() 已调用                      |
| 副作用   | 无                                        |
| 测试     | 模拟器设置已知电压后读回验证                |
| 备注     | ADC 值需乘以 100 得到实际 mV               |

#### vendor 调用路径
voltage_get_output() → XX123_SET_H() → read_reg(0x02) → XX123_IIC_READ() → XX123_SET_L()

### voltage_get_status

| 属性     | 值                                        |
|----------|-------------------------------------------|
| 签名     | unsigned char voltage_get_status(void)    |
| 参数     | 无                                        |
| 返回值   | bit0=过温, bit1=过流, 0xFF=通信失败       |
| ISR安全  | 否                                        |
| 阻塞     | 是, ~1ms                                  |
| 前置条件 | voltage_init() 已调用                      |
| 副作用   | 无                                        |
| 测试     | 模拟器模拟过温/过流后读回验证              |
| 备注     |                                          |

#### vendor 调用路径
voltage_get_status() → XX123_GET_STATUS() → XX123_IIC_READ()

### voltage_check_reset

| 属性     | 值                                        |
|----------|-------------------------------------------|
| 签名     | void voltage_check_reset(void)            |
| 参数     | 无                                        |
| 返回值   | 无                                        |
| ISR安全  | 否                                        |
| 阻塞     | 是, ~2ms (检测 + 可能重新初始化)           |
| 前置条件 | voltage_init() 已调用                      |
| 副作用   | 若检测到复位，会重新执行 XX123_INIT()      |
| 测试     | 模拟器模拟芯片复位后验证自动恢复            |
| 备注     | 应在主循环中定期调用 (建议100ms)           |

#### vendor 调用路径
voltage_check_reset() → XX123_GET_RESET() → (若复位) → XX123_INIT()
```

---

## 4. 关键对照：vendor 层 vs 接口层

| 维度 | vendor 层 (xx123.h) | 接口层 (voltage.h) |
|------|---------------------|---------------------|
| 函数命名 | `XX123_INIT`, `XX123_SET_H` | `voltage_init`, `voltage_set` |
| 参数风格 | 无参数或原始寄存器值 | 业务语义 (mV) |
| 错误处理 | 无返回值或裸返回 | 统一错误码 (VOLTAGE_OK/ERR_PARAM/ERR_IIC) |
| 注释内容 | 寄存器地址、位域 | 阻塞行为、ISR安全、前置条件 |
| 头文件依赖 | config.h, iic_2.h | 无 vendor 依赖 |
| 全局变量 | IIC_ADDRESS, IIC_DAT | 不暴露 |
| 寄存器常量 | 0x02, 0x03, 0x05 | 不暴露，用 VOLTAGE_5V 等业务常量替代 |
