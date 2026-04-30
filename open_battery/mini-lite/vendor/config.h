/**
 * @file    config.h
 * @brief   全局变量和配置声明
 * @note    所有模块共享的全局变量 extern 声明
 */

#ifndef __CONFIG_H
#define __CONFIG_H

#include "Inc_mcu.h"

/* ========== IIC 通信公共变量 ========== */
extern unsigned char IIC_ADDRESS;   /* IIC 寄存器地址 (16位地址, 低8位有效) */
extern unsigned char IIC_DAT;       /* IIC 读写数据缓冲 */

/* ========== IIC 设备地址常量 ========== */
extern unsigned char IIC1_ADDRESS0; /* IIC1 设备地址 (SW6301, 0x14B>>1=0x0A5 -> 0x29) */
extern unsigned char IIC2_ADDRESS0; /* IIC2 设备地址 (SW6303, 0x23) */
extern unsigned char IIC3_ADDRESS0; /* IIC3 设备地址 */

/* ========== 按键相关变量 ========== */
extern unsigned char key_time_flay; /* 按键计时使能标志 */
extern unsigned int  key_time_1ms;  /* 按键持续时间计数 (1ms精度) */
extern unsigned char key_sta;       /* 按键状态: 0=无, 1=短按, 2=长按 */
extern unsigned int  Cnt_Keys;      /* 按键扫描计数器 */

/* ========== 定时器相关变量 ========== */
extern unsigned int  power_time_1ms;    /* 电源处理周期计数 (1ms精度) */
extern unsigned int  sleep_time_1ms;    /* 睡眠计时 (1ms精度) */
extern unsigned int  LED_time_1ms;      /* LED 扫描周期计数 (1ms精度) */
extern unsigned int  VALUE_100_time;    /* 100% 电量显示计时 */

/* ========== 充电/放电状态变量 ========== */
extern unsigned char dizuo_flay;        /* 底座接入标志: 0=未接入, 1=已接入 */
extern unsigned int  PLUG_IN_TIME;      /* 插入事件计时 */
extern unsigned int  SLEED_TIME_S;      /* 睡眠超时时间 (单位: 1ms) */
extern unsigned char SLEED_FLAY;        /* 睡眠条件就绪标志 */
extern unsigned char VALUE_0_FLAY;      /* 电量为0标志 */
extern unsigned char power_level;       /* 电量百分比 (0-100) */

/* ========== 充电功率配置变量 ========== */
extern unsigned char POWE_16_1_NUM;     /* SW6301 (16脚) 配置功率值 */
extern unsigned char POWE_16_2_NUM;     /* SW6303 (16脚) 配置功率值 */
extern unsigned char POWE_16_2_A_NUM;   /* SW6303 A口配置功率值 */

/* ========== LED 显示变量 ========== */
extern unsigned char LED_Bright;        /* LED 亮度/显示模式控制字节 */
extern unsigned char VALUE_100;         /* 100% 电量显示状态: 0=正常, 1=计时中, 2=关灯, 3=过渡 */
extern unsigned char DIANLIANG;         /* 当前电量档位: 0=无, 1-4=对应电量 */
extern unsigned char LAST_DIANLIANG;    /* 上次电量档位 */

/* ========== NTC 温度检测变量 ========== */
extern unsigned char ntc_flay;          /* NTC 过温标志: 0=正常, 1=过温 */
extern unsigned char NTC_FLAY_ONE;      /* NTC 过温历史标志 (用于恢复判断) */
extern unsigned char ntc_time;          /* NTC 异常持续时间 */

/* ========== 端口状态变量 ========== */
extern unsigned char port_6301;         /* SW6301 端口状态 */
extern unsigned char port_6303;         /* SW6303 端口状态 */
extern unsigned char sta_6301;          /* SW6301 充放电状态 */
extern unsigned char sta_6303;          /* SW6303 充放电状态 */
extern unsigned char sw6301_num;        /* SW6301 配置模式: 1=充电, 2=按键5次 */

/* ========== ADC 相关变量 ========== */
extern unsigned int  tmp_data;          /* ADC 临时数据 */
extern unsigned int  VDD_data;          /* VDD ADC 值 */
extern float        dizuo_adc;          /* 底座 ADC 电压值 */
extern float        ntc_data;           /* NTC 电阻值 */

/* ========== 库仑计变量 ========== */
extern unsigned int  max_coulomb;           /* 最大库仑计值 */
extern unsigned int  Current_max_coulomb;   /* 当前库仑计值 */
extern unsigned char Current_max_coulomb1;  /* 当前库仑计低8位缓存 */
extern unsigned int  LAST_max_coulomb;      /* 上次最大库仑计值 */
extern unsigned int  LAST_Current_max_coulomb; /* 上次当前库仑计值 */

/* ========== UART 调试变量 ========== */
extern unsigned int  usart_power_level;     /* 串口发送的电量等级 */
extern unsigned int  usart_adc_value;       /* 串口发送的 ADC 值 */
extern unsigned int  usart_uart_vbat;       /* 串口发送的电池电压值 */
extern unsigned int  last_uart_value;       /* 上次串口发送的 ADC 值 */
extern unsigned int  last_uart_vbat;        /* 上次串口发送的电池电压值 */

/* ========== 中断相关变量 ========== */
extern unsigned char int_flay;              /* INT0 中断标志 */
extern unsigned char TIME_CCH_1MS;          /* 定时器周期计数 */

/* ========== SW6301 扩展全局变量 ========== */
extern unsigned char SW_2B_1;               /* SW6301 寄存器0x2B缓存 */
extern unsigned char SW_2C_1;               /* SW6301 寄存器0x2C缓存 */
extern unsigned int  SW6301_25_FLAY;        /* SW6301 0x25寄存器复位计数 */

/* ========== SW6303 扩展全局变量 ========== */
extern unsigned char SW_2B;                 /* SW6303 寄存器0x2B缓存 */
extern unsigned char SW_2C;                 /* SW6303 寄存器0x2C缓存 */
extern unsigned int  SW6303_25_FLAY;        /* SW6303 0x25寄存器复位计数 */

#endif /* __CONFIG_H */
