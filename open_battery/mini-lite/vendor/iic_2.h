/**
 * @file    iic_2.h
 * @brief   IIC2 总线驱动 (软件模拟)
 * @note    IIC2 用于与 SW6303 通信
 *          引脚定义在 Inc_mcu.h 中
 */

#ifndef __IIC_2_H
#define __IIC_2_H

#include "Inc_mcu.h"
#include "delay.h"
#include "config.h"

/* ========== IIC2 引脚定义 ========== */
/* 以下宏需根据实际硬件连接修改 */
#define IIC2_SCL        P05         /* IIC2 时钟线 - P0.5 (需确认) */
#define IIC2_SDA        P06         /* IIC2 数据线 - P0.6 (需确认) */

/* 引脚方向控制 */
#define IIC2_SCL_Out()  P05_OUT_EN  /* SCL 设为输出 */
#define IIC2_SCL_In()   P05_IN_EN   /* SCL 设为输入 */
#define IIC2_SDA_Out()  P06_OUT_EN  /* SDA 设为输出 */
#define IIC2_SDA_In()   P06_IN_EN   /* SDA 设为输入 */

/* ========== SW6303 IIC 操作宏 ========== */
#define SW6303_IIC_READ()   IIC2_READ()   /* SW6303 IIC 读操作 */
#define SW6303_IIC_WRITE()  IIC2_WRITE()  /* SW6303 IIC 写操作 */

/* ========== IIC2 公共函数声明 ========== */

/**
 * @brief  IIC2 写一个字节到设备
 * @note   使用 IIC_ADDRESS 和 IIC_DAT 全局变量
 *         IIC_ADDRESS: 目标寄存器地址
 *         IIC_DAT: 要写入的数据
 */
void IIC2_WRITE(void);

/**
 * @brief  IIC2 从设备读一个字节
 * @note   使用 IIC_ADDRESS 和 IIC_DAT 全局变量
 *         IIC_ADDRESS: 目标寄存器地址
 *         IIC_DAT: 读取的数据 (返回值)
 */
void IIC2_READ(void);

#endif /* __IIC_2_H */
