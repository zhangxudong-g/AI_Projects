#ifndef ___LED_H__
#define __LED_H__

#include "Inc_mcu.h"


#define LED1  	P16
#define LED2  	P15
#define LED3  	P14
#define LED4 	  P13
#define DC_EN   P11

#define PB1  P21
extern bit f_BAT_temp;
extern bit f_BAT_temp,f_charge,dis_charge;


extern void KEY_mode(void);
extern void key_and_Wireless_charging();
extern void sleep();
extern void Power_bank_mode();
extern char filter();
extern bit Power_onflag;
extern bit Fast_charging;
extern bit load_IN;
extern bit dis_charge;
extern bit LVD_flag;


extern void LED_mode(void);


#endif