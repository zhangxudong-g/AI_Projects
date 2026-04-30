#include "Inc_mcu.h"
#include "user_com.h"
#include "config.h"


unsigned char int_flay;
void INT0Interrupt() interrupt 0
{
	if(IOINT0_IF & 0x08) 
	{
//		key_time_flay = 1;
//		key_time_1ms = 0;
		
		
		
	}
	int_flay = 1;
	IOINT0_IF=0;
}


void KEY_Scan(void);
extern void LED_RUN(void);
extern unsigned int VALUE_100_time;
unsigned int PLUG_IN_TIME;
unsigned char TIME_CCH_1MS; 
void INT1Interrupt() interrupt 2
{
	if(TMR0_IF)
	{
		power_time_1ms++;
		sleep_time_1ms++;
		LED_time_1ms++;
		VALUE_100_time++;
		PLUG_IN_TIME++;
		TIME_CCH_1MS ++;
		KEY_Scan();
		
		if(key_time_flay)
		{
			key_time_1ms++;
		}
		LED_RUN();
		TMR0_IF = 0;
	}
	
}