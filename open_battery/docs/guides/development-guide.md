# 固件开发指南

## 编译与烧录

```
1. Keil uVision 打开 test_tmr1.uvproj
2. F7 编译生成 HEX 文件
3. 使用 SH68 系列烧录器 / ULINK 仿真器烧录
4. 用 Arduino 模拟器辅助调试 IIC 通信
```

## IIC 通信

### 硬件连接

```
SH68F06 MCU              SW6301/SW6303
    ├─ P10 (SDA) ───────► SDA
    ├─ P07 (SCL) ───────► SCL
    └─ GND ─────────────► GND
```

### 通信接口

使用全局变量传递参数，调用统一的读写函数：

```c
// 写入：设置寄存器
R_Address = 0x02;      // 寄存器地址
R_Value = 0x4B;        // 要写入的数据
IIC_WriteByte();       // 执行写入

// 读取：获取寄存器值
R_Address = 0x22;
IIC_ReadByte();        // 结果在 R_Value 中
if (R_Value & 0x01) { /* 充电中 */ }
```

### SW6301 升压IC (地址 0x14B)

| 寄存器 | 名称 | 说明 | 常用值 |
|--------|------|------|--------|
| 0x02 | OUTPUT_VOL | 输出电压 | 0x4B=5V, 0x6B=9V, 0x7B=12V |
| 0x03 | OUTPUT_CUR | 输出电流 | 值×100mA |
| 0x04 | STATUS | 状态寄存器 | - |

### SW6303 充电IC (地址 0x23)

| 寄存器 | 名称 | 说明 | 常用值 |
|--------|------|------|--------|
| 0x20 | INPUT_VOL | 输入电压 | bit0=1 则为12.6V |
| 0x21 | CHG_CUR | 充电电流 | - |
| 0x22 | STATUS | 充电状态 | 0x01=充电中 |

### IIC 读写时序

```
写入: Start → SendByte(地址+W) → SendByte(寄存器) → SendByte(数据) → Stop
读取: Start → SendByte(地址+W) → SendByte(寄存器) → ReStart → SendByte(地址+R) → RcvByte() → Stop
```

### 软件模拟 IIC

代码使用位操作模拟 IIC，不依赖硬件 IIC 模块：

```c
// 时序控制
void NOP3() { NOP(); NOP(); NOP(); }
void NOP8() { NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); NOP(); }

// 关键全局变量 (IIC.c)
idata u8 R_Address;    // 寄存器地址
idata u8 R_Value;      // 读写数据
idata bit f_ack;       // 应答标志
```

## 核心流程

### 主程序流程 (main.c)

```
上电复位 → 时钟配置(4MHz) → GPIO初始化 → ADC初始化
→ SW6301/6303 IIC初始化 → 定时器启动(1ms) → 看门狗使能
→ 主循环 while(1):
    喂狗 → 读VDD → 扫描按键
    每100ms: 检测P21(负载) → 有负载则开照明/配SW6301 → Set_Power()
```

### 中断服务 (int.c)

```
1ms定时中断 INT1Interrupt:
    ├─ 时间计数器 +1ms (power_time_1ms, key_time_1ms, sleep_time_1ms)
    ├─ KEY_Scan() 按键扫描
    └─ LED_RUN() LED 扫描显示
```

### 按键处理 (main.c)

| 操作 | 条件 | 动作 |
|------|------|------|
| 短按 | 5~500ms | 唤醒充电路径，1.5s内按5次切换低功率模式 |
| 长按 | >10s | 开启光输出，关闭负载检测 |

### 充放电状态机 (sys.c)

```
检测P21(充电器) ─┬─ 有(P21=0): ADC采样 → NTC检测 → 配输出电流 → Set_Power()
                 └─ 无(P21=1): 关闭照明 → 清标志
```

## 修改指南

### 修改 LED 显示

`main.c` → `LED_RUN()` 函数，修改 `LED_Bright` 变量：

```c
LED_Bright = 0x00;
LED_Bright |= (1<<1);  // 点亮第1格
LED_Bright |= (1<<3);  // 点亮第2格
LED_Bright |= (1<<5);  // 点亮第3格
```

### 修改充电参数

`sys.c` → `PowerOn_Chk()` 函数：

```c
// 输入电压 (第13-21行)
R_Address = 0x20;  // 12V 输入

// 输出电流限制 (第194-207行)
if(VBUS_OUT_VOL < 11500)  // 11.5V以下限流500mA
if(VBUS_OUT_VOL > 11800)  // 11.5V以上限流1800mA
```

### 修改按键功能

按键处理分两层：`KEY_Scan()` 在 1ms 中断中检测按键时长，`KEY_RUN()` 在主循环中根据 `key_sta` 执行动作。

```
KEY_Scan() (int.c, 1ms中断中调用)
    │ 按键按下 → Cnt_Keys 累加
    │ 按键松开:
    │   5~500 → key_sta = 1 (短按)
    │   >10000 → key_sta = 2 (长按)
    ▼
KEY_RUN() (main.c, 主循环中调用)
    │ key_sta == 1 (短按):
    │   唤醒 SW6303/SW6301 充电路径
    │   1.5s 内按 5 次 → 切换 SW6301 低功率模式
    │
    │ key_sta == 2 (长按):
    │   开启光输出 (guang_shuchu)
    │   关闭 SW6301 负载检测
    ▼
```

要自定义按键行为，修改 `KEY_RUN()` 中 `key_sta == 1` 或 `key_sta == 2` 分支的代码。例如：

```c
// 改成长按关机
else if(key_sta == 2) {
    R_Address = 0x02;
    R_Value = 0x00;        // 关闭输出
    IIC_WriteByte();
    // 进入睡眠...
    key_sta = 0;
}
```

## 调试技巧

### Arduino 模拟器

```bash
1. 上传 arduino_iic_simulator.ino 到 Arduino
2. 串口监视器 (115200 baud)
3. 命令: help, status, stats, set <芯片> <寄存器> <值>, sim <事件>
```

### 常见 IIC 问题

| 问题 | 可能原因 | 解决方法 |
|------|---------|---------|
| 无 ACK 应答 | 芯片地址错误 | 检查 SW6301(0x14B)/SW6303(0x23) |
| 读取数据错误 | 时序不匹配 | 调整 NOP3/NOP8 延时 |
| SDA/SCL 无信号 | GPIO 配置错误 | 检查 SDA_OUT/SDA_IN 宏 |

## 已知问题

| 问题 | 位置 | 建议 |
|------|------|------|
| float 在主循环 | main.c:149 | 改为定点运算 `(tmp_data * 1010) / 1000` |
| 看门狗多处喂狗 | main.c:312, sys.c:17 | 统一喂狗位置 |
| 变量名拼写 | int.c:6 | `int_flay` → `int_flag` |
| 睡眠前未关外设 | sleep.c:80 | 睡眠前关闭 LED/ADC |
