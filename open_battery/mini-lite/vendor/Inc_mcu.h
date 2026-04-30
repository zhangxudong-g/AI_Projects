/**
 * @file    Inc_mcu.h
 * @brief   SH68F06 MCU 寄存器定义
 * @note    需从中颖电子官方 SDK 获取完整版本替换本文件
 *          以下定义从代码和 lst 文件中提取，仅供编译参考
 *          实际 SFR 地址需参考 SH68F06 数据手册
 */

#ifndef __INC_MCU_H
#define __INC_MCU_H

#include <reg51.h>

/* ========== GPIO 端口寄存器 ========== */
/* P0 端口 */
sfr P0       = 0x80;   /* P0 端口数据寄存器 */
sbit P00     = P0^0;   /* P0.0 - 按键控制 / DC_EN */
sbit P01     = P0^1;   /* P0.1 - UART TX (TX0) */
sbit P02     = P0^2;   /* P0.2 - UART TX0 功能复用 */
sbit P03     = P0^3;   /* P0.3 */
sbit P04     = P0^4;   /* P0.4 */
sbit P05     = P0^5;   /* P0.5 - IIC3 SDA/SCL */
sbit P06     = P0^6;   /* P0.6 - 无线充电检测 / IRQ */
sbit P07     = P0^7;   /* P0.7 - IIC1 SCL */

/* P1 端口 */
sfr P1       = 0x90;   /* P1 端口数据寄存器 */
sbit P10     = P1^0;   /* P1.0 - IIC1 SDA */
sbit P11     = P1^1;   /* P1.1 - LED3 */
sbit P12     = P1^2;   /* P1.2 - LED2 */
sbit P13     = P1^3;   /* P1.3 - 按键 (KEY) */
sbit P14     = P1^4;   /* P1.4 - 充电指示LED */
sbit P15     = P1^5;   /* P1.5 - LED2 */
sbit P16     = P1^6;   /* P1.6 - LED1 / ADC输入 */
sbit P17     = P1^7;   /* P1.7 - LED1 */

/* P2 端口 */
sfr P2       = 0xA0;   /* P2 端口数据寄存器 */
sbit P20     = P2^0;   /* P2.0 - IRQ / 无线充电检测 */
sbit P21     = P2^1;   /* P2.1 - 底座检测输入 */

/* ========== GPIO 方向/功能控制寄存器 ========== */
/* 端口输出使能 (0=输出使能, 1=输出禁止) */
sfr P00_OE   = 0xF0;   /* P0.0 输出使能 */
sfr P01_OE   = 0xF1;   /* P0.1 输出使能 */
sfr P02_OE   = 0xF2;   /* P0.2 输出使能 */
sfr P03_OE   = 0xF3;   /* P0.3 输出使能 */
sfr P04_OE   = 0xF4;   /* P0.4 输出使能 */
sfr P05_OE   = 0xF5;   /* P0.5 输出使能 */
sfr P06_OE   = 0xF6;   /* P0.6 输出使能 */
sfr P07_OE   = 0xF7;   /* P0.7 输出使能 */

/* 端口输入使能 (0=输入禁止, 1=输入使能) */
sfr P00_IE   = 0xE0;   /* P0.0 输入使能 */
sfr P01_IE   = 0xE1;   /* P0.1 输入使能 */
sfr P02_IE   = 0xE2;   /* P0.2 输入使能 */
sfr P03_IE   = 0xE3;   /* P0.3 输入使能 */
sfr P04_IE   = 0xE4;   /* P0.4 输入使能 */
sfr P05_IE   = 0xE5;   /* P0.5 输入使能 */
sfr P06_IE   = 0xE6;   /* P0.6 输入使能 */
sfr P07_IE   = 0xE7;   /* P0.7 输入使能 */

/* 端口功能选择寄存器 */
sfr P02_FUN  = 0xF8;   /* P0.2 功能选择 */

/* 端口上拉使能寄存器 */
sfr P06_PU   = 0xFC;   /* P0.6 上拉使能 */
sfr P13_PU   = 0xFD;   /* P1.3 上拉使能 */
sfr P20_PU   = 0xFE;   /* P2.0 上拉使能 */
sfr P21_PU   = 0xFF;   /* P2.1 上拉使能 */

/* ========== GPIO 控制宏定义 ========== */
/* 输出使能 */
#define P00_OUT_EN      P00_OE &= ~0x01
#define P01_OUT_EN      P01_OE &= ~0x01
#define P02_OUT_EN      P02_OE &= ~0x01
#define P03_OUT_EN      P03_OE &= ~0x01
#define P04_OUT_EN      P04_OE &= ~0x01
#define P05_OUT_EN      P05_OE &= ~0x01
#define P06_OUT_EN      P06_OE &= ~0x01
#define P07_OUT_EN      P07_OE &= ~0x01
#define P10_OUT_EN      P1   &= ~0x01; /* 注意: 地址需确认 */
#define P11_OUT_EN      P1   &= ~0x02
#define P12_OUT_EN      P1   &= ~0x04
#define P13_OUT_EN      P1   &= ~0x08
#define P14_OUT_EN      P1   &= ~0x10
#define P15_OUT_EN      P1   &= ~0x20
#define P16_OUT_EN      P1   &= ~0x40
#define P17_OUT_EN      P1   &= ~0x80
#define P20_OUT_EN      P2   &= ~0x01
#define P21_OUT_EN      P2   &= ~0x02

/* 输出禁止 */
#define P00_OUT_DIS     P00_OE |= 0x01
#define P01_OUT_DIS     P01_OE |= 0x01
#define P02_OUT_DIS     P02_OE |= 0x01
#define P03_OUT_DIS     P03_OE |= 0x01
#define P04_OUT_DIS     P04_OE |= 0x01
#define P05_OUT_DIS     P05_OE |= 0x01
#define P06_OUT_DIS     P06_OE |= 0x01
#define P07_OUT_DIS     P07_OE |= 0x01
#define P10_OUT_DIS     P1   |= 0x01
#define P11_OUT_DIS     P1   |= 0x02
#define P12_OUT_DIS     P1   |= 0x04
#define P13_OUT_DIS     P1   |= 0x08
#define P14_OUT_DIS     P1   |= 0x10
#define P15_OUT_DIS     P1   |= 0x20
#define P16_OUT_DIS     P1   |= 0x40
#define P17_OUT_DIS     P1   |= 0x80
#define P20_OUT_DIS     P2   |= 0x01
#define P21_OUT_DIS     P2   |= 0x02

/* 输入使能 */
#define P00_IN_EN       P00_IE |= 0x01
#define P01_IN_EN       P01_IE |= 0x01
#define P02_IN_EN       P02_IE |= 0x01
#define P03_IN_EN       P03_IE |= 0x01
#define P04_IN_EN       P04_IE |= 0x01
#define P05_IN_EN       P05_IE |= 0x01
#define P06_IN_EN       P06_IE |= 0x01
#define P07_IN_EN       P07_IE |= 0x01
#define P10_IN_EN       /* 需确认地址 */
#define P13_IN_EN       P13_PU |= 0x01   /* 需确认 */
#define P15_IN_EN       /* 需确认地址 */
#define P16_IN_EN       P16   |= 0x01    /* 需确认 */
#define P20_IN_EN       P20_PU |= 0x01   /* 需确认 */
#define P21_IN_EN       P21_PU |= 0x01   /* 需确认 */

/* 输入禁止 */
#define P00_IN_DIS      P00_IE &= ~0x01
#define P01_IN_DIS      P01_IE &= ~0x01
#define P02_IN_DIS      P02_IE &= ~0x01
#define P03_IN_DIS      P03_IE &= ~0x01
#define P04_IN_DIS      P04_IE &= ~0x01
#define P05_IN_DIS      P05_IE &= ~0x01
#define P06_IN_DIS      P06_IE &= ~0x01
#define P07_IN_DIS      P07_IE &= ~0x01
#define P15_IN_DIS      /* 需确认地址 */
#define P16_IN_DIS      P16   &= ~0x01    /* 需确认 */

/* 上拉使能 */
#define P06_PU_EN       P06_PU |= 0x01
#define P13_PU_EN       P13_PU |= 0x01
#define P20_PU_EN       P20_PU |= 0x01
#define P21_PU_EN       P21_PU |= 0x01

/* 功能选择 */
#define P02_SET         P02 = 1           /* P02 置位 */
#define P02_FUN_TX0     P02_FUN = 0x01    /* P02 复用为 UART0 TX */

/* ========== 中断系统寄存器 ========== */
/* 中断使能寄存器 */
sfr IE0      = 0xA8;   /* 中断使能 0 */
sfr IE1      = 0xB8;   /* 中断使能 1 */
sfr EIE      = 0xE8;   /* 扩展中断使能 */

/* 中断优先级寄存器 */
sfr IP0      = 0xB8;   /* 中断优先级 0 */
sfr IP1      = 0xB9;   /* 中断优先级 1 */

/* 中断标志寄存器 */
sfr IOINT0_IF = 0x00;  /* IO 中断标志寄存器 (需确认地址) */

/* 中断使能控制位 */
#define INT0_EN         IE0 |= 0x01       /* 外部中断0 使能 */
#define INT1_EN         IE0 |= 0x04       /* 外部中断1 使能 (Timer0) */
#define INT5_EN         EIE |= 0x20       /* UART 中断使能 */
#define GIE_EN          IE0 |= 0x80       /* 全局中断使能 */

/* 中断标志清除 */
#define P06_INT_IF_CLR  IOINT0_IF &= ~0x01
#define P20_INT_IF_CLR  IOINT0_IF &= ~0x02

/* 下降沿触发 */
#define P06_NEG_INT_EN  /* 需确认寄存器 */
#define P20_NEG_INT_EN  /* 需确认寄存器 */
#define P13_NEG_INT_EN  /* 需确认寄存器 */

/* ========== 定时器寄存器 ========== */
sfr TMR0_CY  = 0x00;   /* TMR0 周期寄存器 (需确认地址) */
sfr TMR0_C0  = 0x00;   /* TMR0 控制寄存器0 (需确认地址) */

/* 定时器控制宏 */
#define TMR0_EN         /* 使能 TMR0 (需确认) */
#define TMR0_DIS        /* 禁止 TMR0 (需确认) */
#define TMR0_INT_EN     IE0 |= 0x02       /* TMR0 中断使能 */

/* 定时器中断标志 */
sbit TMR0_IF  = PSW^0;  /* TMR0 中断标志 (需确认) */

/* ========== 时钟控制寄存器 ========== */
sfr CLK_PR   = 0x00;    /* 时钟保护寄存器 (需确认地址) */
sfr CLK_C0   = 0x00;    /* 时钟控制寄存器0 (需确认地址) */

#define SYSCK_DIV4      CLK_C0 = 0x02    /* 系统时钟4分频: 16MHz/4=4MHz */

/* ========== ADC 寄存器 ========== */
sfr ADC_CON  = 0x00;    /* ADC 控制寄存器 (需确认地址) */
sfr ADC_DH   = 0x00;    /* ADC 结果高字节 (需确认地址) */
sfr ADC_DL   = 0x00;    /* ADC 结果低字节 (需确认地址) */

/* ADC 控制宏 */
#define ADC_EN          ADC_CON |= 0x80   /* ADC 使能 */
#define ADC_DIS         ADC_CON &= ~0x80  /* ADC 禁止 */
#define VREF_EN         ADC_CON |= 0x40   /* 参考电压使能 */
#define ADC_SOFT_TG     ADC_CON |= 0x01   /* 软件触发转换 */
#define ADC_WAIT        while(!(ADC_CON & 0x10))  /* 等待转换完成 */
#define ADC_INT_IF_CLR  ADC_CON &= ~0x20  /* 清除ADC中断标志 */

/* ADC 通道/模式选择 */
#define ADC_VDD_DIV4        ADC_CON = (ADC_CON & 0xF0) | 0x00  /* VDD/4 通道 */
#define ADC_P16_AN10        ADC_CON = (ADC_CON & 0xF0) | 0x0A  /* P16 AN10 通道 */
#define ADC_P15_AN11        ADC_CON = (ADC_CON & 0xF0) | 0x0B  /* P15 AN11 通道 */
#define ADC_RVDD_AVG8       ADC_CON = (ADC_CON & 0x0F) | 0x00  /* VDD参考 8次平均 */
#define ADC_RVREF25_AVG8    ADC_CON = (ADC_CON & 0x0F) | 0x00  /* 内部2.5V参考 8次平均 */

/* ========== UART0 寄存器 ========== */
sfr UART0_TXB = 0x00;    /* UART0 发送缓冲 (需确认地址) */
sfr UART0_BRL = 0x00;    /* UART0 波特率低字节 (需确认地址) */
sfr UART0_BRH = 0x00;    /* UART0 波特率高字节 (需确认地址) */
sfr UART0_CON = 0x00;    /* UART0 控制寄存器 (需确认地址) */

/* UART 控制宏 */
#define UART0_RX8           UART0_CON |= 0x00   /* 8位接收 (需确认) */
#define UART0_TX8_1S        UART0_CON |= 0x00   /* 8位发送+1停止位 (需确认) */
#define UART0_RX0_INT_EN    UART0_CON |= 0x80   /* 接收中断使能 (需确认) */

/* UART 标志位 */
sbit RX0_IF   = PSW^1;    /* UART0 接收中断标志 (需确认) */
sbit TX0_IF   = PSW^2;    /* UART0 发送中断标志 (需确认) */

/* ========== 看门狗寄存器 ========== */
sfr WDT_C    = 0x00;      /* 看门狗控制寄存器 (需确认地址) */

#define CLR_WDT         WDT_C = 0x00    /* 清除看门狗 (需确认值) */

/* ========== 低功耗模式控制 ========== */
#define SLEEP_MD        PCON |= 0x01    /* 进入睡眠模式 (需确认) */
#define WKUP_T_8US      /* 8us唤醒定时器 (需确认) */

/* ========== LED 宏定义 ========== */
#define LED1            P17             /* LED1 引脚 */
#define LED2            P12             /* LED2 引脚 */
#define LED3            P11             /* LED3 引脚 */

#define LED1_OUT        P17_OUT_EN      /* LED1 输出模式 */
#define LED2_OUT        P12_OUT_EN      /* LED2 输出模式 */
#define LED3_OUT        P11_OUT_EN      /* LED3 输出模式 */
#define LED1_IN         P17_IN_EN       /* LED1 输入模式 (高阻) */
#define LED2_IN         P12_IN_EN       /* LED2 输入模式 (高阻) */
#define LED3_IN         P11_IN_EN       /* LED3 输入模式 (高阻) */

/* ========== NOP 定义 ========== */
#define NOP()           _nop_()         /* 空操作指令 */

#endif /* __INC_MCU_H */
