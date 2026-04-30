# 接口与实现分离

## 当前问题

main.c 把业务逻辑和芯片寄存器操作混在一起。改一个电压值需要理解四步：

```c
// 当前：直接操作寄存器
IIC_ADDRESS = 0x14B;    // 1. 哪个芯片
R_Address = 0x02;        // 2. 哪个寄存器
R_Value = 0x6B;          // 3. 什么值 (9V)
SW6301_IIC_WRITE();      // 4. 怎么写
```

目标：封装为一行调用，业务代码不关心寄存器细节。

```c
// 目标：只调接口
boost_set_voltage(9000);  // 设升压输出 9V
```

## 硬件依赖分层

### 不依赖硬件（纯业务逻辑）

目前项目中没有独立的业务逻辑层，全部混在 main.c 中。

### 轻度依赖硬件（可抽象为接口）

| 当前代码 | 硬件依赖 | 抽象接口 |
|---------|---------|---------|
| main.c 按键逻辑 (`Cnt_Keys`, `key_sta`) | P13 引脚电平 | `key_get_event()` |
| main.c LED 显示 (`LED_Bright` bit 位) | LED1/2/3 引脚 | `led_set_level(n)` |
| main.c 充放电判断 (`P21` 读取) | P21 引脚电平 | `charger_is_connected()` |
| sys.c 功率管理 (电压/电流阈值) | VBUS_OUT_VOL 等全局变量 | `power_set_mode(mode)` |

### 中度依赖硬件（芯片功能封装）

| 文件 | 硬件依赖 | 换芯片 |
|------|---------|--------|
| SW6301.c | 寄存器地址 0x14B、0x02/0x03 等 | 整个文件重写 |
| SW6303.c | 寄存器地址 0x23、0x20-0x22 等 | 整个文件重写 |
| config.c | IIC_ADDRESS 设置、芯片配置序列 | 配置值全改 |
| iic_1/2/3.c | SDA/SCL 引脚分配、时序参数 | 时序和引脚可能要调 |

### 强依赖硬件（MCU 寄存器级）

| 文件 | 硬件依赖 | 换 MCU |
|------|---------|--------|
| Inc_mcu.h | SFR 地址、sbit 定义 | 整个文件 |
| STARTUP_F06.A51 | SH68F06 启动向量、内存初始化 | 整个文件 |
| int.c | 中断向量号 `interrupt 0/2/10` | 中断号和寄存器 |
| delay.c | `NOP()` 精确延时 | 时钟频率变了要调 |
| main.c IO_INIT | `P06_IN_EN` 等 GPIO 方向控制宏 | 引脚映射全改 |
| main.c ADC_INIT | `ADC_EN`/`ADC_RVDD_AVG8` 等 | 整个 ADC 配置 |
| main.c UART_INIT | UART0 寄存器、波特率计算 | 波特率配置 |

### 分层总览

```
 ┌─────────────────────────────────────────────┐
 │  业务逻辑（目前没有，全混在 main.c 里）       │  ← 换产品改这里
 ├─────────────────────────────────────────────┤
 │  芯片驱动（SW6301.c SW6303.c config.c）       │  ← 换芯片型号改这里
 ├─────────────────────────────────────────────┤
 │  通信/外设驱动（iic_1.c delay.c）            │  ← 换 MCU 架构改这里
 ├─────────────────────────────────────────────┤
 │  MCU 寄存器（Inc_mcu.h 启动文件 中断配置）    │  ← 换 MCU 必须改
 └─────────────────────────────────────────────┘
```

## 推荐方案：纯 C 函数接口

在 8KB ROM / 256B RAM 的约束下，用普通函数作为接口层，零额外开销。

### 目标接口定义

```c
// === power.h === 电源管理接口
void power_init(void);
void boost_set_voltage(unsigned int mv);       // 设升压输出电压(mV)
void boost_enable(void);
void boost_disable(void);
void charge_set_current(unsigned int ma);       // 设充电电流(mA)
unsigned int charge_get_status(void);          // 读充电状态
unsigned int battery_get_voltage(void);        // 读电池电压(mV)

// === led.h === LED 显示接口
void led_set_level(unsigned char level);       // 0-4 档电量显示
void led_set_pattern(unsigned char pattern);   // 常亮/闪烁/关闭

// === key.h === 按键接口
unsigned char key_get_event(void);             // KEY_NONE=0, KEY_SHORT=1, KEY_LONG=2
```

### 驱动层由 AI 从数据手册生成

数据手册 markdown（`docs/datasheets/SW6301_数据手册_V1.0.1.md` 和 `SW6303_数据手册_V1.0.1.md`）作为 AI 上下文，生成 SW6301/SW6303 的寄存器操作实现。

接口注释中写明规格，AI 读注释就能生成正确的驱动代码。

### 初始化序列用查表法

芯片上电的多步寄存器配置适合用 ROM 查表：

```c
typedef struct {
    unsigned int iic_addr;
    unsigned char reg;
    unsigned char val;
} reg_cfg_t;

code reg_cfg_t sw6301_init_seq[] = {
    {0x024, 0x20, 0x01},  // 关闭过流保护
    {0x024, 0x00, 0x00},  // ...
};

void chip_init_seq(code reg_cfg_t *seq, unsigned char len) {
    for (unsigned char i = 0; i < len; i++) {
        IIC_ADDRESS = seq[i].iic_addr;
        R_Address = seq[i].reg;
        R_Value = seq[i].val;
        iic_write();
    }
}
```

## 改造收益

| 方面 | 改造前 | 改造后 |
|------|--------|--------|
| 改电压 | 找寄存器地址、算值、写 IIC 操作 | `boost_set_voltage(9000)` |
| 换芯片型号 | 散布在 main.c/sys.c 中的寄存器操作全改 | 只改 vendor/ 驱动文件 |
| AI 生成业务逻辑 | 需要读懂数据手册和寄存器 | 只需看接口注释 |
| 新人理解代码 | 要同时理解业务 + 芯片 + 通信协议 | 业务和驱动分开看 |

## 约束说明

- SH68F06: 8KB ROM, 256B RAM, 768B XRAM, 无动态内存
- C51 不支持 struct 函数指针表的 ROM 存储（code 关键字有局限）
- 纯函数接口零 RAM/ROM 额外开销，最适合本平台
- 函数指针方案每次调用 3 字节 ROM 开销，可接受但非必要
