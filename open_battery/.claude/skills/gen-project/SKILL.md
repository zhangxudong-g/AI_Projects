---
name: gen-project
description: 从用户需求描述生成 main.c 业务逻辑。当用户提到"生成业务逻辑"、"Phase 2"、"阶段2"、"生成 main.c"、"从需求生成代码"、"状态机"、"充放电逻辑"时触发此技能。仅使用接口定义，禁止读取数据手册。
origin: custom
---

# Phase 2: 用户需求 → 业务逻辑生成

基于用户的自然语言功能需求和已生成的接口定义，在 main.c 中生成完整的业务逻辑。严格遵循三层架构：main.c 只调用 power.h/led.h/key.h 接口，绝不直接操作寄存器或调用 vendor 层函数。

## 架构背景

```
vendor/（厂家驱动）  →  接口层（power.h/led.h/key.h）  →  main.c（业务逻辑，本次生成）
       只读                     只读                           写入
```

main.c 禁止出现：`IIC_ADDRESS`、`IIC_DAT`、`SW6301_IIC_WRITE/READ`、`SW6303_IIC_WRITE/READ`、寄存器地址常量。

## 执行协议

### Step 1: 读取接口定义（唯一允许的接口信息源）

按顺序读取以下 6 个文件：

1. `mini-lite/vendor/power.h` — 电源管理接口函数签名
2. `mini-lite/vendor/led.h` — LED 显示接口函数签名
3. `mini-lite/vendor/key.h` — 按键检测接口函数签名
4. `docs/interfaces/power-spec.md` — 电源接口详细规格
5. `docs/interfaces/led-spec.md` — LED 接口详细规格
6. `docs/interfaces/key-spec.md` — 按键接口详细规格

从中提取：函数签名、参数类型与有效范围、返回值含义、ISR 安全性、阻塞行为与耗时、前置条件。

**严格禁止**：
- 读取 `docs/datasheets/` 下的任何数据手册
- 读取 `mini-lite/vendor/SW6301.c/h`、`SW6303.c/h` 等 vendor 实现文件
- 读取 `mini-lite/vendor/iic_*.c/h`、`config.c/h`、`Inc_mcu.h`

### Step 2: 读取项目上下文

读取以下文件了解框架（不参考芯片细节）：

1. `docs/guides/ai-dev-workflow.md` — 状态机定义、审查清单
2. `mini-lite/src/main.c` — 保留 IO_INIT、ADC_INIT、UART_INIT 等硬件初始化代码
3. `mini-lite/src/int.c` — 保留中断框架，理解时间基准
4. `mini-lite/src/main.h` — 现有头文件
5. `mini-lite/vendor/config.h` — 仅使用 power_time_1ms 等时间变量

### Step 3: 分析用户需求

将自然语言需求翻译为：

1. **状态转换规则** — 每个状态在什么条件下转换到什么状态
2. **接口调用序列** — 在每个状态/事件中调用哪些接口函数
3. **时序要求** — 超时时间、轮询间隔、消抖时间
4. **LED 行为** — 每个状态下 LED 的显示模式

**翻译示例**：

| 用户描述 | 翻译结果 |
|---------|---------|
| "电量低于 6.2V 关闭输出进入睡眠" | `if (battery_get_voltage() < 6200) { boost_disable(); /* → STATE_SLEEP */ }` |
| "按键短按开启 9V 升压输出" | `boost_set_voltage(9000); boost_enable();` |
| "4颗LED显示电量" | `led_set_level(level)` 根据 `battery_get_voltage()` 设置 1-4 档 |
| "插入充电器自动充电" | `if (charger_is_connected()) { charge_enable(); /* → STATE_CHARGING */ }` |
| "低电量闪烁提醒" | `if (level == 0) { led_set_blink(1); }` |

**参数范围校验规则**：
- `boost_set_voltage()` 参数只能是 5000/9000/12000
- `led_set_level()` 参数范围 0-4
- `key_get_event()` 返回值 KEY_NONE/KEY_SHORT/KEY_LONG
- 阻塞函数（标注 ISR 不安全）不能在中断服务函数中调用

### Step 4: 生成状态机代码

**预定义状态枚举**（不可修改）：

```c
typedef enum {
    STATE_POWER_ON,        // 上电/复位入口，执行初始化
    STATE_IDLE,            // 空闲，等待事件
    STATE_CHARGING,        // 充电中
    STATE_DISCHARGING,     // 放电中（升压输出）
    STATE_SLEEP,           // 睡眠模式
    STATE_WAKEUP,          // 从睡眠唤醒
    STATE_FAULT_OVERTEMP,      // 过温保护
    STATE_FAULT_OVERCURRENT,   // 过流保护
    STATE_FAULT_UNDERVOLTAGE,  // 欠压保护
    STATE_FAULT_COMM            // IIC 通信失败
} SystemState;
```

**预定义状态转换表**（基础框架，根据用户需求扩展）：

| 当前状态 | 条件 | 下一状态 | 动作 |
|---------|------|---------|------|
| POWER_ON | 初始化完成 | IDLE | 关闭所有输出 |
| POWER_ON | 初始化失败 | FAULT_COMM | 标记硬件故障 |
| IDLE | 检测到充电器 | CHARGING | charge_enable() |
| IDLE | 按键短按 AND 电量正常 | DISCHARGING | boost_set_voltage() + boost_enable() |
| IDLE | 无电源 AND 无按键 AND 超时 | SLEEP | 关闭所有外设 |
| CHARGING | 充电器拔出 / 充满 | IDLE | charge_disable() |
| CHARGING | 过温 | FAULT_OVERTEMP | charge_disable() |
| CHARGING | 过流 / 通信失败 | FAULT_xxx | 关闭输出 |
| DISCHARGING | 按键关闭 / 负载移除 | IDLE | boost_disable() |
| DISCHARGING | 电压 < 6.2V 持续 5s | SLEEP | boost_disable() |
| DISCHARGING | 过温 / 过流 | FAULT_xxx | boost_disable() |
| SLEEP | 按键按下 | WAKEUP | 恢复时钟、初始化 IIC |
| WAKEUP | 初始化完成 | CHARGING / IDLE | 根据条件决定 |
| WAKEUP | 初始化失败 | FAULT_COMM | 标记硬件故障 |
| FAULT_xxx | 条件恢复 | IDLE / CHARGING | 恢复动作 |

**main.c 结构模板**：

```c
#include "main.h"
#include "config.h"
#include "power.h"
#include "led.h"
#include "key.h"

static SystemState g_state = STATE_POWER_ON;

/* 每个状态一个 static 函数 */
static void state_power_on(void);
static void state_idle(void);
static void state_charging(void);
static void state_discharging(void);
static void state_sleep(void);
static void state_wakeup(void);
static void state_fault_overtemp(void);
static void state_fault_overcurrent(void);
static void state_fault_undervoltage(void);
static void state_fault_comm(void);

void main(void)
{
    /* 保留现有硬件初始化代码 (IO_INIT, ADC_INIT, 时钟配置, 定时器配置) */

    led_all_off();

    while(1)
    {
        CLR_WDT;  /* 喂狗 */

        /* 定时任务 (100ms 周期) */
        if (power_time_1ms > 100)
        {
            power_time_1ms = 0;

            switch(g_state)
            {
                case STATE_POWER_ON:         state_power_on();         break;
                case STATE_IDLE:             state_idle();             break;
                case STATE_CHARGING:         state_charging();         break;
                case STATE_DISCHARGING:      state_discharging();      break;
                case STATE_SLEEP:            state_sleep();            break;
                case STATE_WAKEUP:           state_wakeup();           break;
                case STATE_FAULT_OVERTEMP:   state_fault_overtemp();   break;
                case STATE_FAULT_OVERCURRENT: state_fault_overcurrent(); break;
                case STATE_FAULT_UNDERVOLTAGE: state_fault_undervoltage(); break;
                case STATE_FAULT_COMM:       state_fault_comm();       break;
                default: g_state = STATE_IDLE; break;
            }

            power_check_reset();
        }

        led_scan();
    }
}
```

### Step 5: 输出 int.c 修改建议

不直接修改 int.c，输出修改说明（diff 格式或文字描述）：

- 在定时器 ISR 中用 `key_scan_isr()` 替换 `KEY_Scan()`
- 在定时器 ISR 中用 `led_scan()` 替换 `LED_RUN()`
- 保持 1ms 定时基准不变
- 保持时间计数器累加逻辑不变

### Step 6: 自检验证

生成完成后，逐项检查并输出报告：

**接口隔离**：
- [ ] main.c 中没有 `#include "SW6301.h"` 或 `#include "SW6303.h"`
- [ ] main.c 中没有直接调用 `SW6301_IIC_WRITE/READ` 或 `SW6303_IIC_WRITE/READ`
- [ ] main.c 中没有出现 `IIC_ADDRESS`、`IIC_DAT`
- [ ] main.c 中没有寄存器地址常量（0x14B、0x02、0x23 等）
- [ ] main.c 唯一的外部头文件包含是 power.h、led.h、key.h、config.h、main.h

**接口调用参数**：
- [ ] `boost_set_voltage()` 参数在有效范围内（5000/9000/12000）
- [ ] `led_set_level()` 参数在 0-4 范围内
- [ ] 阻塞函数只出现在主循环中，不出现在 ISR 中

**状态机**：
- [ ] 每个状态都有至少一个退出路径（无死锁）
- [ ] 每个状态都能从其他状态到达（无孤立状态）
- [ ] 故障状态有恢复路径或不恢复策略
- [ ] STATE_POWER_ON 总是第一个执行的状态
- [ ] switch 有 default 分支

**主循环**：
- [ ] while(1) 入口有 CLR_WDT
- [ ] 主循环中无阻塞调用（while 等待、长延时）
- [ ] 状态机在 if(power_time_1ms > 100) 条件内（100ms 周期）
- [ ] led_scan() 在每个循环迭代中执行

**ISR 安全**：
- [ ] ISR 中只调用标注 "ISR安全" 的函数
- [ ] ISR 中无阻塞操作

**C51 兼容**：
- [ ] 无 float 运算
- [ ] 无动态内存分配
- [ ] 数据类型使用 unsigned char/unsigned int

## 前置条件

Phase 1 必须已完成：
- `mini-lite/vendor/power.h` 和 `power.c` 存在
- `mini-lite/vendor/led.h` 和 `led.c` 存在
- `mini-lite/vendor/key.h` 和 `key.c` 存在
- `docs/interfaces/power-spec.md`、`led-spec.md`、`key-spec.md` 存在

如果前置条件不满足，提示用户先执行 Phase 1（`phase1-interface-gen` skill）。

## 错误处理

如果用户需求中出现接口不支持的功能：
1. 列出无法通过现有接口实现的功能
2. 说明原因
3. 提供选择：a) 跳过该功能生成其余部分；b) 回到 Phase 1 补充接口

## 约束

1. **禁止读取数据手册** — 所有硬件信息通过接口文件获取
2. **禁止调用 vendor 函数** — main.c 只调 power.h/led.h/key.h
3. **保留硬件初始化** — IO_INIT、ADC_INIT、UART_INIT、时钟/定时器配置从现有代码保留
4. **主循环不阻塞** — while(1) 中无阻塞调用
5. **ISR 不阻塞** — 中断中不调 ISR 不安全的函数
6. **状态机用 switch** — 不引入框架库
7. **C51 兼容** — Keil C51 可编译
8. **资源约束** — main.c ROM 开销控制在 2KB 以内
9. **UTF-8 编码** — 注释使用中文

## 输出文件

| 文件 | 描述 |
|------|------|
| `mini-lite/src/main.c` | 业务逻辑主程序（完整替换） |
| `mini-lite/src/main.h` | 主程序头文件（如需更新） |
| int.c 修改说明 | int.c 的修改建议（文字说明或 diff） |
