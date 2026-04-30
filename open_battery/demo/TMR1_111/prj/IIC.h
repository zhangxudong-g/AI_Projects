
/****Pin***********************************************************************************
			  _____________________________   _____________________________
			-|VSS						     							VDD|-
	    LED1-|PA0/AIN0/OSC2/CMP1N/CKO	     PC1/SCL/TX/ISPCK/PINT1/CMP1OUT|-SCL
	    LED2-|PA1/AIN1/OSC1/CKI/CMP1P/PWM10		    PC0/SDA/RX/ISPDAT/PINT0|-SDA
		    -|PA2/N_MRST						 PB7/VREFP/ISPCK/PINT4/KIN3|-IRQ
	    LED3-|PA3/AIN2/CMP2P/N_EPAS		   PB6/AIN13/OPAN/ISPDAT/PINT3/KIN2|-Load_Chk
		LED4-|PA4/AIN3/CMP3P/VREFN/T8NCKI   PB5/AIN12/OPAP/CMP4P/PINT2/KIN1|-En
		LED5-|PA5/AIN4/CMP5P/PPG/PWM11	              PB4/AIN11/OPAOUT/KIN0|-Curr_Chk
		LED6-|PA6/AIN5/PWM20	                      PB3/AIN10/PWM21/T13CI|-LED7
			  _____________________________________________________________
*******************************************************************************************/

#ifndef ___IIC_H__
#define __IIC_H__

#include "Inc_mcu.h"


#define ADR_SW6124 0x78


#define NOP() _nop_()
extern void          _nop_     (void);
extern bit           _testbit_ (bit);
#define u8 unsigned char  
#define u16 unsigned int
#define u32 unsigned long

extern idata u8 R_Value;
extern idata u8 R_Address;
extern bit f_Sys25ms,f_Sys100ms,f_Sys500ms,f_Sys1ms;

#define SCL  P07
#define SDA  P10
#define Wireless_charging  P06
#define IRQ  P06

#define SDA_OUT 	P1_OE |= 0x01; P1_IE &= 0xFE
#define SDA_IN   	P1_OE &= 0xFE; P1_IE |= 0x01

#define SCL_OUT 	P0_OE |= 0x80; P0_IE &= 0x7F
#define SCL_IN   	P0_OE &= 0x7F; P0_IE |= 0x80


extern void IIC_Start();
extern void IIC_Stop();
extern void  SendByte(unsigned char  c);
extern void  RcvByte();
extern void IIC_ReadByte();
extern void IIC_WriteByte();
extern void NOP8();
extern void NOP3();


extern u32 VBAT_Temp;



#endif