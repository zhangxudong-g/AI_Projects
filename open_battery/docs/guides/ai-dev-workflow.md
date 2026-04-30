# AI 辅助固件开发工作流

## 目标

```
阶段1: 芯片资料 ──→ AI ──→ 硬件抽象层 + 业务层接口 ──→ 人工验证
阶段2: 用户需求 ──→ AI ──→ 业务逻辑代码               ──→ 人工审查
```

## 代码的三层结构

```
厂家驱动（vendor/）          我们定义的接口              业务代码
┌──────────────┐        ┌──────────────┐        ┌──────────────┐
│ SW6301.c     │   →    │ power.h/.c   │   →    │ main.c       │
│ SW6303.c     │   →    │              │        │              │
│ iic 驱动      │   →    │ led.h/.c     │        │              │
│ Inc_mcu.h    │        │ key.h/.c     │        │              │
│ SW630x_init  │        │              │        │              │
│ user_com/    │        │              │        │              │
└──────────────┘        └──────────────┘        └──────────────┘
  寄存器操作/芯片初始化       业务能力(不含寄存器)       只调接口
  厂家提供或从清单恢复         我们定义的               AI可生成
```

- **vendor/** — 芯片厂家提供的寄存器级驱动 + 厂商标准通信库
  - `SW6301.c` / `SW6303.c` — 寄存器操作（知道怎么写 0x02 寄存器）
  - `SW630x_init` — 芯片初始化序列（从现有 `KEY.c` 的 `PowerOn_Chk()` 中拆出）
  - `iic 驱动` — IIC 底层通信
  - `Inc_mcu.h` — MCU 寄存器定义
  - `user_com/` — 厂商提供的标准通信库，被 power.h 等接口内部调用
- **我们定义的接口** — 业务层抽象，**不直接操作寄存器**
  - `power.h/.c` — 充放电控制（`boost_set_voltage()` 表示"设电压"）
  - `led.h/.c` — LED 指示控制（纯 GPIO，不涉及芯片寄存器）
  - `key.h/.c` — 按键检测（消抖、短按/长按判定），不含芯片初始化
- **main.c** — 只调接口，不直接操作寄存器

power.h / led.h / key.h 是我们**自己造的中间层**，把厂家的寄存器操作包起来。厂家给的是"怎么写寄存器"，我们定义的是"这个系统能做什么"。

## 阶段1：芯片资料 → 硬件抽象层 + 业务层接口

**输入**：芯片数据手册 markdown（`docs/datasheets/`）
**输出**：驱动实现（vendor/）+ 业务接口（power.h / led.h / key.h）

### AI 处理流程

1. 读取数据手册，提取寄存器定义、电气特性、功能描述、保护机制
2. 生成硬件驱动（vendor/SW6301.c、SW6303.c）
3. 生成业务层接口（power.h / led.h / key.h）
4. 生成配置表（芯片初始化序列用查表法，存 ROM）

### 人工验证

- [ ] 对比数据手册，确认寄存器地址正确
- [ ] 验证 IIC 地址格式（SW6301 用 10 位 0x14B，SW6303 用 7 位 0x23）
- [ ] 检查寄存器写入后的延时是否满足数据手册要求
- [ ] 确认 GPIO 引脚分配与原理图一致
- [ ] 验证每个业务接口函数内部的 vendor 调用路径正确（IIC 地址拼接、寄存器地址、参数范围校验）

## 阶段2：用户需求 → 业务逻辑

**输入**：用户用自然语言描述功能需求
**输出**：main.c 中的主循环、状态处理、按键/LED 逻辑

### 接口约定（阶段1 和阶段2 之间的契约）

AI 在阶段2 **只看接口定义**，不读数据手册。接口由两部分组成：

1. **C 头文件**（`power.h` / `led.h` / `key.h`）— 可编译的接口定义，带结构化注释
2. **独立规格文档**（`docs/interfaces/{module}-spec.md`）— 表格形式，人工审查用

每个接口函数的规格包含以下属性：

| 属性 | 说明 |
|------|------|
| 签名 | 完整 C 函数声明 |
| 参数 | 名称、类型、有效范围、单位 |
| 返回值 | 成功/错误码定义 |
| ISR安全 | 是否可在中断服务函数中调用 |
| 阻塞 | 是否阻塞，阻塞时长 |
| 前置条件 | 调用前需满足的条件 |
| 副作用 | 修改的全局状态/寄存器 |

#### 规格表示例（docs/interfaces/power-spec.md）

```markdown
## boost_set_voltage

| 属性     | 值                                        |
|----------|-------------------------------------------|
| 签名     | int boost_set_voltage(unsigned int mv)     |
| 参数     | mv: 5000/9000/12000 mV (SW6301 预设值)     |
| 返回值   | 0=成功, -1=参数无效, -2=IIC 通信失败       |
| ISR安全  | 否                                        |
| 阻塞     | 是, ~1ms (一次 IIC 写操作)                 |
| 前置条件 | boost_init() 已调用                        |
| 副作用   | 修改 SW6301 OUTPUT_VOL 寄存器 (0x02)       |
| 测试     | Arduino 模拟器验证 IIC 时序                |
| 备注     | 预设映射: 5000mV→0x4B, 9000mV→0x6B, 12000mV→0x7B; 换算公式待数据手册补充 |
```

#### 头文件示例

```c
// power.h
/**
 * 设升压输出电压
 * @param mv  目标电压(mV): 3300~12300, 步进10mV
 * @return 0=成功, -1=参数越界, -2=IIC通信失败
 * @note  阻塞, 耗时约1ms (IIC一次)
 * @warning 不可在 ISR 中调用
 * @pre   boost_init() 已调用
 */
int boost_set_voltage(unsigned int mv);
```

### 示例

用户描述 → AI 生成：

```
"电量低于 6.2V 关闭输出进入睡眠"
  → if (battery_get_voltage() < 6200) { boost_disable(); enter_sleep(); }

"按键短按开启 9V 升压输出"
  → boost_set_voltage(9000); boost_enable();
```

### 人工审查

- [ ] 接口调用参数在有效范围内
- [ ] 状态转换无死锁（每个状态都有退出路径）
- [ ] 中断服务函数中不调用阻塞操作
- [ ] 主循环不被任何条件阻塞

## 状态机设计

| 当前状态 | 条件 | 下一状态 | 动作 |
|---------|------|---------|------|
| POWER_ON | 初始化完成 | IDLE | 关闭所有输出 |
| IDLE | 检测到输入电源 | CHARGING | 配置充电参数 |
| IDLE | 按键短按 / 负载插入 AND 电量正常 | DISCHARGING | 开启升压输出 |
| IDLE | 无电源 AND 无按键 AND 超时 | SLEEP | 关闭所有外设 |
| CHARGING | 电源拔出 / 充满 | IDLE | 关闭充电 |
| CHARGING | 过温 / 过流 / 通信失败 | FAULT | 关闭输出 |
| DISCHARGING | 按键关闭 / 负载移除 | IDLE | 关闭升压 |
| DISCHARGING | 电压 < 6.2V 持续 5s | SLEEP | 关闭输出 |
| DISCHARGING | 过温 / 过流 | FAULT | 关闭输出 |
| SLEEP | 按键按下 | IDLE | 唤醒 |
| SLEEP | 插入电源 | WAKEUP | 恢复时钟、初始化 IIC、配置充电参数 |
| WAKEUP | 初始化完成 | CHARGING | 开始充电 |
| WAKEUP | 初始化失败 | FAULT | 标记硬件故障 |
| FAULT | 故障类型 | 退出条件 | 恢复动作 |
| --- | --- | --- | --- |
| FAULT_OVERTEMP | 温度恢复正常 | 重启升压或充电 | 需人工确认或按键触发 |
| FAULT_OVERCURRENT | 去除过流负载 | 电流回落至安全值 | 自动恢复或按键触发 |
| FAULT_UNDERVOLTAGE | 插入电源充电 | 电压回升至 6.6V | 自动进入 CHARGING |
| FAULT_COMM | IIC 通信恢复 | 连续 3 次通信成功 | 自动恢复到故障前状态 |

状态用 enum 定义，主循环 switch 处理，不搞复杂的状态机框架。

### 复位行为

上电复位和看门狗复位均从 POWER_ON 开始，执行完整初始化流程后进入 IDLE。不区分复位来源，避免初始化不完整导致硬件处于不确定状态。

```c
typedef enum {
    STATE_POWER_ON,       // 上电/复位入口，执行初始化
    STATE_IDLE,
    STATE_CHARGING,
    STATE_DISCHARGING,
    STATE_SLEEP,
    STATE_WAKEUP,
    STATE_FAULT_OVERTEMP,    // 过温保护
    STATE_FAULT_OVERCURRENT, // 过流保护
    STATE_FAULT_UNDERVOLTAGE,// 欠压保护
    STATE_FAULT_COMM         // IIC 通信失败
} SystemState;
```

