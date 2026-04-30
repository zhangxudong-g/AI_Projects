/**
 * @file    iic_1.h
 * @brief   IIC1 总线驱动 (软件模拟)
 * @note    IIC1 用于与 SW6301 通信
 *          引脚定义在 Inc_mcu.h 中
 */

#ifndef __IIC_1_H
#define __IIC_1_H

#include "Inc_mcu.h"
#include "delay.h"
#include "config.h"

/* ========== IIC1 引脚定义 ========== */
/* 以下宏需根据实际硬件连接修改 */
#define IIC1_SCL        P07         /* IIC1 时钟线 - P0.7 */
#define IIC1_SDA        P10         /* IIC1 数据线 - P1.0 */

/* 引脚方向控制 */
#define IIC1_SCL_Out()  P07_OUT_EN  /* SCL 设为输出 */
#define IIC1_SCL_In()   P07_IN_EN   /* SCL 设为输入 */
#define IIC1_SDA_Out()  P10_OUT_EN  /* SDA 设为输出 */
#define IIC1_SDA_In()   P10_IN_EN   /* SDA 设为输入 */

/* ========== SW6301 IIC 操作宏 ========== */
#define SW6301_IIC_READ()   IIC1_READ()   /* SW6301 IIC 读操作 */
#define SW6301_IIC_WRITE()  IIC1_WRITE()  /* SW6301 IIC 写操作 */

/* ========== IIC1 公共函数声明 ========== */

/**
 * @brief  IIC1 写一个字节到设备
 * @note   使用 IIC_ADDRESS 和 IIC_DAT 全局变量
 *         IIC_ADDRESS: 目标寄存器地址
 *         IIC_DAT: 要写入的数据
 */
void IIC1_WRITE(void);

/**
 * @brief  IIC1 从设备读一个字节
 * @note   使用 IIC_ADDRESS 和 IIC_DAT 全局变量
 *         IIC_ADDRESS: 目标寄存器地址
 *         IIC_DAT: 读取的数据 (返回值)
 */
void IIC1_READ(void);

#endif /* __IIC_1_H */
