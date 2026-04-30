/**
 * @file    delay.h
 * @brief   延时函数声明
 * @note    包含微秒级延时和看门狗清除
 */

#ifndef __DELAY_H
#define __DELAY_H

/**
 * @brief  微秒级延时
 * @param  Time 延时时间（单位：微秒），每次循环约1us (4MHz时钟)
 * @note   每次延时循环末尾会自动清除看门狗 (CLR_WDT)
 */
void DelayUs(unsigned int Time);

#endif /* __DELAY_H */
