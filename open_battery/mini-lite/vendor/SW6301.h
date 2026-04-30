/**
 * @file    SW6301.h
 * @brief   SW6301 升压输出IC驱动函数声明
 * @note    SW6301 通过 IIC1 总线通信，设备地址 0x14B (10位)
 *          IIC 操作通过 config.h 中定义的 IIC_ADDRESS/IIC_DAT 进行
 */

#ifndef __SW6301_H
#define __SW6301_H

#include "config.h"
#include "iic_1.h"

/* ========== SW6301 寄存器地址定义 ========== */
#define SW6301_REG_STATUS      0x19   /* 状态寄存器 */
#define SW6301_REG_PORT        0x1D   /* 端口状态 */
#define SW6301_REG_PAGE_CTRL   0x23   /* 页面控制 (关闭过流保护等) */
#define SW6301_REG_PAGE_SEL    0x24   /* 页面选择 */
#define SW6301_REG_CHIP_RST    0x25   /* 芯片复位指示 */
#define SW6301_REG_INT_CTRL    0x28   /* 中断控制 (关充/开充/关放电/开放电) */
#define SW6301_REG_PD_SC       0x2E   /* PD Source Cap */
#define SW6301_REG_PD_SC_UFCS  0x2F   /* UFCS Source Cap */
#define SW6301_REG_PORT_2B     0x2B   /* 端口寄存器 2B */
#define SW6301_REG_PORT_2C     0x2C   /* 端口寄存器 2C */
#define SW6301_REG_A4          0xA4   /* 充放电控制/输入状态 */
#define SW6301_REG_A5          0xA5   /* ADC电压低8位 */
#define SW6301_REG_A6          0xA6   /* ADC电压高4位 */
#define SW6301_REG_COULOMB_86  0x86   /* 库仑计最大值低8位 */
#define SW6301_REG_COULOMB_87  0x87   /* 库仑计最大值高8位 */
#define SW6301_REG_COULOMB_88  0x88   /* 当前库仑计低8位 */
#define SW6301_REG_COULOMB_89  0x89   /* 当前库仑计中8位 */
#define SW6301_REG_COULOMB_8A  0x8A   /* 当前库仑计高8位 */
#define SW6301_REG_VBAT_30     0x30   /* 电池电压采样控制 */
#define SW6301_REG_VBAT_31     0x31   /* 电池电压低8位 */
#define SW6301_REG_VBAT_32     0x32   /* 电池电压高4位 */
#define SW6301_REG_INPUT_PWR   0x45   /* 输入功率限制 */
#define SW6301_REG_OUTPUT_PWR  0x4F   /* 输出功率限制 */
#define SW6301_REG_99          0x99   /* 电量百分比读取 */

/* ========== 初始化和控制函数 ========== */

/**
 * @brief  SW6301 芯片初始化
 * @note   配置所有寄存器，包括协议、保护、功率限制等
 */
void SW6301_INIT(void);

/**
 * @brief  设置页面为高位地址模式
 * @note   用于访问 0x100 以上的扩展寄存器
 */
void SW6301_SET_H(void);

/**
 * @brief  设置页面为低位地址模式
 * @note   用于访问 0xFF 以下的普通寄存器
 */
void SW6301_SET_L(void);

/* ========== 功率控制函数 ========== */

/**
 * @brief  设置 SW6301 输出功率为 65W
 */
void SW6301_SET_OUTPUT_POWER_65W(void);

/**
 * @brief  设置 SW6301 输入功率为 65W
 */
void SW6301_SET_INTPUT_POWER_65W(void);

/**
 * @brief  设置 SW6301 输入功率为 30W
 */
void SW6301_SET_INTPUT_POWER_30W(void);

/* ========== 中断控制函数 ========== */

/**
 * @brief  关闭充电 (关闭中断)
 */
void SW6301_SET_GUAN_INT(void);

/**
 * @brief  开启充电 (开启中断)
 */
void SW6301_SET_KAI_INT(void);

/**
 * @brief  关闭充放电
 */
void SW6301_SET_GUAN_INT_OUT(void);

/**
 * @brief  开启充放电
 */
void SW6301_SET_KAI_INT_OUT(void);

/* ========== 状态读取函数 ========== */

/**
 * @brief  获取电池电压 (VBAT)
 * @return 电池电压 ADC 值 (需乘以7得到实际mV)
 */
unsigned int SW6301_GET_VBAT(void);

/**
 * @brief  获取 SW6301 充放电状态
 * @return 状态值: bit0=放电指示(0x20), bit1=SINK指示(0x10)
 */
unsigned char SW6301_GET_STASE(void);

/**
 * @brief  获取 SW6301 端口连接状态
 * @return 端口状态 (bit0=C1, bit4/5=其他)
 */
unsigned char SW6301_GET_PORT(void);

/**
 * @brief  读取 SW6301 0xA4 寄存器并设置 bit1
 */
void SW6301_A4_BIT1(void);

/**
 * @brief  读取 SW6301 0xA4 寄存器并设置 bit0
 */
void SW6301_A4_BIT0(void);

/**
 * @brief  设置 SW6301 输入电压/电流状态
 * @param  adc_va  ADC 电压值
 * @param  VA      充放电方向: 0=充电, 1=放电
 */
void SW6301_INPUT_STATUS(unsigned int adc_va, unsigned char VA);

/**
 * @brief  读取 SW6301 电量百分比
 * @return 电量值 (0-100)
 */
unsigned char SW6301_read(void);

/* ========== 库仑计函数 ========== */

/**
 * @brief  获取库仑计数据
 * @note   读取结果存入全局变量:
 *         max_coulomb - 最大库仑计值
 *         Current_max_coulomb - 当前库仑计值
 *         Current_max_coulomb1 - 当前库仑计低8位缓存
 */
void GET_Coulomb_meter_VALUE(void);

/* ========== 复位检测函数 ========== */

/**
 * @brief  检测 SW6301 是否发生复位
 * @note   检测 0x25 寄存器 bit7，若为0则重新初始化
 *         复位计数存入 SW6301_25_FLAY
 */
void SW6301_GET_RESET(void);

#endif /* __SW6301_H */
