#include "LED.h"
#include "IIC.h"
#include "KEY.h"
#include "LED.h"
u8 dai_ji_cnt;

void sleep()
{
		if((!dis_charge)&&(!f_charge))
		{
					dai_ji_cnt++;
					if(dai_ji_cnt >= 60)
				{		
									dai_ji_cnt = 0;	
					
//									  SCL_IN;
//										SDA_IN;
//										
//										LED1 = 0;
//										LED2 = 0;
//										LED3 = 0;
//										LED4 = 0;
//					
//										TMR0_DIS;
//										TMR0_INT_DIS;
					
//										P2_DAT= 0X00;
//					
//										WDT_DIS;
										CLR_WDT;
										R_Address=0x0C; // INDTA1泄放电压 开
										IIC_ReadByte();	
										R_Value |= (1<<1);		
										IIC_WriteByte();

										R_Address=0x0C; // VBUS泄放电压 开
										IIC_ReadByte();	
										R_Value |= (1<<3);		
										IIC_WriteByte();										

										delay_1ms(500);

										R_Address=0x0C; // VBUS泄放电压 开
										IIC_ReadByte();	
										R_Value &= ~(1<<3);		
										IIC_WriteByte();
										
										R_Address=0x0C; // INDTA1泄放电压 关
										IIC_ReadByte();	
										R_Value &= ~(1<<1);
										IIC_WriteByte();				

										R_Address=0x04; // 
										IIC_ReadByte();	
										R_Value |= (1<<0);
										IIC_WriteByte();	
										
										R_Address=0x18; // 负载接入检测使能
										IIC_ReadByte();	
										R_Value &= ~(1<<1);
										IIC_WriteByte();	
										
										R_Address=0x18; // 负载接入检测使能
										IIC_ReadByte();	
										R_Value |= (1<<1);
										IIC_WriteByte();	
										
										R_Address=0x02; // 负载接入检测中断使能
										IIC_ReadByte();	
										R_Value &= ~(1<<0);
										IIC_WriteByte();					

										R_Address=0x18; // 低功耗模式使能
										IIC_ReadByte();	
										R_Value &= ~(1<<4);
										IIC_WriteByte();
										
										
										WKUP_T_8US;
										SLEEP_MD;
										NOP();
					
//										TMR0_EN;
//										TMR0_INT_EN;
								
//										PowerOn_Chk();
										
										CLR_WDT;
										dai_ji_cnt = 0;
					
										
																				
										
					
								
				}
		}
		else dai_ji_cnt = 0;
}