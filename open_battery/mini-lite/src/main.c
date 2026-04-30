/*********************************************************
*Copyright (C)
*文件名:
*作  者:
*版  本:	V1.00
*日  期:
*描  述:
*备  注:
**********************************************************/
#include "main.h"
#include "Inc_mcu.h"
#include "iic_2.h"
#include "iic_1.h"
#include "config.h"
#include "SW6301.h"
#include "SW6303.h"

/*********************************************************
函数名:	void main(void)
描  述:
输入值: 无
输出值: 无
返回值: 无
**********************************************************/
extern void SW6301_SET_L(void);
extern void SW6301_SET_H(void);
void IO_INIT(void)
{
	P06_IN_EN;   //IRQ	
	P06_PU_EN;   // 上拉
	P06_INT_IF_CLR;
	P06_NEG_INT_EN;	   // 下降沿触发	
	
	P20_IN_EN;   //IRQ	
	P20_PU_EN;   // 上拉
	P20_INT_IF_CLR;
	P20_NEG_INT_EN;	   // 下降沿触发	

	P13_IN_EN;   //IRQ	  按键
	P13_PU_EN;   // 上拉
	P13_INT_IF_CLR;
	P13_NEG_INT_EN;	   // 下降沿触发	
	
	INT0_EN;
	
	P21_IN_EN;   //  底座接入
	P21_PU_EN; 	
	
	P21_INT_IF_CLR;
	P21_NEG_INT_EN;	   // 下降沿触发		
	
	
	P17_OUT_EN;         // LED1
	P12_OUT_EN;         // LED2
	P11_OUT_EN;        	// LED3
	
	
	P15_OUT_EN;        	// P15
	P15_IN_DIS;
	
	P17_IN_DIS;
	P12_IN_DIS;	
	P11_IN_DIS;
	
	
	P00_OUT_EN;         
	P01_OUT_EN;         
	P02_OUT_EN;  
	P03_OUT_EN;	
	
	P00_IN_DIS;
	P01_IN_DIS;	
	P02_IN_DIS;
	P03_IN_DIS;	
	
	P14_OUT_EN;        
	P14_IN_DIS;	
	
	P14 = 0;
	
	P00 = 1;
	P01 = 0;
	P02 = 0;
	P03 = 0;
}

void ADC_INIT(void)
{
//	P16_IN_EN;
//	P00_IN_EN;
//	P15_IN_DIS
	P16_IN_DIS
	P16_OUT_DIS;	
//	P15_OUT_DIS;	
	VREF_EN;             //ADC参考使用配置
	ADC_EN;
	ADC_RVDD_AVG8;     //ADC 内部2.5v参考

}

unsigned int  tmp_data;
unsigned int  VDD_data;
float dizuo_adc;


unsigned int GET_VDD_VALUE(void)
{
	
//	P15_IN_DIS
	P16_IN_DIS
	P16_OUT_DIS;	
//	P15_OUT_DIS;	
	VREF_EN;             //ADC参考使用配置
	ADC_EN;
	ADC_RVDD_AVG8;     //ADC 内部2.5v参考	
	
	ADC_VDD_DIV4;	      //选择通道0
	DelayUs(1000);
	ADC_SOFT_TG;        //ADC启动
	ADC_WAIT;
	VDD_data = (ADC_DH << 8)| ADC_DL;
//	VDD_data = VDD_data <<8;
//	VDD_data = VDD_data | ADC_DL;
	VDD_data =VDD_data *4;
	ADC_INT_IF_CLR;    //清中断标志位	
	

	return 0;
}
unsigned int GET_ADC_VALUE(void)
{
//	P15_IN_DIS
	P16_IN_DIS
	P16_OUT_DIS;	
//	P15_OUT_DIS;	
	VREF_EN;             //ADC参考使用配置
	ADC_EN;
	ADC_RVREF25_AVG8;     //ADC 内部2.5v参考	
	
	ADC_P16_AN10;	      //选择通道0
	DelayUs(1000);
	ADC_SOFT_TG;        //ADC启动
	ADC_WAIT;
	tmp_data = (ADC_DH << 8) | ADC_DL;
//	tmp_data = tmp_data <<8 | ADC_DL;
//	tmp_data = tmp_data | ADC_DL;
	ADC_INT_IF_CLR;    //清中断标志位
	
	dizuo_adc = tmp_data*1.010;
	
	return tmp_data;
}
float GET_NTC_VALUE(void)
{
	unsigned int Ntcdata = 0;

//	P15_IN_DIS
//	P16_IN_DIS
//	P16_OUT_DIS;	
//	P15_OUT_DIS;	
//	VREF_EN;             //ADC参考使用配置
//	ADC_EN;
//	ADC_RVDD_AVG8;     //ADC 内部2.5v参考	

//	ADC_P15_AN11;	      //选择通道0
//	DelayUs(1000);
//	ADC_SOFT_TG;        //ADC启动
//	ADC_WAIT;
//	Ntcdata = (ADC_DH<<8)| ADC_DL;
////	Ntcdata = Ntcdata <<8;
////	Ntcdata = Ntcdata | ADC_DL;
//	ADC_INT_IF_CLR;    //清中断标志位


	return (51.0*Ntcdata/(VDD_data-Ntcdata)); //单位R
}
void UART0_BRR_WR(unsigned int brr)
{
	unsigned int tmp_data;
	tmp_data =brr>>8;
	UART0_BRL =  (unsigned char)brr;
	UART0_BRH =  (unsigned char)tmp_data;
}
void UART_INIT(void)
{
		P02_SET;
		P02_FUN_TX0;		     //P16设置为UART发送
		P02_OUT_EN;			     //该管脚设置成输出	

		UART0_RX8;           //八位数据接收
		UART0_TX8_1S;        //发送为发送一个stop位
		UART0_BRR_WR(34);  //8M/(832+1)=9600	8M为系统时钟
		UART0_RX0_INT_EN;    //接收中断使能
		INT5_EN;             //UART所属中断使能
		GIE_EN;              //总中断开启，接收到数据后进中断，数据加1后发送出来
}

void LED_RUN(void);
void KEY_RUN(void);
//float last_dizuo_adc;

unsigned char sw6301_num;

//unsigned char dizuo_adc_level;
void main()
{
	SYSCK_DIV4;  //16M启动，4分频，4M

	CLK_PR = 0XA5; 
	CLK_C0 = 0x02;
	CLK_PR = 0X5a;
	TMR0_CY = 0X7C;	  //周期设置	1/4 us *4*8=8us *125=1ms
	//tmr使能
	TMR0_CY = 0X7C;	  //周期设置	1/4 us *4*8=8us *125=1ms
										//tmr使能
	TMR0_C0 = 0XC3;
	TMR0_INT_EN;      //中断使能
	INT1_EN;	        //使能对应中断
	GIE_EN;     // 总中断使能
	



	GIE_EN;

	DelayUs(1000000);
	DelayUs(1000000);
	
	
IO_INIT();     //IO 初始化
ADC_INIT();   //ADC初始化
//===============
  IIC_ADDRESS = 0X23;   // 关闭低功耗    第一次上电误进无线充模式，上电稳定后复位1次IC
	SW6303_IIC_READ();
	IIC_DAT |= (1<<0);
	SW6303_IIC_WRITE();
	
//	IIC_ADDRESS = 0X23;     // 关闭低功耗
//	SW6301_IIC_READ();
//	IIC_DAT |= (1<<0);  
//	SW6301_IIC_WRITE();		
	
	DelayUs(10000);	
	
	
	IIC_ADDRESS = 0X24;
	IIC_DAT = 0X20;
	SW6303_IIC_WRITE();
	
	IIC_DAT = 0X40;
	SW6303_IIC_WRITE();
	
	IIC_DAT = 0X80;
	SW6303_IIC_WRITE();
	
	
	IIC_ADDRESS = 0XD9;
	IIC_DAT = 0X20;
	SW6303_IIC_WRITE();
	
	IIC_DAT = 0X40;
	SW6303_IIC_WRITE();
	
	IIC_DAT = 0X80;
	SW6303_IIC_WRITE();
	
	
//	SW6303_SET_H();     //切高位
//	
//	IIC_ADDRESS = 0X11B;
//	SW6303_IIC_READ();
//	IIC_DAT &= 0X3F;
//	IIC_DAT |= 0X80;
//	SW6303_IIC_WRITE();
//	
//	SW6303_SET_L();  //切低位
	
	
	IIC_ADDRESS = 0X24;
	IIC_DAT = 0X20;
	SW6301_IIC_WRITE();
	
	IIC_DAT = 0X40;
	SW6301_IIC_WRITE();	

	IIC_DAT = 0X80;
	SW6301_IIC_WRITE();	
	
	IIC_ADDRESS = 0XD9;
	IIC_DAT = 0X20;
	SW6301_IIC_WRITE();
	
	IIC_DAT = 0X40;
	SW6301_IIC_WRITE();
	
	IIC_DAT = 0X80;
	SW6301_IIC_WRITE();
//=================
	SW6303_INIT();
	SW6301_INIT();
	UART_INIT();
	UART0_TX_DAT(1+48);
	UART0_TX_DAT(1+48);
	UART0_TX_DAT(1+48);
	WDT_C = 0X20;                       //使能看门狗
	
	dizuo_flay = 0;

	SLEED_TIME_S = 10000;
	while(1)
	{
		CLR_WDT;                      // 看门狗
		GET_VDD_VALUE();
		KEY_RUN();
		
		if(power_time_1ms > 100)
		{
			power_time_1ms = 0;
			if(P21 == 0)                 // 检测底座
			{
				GET_ADC_VALUE();	
//				if((last_dizuo_adc-dizuo_adc > 200) && (dizuo_adc<50))
//				{
//					dizuo_adc_level = 1;
//				
//				}
//				if((dizuo_adc - last_dizuo_adc > 200) && (dizuo_adc>150))
//				{
//					dizuo_adc_level = 0;
//				}
//				last_dizuo_adc = dizuo_adc;
//				if(dizuo_adc_level == 1)
//				{
////					dizuo_adc = 0;
//					//dizuo_flay = 0;		
//					//P14 = 0;
//				}else
//				{
//					dizuo_flay = 1;
////					P14 = 1;
//				}	

					dizuo_flay = 1;
//					P14 = 1;	

				if(ntc_flay)                // NTC保护  时底座充电不打开
				{
					P14 = 0;
				
				}else
				{
					P14 = 1;	
				
				}
				
				if(sw6301_num != 1)   //新增测试需求，1.5S内5次开C口充电  底座在线恢复不充电
				{
					sw6301_num = 1;
					SW6301_SET_H();    // 置高位		
					IIC_ADDRESS = 0X14B;     // 
					SW6301_IIC_READ();
					IIC_DAT &= ~(3<<6);    
					IIC_DAT |= (1<<6);  	 
					SW6301_IIC_WRITE();		
					SW6301_SET_L();        // 切低位
					
				}				
						
			}
			else
			{
				//dizuo_adc_level = 0;
				dizuo_adc = 0;
				P14 = 0;		
				dizuo_flay = 0;
			}			
			
			Set_Power();
			
		}
		

	}
		
}



#define KEY    P13


unsigned char key_sta;

//void KEY_RUN(void)
//{
//	if(key_time_flay)
//	{
//		if(KEY == 1)
//		{
//			key_time_flay = 0;
//			if(key_time_1ms > 10000)   // 3S
//			{
//				key_sta = 2;
//	
////				IIC_ADDRESS = 0X21;   // 关输出
////				SW6303_IIC_READ();
////				IIC_DAT |= (1<<5);
////				SW6303_IIC_WRITE();	
//				guang_shuchu();
//				IIC_ADDRESS = 0X21;   // 关输出
//				SW6301_IIC_READ();
//				IIC_DAT |= (1<<5);
//				SW6301_IIC_WRITE();	
//				
//			}else if(key_time_1ms > 5  && key_time_1ms< 500)   // 单击
//			{
//				key_sta = 1;
//				sleep_time_1ms = 0;
//				IIC_ADDRESS = 0X20;   // 触发短按  开输出
//				SW6303_IIC_READ();
//				IIC_DAT |= (1<<0);
//				SW6303_IIC_WRITE();	
//				IIC_ADDRESS = 0X20;   // 触发短按  开输出
//				SW6301_IIC_READ();
//				IIC_DAT |= (1<<0);
//				SW6301_IIC_WRITE();	
//			}
//			key_time_1ms = 0;
//		}
//	}
//}

extern unsigned char VALUE_100;
extern unsigned char ntc_time;
void KEY_RUN(void)
{
	
	static unsigned char num = 0;
	if(key_sta == 2)
	{
//				IIC_ADDRESS = 0X21;   // 关输出
//				SW6303_IIC_READ();
//				IIC_DAT |= (1<<5);
//				SW6303_IIC_WRITE();	
				guang_shuchu();
				IIC_ADDRESS = 0X21;   // 关输出
				SW6301_IIC_READ();
				IIC_DAT |= (1<<5);
				SW6301_IIC_WRITE();	
		
				IIC_ADDRESS = 0XA4;   // 
				SW6301_IIC_READ();
				IIC_DAT &= ~(1<<3);   
				SW6301_IIC_WRITE();	
		
		
		key_sta = 0;
	}else if(key_sta == 1)
	{
		key_sta = 0;
		VALUE_100 = 0;
//		sleep_time_1ms = 0;
		ntc_time = 0;
		if(key_time_flay == 0)
		{
			key_time_flay = 1;
			key_time_1ms = 0;
			num = 0;
			sleep_time_1ms = 0;
			IIC_ADDRESS = 0X20;   // 触发短按  开输出
			SW6303_IIC_READ();
			IIC_DAT |= (1<<0);
			SW6303_IIC_WRITE();	
			IIC_ADDRESS = 0X20;   // 触发短按  开输出
			SW6301_IIC_READ();
			IIC_DAT |= (1<<0);
			SW6301_IIC_WRITE();				
		}
		num++;
		
	}
		if(key_time_1ms <= 1500)    //新增测试需求，1.5S内5次开C口充电
		{
			if(num >= 5)
			{
				if(sw6301_num != 2)
				{
					sw6301_num = 2;
					SW6301_SET_H();    // 置高位		
					IIC_ADDRESS = 0X14B;     // 
					SW6301_IIC_READ();
					IIC_DAT &= ~(3<<6);    
					IIC_DAT |= (0<<6);  	 
					SW6301_IIC_WRITE();		
					SW6301_SET_L();        // 切低位
					
				}
				num = 0;
			}
		}else
		{
			key_time_flay = 0;
			key_time_1ms = 0;	
			num = 0;			
		}

}
unsigned int Cnt_Keys = 0;
void KEY_Scan(void)
{
	
	
	if(KEY == 0)
	{
		Cnt_Keys++;
		if(Cnt_Keys > 10000)
		{
			key_sta = 2;
		}
	}
	else
	{
	   if((Cnt_Keys >=5) && (Cnt_Keys <=500))
		{
			key_sta = 1;
		}
		Cnt_Keys = 0;
	}
}




unsigned char LED_Bright = 0;

//void LED_RUN1(void)
//{
//	static unsigned char LEDScan_cnt;
//		if(LED_time_1ms >= 2)
//		{
//			LED_time_1ms = 0;
//	
//			LED1_IN ;
//			LED2_IN ;
//			LED3_IN ;
//	
//	
//			 LEDScan_cnt++;
//			if(LEDScan_cnt >= 3)	
//			{
//				LEDScan_cnt = 0;
//			}
//			
////			LED_Bright = 0X07;

//			LED_Bright |= (1<<0);
//			LED_Bright |= (1<<1);
//			LED_Bright &= ~(1<<2);
//			LED_Bright &= ~(1<<3);
//			LED_Bright |= (1<<4);
//			LED_Bright |= (1<<5);
//			switch(LEDScan_cnt)
//			{
//					case 0:
//							LED1_OUT;
//							LED1 = 0;
//							if(LED_Bright &  0X02) {LED3_OUT; LED3 = 1; }	//  202
//							if(LED_Bright &  0X20) {LED2_OUT; LED2 = 1; }  //  206	
//					break;

//					case 1:
//							LED2_OUT; 
//							LED2 = 0;
//							if(LED_Bright &  0X10) {LED1_OUT; LED1 = 1; }	//  205
//							if(LED_Bright &  0X08) {LED3_OUT; LED3 = 1; }  //  204								
//					break;

//					case 2:
//							LED3_OUT;
//							LED3 = 0;
//							if(LED_Bright &  0X01) {LED1_OUT; LED1 = 1; }	//  201
//							if(LED_Bright &  0X04) {LED2_OUT; LED2 = 1; }  //  203	
//					break;
////					case 3:
////							LED2_OUT;
////							LED2 = 0;
////							
////					break;
////					case 4:
////							LED2_OUT;
////							LED2 = 0;
////							if(LED_Bright &  (1<<5)) {LED1_OUT; LED1 = 1; }	//  205
////					break;							
//			}		
//		}
//		
//		
//	
//}

void LED_RUN(void)
{
	static unsigned char LEDScan_cnt;
		if(LED_time_1ms >= 0)
		{
			LED_time_1ms = 0;
	
			LED1_IN ;
			LED2_IN ;
			LED3_IN ;
			LEDScan_cnt++;
			if(LEDScan_cnt >= 5)	
			{
				LEDScan_cnt = 0;
			}

			switch(LEDScan_cnt)
			{
					case 0:
							if(LED_Bright &  (1<<2)) {LED3_OUT; LED3 = 1; }	//  202
							if(LED_Bright &  (1<<6)) {LED2_OUT; LED2 = 1; }  //  206
							LED1_OUT;LED1 = 0;
					break;

					case 1:
							
							if(LED_Bright &  (1<<5)) {LED1_OUT; LED1 = 1; }	//  205
							if(LED_Bright &  (1<<4)) {LED3_OUT; LED3 = 1; }  //  204
							LED2_OUT; LED2 = 0;
					break;

					case 2:
							
							if(LED_Bright &  (1<<1)) {LED1_OUT; LED1 = 1; }	//  202
							if(LED_Bright &  (1<<3)) {LED2_OUT; LED2 = 1; }  //  206	
							LED3_OUT; LED3 = 0;
					break;
					case 3:
							
							if(LED_Bright &  (1<<5)) {LED1_OUT; LED1 = 1; LED2_OUT; LED2 = 0;}	//  205	
						break;
					case 4:
					
							if(LED_Bright &  (1<<5)) {LED1_OUT; LED1 = 1; LED2_OUT; LED2 = 0;}	//  205
					break;							
			}


//					if(LEDScan_cnt == 0)
//					{
//							if(LED_Bright &  (1<<2)) {LED3_OUT; LED3 = 1; }	//  202
//							if(LED_Bright &  (1<<6)) {LED2_OUT; LED2 = 1; }  //  206
//							LED1_OUT;LED1 = 0;					
//					}else if(LEDScan_cnt == 1)
//					{
//							if(LED_Bright &  (1<<5)) {LED1_OUT; LED1 = 1; }	//  205
//							if(LED_Bright &  (1<<4)) {LED3_OUT; LED3 = 1; }  //  204
//							LED2_OUT; LED2 = 0;					
//					}else if(LEDScan_cnt == 2)
//					{
//							if(LED_Bright &  (1<<1)) {LED1_OUT; LED1 = 1; }	//  202
//							if(LED_Bright &  (1<<3)) {LED2_OUT; LED2 = 1; }  //  206	
//							LED3_OUT; LED3 = 0;				
//					}else if(LEDScan_cnt == 3)
//					{
//							if(LED_Bright &  (1<<5)) {LED1_OUT; LED1 = 1; LED2_OUT; LED2 = 0;}	//  205				
//					}
//					else if(LEDScan_cnt == 4)
//					{
//							if(LED_Bright &  (1<<5)) {LED1_OUT; LED1 = 1; LED2_OUT; LED2 = 0;}	//  205			
//					}

		}
		
		
	
}




void INT5Interrupt() interrupt 10
{
	if(RX0_IF)
	{

	}
}






