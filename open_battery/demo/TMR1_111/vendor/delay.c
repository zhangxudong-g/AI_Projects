#include "delay.h"
 
 
 
void DelayUs(unsigned int Time)
{
    unsigned int i;
    for(i=0; i<Time; i++)
    {
      NOP();
    }
    CLR_WDT; 
  } 
 
 
//void DelayMs(unsigned char Time)
//{
//  unsigned char i,j,k;
//  for(k=0; k<Time; k++)
//  {
//    for(i=0; i<4; i++)
//        {
//      for(j=0; j<255; j++)
//            {
//        NOP();
//            }
//        }
//  }
//} 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
CODE SIZE        =     22    ----
CONSTANT SIZE    =   ----    ----
XDATA SIZE       =   ----    ----
PDATA SIZE       =   ----    ----
DATA SIZE        =   ----    ----
IDATA SIZE       =   ----    ----
BIT SIZE         =   ----    ----
EDATA SIZE       =   ----    ----
HDATA SIZE       =   ----    ----
XDATA CONST SIZE =   ----    ----
FAR CONST SIZE   =   ----    ----
END OF MODULE INFORMATION.
C51 COMPILATION COMPLETE.  0 WARNING(S),  0 ERROR(S)
