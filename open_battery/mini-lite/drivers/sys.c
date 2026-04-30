#include "Inc_mcu.h"
#include "user_com.h"
#include "IIC.h"
#include "LED.h"
u8 KEY_CNT_FLAG = 0;
u8 OFF_BOOST = 0;

#define N 12

void PowerOn_Chk()
{

		R_Address=0x20; //使能IIC调压
		IIC_ReadByte();
		R_Value &= 0xFE;
		IIC_WriteByte();      //12V

		R_Address=0x27; //
		IIC_ReadByte();
		R_Value |= 0x20;
		IIC_WriteByte();	// 5.9 V


		R_Address=0x32; //
		IIC_ReadByte();
		R_Value |= (1<<7);
		R_Value |= (1<<6);
		IIC_WriteByte();      //


		R_Address=0x20; //
		IIC_ReadByte();
		R_Value |= (1<<2);
		IIC_WriteByte();      //


		R_Address=0x23; //放电 VBUS 输出电压设置高 8bits
		R_Value = 0x70;
		IIC_WriteByte();

		R_Address=0x24; //放电 VBUS 输出电压设置低 3bits
		IIC_ReadByte();
		R_Value &= 0xF8;
		R_Value |= 0x04;
		IIC_WriteByte();      //12V

		R_Address=0x25; //放电 VBUS 输出限流设置
		IIC_ReadByte();
		R_Value = 0x1E;
		IIC_WriteByte();      //500mA+Ibus_dischg[6:0]*50mA    2A

		R_Address=0x18; //A1 口负载接入检测使能
		IIC_ReadByte();
		R_Value = 0x10;
		IIC_WriteByte(); //关机低功耗模式使能 禁止


		R_Address=0x22; //Indetb 和 power 绑定使能
		IIC_ReadByte();
		R_Value |= 0x02;
		IIC_WriteByte();      //不绑定

		R_Address=0x30; //充电设置 1
		IIC_ReadByte();
		R_Value |= 0x01;
		IIC_WriteByte();      //电池节数 2

		R_Address=0x34; //充电设置 1
		IIC_ReadByte();
		R_Value = 0x43;
		IIC_WriteByte();      //8.4v

		R_Address=0x35; //充电设置 1
		IIC_ReadByte();
		R_Value = 0x04;
		IIC_WriteByte();      //8.4v

		R_Address=0x36; //涓流电压设置
		IIC_ReadByte();
		R_Value = 0x22;
		IIC_WriteByte();      //5.9V

		R_Address=0x37;//涓流电流设置
		IIC_ReadByte();
		R_Value = 0x00;
		IIC_WriteByte();

		R_Address=0x38;//充电 VBUS 欠压设置
		IIC_ReadByte();
		R_Value = 0x05;
		IIC_WriteByte(); // 4.5V

		R_Address=0x39; //充电 VBUS 输入限流设置
		R_Value = 0x18;
		IIC_WriteByte();      //4A    2A /2A

		R_Address=0x3A; //充电 VBUS 输入限流设置
		R_Value = 0x77;
		IIC_WriteByte();      //12A


		R_Address=0x10; //ADC 配置
		IIC_ReadByte();
		R_Value &= 0XEF;
		IIC_WriteByte();


}
u8 VBAT_H8,VBAT_L4;
u8 Vbus_H8,Vbus_L4;
u32 VBAT_Temp,VBAT_Temp1,ADC_BUFF_CNT,ADC_BUFF_CNT1,ADC_BUFF_CNT2,ADC_BUFF_CNT3;
u32 Vbus_Temp;
bit f_BAT_temp,f_charge,dis_charge;
bit only_one;
u32 ADC_LED_VBAT,ADC_LED_VBAT1;
u8 time_400ms;
u32 SUM = 0;
u8 count=0;

u8 VBUS_H8_VOL;
u8 VBUS_L4_VOL;
u32 VBUS_TEMP_VOL;
u32 VBUS_SUM_VOL=0;
u32 VBUS_count_VOL;
u32 VBUS_OUT_VOL;

void SW6124_Status_Read()
{
		R_Address=0x10; //ADC 配置
		IIC_ReadByte();
		R_Value &= 0x30;   // 4~5位不动   0B0011 0000
		R_Value = 0xC0;
		IIC_WriteByte();  //：VBAT 电压（VBAT= adc_data[11:0]*7.5mV）

		R_Address=0x11; //ADC 数据高 8bits
		IIC_ReadByte();
		VBAT_H8  = R_Value;

		R_Address=0x12; //ADC 数据低 4bit
		IIC_ReadByte();
		VBAT_L4 = R_Value;

				VBAT_Temp1  =  VBAT_H8 << 4;
				VBAT_Temp1 |=  VBAT_L4;
				VBAT_Temp1 *=  7.5;
				SUM += VBAT_Temp1;
				count++;

	ADC_BUFF_CNT = VBAT_Temp;
	ADC_BUFF_CNT1	= 	ADC_BUFF_CNT;

		if(count == 12)
		{
				VBAT_Temp = SUM / 12;
		}
		if(count == 13)
		{
				SUM = 0;
				count = 0;

		}


		R_Address=0x10; //ADC 配置
		IIC_ReadByte();
		R_Value &= 0x30;   // 4~5位不动   0B0011 0000
		R_Value |= 0xC1;
		IIC_WriteByte();  //：VBUS 电压（VBUS= adc_data[11:0]*7.5mV）

		R_Address=0x11; //ADC 数据高 8bits
		IIC_ReadByte();
		VBUS_H8_VOL  = R_Value;

		R_Address=0x12; //ADC 数据低 4bit
		IIC_ReadByte();
		VBUS_L4_VOL = R_Value;
		VBUS_TEMP_VOL = VBUS_H8_VOL << 4;
		VBUS_TEMP_VOL |= VBUS_L4_VOL;
		VBUS_TEMP_VOL *= 7.5;
		VBUS_SUM_VOL += VBUS_TEMP_VOL;
		VBUS_count_VOL++;

		if(VBUS_count_VOL == 12)
		{
				VBUS_OUT_VOL = VBUS_SUM_VOL/12;

		}
		if(VBUS_count_VOL == 13)
		{
				VBUS_count_VOL = 0;
				VBUS_SUM_VOL = 0;
		}

			if(VBUS_OUT_VOL <11500)  // 11.5V
			{

					R_Address=0x39; //充电 VBUS 输入限流设置
					R_Value = 0x00;
					IIC_WriteByte();      //   500mA /00

			}else if(VBUS_OUT_VOL > 11800)  // 11.5V
			{
					R_Address=0x39; //充电 VBUS 输入限流设置
					R_Value = 0x18;
					IIC_WriteByte();      // 		1800mA / 1A

			}


		R_Address=0x06; //状态指示
		IIC_ReadByte();
		if(R_Value & 0x80)
		{
				f_charge = 1;  //充电标志位
		}
		else f_charge = 0;

		if(PB1)    //插入检测
		{
				DC_EN = 1;   //充电使能
				R_Address=0x19; //工作模式控制
				IIC_ReadByte();
				R_Value &= 0xFD;
				R_Value |= 0x06;
				IIC_WriteByte();  //GATEA ON  GATEB ON
				IIC_ReadByte();

				R_Address=0x0D; //工作模式控制
				R_Value = 0x10;
				IIC_WriteByte();  //打开充电 关闭放电
				IIC_ReadByte();
		}
		else
		{
				if(VBAT_Temp > 5900)
				{

						DC_EN = 0;


						R_Address=0x19; //工作模式控制
						IIC_ReadByte();
						R_Value &= 0xFB;
						R_Value |= 0x02;
						IIC_WriteByte();  //GATEA1 ON   GATEB OFF

						R_Address=0x0D; //工作模式控制
						R_Value = 0x11;
						IIC_WriteByte();  //打开放电 关闭充电

				}else
				{
						R_Address=0x0D; //工作模式控制
						R_Value = 0x00;
						IIC_WriteByte();  //打关闭放电 关闭充电

				}


		}


		R_Address=0x10; //ADC 配置
		IIC_ReadByte();
		R_Value = 0xC7;
		IIC_WriteByte();  //：：VBUS放电电流（IBUS_DISCHG= adc_data[11:0]*5mA）

		R_Address=0x11; //ADC 数据高 8bits
		IIC_ReadByte();
		Vbus_H8  = R_Value;

		R_Address=0x12; //ADC 数据低 4bit
		IIC_ReadByte();
		Vbus_L4 = R_Value;

		Vbus_Temp  =  Vbus_H8 << 4;
		Vbus_Temp |=  Vbus_L4;
		Vbus_Temp *=  5;

		if(Vbus_Temp <= 50)                     // 小于50mA
		{
					dis_charge = 0;
		}
		else if(Vbus_Temp >= 100)
		{
					dis_charge = 1;
		}

}
