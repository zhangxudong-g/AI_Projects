/*********************************************************
*Copyright (C)
*文件名:
*作  者:
*版  本:	V1.00
*日  期:
*描  述:
*备  注:
**********************************************************/
#include "Inc_mcu.h"
/***********************1ms延时函数*****************************/
void delay_1ms(unsigned int q)
{
	unsigned int i,j;
	for(i=0; i<q; i++)
		for(j=0; j<200; j++);
            CLR_WDT;
}

/***********************P12按键*****************************/
void key_and_dis(unsigned char q)
{
	unsigned char i,j;

	j = 0;
	q = q<<4;
	P1 = 0;
	while (j < 7)
	{
		j = 0;
		P0 = P0^q;
		for (i=0; i <10; i = i+1)
		{
			if (P1_2==1)
			{
				j = j +1;
			}
			delay_1ms(10);
		}
	}
	j = 0;
	while (j < 7)
	{
		j = 0;
		for (i=0; i <10; i = i+1)
		{
			if (P1_2==0)
			{
				j = j +1;
			}
			delay_1ms(10) ;
		}
	}
}

/***********************显示序号*****************************/
void 	P07_P04_DIS(unsigned char q)
{
	unsigned char i;
	q = q<<4;
	P0 = 0;
	for (i=0; i <10; i = i+1)
	{
		P0 = P0^q;
		delay_1ms(1000) ;
	}
}

void p1_step_dis(unsigned char q)
{
	unsigned char i;
	q = q<<1;
	P1 = 0;
	for (i=0; i <10; i = i+1)
	{
		P1 = P1^q;
		delay_1ms(1000) ;
	}
}

/***********************P12按键*****************************/
void key_bit(void)
{
	unsigned char i,j;

	j = 0;
	while (j < 7)
	{
		j = 0;
		for (i=0; i <10; i = i+1)
		{
			if (P1_2==1)
			{
				j = j +1;
			}
			delay_1ms(50);
		}
	}
	j = 0;
	while (j < 7)
	{
		j = 0;
		for (i=0; i <10; i = i+1)
		{
			if (P1_2==0)
			{
				j = j +1;
			}
			delay_1ms(50) ;
		}
	}
}

/***********************P12按键*****************************/
void key2_bit(void)
{
	unsigned char i,j;

	j = 0;
	while (j < 7)
	{
		j = 0;
		for (i=0; i <10; i = i+1)
		{
			if (P1_0==1)
			{
				j = j +1;
			}
			delay_1ms(50);
		}
	}
	j = 0;
	while (j < 7)
	{
		j = 0;
		for (i=0; i <10; i = i+1)
		{
			if (P1_0==0)
			{
				j = j +1;
			}
			delay_1ms(50) ;
		}
	}
}