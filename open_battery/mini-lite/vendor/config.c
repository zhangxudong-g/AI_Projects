#include "config.h"
#include "SW6301.h"
#include "SW6303.h"
 
unsigned char dizuo_flay;
unsigned char key_time_flay;
unsigned int power_time_1ms;
unsigned int key_time_1ms;
unsigned int sleep_time_1ms;
unsigned int LED_time_1ms;
 
unsigned char IIC_ADDRESS;
unsigned char IIC_DAT;
 
unsigned char SLEED_FLAY;
unsigned char POWE_16_1_NUM;
unsigned char POWE_16_2_NUM;
unsigned char POWE_16_2_A_NUM;
unsigned int SLEED_TIME_S;
 
 
extern unsigned char int_flay;
unsigned char VALUE_100;
unsigned char NTC_FLAY_ONE;
unsigned char ntc_time;
unsigned int VALUE_0_FLAY;
 
extern unsigned int Cnt_Keys;
void SLEEP_Fun(unsigned char port_n)
{
    static unsigned int  num;
    if(port_n == 0x00)
    {
  
        if((sleep_time_1ms >= SLEED_TIME_S) || (key_sta == 2 ))
        {
          
          Cnt_Keys = 0;
          LED_Bright = 0;
          VALUE_100 = 0;
          SLEED_FLAY = 0;
          sleep_time_1ms = 0;
          ntc_time = 0;
          
          guang_shuchu();                           //���������ػ��󣬻��ڷŵ�
          IIC_ADDRESS = 0X21;   // �����
          SW6301_IIC_READ();
          IIC_DAT |= (1<<5);
          SW6301_IIC_WRITE(); 
          
          IIC_ADDRESS = 0XA4;   // 
          SW6301_IIC_READ();
          IIC_DAT &= ~(1<<3);   
          SW6301_IIC_WRITE();         
          
          IIC_ADDRESS = 0X23;   // ���͹���
          SW6303_IIC_READ();
          IIC_DAT &= ~(1<<0);   
    //      IIC_DAT = 0;
          SW6303_IIC_WRITE(); 
  
          IIC_ADDRESS = 0X23;     //  ���͹���
          SW6301_IIC_READ();
          IIC_DAT &= ~(1<<0);      
    //      IIC_DAT = 0;
          SW6301_IIC_WRITE();     
  
      
          LED1 = 0;
          LED2 = 0;
          LED3 = 0;
          
          P00 = 0;
  
  //        LED1_IN ;
  //        LED2_IN ;
  //        LED3_IN ;
          ADC_DIS;
  
          P15_OUT_EN;
          P16_OUT_EN;
          P15_IN_DIS
          P16_IN_DIS
          P15 = 0;
          P16 = 0;
          P10_OUT_DIS; P10_IN_EN;
          P07_OUT_DIS; P07_IN_EN;
          P06_OUT_DIS; P06_IN_EN;
          P05_OUT_DIS; P05_IN_EN;
  
          TMR0_DIS;
          CLR_WDT;
          
          //if(((dizuo_flay==0) && P06 && P20)  || key_sta == 2)
          if(((dizuo_flay==0) && P06 && P20) || VALUE_0_FLAY || key_sta == 2)
          {
            key_sta = 0;
            WKUP_T_8US;
            SLEEP_MD; 
  
          
  //          int_flay = 0; 
  //          while(int_flay == 0);
            
          }
          
          TMR0_EN;
          TMR0_INT_EN;
          CLR_WDT;
          
          key_sta = 0;
          VALUE_0_FLAY = 0;
          DelayUs(10000);
        
          IIC_ADDRESS = 0X23;     //  �رյ͹���
          SW6301_IIC_READ();
          IIC_DAT |= (1<<0);      
          SW6301_IIC_WRITE();       
          
          IIC_ADDRESS = 0X23;   // �رյ͹���
          SW6303_IIC_READ();
          IIC_DAT |= (1<<0);
          SW6303_IIC_WRITE(); 
        
  
          P00 = 1;
          
          DelayUs(10000);
          
          
      
          P15_OUT_DIS;
          P16_OUT_DIS;
          P15_IN_DIS
          P16_IN_DIS        
        //  WDT_C;
          LED_Bright = 0;
          sleep_time_1ms = 0;
      
          ADC_EN; 
          
          IIC_ADDRESS = 0X24;    //���߻��Ѻ� ���Ĳ�ִ�ж̰�
          IIC_DAT = 0X20;
          SW6303_IIC_WRITE();
          
          IIC_DAT = 0X40;
          SW6303_IIC_WRITE();
          
          IIC_DAT = 0X80;
          SW6303_IIC_WRITE();
          
          IIC_ADDRESS = 0X24;
          IIC_DAT = 0X20;
          SW6301_IIC_WRITE();
          
          IIC_DAT = 0X40;
          SW6301_IIC_WRITE();
          
          IIC_DAT = 0X80;
          SW6301_IIC_WRITE();
          
  //        key_sta = 1;
          
          IIC_ADDRESS = 0X20;   // �����̰�  �����
          SW6303_IIC_READ();
          IIC_DAT |= (1<<0);
          SW6303_IIC_WRITE(); 
          
          IIC_ADDRESS = 0X20;   // �����̰�  �����
          SW6301_IIC_READ();
          IIC_DAT |= (1<<0);
          SW6301_IIC_WRITE(); 
        
        
          
              
        
        }
  
      }else
    {
      num = 0;
    }
  }
unsigned char port_6301;
unsigned char port_6303 ;
unsigned int VALUE_100_time;
 
unsigned char DIANLIANG;
unsigned char LAST_DIANLIANG;
 
unsigned char power_level;
char LED_CONGFIG(unsigned char VALUE,unsigned char STA)
{
    static unsigned int time_i;
    static unsigned char last_le;
    unsigned char isLedNeedFlick = 0;
    unsigned char SW6303_15=0;
    unsigned char le=0;
     
    if(STA == 2)  // ���
    {
      
      
      if(((port_6301&0X20)!=0) || ((port_6303&0XA4)!=0))
      {
        VALUE_100 = 0;
      }
  
      if(VALUE_100==1||VALUE_100==2)
      {
        if(VALUE_100_time >= 10000)
        {
          VALUE_100_time = 10000;
          LED_Bright = 0;
          VALUE_100 = 2;
          return 0;
        }
      }
      
      if(VALUE < 100)
      {
        
        isLedNeedFlick = 1;
      }
      if(VALUE <= 10)
      { 
        DIANLIANG = 1;
        LED_Bright &= ~(1<<2);
        LED_Bright &= ~(1<<3);
        LED_Bright &= ~(1<<4);
        LED_Bright |= (1<<5);
        LED_Bright |= (1<<6);
        le = 2;     
      }else if(VALUE <= 30)
      {
        DIANLIANG = 2;
        LED_Bright |= (1<<1);
        LED_Bright &= ~(1<<3);
        LED_Bright &= ~(1<<4);
        LED_Bright |= (1<<5);
        LED_Bright |= (1<<6);
        le = 3;
      }else   if(VALUE <= 60)
      {
        DIANLIANG = 3;
        LED_Bright |= (1<<1);
        LED_Bright |= (1<<2);
        LED_Bright &= ~(1<<4);
        LED_Bright |= (1<<5);
        LED_Bright |= (1<<6);
        le = 4;
      }else if(VALUE < 99)
      {
        DIANLIANG = 4;
        LED_Bright |= (1<<1);
        LED_Bright |= (1<<2);
        LED_Bright |= (1<<3);
        LED_Bright |= (1<<5);
        LED_Bright |= (1<<6);
        le = 5;
      }else 
      {
        DIANLIANG = 5;
        LED_Bright |= (1<<1);
        LED_Bright |= (1<<2);
        LED_Bright |= (1<<3);
        LED_Bright |= (1<<4);
        LED_Bright |= (1<<5);
        LED_Bright |= (1<<6);
        if(VALUE_100 == 0 || VALUE_100 == 3)
        {
          VALUE_100_time = 0;
        }
        if(((port_6301&0X20)==0) && ((port_6303&0XA4)==0))         // 2026/01/21 �ı߳�߷�ʱ����
        {
          VALUE_100 = 1;
        }else
        {
          VALUE_100 = 0;
        }
        
      }   
    }else    // �ŵ�
    {
  
      if(VALUE_100 >= 2&& STA == 0)
      {
        VALUE_100 = 3;
        LED_Bright = 0;
        return 0;
      }   
      VALUE_100 = 0;
      
      IIC_ADDRESS = 0X15;
        SW6303_IIC_READ();  
        SW6303_15 = IIC_DAT;
      if((SW6303_15 & 0X10))
      {
        IIC_ADDRESS = 0XA4;   //2026.2.2 6303Ƿѹ��д�ⲿ�͵�δ��Ч
        SW6301_IIC_READ();
        IIC_DAT &= 0XFC;   // 11110011
        IIC_DAT |= (1<<3);
        IIC_DAT |= (1<<2);
        SW6301_IIC_WRITE();
        
        SW6301_A4_BIT0();
      }   
      if(power_level <= 0)
      {
        SLEED_TIME_S = 3000;    
        LED_Bright &= 0X20;
        
        DIANLIANG = 0;
  
        IIC_ADDRESS = 0X18;
        SW6301_IIC_READ();      
        if((IIC_DAT & 0x04) || (SW6303_15 & 0X10))
        {
          IIC_ADDRESS = 0X15;
          IIC_DAT = SW6303_15;
          SW6303_IIC_WRITE(); 
          
          
          IIC_ADDRESS = 0X21;   // �����
          SW6301_IIC_READ();
          IIC_DAT |= (1<<5);
          SW6301_IIC_WRITE();   
        }
  
  
  
        
        IIC_ADDRESS = 0X18;
        SW6303_IIC_READ();      
        if((IIC_DAT & 0x09))
        {
          
  //        IIC_ADDRESS = 0X21;   // �����
  //        SW6303_IIC_READ();
  //        IIC_DAT |= (1<<5);
  //        SW6303_IIC_WRITE(); 
  
          guang_shuchu();       
        }
        VALUE_0_FLAY = 1;
  
        le = 1;
        isLedNeedFlick = 1;
  //      LED_Bright &= 0X20;
  //      isLedNeedFlick = 1;
  //      le = 1;
      }else if(VALUE <= 10)
      {
        DIANLIANG = 1;
        
  //      LED_Bright |= (1<<1);
  //      LED_Bright &= ~(1<<2);
  //      LED_Bright &= ~(1<<3);
  //      LED_Bright &= ~(1<<4);
  //      LED_Bright |= (1<<5);
  //      LED_Bright |= (1<<6);   
  
        
        LED_Bright &= ~(1<<2);
        LED_Bright &= ~(1<<3);
        LED_Bright &= ~(1<<4);
        LED_Bright |= (1<<5);
        LED_Bright |= (1<<6);
        isLedNeedFlick = 1;
        le = 2; 
        
      }else   if(VALUE <= 30)
      {
        DIANLIANG = 2;
        LED_Bright |= (1<<1);
        LED_Bright |= (1<<2);
        LED_Bright &= ~(1<<3);
        LED_Bright &= ~(1<<4);
        LED_Bright |= (1<<5);
        LED_Bright |= (1<<6);
      }else   if(VALUE <= 60)
      {
        DIANLIANG = 3;
        LED_Bright |= (1<<1);
        LED_Bright |= (1<<2);
        LED_Bright |= (1<<3);
        LED_Bright &= ~(1<<4);
        LED_Bright |= (1<<5);
        LED_Bright |= (1<<6);
      }else 
      {
        DIANLIANG = 4;
        LED_Bright |= (1<<1);
        LED_Bright |= (1<<2);
        LED_Bright |= (1<<3);
        LED_Bright |= (1<<4);
        LED_Bright |= (1<<5);
        LED_Bright |= (1<<6);
      }
    
    
    
    }
    
    if(isLedNeedFlick)
    {
      isLedNeedFlick = 0;
      time_i++;
      if(le != last_le)
      {
        last_le = le;
        time_i = 0;
      
      }   
      if(le == 1)
      {
        if(time_i > 2)
        {
          time_i = 0;
          LED_Bright ^= (1<<5);
        }
    
      }else if(time_i > 5)
      {
        time_i = 0;
        if(le == 2)
        {
          LED_Bright ^= (1<<1);
        }else if(le == 3)
        {
          LED_Bright ^= (1<<2);
        }else if(le == 4)
        {
          LED_Bright ^= (1<<3);
        }else if(le == 5)
        {
          LED_Bright ^= (1<<4);
        }     
      
      }
    
    }
  
    return 1;
  }
 
void UART0_TX_DAT(unsigned char tx_data)
{
    while (TX0_IF==0) {};
    UART0_TXB = tx_data;
  }
 
void UART0_TX(unsigned int tx_data)
{
    UART0_TX_DAT(tx_data/10000+48);
    UART0_TX_DAT(tx_data/1000%10+48);
      UART0_TX_DAT(tx_data/100%10+48);
    UART0_TX_DAT(tx_data/10%10+48);
    UART0_TX_DAT(tx_data%10+48);
    
  }
 
extern unsigned int PLUG_IN_TIME;
//void Port_State_PlugIn(unsigned char sta_6301,unsigned char sta_6303)
//{
//  static unsigned char num;
//  
//  
//  switch(num)
//  {
//    case 0:
//      if(sta_6301 | sta_6303)
//      {
//        PLUG_IN_TIME = 0;
//        num = 1;
//      }
//      if((sta_6301 | sta_6303) == 3)
//      {
 
//        IIC_ADDRESS = 0X21;   // �����
//        SW6301_IIC_READ();
//        IIC_DAT |= (1<<5);
//        SW6301_IIC_WRITE();           
//      
 
////        IIC_ADDRESS = 0X21;   // �����
////        SW6303_IIC_READ();
////        IIC_DAT |= (1<<5);
////        SW6303_IIC_WRITE();           
//          guang_shuchu();
//        num = 2;
//      }
//      
//      break;
//    case 1:
//      if(PLUG_IN_TIME < 500)
//      {
//        if((sta_6301 | sta_6303) == 3)
//        {
 
//          IIC_ADDRESS = 0X21;   // �����
//          SW6301_IIC_READ();
//          IIC_DAT |= (1<<5);
//          SW6301_IIC_WRITE();           
 
////          IIC_ADDRESS = 0X21;   // �����
////          SW6303_IIC_READ();
////          IIC_DAT |= (1<<5);
////          SW6303_IIC_WRITE();           
//            guang_shuchu();
//          num = 2;  
//          PLUG_IN_TIME = 0;
//        }
//      }else if(PLUG_IN_TIME > 500)
//      {
//        num = 2;
//      }
//      
//    
//      break;
//    case 2:
//      if(sta_6301 | sta_6303)
//      {
//        num = 0;
//      }
//      break;
//  
//  }
 
//}
 
 
 
 
unsigned char ntc_flay;
unsigned char sta_6301 = 0;
unsigned char sta_6303 = 0;
extern float dizuo_adc;
unsigned int ntc_port_last;
float  ntc_data;
unsigned char last_uart_data;
unsigned int last_uart_value;
//unsigned int last_6303uart_value;
unsigned int last_uart_vbat;
unsigned int uart_vbat;
 
//extern unsigned char zuizhongdianliang;
//extern unsigned char last_zuizhongdianliang;
 
unsigned int LAST_Current_max_coulomb;
unsigned int LAST_max_coulomb;
 
extern unsigned  int Current_max_coulomb;
extern unsigned int max_coulomb;
 
 
unsigned int usart_power_level;
unsigned int usart_adc_value;
//unsigned int usart_6303adc_value;
unsigned int usart_uart_vbat;
 
void Set_Power(void)
{
    static unsigned int i;
    static unsigned char out_last_port;
  //  static unsigned char one;
  //  static unsigned char bachushijian;
    unsigned char led_flay = 0;
    unsigned char port = 0;
    unsigned char sta_flay = 0;
    unsigned int adc_6303 = 0;
    float val = 0;
    static int adc_value;
    
    VALUE_0_FLAY = 0;
    SLEED_TIME_S = 10000; 
    
    SW6301_GET_RESET();
    SW6303_GET_RESET();
  
    sta_6301 = SW6301_GET_STASE();
    sta_6303 = SW6303_GET_STASE();
    
  //  Port_State_PlugIn( sta_6301, sta_6303);
    
    port_6301 = SW6301_GET_PORT();
    port_6303 = SW6303_GET_PORT();
    
    if(P06 == 0)
    {
      adc_6303 = SW6303_GET_IBAT();
    }
    adc_value = dizuo_adc;
    
  //  usart_6303adc_value = adc_6303;
    if(dizuo_flay)
    {
      if(dizuo_adc < 100)
      {
        i++;
        if(i > 2000)                              // 2026/2/1   ��Ϊ������Դ�����β���������� ʱ���20s�ĵ� 20
-0s  ���������ӵ�ѹ�ж�13.5V
        {
          SW6301_A4_BIT1();
        }
      }else
      {
        i = 0;
      }     
    }
    
    
    if( (sta_6303 & 0X01) || (port_6303 > 0))   //�ŵ�  2026.2.2 ���Ӷ˿����� дADC ���ͻ�����A�ڷŵ�û�����
-�ؼƣ�
    {
      adc_value = dizuo_adc - adc_6303;
    }else if(sta_6303 & 0X02) 
    {
      if(adc_6303 < 100)
      {
        i++;
        if(i > 10)                     
        {
          SW6301_A4_BIT1();
        }
        
      }else
      {
        i = 0;
      }   
      
      adc_value = dizuo_adc + adc_6303;
    }
    usart_adc_value = adc_value;
    adc_value /= 5;
    
    ntc_data = GET_NTC_VALUE();
    if(ntc_data > 5.314 && ntc_data < 32.754)
    {
      ntc_flay = 0;
    
    }
      
    if((port_6301 != 0 || port_6303 != 0 || dizuo_flay  || (sta_6301==0x02) || (sta_6303==0x02)) )
    {
      if(dizuo_flay || (sta_6301==0x02) || (sta_6303==0x02))                //���
      {
        led_flay = 2;
        if(adc_value > 0)
        {
          SW6301_INPUT_STATUS(adc_value,0);  // 0 ���
        }else if(adc_value < 0)
        {
          adc_value = 0-adc_value;
          SW6301_INPUT_STATUS(adc_value,1);  // 1 �ŵ�
        }
        if(ntc_data < 3.588 || ntc_data > 36.311)    // 50  -2
        {
          ntc_flay = 1;
        }else if(ntc_data > 5.314  && ntc_data < 32.754)    // 50
        {
          ntc_flay = 0;
        } 
      }else                                        // 1 �ŵ�
      {
        i = 0;
        led_flay = 1;
        if(adc_value < 0)
        {
          adc_value = 0 - adc_value;
          SW6301_INPUT_STATUS(adc_value,1);  // 1 �ŵ�
        }
        if(ntc_data < 2.473 || ntc_data > 55.595)    // 60
        {
          ntc_flay = 1;
        }else if(ntc_data > 2.971  && ntc_data < 42.490)    // 50
        {
          ntc_flay = 0;
        }   
      } 
    }else
    {
      i = 0;
      IIC_ADDRESS = 0XA4;   // 
      SW6301_IIC_READ();
      IIC_DAT &= ~(1<<3);   
      SW6301_IIC_WRITE();     
    }
    
  /*
  
    if((sta_6301 >= 2 || sta_6303 >= 2))     // ���ڳ�� ��߳�߷�
    {
      if((sta_6301 >= 2 && sta_6303 >= 2))
      {
        if(one == 0)
        {
          one = 1;
          if(POWE_16_2_NUM != 45) { POWE_16_2_NUM = 45;  SW6303_SET_OUTPUT_POWER_45W(); }  // 3536  
          SW6303_SET_GUAN_INT();
          SW6301_SET_KAI_INT();           
        }
      }
      else if(sta_6301 >= 2)
      {
        if(one != 1)
        {
          one = 1;
          if(POWE_16_2_NUM != 45) { POWE_16_2_NUM = 45;  SW6303_SET_OUTPUT_POWER_45W(); }  // 3536  
          SW6303_SET_GUAN_INT();
          SW6301_SET_KAI_INT();       
        }
      }else if(sta_6303 >= 2)
      {
        if(one != 2)
        {
          one = 2;
          SW6301_SET_GUAN_INT();
          SW6303_SET_KAI_INT();     
        }
      }   
    }else      // ���ڷŵ�
    {
      if(one)
      {
        one = 0;
        SW6301_SET_KAI_INT();
        SW6303_SET_KAI_INT();     
      }
  
      
      if(port_6301&0x01)     // C1
      {
        port |= 0x01;
      }
      
      if(port_6303&0x80)    //C2
      {
        port |= 0x02;
      }   
  
      if(port_6303&0x20)    // A
      {
        port |= 0x04;
      } 
      if((dizuo_flay==1))                 // ������
      {
        if(POWE_16_1_NUM != 30) { POWE_16_1_NUM =30; SW6301_SET_INTPUT_POWER_30W(); }
        if(POWE_16_2_NUM != 30) { POWE_16_2_NUM = 30;  SW6303_SET_INTPUT_POWER_30W(); }  // 3536  
  
      }else   if(port != out_last_port)
      {
        out_last_port = port;
        switch(port)
        {
          case 0x01:          // �� C1
            if(POWE_16_1_NUM != 65) { POWE_16_1_NUM =65; SW6301_SET_OUTPUT_POWER_65W(); }
              
            break;
          case 0x02:      // �� C2
            if(POWE_16_2_NUM != 45) { POWE_16_2_NUM = 45;  SW6303_SET_OUTPUT_POWER_45W(); }  // 3536  
              
            break;
          case 0x04:      // �� C3
            if(POWE_16_2_A_NUM != 30) { POWE_16_2_A_NUM = 30; POWE_16_2_NUM = 0;  SW6303_SET_OUTPUT_POWER_30W_A()
-;}
            
            break;
  
          case 0x03:      // ˫ C1+C2    
            if(POWE_16_1_NUM != 65) { POWE_16_1_NUM = 65; SW6301_SET_OUTPUT_POWER_65W(); }
            if(POWE_16_2_NUM != 30) { POWE_16_2_NUM = 30; POWE_16_2_A_NUM = 0;  SW6303_SET_OUTPUT_POWER_30W();}   
-
            break;  
            
          case 0x05:      // ˫ C1+C3
            if(POWE_16_1_NUM != 65) { POWE_16_1_NUM = 65; SW6301_SET_OUTPUT_POWER_65W(); }
            if(POWE_16_2_A_NUM != 30) { POWE_16_2_A_NUM = 30; POWE_16_2_NUM = 0;  SW6303_SET_OUTPUT_POWER_30W_A()
-;}
            break;        
          
          case 0x06:      // ˫ C2+C3
            break;  
                
          case 0x07:      // �� C1+C2+C3
            if(POWE_16_1_NUM != 65) { POWE_16_1_NUM =65; SW6301_SET_OUTPUT_POWER_65W(); }
            break;
        }   
    
      } 
    
    }
    */
      if(port_6301&0x01)     // C1
      {
        port |= 0x01;
      }
      
      if(port_6303&0x80)    //C2
      {
        port |= 0x02;
      }   
  
      if(port_6303&0x20)    // A
      {
        port |= 0x04;
      }   
      if(port != out_last_port)
      {
        out_last_port = port;
        switch(port)
        {
          case 0x01:          // �� C1
            if(POWE_16_1_NUM != 65) { POWE_16_1_NUM =65; SW6301_SET_OUTPUT_POWER_65W(); }
              
            break;
          case 0x02:      // �� C2
            if(POWE_16_2_NUM != 45) { POWE_16_2_NUM = 45;  SW6303_SET_OUTPUT_POWER_45W(); }  // 3536  
              
            break;
          case 0x04:      // �� C3
            if(POWE_16_2_A_NUM != 30) { POWE_16_2_A_NUM = 30; POWE_16_2_NUM = 0;  SW6303_SET_OUTPUT_POWER_30W_A()
-;}
            
            break;
  
          case 0x03:      // ˫ C1+C2    
            if(POWE_16_1_NUM != 65) { POWE_16_1_NUM = 65; SW6301_SET_OUTPUT_POWER_65W(); }
            if(POWE_16_2_NUM != 30) { POWE_16_2_NUM = 30; POWE_16_2_A_NUM = 0;  SW6303_SET_OUTPUT_POWER_30W();}   
-
            break;  
            
          case 0x05:      // ˫ C1+C3
            if(POWE_16_1_NUM != 65) { POWE_16_1_NUM = 65; SW6301_SET_OUTPUT_POWER_65W(); }
            if(POWE_16_2_A_NUM != 30) { POWE_16_2_A_NUM = 30; POWE_16_2_NUM = 0;  SW6303_SET_OUTPUT_POWER_30W_A()
-;}
            break;        
          
          case 0x06:      // ˫ C2+C3
            break;  
                
          case 0x07:      // �� C1+C2+C3
            if(POWE_16_1_NUM != 65) { POWE_16_1_NUM =65; SW6301_SET_OUTPUT_POWER_65W(); }
            break;
        }   
    
      } 
    
    
    
    
    
  //  if(key_sta == 1)
  //  {
  //    key_sta = 0;
  //    VALUE_100 = 0;
  //    sleep_time_1ms = 0;
  //    ntc_time = 0;
  //  }
    
  //  if((port_6303+port_6301)> ntc_port_last)
  //  {
  ////    bachushijian = 0;
  //    ntc_port_last = port_6303+port_6301;
  //    ntc_time = 0;
  //  }else
  //  {
  ////    if(bachushijian > 5)
  ////    {
  //      ntc_port_last = port_6303+port_6301;
  ////    }
  //  }
    
    uart_vbat = SW6301_GET_VBAT();
    uart_vbat *= 7;
  
    usart_uart_vbat =   uart_vbat;
    if(ntc_flay)
    {
      NTC_FLAY_ONE = 1;
      VALUE_100 = 0;
      if(ntc_time > 50)
      {
        ntc_time = 51;
        LED_Bright = 0;
      }else
      {
        if(ntc_time == 0)
        {
          LED_Bright = 0;
        }
        if((ntc_time%5) == 0)
        {
          LED_Bright ^= 0xff;;
        }   
      
      }
      ntc_time++;
      SW6303_SET_GUAN_INT_OUT();
      SW6301_SET_GUAN_INT_OUT();
      return;
    }else
    {
      ntc_time = 0;
      if(NTC_FLAY_ONE == 1)
      {
        NTC_FLAY_ONE = 0;
        SW6303_SET_KAI_INT_OUT();
        SW6301_SET_KAI_INT_OUT();
      }
      power_level = SW6301_read();
      GET_Coulomb_meter_VALUE();
      
      val = Current_max_coulomb*100.0/max_coulomb+0.5;
      if(val>61 && dizuo_adc > 200)  //2026.2.2  ���ؼƲ�׼ ����δ�������
      {
        val = 98;
      }
      usart_power_level = power_level;
  //    LED_CONGFIG(power_level,led_flay);
      LED_CONGFIG(val,led_flay);
      
    } 
    
    if(  LAST_Current_max_coulomb != Current_max_coulomb || LAST_DIANLIANG != DIANLIANG || last_uart_value !=
- usart_adc_value)
    //if(last_zuizhongdianliang != zuizhongdianliang || last_uart_data != usart_power_level || LAST_Current_m
-ax_coulomb != Current_max_coulomb || LAST_DIANLIANG != DIANLIANG)
    { 
      last_uart_value = usart_adc_value;
      last_uart_vbat = usart_uart_vbat;
    //  last_uart_data = usart_power_level;
      LAST_Current_max_coulomb = Current_max_coulomb;
      LAST_max_coulomb = max_coulomb;
  //    last_6303uart_value = usart_6303adc_value;
      //last_zuizhongdianliang = zuizhongdianliang;
      LAST_DIANLIANG = DIANLIANG;
  
      UART0_TX_DAT('I');
      UART0_TX_DAT(':');
      UART0_TX(usart_adc_value);
      UART0_TX_DAT('\r');
      UART0_TX_DAT('\n');   
  //    UART0_TX_DAT('I');
  //    UART0_TX_DAT(':');
  //    UART0_TX(usart_6303adc_value);
  //    UART0_TX_DAT('\r');
  //    UART0_TX_DAT('\n');
  //    UART0_TX_DAT(' ');
      UART0_TX_DAT('V');
      UART0_TX_DAT(':');
      UART0_TX(usart_uart_vbat);
      UART0_TX_DAT('\r');
      UART0_TX_DAT('\n'); 
      
      UART0_TX_DAT('m');
      UART0_TX_DAT('W');
      UART0_TX_DAT(':');
      UART0_TX(max_coulomb);
      UART0_TX_DAT('\r');
      UART0_TX_DAT('\n'); 
  
      UART0_TX_DAT('m');
      UART0_TX_DAT('W');
      UART0_TX_DAT(':');
      UART0_TX(Current_max_coulomb);  
    
      
      UART0_TX_DAT('\r'); 
      UART0_TX_DAT('\n'); 
  //    UART0_TX(666666);
      
  //    UART0_TX_DAT('D');
  //    UART0_TX_DAT(':');
  //    UART0_TX(usart_power_level);
  //    UART0_TX_DAT(' ');
  //    UART0_TX(zuizhongdianliang);
  //    UART0_TX_DAT(' ');
      UART0_TX(DIANLIANG);
  //    UART0_TX_DAT('\r');
  //    UART0_TX_DAT('\n'); 
  
  //    UART0_TX_DAT('D');
  //    UART0_TX_DAT(':');
      
  //    UART0_TX_DAT('\r');
  //    UART0_TX_DAT('\n'); 
    } 
    
    if(P06 && P20)
    {
      SLEED_FLAY = 1;
      
    }else
    {
      SLEED_FLAY = 0;
    }
    
    if((SLEED_FLAY== 0 || dizuo_flay)&&VALUE_0_FLAY==0)
    {
      sleep_time_1ms = 0;
    }
    
    if((SLEED_FLAY && dizuo_flay==0) || VALUE_0_FLAY ||key_sta == 2 )
    {
      SLEEP_Fun(0);
    }else
    {
      SLEEP_Fun(1);
    }
  }
 
 
CODE SIZE        =   2445    ----
CONSTANT SIZE    =   ----    ----
XDATA SIZE       =   ----    ----
PDATA SIZE       =   ----    ----
DATA SIZE        =     66      13
IDATA SIZE       =   ----    ----
BIT SIZE         =   ----    ----
EDATA SIZE       =   ----    ----
HDATA SIZE       =   ----    ----
XDATA CONST SIZE =   ----    ----
FAR CONST SIZE   =   ----    ----
END OF MODULE INFORMATION.
C51 COMPILATION COMPLETE.  0 WARNING(S),  0 ERROR(S)
