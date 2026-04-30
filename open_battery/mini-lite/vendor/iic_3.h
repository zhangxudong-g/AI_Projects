/**
 * @file    iic_3.h
 * @brief   IIC3 总线驱动 (软件模拟)
 * @note    IIC3 预留总线，具体连接设备待确认
 *          引脚定义在 Inc_mcu.h 中
 */

#ifndef __IIC_3_H
#define __IIC_3_H

#include "Inc_mcu.h"
#include "delay.h"
#include "config.h"

/* ========== IIC3 引脚定义 ========== */
/* 以下宏需根据实际硬件连接修改 */
#define IIC3_SCL        P04         /* IIC3 时钟线 - P0.4 (需确认) */
#define IIC3_SDA        P03         /* IIC3 数据线 - P0.3 (需确认) */

/* 引脚方向控制 */
#define IIC3_SCL_Out()  P04_OUT_EN  /* SCL 设为输出 */
#define IIC3_SCL_In()   P04_IN_EN   /* SCL 设为输入 */
#define IIC3_SDA_Out()  P03_OUT_EN  /* SDA 设为输出 */
#define IIC3_SDA_In()   P03_IN_EN   /* SDA 设为输入 */

/* ========== IIC3 公共函数声明 ========== */

/**
 * @brief  IIC3 写一个字节到设备
 * @note   使用 IIC_ADDRESS, IIC_DAT, IIC3_ADDRESS0 全局变量
 *         IIC3_ADDRESS0: 设备从地址
 *         IIC_ADDRESS: 目标寄存器地址
 *         IIC_DAT: 要写入的数据
 */
void IIC3_WRITE(void);

/**
 * @brief  IIC3 从设备读一个字节
 * @note   使用 IIC_ADDRESS, IIC_DAT, IIC3_ADDRESS0 全局变量
 *         IIC3_ADDRESS0: 设备从地址
 *         IIC_ADDRESS: 目标寄存器地址
 *         IIC_DAT: 读取的数据 (返回值)
 */
void IIC3_READ(void);

#endif /* __IIC_3_H */
