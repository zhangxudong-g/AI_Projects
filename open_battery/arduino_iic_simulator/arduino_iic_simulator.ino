/*
 * mini-Lite IIC 模拟器
 * 模拟 SW6301 (升压IC) 和 SW6303 (充电IC)
 *
 * 硬件连接:
 * Arduino A4 (SDA) <---> SH68F06 SDA
 * Arduino A5 (SCL) <---> SH68F06 SCL
 * Arduino GND    <---> SH68F06 GND
 *
 * 串口监控: 115200 baud
 */

#include <Wire.h>

// ==================== 配置 ====================
#define SERIAL_BAUD 115200

// IIC 地址 (7位格式)
#define ADDR_SW6301 0x0A  // SW6301: 0x14B >> 1
#define ADDR_SW6303 0x11  // SW6303: 0x23 >> 1

// ==================== SW6301 寄存器定义 ====================
enum SW6301_Reg {
    REG_SW6301_OUTPUT_VOL = 0x02,   // 输出电压
    REG_SW6301_OUTPUT_CUR = 0x03,   // 输出电流
    REG_SW6301_STATUS      = 0x04,   // 状态寄存器
};

// ==================== SW6303 寄存器定义 ====================
enum SW6303_Reg {
    REG_SW6303_INPUT_VOL  = 0x20,   // 输入电压设置
    REG_SW6303_CHG_CUR    = 0x21,   // 充电电流
    REG_SW6303_STATUS     = 0x22,   // 充电状态
};

// ==================== 全局变量 ====================
// SW6301 寄存器数据
volatile uint8_t sw6301_regs[256] = {0};
volatile uint8_t sw6301_reg_addr = 0;

// SW6303 寄存器数据
volatile uint8_t sw6303_regs[256] = {0};
volatile uint8_t sw6303_reg_addr = 0;

// 统计信息
volatile uint32_t sw6301_read_count = 0;
volatile uint32_t sw6301_write_count = 0;
volatile uint32_t sw6303_read_count = 0;
volatile uint32_t sw6303_write_count = 0;

// ==================== 初始化寄存器 ====================
void init_registers() {
    // SW6301 初始值 (升压IC)
    sw6301_regs[REG_SW6301_OUTPUT_VOL] = 0x4B;  // 5V 输出
    sw6301_regs[REG_SW6301_OUTPUT_CUR] = 0x00;  // 500mA
    sw6301_regs[REG_SW6301_STATUS]      = 0x00;  // 正常

    // SW6303 初始值 (充电IC)
    sw6303_regs[REG_SW6303_INPUT_VOL]  = 0x20;  // 12V 输入
    sw6303_regs[REG_SW6303_CHG_CUR]    = 0x00;  // 默认充电电流
    sw6303_regs[REG_SW6303_STATUS]     = 0x01;  // 充电中
}

// ==================== SW6301 回调函数 ====================
void sw6301_receive(int byteCount) {
    sw6301_reg_addr = Wire.read();

    if (byteCount > 1) {
        // 写操作
        uint8_t value = Wire.read();
        sw6301_regs[sw6301_reg_addr] = value;
        sw6301_write_count++;

        Serial.print("[SW6301] 写入: 0x");
        Serial.print(sw6301_reg_addr, HEX);
        Serial.print(" = 0x");
        Serial.println(value, HEX);

        // 根据寄存器执行相应动作
        handle_sw6301_write(sw6301_reg_addr, value);
    }
}

void sw6301_request() {
    uint8_t value = sw6301_regs[sw6301_reg_addr];
    Wire.write(value);
    sw6301_read_count++;

    Serial.print("[SW6301] 读取: 0x");
    Serial.print(sw6301_reg_addr, HEX);
    Serial.print(" = 0x");
    Serial.println(value, HEX);
}

void handle_sw6301_write(uint8_t reg, uint8_t value) {
    switch (reg) {
        case REG_SW6301_OUTPUT_VOL:
            Serial.print("    → 设置输出电压: ");
            Serial.println(value == 0x4B ? "5V" :
                          value == 0x6B ? "9V" :
                          value == 0x7B ? "12V" : "未知");
            break;

        case REG_SW6301_OUTPUT_CUR:
            Serial.print("    → 设置输出电流: ");
            Serial.print(value * 100);
            Serial.println("mA");
            break;

        case REG_SW6301_STATUS:
            Serial.print("    → 状态寄存器: 0x");
            Serial.println(value, HEX);
            break;
    }
}

// ==================== SW6303 回调函数 ====================
void sw6303_receive(int byteCount) {
    sw6303_reg_addr = Wire.read();

    if (byteCount > 1) {
        // 写操作
        uint8_t value = Wire.read();
        sw6303_regs[sw6303_reg_addr] = value;
        sw6303_write_count++;

        Serial.print("[SW6303] 写入: 0x");
        Serial.print(sw6303_reg_addr, HEX);
        Serial.print(" = 0x");
        Serial.println(value, HEX);

        // 根据寄存器执行相应动作
        handle_sw6303_write(sw6303_reg_addr, value);
    }
}

void sw6303_request() {
    uint8_t value = sw6303_regs[sw6303_reg_addr];
    Wire.write(value);
    sw6303_read_count++;

    Serial.print("[SW6303] 读取: 0x");
    Serial.print(sw6303_reg_addr, HEX);
    Serial.print(" = 0x");
    Serial.println(value, HEX);
}

void handle_sw6303_write(uint8_t reg, uint8_t value) {
    switch (reg) {
        case REG_SW6303_INPUT_VOL:
            Serial.print("    → 设置输入电压: ");
            Serial.println((value & 0x01) ? "12.6V" : "12V");
            break;

        case REG_SW6303_CHG_CUR:
            Serial.print("    → 设置充电电流: ");
            Serial.print(value * 100);
            Serial.println("mA");
            break;

        case REG_SW6303_STATUS:
            Serial.print("    → 充电状态: ");
            Serial.println(value == 0x01 ? "充电中" :
                          value == 0x00 ? "未充电" : "其他");
            break;
    }
}

// ==================== 串口命令处理 ====================
void handle_serial_command() {
    if (!Serial.available()) return;

    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    cmd.toLowerCase();

    if (cmd == "help" || cmd == "h") {
        print_help();
    }
    else if (cmd == "status" || cmd == "s") {
        print_status();
    }
    else if (cmd == "stats") {
        print_statistics();
    }
    else if (cmd.startsWith("set ")) {
        handle_set_command(cmd);
    }
    else if (cmd.startsWith("sim ")) {
        handle_sim_command(cmd);
    }
    else if (cmd == "clear") {
        sw6301_read_count = 0;
        sw6301_write_count = 0;
        sw6303_read_count = 0;
        sw6303_write_count = 0;
        Serial.println("统计信息已清除");
    }
    else {
        Serial.println("未知命令，输入 'help' 查看帮助");
    }
}

void print_help() {
    Serial.println("\n=== 命令帮助 ===");
    Serial.println("help, h          - 显示帮助");
    Serial.println("status, s        - 显示寄存器状态");
    Serial.println("stats            - 显示通信统计");
    Serial.println("clear            - 清除统计信息");
    Serial.println("set <reg> <val>  - 设置寄存器值");
    Serial.println("                  例: set sw6301 0x02 0x4B");
    Serial.println("sim <event>      - 模拟事件");
    Serial.println("                  例: sim overtemp (过温)");
    Serial.println("                  例: sim overcurr (过流)");
    Serial.println("                  例: sim normal (恢复正常)");
    Serial.println();
}

void print_status() {
    Serial.println("\n=== SW6301 状态 (升压IC) ===");
    Serial.print("输出电压: ");
    Serial.println(sw6301_regs[REG_SW6301_OUTPUT_VOL] == 0x4B ? "5V" :
                  sw6301_regs[REG_SW6301_OUTPUT_VOL] == 0x6B ? "9V" :
                  sw6301_regs[REG_SW6301_OUTPUT_VOL] == 0x7B ? "12V" : "未知");

    Serial.print("输出电流: ");
    Serial.print(sw6301_regs[REG_SW6301_OUTPUT_CUR] * 100);
    Serial.println("mA");

    Serial.print("状态: 0x");
    Serial.println(sw6301_regs[REG_SW6301_STATUS], HEX);

    Serial.println("\n=== SW6303 状态 (充电IC) ===");
    Serial.print("输入电压: ");
    Serial.println((sw6303_regs[REG_SW6303_INPUT_VOL] & 0x01) ? "12.6V" : "12V");

    Serial.print("充电电流: ");
    Serial.print(sw6303_regs[REG_SW6303_CHG_CUR] * 100);
    Serial.println("mA");

    Serial.print("充电状态: ");
    Serial.println(sw6303_regs[REG_SW6303_STATUS] == 0x01 ? "充电中" : "未充电");
    Serial.println();
}

void print_statistics() {
    Serial.println("\n=== 通信统计 ===");
    Serial.println("SW6301:");
    Serial.print("  读取: ");
    Serial.println(sw6301_read_count);
    Serial.print("  写入: ");
    Serial.println(sw6301_write_count);

    Serial.println("SW6303:");
    Serial.print("  读取: ");
    Serial.println(sw6303_read_count);
    Serial.print("  写入: ");
    Serial.println(sw6303_write_count);
    Serial.println();
}

void handle_set_command(String cmd) {
    cmd.remove(0, 4); // 移除 "set "

    int space1 = cmd.indexOf(' ');
    int space2 = cmd.indexOf(' ', space1 + 1);

    if (space1 == -1 || space2 == -1) {
        Serial.println("格式错误: set <芯片> <寄存器> <值>");
        return;
    }

    String chip = cmd.substring(0, space1);
    String reg_str = cmd.substring(space1 + 1, space2);
    String val_str = cmd.substring(space2 + 1);

    uint8_t reg = (uint8_t)strtol(reg_str.c_str(), NULL, 0);
    uint8_t val = (uint8_t)strtol(val_str.c_str(), NULL, 0);

    if (chip == "sw6301") {
        sw6301_regs[reg] = val;
        Serial.print("SW6301[0x");
        Serial.print(reg, HEX);
        Serial.print("] = 0x");
        Serial.println(val, HEX);
    }
    else if (chip == "sw6303") {
        sw6303_regs[reg] = val;
        Serial.print("SW6303[0x");
        Serial.print(reg, HEX);
        Serial.print("] = 0x");
        Serial.println(val, HEX);
    }
    else {
        Serial.println("未知芯片，请使用 sw6301 或 sw6303");
    }
}

void handle_sim_command(String cmd) {
    cmd.remove(0, 4); // 移除 "sim "
    cmd.toLowerCase();

    if (cmd == "normal") {
        // 恢复正常状态
        sw6301_regs[REG_SW6301_STATUS] = 0x00;
        sw6303_regs[REG_SW6303_STATUS] = 0x01;
        Serial.println("→ 模拟: 正常状态");
    }
    else if (cmd == "overtemp") {
        // 过温保护
        sw6301_regs[REG_SW6301_STATUS] |= 0x04;
        sw6303_regs[REG_SW6303_STATUS] = 0x00;
        Serial.println("→ 模拟: 过温保护");
    }
    else if (cmd == "overcurr") {
        // 过流保护
        sw6301_regs[REG_SW6301_STATUS] |= 0x02;
        Serial.println("→ 模拟: 过流保护");
    }
    else if (cmd == "no_battery") {
        // 无电池
        sw6303_regs[REG_SW6303_STATUS] = 0x00;
        Serial.println("→ 模拟: 无电池");
    }
    else if (cmd == "charging") {
        // 充电中
        sw6303_regs[REG_SW6303_STATUS] = 0x01;
        Serial.println("→ 模拟: 充电中");
    }
    else {
        Serial.println("未知事件");
        Serial.println("可用事件: normal, overtemp, overcurr, no_battery, charging");
    }
}

// ==================== 主函数 ====================
void setup() {
    Serial.begin(SERIAL_BAUD);
    while (!Serial) {
        ; // 等待串口连接
    }

    Serial.println("\n╔═══════════════════════════════════════╗");
    Serial.println("║   mini-Lite IIC 模拟器                ║");
    Serial.println("║   模拟 SW6301 + SW6303                 ║");
    Serial.println("╚═══════════════════════════════════════╝");

    // 初始化寄存器
    init_registers();

    // 初始化 IIC (作为从设备)
    Wire.begin(ADDR_SW6301);  // 先作为 SW6301
    Wire.onReceive(sw6301_receive);
    Wire.onRequest(sw6301_request);

    Serial.print("SW6301 (0x14B) 已启动在地址: 0x");
    Serial.println(ADDR_SW6301, HEX);

    // 注意: Arduino 标准库不支持同一总线多地址
    // 需要切换地址或使用第三方库

    Serial.println("\n输入 'help' 查看命令列表");
    Serial.println("==========================================\n");
}

void loop() {
    // 处理串口命令
    if (Serial.available()) {
        handle_serial_command();
    }

    // 可以在这里添加其他功能
    delay(10);
}
