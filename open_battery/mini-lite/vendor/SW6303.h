/**
 * @file    SW6303.h
 * @brief   SW6303 充电管理IC驱动函数声明
 * @note    SW6303 通过 IIC2 总线通信，设备地址 0x23 (7位)
 *          IIC 操作通过 config.h 中定义的 IIC_ADDRESS/IIC_DAT 进行
 */

#ifndef __SW6303_H
#define __SW6303_H

#include "config.h"
#include "iic_2.h"

/* ========== SW6303 寄存器地址定义 ========== */
#define SW6303_REG_STATUS      0x19   /* 状态寄存器 */
#define SW6303_REG_PORT        0x1D   /* 端口状态 */
#define SW6303_REG_PAGE_CTRL   0x23   /* 页面控制 (关闭过流保护等) */
#define SW6303_REG_PAGE_SEL    0x24   /* 页面选择 */
#define SW6303_REG_CHIP_RST    0x25   /* 芯片复位指示 */
#define SW6303_REG_INT_CTRL    0x28   /* 中断控制 (关充/开充/关放电/开放电) */
#define SW6303_REG_PD_SC       0x2E   /* PD Source Cap */
#define SW6303_REG_PD_SC_UFCS  0x2F   /* UFCS Source Cap */
#define SW6303_REG_PORT_2B     0x2B   /* 端口寄存器 2B */
#define SW6303_REG_PORT_2C     0x2C   /* 端口寄存器 2C */
#define SW6303_REG_OUTPUT_CTRL 0x21   /* 输出控制 */
#define SW6303_REG_IBAT_30     0x30   /* 充电电流采样控制 */
#define SW6303_REG_IBAT_31     0x31   /* 充电电流低8位 */
#define SW6303_REG_IBAT_32     0x32   /* 充电电流高4位 */
#define SW6303_REG_INPUT_PWR   0x45   /* 输入功率限制 */
#define SW6303_REG_OUTPUT_PWR  0x4F   /* 输出功率限制 */

/* ========== 初始化和控制函数 ========== */

/**
 * @brief  SW6303 芯片初始化
 * @note   配置所有寄存器，包括协议、保护、功率限制等
 */
void SW6303_INIT(void);

/**
 * @brief  设置页面为高位地址模式
 * @note   用于访问 0x100 以上的扩展寄存器
 */
void SW6303_SET_H(void);

/**
 * @brief  设置页面为低位地址模式
 * @note   用于访问 0xFF 以下的普通寄存器
 */
void SW6303_SET_L(void);

/* ========== 功率控制函数 ========== */

/**
 * @brief  设置 SW6303 输出功率为 45W
 */
void SW6303_SET_OUTPUT_POWER_45W(void);

/**
 * @brief  设置 SW6303 输出功率为 30W
 */
void SW6303_SET_OUTPUT_POWER_30W(void);

/**
 * @brief  设置 SW6303 A口输出功率为 30W (备用)
 */
void SW6303_SET_OUTPUT_POWER_30W_A(void);

/**
 * @brief  设置 SW6303 输入功率为 45W
 */
void SW6303_SET_INTPUT_POWER_45W(void);

/**
 * @brief  设置 SW6303 输入功率为 30W
 */
void SW6303_SET_INTPUT_POWER_30W(void);

/* ========== 中断控制函数 ========== */

/**
 * @brief  关闭充电 (关闭中断)
 */
void SW6303_SET_GUAN_INT(void);

/**
 * @brief  开启充电 (开启中断)
 */
void SW6303_SET_KAI_INT(void);

/**
 * @brief  关闭充放电
 */
void SW6303_SET_GUAN_INT_OUT(void);

/**
 * @brief  开启充放电
 */
void SW6303_SET_KAI_INT_OUT(void);

/* ========== 状态读取函数 ========== */

/**
 * @brief  获取 SW6303 充放电状态
 * @return 状态值: bit0=放电指示(0x80), bit1=SINK指示(0x40)
 */
unsigned char SW6303_GET_STASE(void);

/**
 * @brief  获取 SW6303 端口连接状态
 * @return 端口状态
 */
unsigned char SW6303_GET_PORT(void);

/**
 * @brief  获取 SW6303 充电电流 (IBAT)
 * @return 充电电流值 (已乘以5)
 */
unsigned int SW6303_GET_IBAT(void);

/**
 * @brief  关闭 SW6303 输出
 * @note   设置 0x21 寄存器 bit5
 */
void guang_shuchu(void);

/* ========== 复位检测函数 ========== */

/**
 * @brief  检测 SW6303 是否发生复位
 * @note   检测 0x25 寄存器 bit7，若为0则重新初始化
 *         复位计数存入 SW6303_25_FLAY
 */
void SW6303_GET_RESET(void);

#endif /* __SW6303_H */
