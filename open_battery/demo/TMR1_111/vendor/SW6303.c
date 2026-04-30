#include "SW6303.h"
 
 
void SW6303_SET_H(void)
{
    IIC_ADDRESS = 0X24;
    IIC_DAT = 0X81;
    SW6303_IIC_WRITE();   
  }
 
void SW6303_SET_L(void)
{
    IIC_ADDRESS = 0X1FF;
    IIC_DAT = 0;
    SW6303_IIC_WRITE();   
  }
 
 
void SW6303_SET_OUTPUT_POWER_45W(void)
{
  
    
    SW6303_SET_H();
    
    IIC_ADDRESS = 0X140;
    IIC_DAT = 0;
    IIC_DAT |= (1<<7);      // PPS1�㹦��
    IIC_DAT |= 90;     // 4.5A
    SW6303_IIC_WRITE(); 
    
    SW6303_SET_L();      // �е�λ
  
    IIC_ADDRESS = 0X4F;   // �������
    SW6303_IIC_READ();
    IIC_DAT &= 0x80;
    IIC_DAT |= 45;
    SW6303_IIC_WRITE(); 
  
    IIC_ADDRESS = 0X2E;     // 
    SW6303_IIC_READ();
    IIC_DAT &= 0XF0;
    IIC_DAT |= (1<<0);      // PD source cap
    SW6303_IIC_WRITE();   
    
    
  }
 
void SW6303_SET_OUTPUT_POWER_30W(void)
{
    SW6303_SET_H();
    
    IIC_ADDRESS = 0X140;
    IIC_DAT = 0;
    IIC_DAT |= (1<<7);      // PPS1�㹦��
    IIC_DAT |= 60;     // 4.5A
    SW6303_IIC_WRITE(); 
    
    SW6303_SET_L();      // �е�λ
  
    IIC_ADDRESS = 0X4F;   // �������
    SW6303_IIC_READ();
    IIC_DAT &= 0x80;
    IIC_DAT |= 30;
    SW6303_IIC_WRITE(); 
  
    IIC_ADDRESS = 0X2E;     // 
    SW6303_IIC_READ();
    IIC_DAT &= 0XF0;
    IIC_DAT |= (1<<0);      // PD source cap
    SW6303_IIC_WRITE();   
    
    
    
  }
 
 
void SW6303_SET_OUTPUT_POWER_30W_A(void)
{
  
    //SW6303_SET_L();      // �е�λ
  
  //  IIC_ADDRESS = 0X4F;   // �������
  //  SW6303_IIC_READ();
  //  IIC_DAT &= 0x80;
  //  IIC_DAT |= 18;
  //  SW6303_IIC_WRITE(); 
  
  //  IIC_ADDRESS = 0X2E;     // 
  //  SW6303_IIC_READ();
  //  IIC_DAT &= 0XF0;
  //  IIC_DAT |= (1<<0);      // PD source cap
  //  SW6303_IIC_WRITE();   
    
  }
 
 
void SW6303_SET_INTPUT_POWER_45W(void)     // ���빦��
{
    
    IIC_ADDRESS = 0X45;   // ���빦��
    SW6303_IIC_READ();
    IIC_DAT &= 0x80;
    IIC_DAT |= 45;
    SW6303_IIC_WRITE();   
    
    IIC_ADDRESS = 0X2E;     // 
    SW6303_IIC_READ();
    IIC_DAT &= 0XF0;
    IIC_DAT |= (1<<0);      // PD source cap
    SW6303_IIC_WRITE(); 
      
  }
 
void SW6303_SET_INTPUT_POWER_30W(void)     // ���빦��
{
    
    IIC_ADDRESS = 0X45;   // ���빦��
    SW6303_IIC_READ();
    IIC_DAT &= 0x80;
    IIC_DAT |= 30;
    SW6303_IIC_WRITE();   
    
    IIC_ADDRESS = 0X2E;     // 
    SW6303_IIC_READ();
    IIC_DAT &= 0XF0;
    IIC_DAT |= (1<<0);      // PD source cap
    SW6303_IIC_WRITE(); 
      
  }
 
void SW6303_SET_GUAN_INT(void)     // �س��
{
  
    IIC_ADDRESS = 0X28;   
    SW6303_IIC_READ();
    IIC_DAT |= (1<<2);
    SW6303_IIC_WRITE();   
    
  }
 
void SW6303_SET_KAI_INT(void)     // �����
{
    
    IIC_ADDRESS = 0X28;   
    SW6303_IIC_READ();
    IIC_DAT &= ~(1<<2);
    SW6303_IIC_WRITE();   
  }
 
void SW6303_SET_GUAN_INT_OUT(void)     // �س�ŵ�
{
    
    IIC_ADDRESS = 0X28;   
    SW6303_IIC_READ();
    IIC_DAT |= (1<<2);
    IIC_DAT |= (1<<3);
    SW6303_IIC_WRITE(); 
  }
 
void SW6303_SET_KAI_INT_OUT(void)     // ����ŵ�
{
    
    IIC_ADDRESS = 0X28;   
    SW6303_IIC_READ();
    IIC_DAT &= ~(1<<2);
    IIC_DAT &= ~(1<<3);
    SW6303_IIC_WRITE(); 
    
    
    IIC_ADDRESS = 0X2E;   
    SW6303_IIC_READ();
    IIC_DAT &= 0XF0;
    IIC_DAT |= (1<<1);
    SW6303_IIC_WRITE(); 
  }
 
 
 
unsigned char SW6303_GET_STASE(void)
{
    unsigned char sta = 0;
    IIC_ADDRESS = 0X19;
    SW6303_IIC_READ();
    IIC_DAT &= 0XC0;
    if((IIC_DAT & 0xC0)==0X80)     // �ŵ�ָʾ 
    {
      sta |= 0X01;
    }
    if((IIC_DAT & 0xC0)==0X40)     // SINK���
    {
      sta |= 0X02;
    }
    
    return sta;
  }
unsigned char SW_2B;
unsigned char SW_2C;
unsigned char SW6303_GET_PORT(void)
{
    
    unsigned char sta = 0;
    IIC_ADDRESS = 0X1D;
    SW6303_IIC_READ();
    
    sta = IIC_DAT & 0xF7; 
  
    IIC_ADDRESS = 0X2B;
    SW6303_IIC_READ();
    SW_2B = IIC_DAT;
    
    if(IIC_DAT & 0x10)
    {
      SW6303_INIT();
    }
    
    IIC_ADDRESS = 0X2C;
    SW6303_IIC_READ();
    SW_2C = IIC_DAT;
    return sta;
  }
 
void guang_shuchu(void)
{
  
    IIC_ADDRESS = 0X21;   // �����
    SW6303_IIC_READ();
    IIC_DAT |= (1<<5);
    SW6303_IIC_WRITE(); 
  
  }
 
 
unsigned int SW6303_GET_IBAT(void)
{
  
    unsigned int sta = 0;
    IIC_ADDRESS = 0X30;
    SW6303_IIC_READ();
    IIC_DAT &= 0XE0;
    IIC_DAT |= 3;
    SW6303_IIC_WRITE();
    
    IIC_ADDRESS = 0X31;
    SW6303_IIC_READ();
    sta = IIC_DAT;
    
    IIC_ADDRESS = 0X32;
    SW6303_IIC_READ();
    sta |= (IIC_DAT << 8);
    
    sta = sta*5;
    return sta;
  }
unsigned int SW6303_25_FLAY;
void SW6303_GET_RESET(void)
{
    IIC_ADDRESS = 0X25;
    SW6303_IIC_READ();
  
    if((IIC_DAT & (1<<7)) == 0)
    {
  
      SW6303_25_FLAY++;
      SW6303_INIT();
    
    }
    
  
  }
 
 
 
void SW6303_INIT(void)
{
    
      IIC_ADDRESS = 0XFF;
      IIC_DAT = 0X00;
      SW6303_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X23;   // �رյ͹���
    SW6303_IIC_READ();
    IIC_DAT |= (1<<0);
    SW6303_IIC_WRITE();
    
    DelayUs(10000); 
    
    
    IIC_ADDRESS = 0X24;
    IIC_DAT = 0X20;
    SW6303_IIC_WRITE();
    
    IIC_DAT = 0X40;
    SW6303_IIC_WRITE();
    
    IIC_DAT = 0X80;
    SW6303_IIC_WRITE();
    
      IIC_ADDRESS = 0XFF;
      IIC_DAT = 0X00;
      SW6303_IIC_WRITE(); 
    
    
    IIC_ADDRESS = 0X25;    // оƬ��λָʾ
    SW6303_IIC_READ();
    IIC_DAT |= (1<<7);
    SW6303_IIC_WRITE();   
    
    
    IIC_ADDRESS = 0X15;
    SW6303_IIC_READ();
    SW6303_IIC_WRITE();   
  
  
  
    
    SW6303_SET_H();     //�и�λ
    
    IIC_ADDRESS = 0X108;   // 
    SW6303_IIC_READ();
    IIC_DAT = 0XDC;
  //  IIC_DAT |= (1<<3);
  //  IIC_DAT |= (1<<1);  
  //  IIC_DAT |= (4<<0);    // 4��
  //  IIC_DAT |= (6<<4);    // 3.65V
  //  IIC_DAT |= (1<<7);
    SW6303_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X116;   // 
    SW6303_IIC_READ();
    IIC_DAT |= (1<<4);      //�ŵ� NTC ���±�������  ��ֹ
    SW6303_IIC_WRITE();
    
    
    IIC_ADDRESS = 0X11B;  //�����߳�ģʽ
    SW6303_IIC_READ();
    IIC_DAT &= 0X3F;
    IIC_DAT |= 0X80;
    SW6303_IIC_WRITE();
  
    IIC_ADDRESS = 0X103;   // 
    SW6303_IIC_READ();
    IIC_DAT &= 0XF0;      //
    IIC_DAT |= 0x07;      //
    SW6303_IIC_WRITE();
    
    IIC_ADDRESS = 0X10D;   // 
    SW6303_IIC_READ();
    IIC_DAT &= ~(3<<6);      //
    IIC_DAT |= (2<<6);      //
    SW6303_IIC_WRITE();   
    
    
    IIC_ADDRESS = 0X132;   // 
    SW6303_IIC_READ();
    IIC_DAT &= ~(3<<0);    
    IIC_DAT |= (1<<0);     // only source
    SW6303_IIC_WRITE(); 
    
  
    IIC_ADDRESS = 0X155;   // 
    SW6303_IIC_READ();
    IIC_DAT |= (1<<7);      //�ŵ� 62368 ���±���ʹ��  ��ֹ
    SW6303_IIC_WRITE();
    
    IIC_ADDRESS = 0X156;   // 
    SW6303_IIC_READ();
    IIC_DAT |= (1<<0);      //��� 62368 ���±���ʹ��  ��ֹ
    IIC_DAT |= (1<<1);      //��� 62368 ���±���ʹ��  ��ֹ
    IIC_DAT |= (1<<2);      //��� NTC ���±���ʹ��    ��ֹ
    SW6303_IIC_WRITE();
    
    IIC_ADDRESS = 0X118;   // 
    SW6303_IIC_READ();
    IIC_DAT &= ~(7<<2);      //����ʹ��
    SW6303_IIC_WRITE();
    
    IIC_ADDRESS = 0X119;    
    IIC_DAT = 0;
    IIC_DAT |= (1<<0);   
    IIC_DAT |= (1<<3); 
    IIC_DAT |= (2<<4);      
    IIC_DAT |= (1<<6);      
    SW6303_IIC_WRITE(); 
    
    
    IIC_ADDRESS = 0X135;   // 
    SW6303_IIC_READ();
    IIC_DAT |= (1<<0);      //����ֹPPS
    IIC_DAT |= (1<<3);      // PPS�ֶ�����
    SW6303_IIC_WRITE();
    
    IIC_ADDRESS = 0X134;
    SW6303_IIC_READ();
    IIC_DAT |= (1<<2);    // �� PPS0
    IIC_DAT |= (1<<4);    // �� PPS2
    IIC_DAT |= (1<<5);    // �� PPS3
    SW6303_IIC_WRITE(); 
    
    
    IIC_ADDRESS = 0X140;
    IIC_DAT = 0;
    IIC_DAT |= (1<<7);      // PPS1�㹦��
    IIC_DAT |= 100;     // 5A
    SW6303_IIC_WRITE(); 
  
    IIC_ADDRESS = 0X100;   // 
    SW6303_IIC_READ();
    IIC_DAT &= ~(1<<7);     // ʹ�ܷ�����»�
    IIC_DAT &= ~(7<<4);    
    IIC_DAT |= (1<<4);      // ���»���ֵ  70��
    SW6303_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X101;   // 
    SW6303_IIC_READ();
    IIC_DAT &= ~(3<<6);      //������ 4.2V
  //  IIC_DAT |= (2<<6);
  //  IIC_DAT &= ~(3<<4);
  //  IIC_DAT |= (1<<4);
    SW6303_IIC_WRITE();
  
    IIC_ADDRESS = 0X150;     // ����
    SW6303_IIC_READ();
    IIC_DAT |= (1<<0);      
    IIC_DAT |= (1<<1);      
    IIC_DAT |= (1<<2);      
    SW6303_IIC_WRITE(); 
  
    IIC_ADDRESS = 0X151;     // ����
    SW6303_IIC_READ();
    IIC_DAT |= (7<<4);           
    SW6303_IIC_WRITE(); 
  
    
    IIC_ADDRESS = 0X123;     // 
    SW6303_IIC_READ();
    IIC_DAT = 0;
    IIC_DAT |= (1<<0);      //FCP��ߵ�ѹ 9V
    IIC_DAT |= (1<<1);      //AFC��ߵ�ѹ 9V
    IIC_DAT |= (1<<2);      //QC3��ߵ�ѹ 12V
    IIC_DAT |= (0<<4);      //QC2��ߵ�ѹ 12V
    IIC_DAT |= (1<<6);      // QC3+ 27W
    SW6303_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X122;     // 
    SW6303_IIC_READ();
    IIC_DAT &= ~(3<<6);
    IIC_DAT |= (1<<6);       // DPDM   30W
    SW6303_IIC_WRITE();   
    
    
    IIC_ADDRESS = 0X12D;     // 
    SW6303_IIC_READ();
    IIC_DAT |= (1<<3);      // UFCS �Ĵ�������
    IIC_DAT |= (1<<4);      //UFCS source 20v �ɱ�̵�λʹ��  �ر�
    SW6303_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X12E;     // 
    SW6303_IIC_READ();
    IIC_DAT &= 0X80;
    IIC_DAT |= 60;      // UFCS 5V��������   50mA/step
    SW6303_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X12F;     // 
    SW6303_IIC_READ();
    IIC_DAT &= 0X80;
    IIC_DAT |= 60;      // UFCS 10V��������   50mA/step
    SW6303_IIC_WRITE();
    
    
    SW6303_SET_L();        // �е�λ
    
    IIC_ADDRESS = 0X40;
    SW6303_IIC_READ();
    IIC_DAT |= (1<<1);     // 46~47 ���Ƴ��Ŀ���ѹ
    IIC_DAT |= (1<<2);
    IIC_DAT |= (1<<7);
    SW6303_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X46;    //  ���Ŀ���ѹ�Ͱ�λ
    SW6303_IIC_READ();   
    IIC_DAT = 0X91; 
    SW6303_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X47;     // ���Ŀ���ѹ����λ
    SW6303_IIC_READ();
    IIC_DAT &= 0xE0;
    IIC_DAT |= 0X05;
    SW6303_IIC_WRITE();   
    
  
    IIC_ADDRESS = 0X45;   // ���빦��
    SW6303_IIC_READ();
    IIC_DAT &= 0x80;
    IIC_DAT |= 45;
    SW6303_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X4F;   // �������
    SW6303_IIC_READ();
    IIC_DAT &= 0x80;
    IIC_DAT |= 45;
    SW6303_IIC_WRITE();   
    
    
  //  IIC_ADDRESS = 0X2E;     // 
  //  SW6303_IIC_READ();
  //  IIC_DAT &= 0XF0;
  //  IIC_DAT |= (1<<0);      // PD source cap
  //  SW6303_IIC_WRITE(); 
  //  
  //  IIC_ADDRESS = 0X2F;     // 
  //  SW6303_IIC_READ();
  //  IIC_DAT |= (1<<0);      // UFCS source cap
  //  SW6303_IIC_WRITE(); 
    
  }
 
 
 
 
 
 
 
CODE SIZE        =    927    ----
CONSTANT SIZE    =   ----    ----
XDATA SIZE       =   ----    ----
PDATA SIZE       =   ----    ----
DATA SIZE        =      4       4
IDATA SIZE       =   ----    ----
BIT SIZE         =   ----    ----
EDATA SIZE       =   ----    ----
HDATA SIZE       =   ----    ----
XDATA CONST SIZE =   ----    ----
FAR CONST SIZE   =   ----    ----
END OF MODULE INFORMATION.
C51 COMPILATION COMPLETE.  0 WARNING(S),  0 ERROR(S)
