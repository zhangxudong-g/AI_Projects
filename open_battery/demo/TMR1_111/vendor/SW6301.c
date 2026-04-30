#include "SW6301.h"
 
 
void SW6301_SET_H(void)
{
    IIC_ADDRESS = 0X24;
    IIC_DAT = 0X81;
    SW6301_IIC_WRITE();   
  }
 
void SW6301_SET_L(void)
{
    IIC_ADDRESS = 0X1FF;
    IIC_DAT = 0;
    SW6301_IIC_WRITE();   
  }
 
 
void SW6301_SET_OUTPUT_POWER_65W(void)
{
  
    
  //  IIC_ADDRESS = 0X4F;     // �����������
  //  SW6301_IIC_READ();
  //  IIC_DAT &= 0x80;
  //  IIC_DAT |= 65;
  //  SW6301_IIC_WRITE(); 
  
  //  IIC_ADDRESS = 0X2E;     // 
  //  SW6301_IIC_READ();
  //  IIC_DAT &= 0XF0;
  //  IIC_DAT |= (1<<0);      // PD source cap
  //  SW6301_IIC_WRITE();   
    
    
    
    
  }
 
void SW6301_SET_INTPUT_POWER_65W(void)
{
  
    IIC_ADDRESS = 0X45;     // �������빦��
    SW6301_IIC_READ();
    IIC_DAT &= 0x80;
    IIC_DAT |= 65;
    SW6301_IIC_WRITE();   
    
    IIC_ADDRESS = 0X2E;     // 
    SW6301_IIC_READ();
    IIC_DAT &= 0XF0;
    IIC_DAT |= (1<<0);      // PD source cap
    SW6301_IIC_WRITE(); 
  
  }
 
void SW6301_SET_INTPUT_POWER_30W(void)
{
  
    IIC_ADDRESS = 0X45;     // �������빦��
    SW6301_IIC_READ();
    IIC_DAT &= 0x80;
    IIC_DAT |= 30;
    SW6301_IIC_WRITE();   
    
    IIC_ADDRESS = 0X2E;     // 
    SW6301_IIC_READ();
    IIC_DAT &= 0XF0;
    IIC_DAT |= (1<<0);      // PD source cap
    SW6301_IIC_WRITE(); 
  
  }
 
 
 
void SW6301_SET_GUAN_INT(void)     // �س��
{
    IIC_ADDRESS = 0X28;   // ���빦��
    SW6301_IIC_READ();
    IIC_DAT |= (1<<2);
    SW6301_IIC_WRITE();   
  }
 
 
 
void SW6301_SET_KAI_INT(void)     // �����
{
    IIC_ADDRESS = 0X28;   
    SW6301_IIC_READ();
    IIC_DAT &= ~(1<<2);
    SW6301_IIC_WRITE(); 
  }
 
 
void SW6301_SET_GUAN_INT_OUT(void)     // �س�ŵ�
{
    IIC_ADDRESS = 0X28;   // ���빦��
    SW6301_IIC_READ();
    IIC_DAT |= (1<<2);
    IIC_DAT |= (1<<3);
    SW6301_IIC_WRITE();   
  }
 
 
 
void SW6301_SET_KAI_INT_OUT(void)     // ����ŵ�
{
    IIC_ADDRESS = 0X28;   
    SW6301_IIC_READ();
    IIC_DAT &= ~(1<<2);
    IIC_DAT &= ~(1<<3);
    SW6301_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X2E;   
    SW6301_IIC_READ();
    IIC_DAT &= 0XF0;
    IIC_DAT |= (1<<1);
    SW6301_IIC_WRITE(); 
  }
 
 
unsigned int SW6301_GET_VBAT(void)
{
    unsigned int sta = 0;
    IIC_ADDRESS = 0X30;
    SW6301_IIC_READ();
    IIC_DAT &= 0XE0;
    IIC_DAT |= 2;
    SW6301_IIC_WRITE();
  
    
    IIC_ADDRESS = 0X31;
    SW6301_IIC_READ();
    sta = IIC_DAT;
    
    IIC_ADDRESS = 0X32;
    SW6301_IIC_READ();
    sta = ((IIC_DAT&0x0F) << 8) | sta;
    
    return sta;
  }
 
 
unsigned char SW6301_GET_STASE(void)
{
    unsigned char sta = 0;
    IIC_ADDRESS = 0X19;
    SW6301_IIC_READ();
    IIC_DAT &= 0X30;
    if((IIC_DAT & 0x30)==0X20)     // �ŵ�ָʾ 
    {
      sta |= 0X01;
    }
    if((IIC_DAT & 0x30)==0X10)     // SINK���
    {
      sta |= 0X02;
    }
    
    return sta;
  }
unsigned char SW_2B_1;
unsigned char SW_2C_1;
unsigned char SW6301_GET_PORT(void)
{
    unsigned char sta = 0;
    IIC_ADDRESS = 0X1D;
    SW6301_IIC_READ();
    
    sta = IIC_DAT & 0x31;
    
    
    IIC_ADDRESS = 0X2B;
    SW6301_IIC_READ();
    SW_2B_1 = IIC_DAT;
    
    if(IIC_DAT & 0x10)
    {
      SW6301_INIT();
    } 
    
    IIC_ADDRESS = 0X2C;
    SW6301_IIC_READ();
    SW_2C_1 = IIC_DAT;
    
  //  if(IIC_DAT & 0x01)     // �ŵ�ָʾ
  //  {
  //    sta |= 0X01;
  //  }
    return sta;
  }
 
 
void SW6301_A4_BIT1(void)
{
    IIC_ADDRESS = 0XA4;
    SW6301_IIC_READ();
    IIC_DAT |= (1<<1);
    IIC_DAT &= ~(1<<0);
    SW6301_IIC_WRITE(); 
  }
 
void SW6301_A4_BIT0(void)
{
    IIC_ADDRESS = 0XA4;
    SW6301_IIC_READ();
    IIC_DAT |= (1<<0);
    IIC_DAT &= ~(1<<1);
    SW6301_IIC_WRITE(); 
  }
 
void SW6301_INPUT_STATUS(unsigned int adc_va,unsigned char VA)
{
    IIC_ADDRESS = 0XA4;
    SW6301_IIC_READ();
    IIC_DAT &= 0XFC;   // 11110011
    IIC_DAT |= (1<<3);
    
    if(VA)
    {
      IIC_DAT |= (1<<2);
      
      
      
      
    }else
    {
      IIC_DAT &= ~(1<<2);
    }
    
    SW6301_IIC_WRITE(); 
    
    IIC_ADDRESS = 0XA5;
    IIC_DAT = adc_va&0xff;
    SW6301_IIC_WRITE();
    
    IIC_ADDRESS = 0XA6;
    IIC_DAT = (adc_va>>8)&0x0f;
    SW6301_IIC_WRITE();
  }
 
unsigned char SW6301_read(void)
{
    IIC_ADDRESS = 0X99;
    SW6301_IIC_READ();
    return IIC_DAT; 
  }
 
unsigned int max_coulomb;
unsigned int Current_max_coulomb;
unsigned char Current_max_coulomb1;
 
//unsigned char zuizhongdianliang;
//unsigned char last_zuizhongdianliang;
void GET_Coulomb_meter_VALUE(void)
{
    max_coulomb = 0;
    IIC_ADDRESS = 0X86;
    SW6301_IIC_READ();
    max_coulomb = IIC_DAT;
  
    IIC_ADDRESS = 0X87;
    SW6301_IIC_READ();
    max_coulomb = max_coulomb|(IIC_DAT<<8);
    max_coulomb *= 32.62236;
    
    
    Current_max_coulomb = 0;
    IIC_ADDRESS = 0X88;
    SW6301_IIC_READ();  
    Current_max_coulomb1 = IIC_DAT;
    
    IIC_ADDRESS = 0X89;
    SW6301_IIC_READ();  
  //  Current_max_coulomb = Current_max_coulomb |(IIC_DAT<<8);
    Current_max_coulomb = IIC_DAT;
    
    IIC_ADDRESS = 0X8A;
    SW6301_IIC_READ();  
    
    Current_max_coulomb = Current_max_coulomb |(IIC_DAT<<8);
    Current_max_coulomb = Current_max_coulomb*0.07964*25.5+Current_max_coulomb1*0.007964;
    
  
    
    
    
  //  IIC_ADDRESS = 0X94;
  //  SW6301_IIC_READ();  
  //  zuizhongdianliang = IIC_DAT;
  }
 
 
 
unsigned int SW6301_25_FLAY;
void SW6301_GET_RESET(void)
{
    IIC_ADDRESS = 0X25;
    SW6301_IIC_READ();
  
    if((IIC_DAT & (1<<7)) == 0)
    {
        
      SW6301_25_FLAY++;
      SW6301_INIT();
    
    }
    
  
  }
 
 
 
 
void SW6301_INIT(void)
{
    IIC_ADDRESS = 0XFF;
    IIC_DAT = 0X00;
    SW6301_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X23;     // �رյ͹���
    SW6301_IIC_READ();
    IIC_DAT |= (1<<0);  
    SW6301_IIC_WRITE(); 
    
    DelayUs(10000); 
    
    
    IIC_ADDRESS = 0X24;
    IIC_DAT = 0X20;
    SW6301_IIC_WRITE();
    
    IIC_DAT = 0X40;
    SW6301_IIC_WRITE(); 
  
    IIC_DAT = 0X80;
    SW6301_IIC_WRITE(); 
    
    IIC_ADDRESS = 0XFF;
    IIC_DAT = 0X00;
    SW6301_IIC_WRITE(); 
  
    
    
    IIC_ADDRESS = 0X25;    // оƬ��λָʾ
    SW6301_IIC_READ();   
    IIC_DAT |= (1<<7); 
    SW6301_IIC_WRITE();   
    
    
    
    SW6301_SET_H();    // �ø�λ
  
    IIC_ADDRESS = 0X108;     // 
    SW6301_IIC_READ();
    IIC_DAT = 0XDC;
  //  IIC_DAT |= (1<<3);
  //  IIC_DAT |= (1<<1);  
  //  IIC_DAT |= (4<<0);    // 4��
  //  IIC_DAT |= (6<<4);    // 3.65V
    SW6301_IIC_WRITE(); 
  
    IIC_ADDRESS = 0X116;     // NTC���±���
    SW6301_IIC_READ();
    IIC_DAT |= (1<<4);       // ��ֹ
    SW6301_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X103;   // 
    SW6301_IIC_READ();
    IIC_DAT &= 0XF0;      //
    IIC_DAT |= 0x07;      //
    SW6301_IIC_WRITE();
    
    
    IIC_ADDRESS = 0X100;   // 
    SW6301_IIC_READ();
    IIC_DAT &= ~(1<<7);     // ʹ�ܷ�����»�
    IIC_DAT &= ~(7<<4);     
    IIC_DAT |= (1<<4);      // ���»���ֵ  70��
    SW6301_IIC_WRITE(); 
    
  
  //  IIC_ADDRESS = 0X101;   // 
  //  SW6301_IIC_READ();
  //  IIC_DAT &= ~(3<<4);
  //  IIC_DAT |= (1<<4);
  //  SW6301_IIC_WRITE();
  
    IIC_ADDRESS = 0X10D;   // 
    SW6301_IIC_READ();
    IIC_DAT &= ~(3<<6);      //
    IIC_DAT |= (2<<6);      //
    SW6301_IIC_WRITE();
    
    
    IIC_ADDRESS = 0X14B;     // only source
    SW6301_IIC_READ();
    IIC_DAT &= ~(3<<6);    
    IIC_DAT |= (1<<6);    
    SW6301_IIC_WRITE();   
    
    
    
    IIC_ADDRESS = 0X155;     // �ŵ�62368���±���
    SW6301_IIC_READ();
    IIC_DAT |= (1<<7);      // ��ֹ
    SW6301_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X156;     // 
    SW6301_IIC_READ();
    IIC_DAT |= (1<<0);      // ���62368���±���  ��ֹ
    IIC_DAT |= (1<<1);      // ���62368���±���  ��ֹ
    IIC_DAT |= (1<<2);      // ���NTC���±���    ��ֹ
    SW6301_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X118;     // 
    SW6301_IIC_READ();
    IIC_DAT &= ~(1<<2);      // C�ڿ���ʹ��
    SW6301_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X119;     // 
    SW6301_IIC_READ();
    IIC_DAT &= ~(7<<0);      // 
    IIC_DAT |= (1<<0);      //   8s
    SW6301_IIC_WRITE();
    
    IIC_ADDRESS = 0X135;     // 
    SW6301_IIC_READ();
    IIC_DAT |= (1<<0);      //����ֹPPS
    IIC_DAT |= (1<<3);      // PPS�ֶ�����
    SW6301_IIC_WRITE();
    
    IIC_ADDRESS = 0X134;
    SW6301_IIC_READ();
    IIC_DAT |= (1<<2);    // �� PPS0
    IIC_DAT |= (1<<4);    // �� PPS2
    IIC_DAT |= (1<<5);    // �� PPS3
    SW6301_IIC_WRITE();     
    
    IIC_ADDRESS = 0X140;
    IIC_DAT = 0;
    IIC_DAT |= (1<<7);      // PPS�㹦��
    IIC_DAT |= 100;     // 5A
    SW6301_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X123;     // 
    SW6301_IIC_READ();
    IIC_DAT = 0;
    IIC_DAT |= (1<<0);      //FCP��ߵ�ѹ 9V
    IIC_DAT |= (1<<1);      //AFC��ߵ�ѹ 9V
    IIC_DAT |= (1<<2);      //QC3��ߵ�ѹ 12V
    IIC_DAT |= (0<<4);      //QC2��ߵ�ѹ 12V
    IIC_DAT |= (1<<6);      // QC3+ 27W
    SW6301_IIC_WRITE(); 
    
    
    IIC_ADDRESS = 0X150;     // ����
    SW6301_IIC_READ();
    IIC_DAT |= (1<<0);      
    IIC_DAT |= (1<<1);      
    IIC_DAT |= (1<<2);      
    SW6301_IIC_WRITE(); 
  
  
  
    IIC_ADDRESS = 0X151;     // ����
    SW6301_IIC_READ();
    IIC_DAT |= (7<<4);           
    SW6301_IIC_WRITE(); 
    
    
    IIC_ADDRESS = 0X122;     // 
    SW6301_IIC_READ();
    IIC_DAT &= ~(3<<6);
    IIC_DAT |= (1<<6);       // DPDM   30W
    SW6301_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X12D;     // 
    SW6301_IIC_READ();
    IIC_DAT |= (1<<3);      // UFCS �Ĵ�������
    IIC_DAT |= (1<<4);      //UFCS source 20v �ɱ�̵�λʹ��  �ر�
    SW6301_IIC_WRITE();   
  
    IIC_ADDRESS = 0X12E;     // 
    SW6301_IIC_READ();
    IIC_DAT &= 0X80;
    IIC_DAT |= 60;      // UFCS 5V��������   50mA/step
    SW6301_IIC_WRITE(); 
    
  //  IIC_ADDRESS = 0X14E;     // 
  //  SW6301_IIC_READ();
  //  IIC_DAT &= ~(1<<7);
  //  IIC_DAT |= (1<<4);      // 
  //  SW6301_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X12F;     // 
    SW6301_IIC_READ();
    IIC_DAT &= 0X80;
    IIC_DAT |= 60;      // UFCS 10V��������   50mA/step
    SW6301_IIC_WRITE();
    
    
    SW6301_SET_L();        // �е�λ
    
    
    IIC_ADDRESS = 0X40;
    SW6301_IIC_READ();
    IIC_DAT |= (1<<1);     // 46~47 ���Ƴ��Ŀ���ѹ
    IIC_DAT |= (1<<2);     // ����
    IIC_DAT |= (1<<7); 
    SW6301_IIC_WRITE();
  
    IIC_ADDRESS = 0X46;    //  ���Ŀ���ѹ�Ͱ�λ
    SW6301_IIC_READ();   
    IIC_DAT = 0X91; 
    SW6301_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X47;     // ���Ŀ���ѹ����λ
    SW6301_IIC_READ();
    IIC_DAT &= 0xE0;
    IIC_DAT |= 0X05;
    SW6301_IIC_WRITE();   
  
    
    IIC_ADDRESS = 0X45;     // �������빦��
    SW6301_IIC_READ();
    IIC_DAT &= 0x80;
    IIC_DAT |= 65;
    SW6301_IIC_WRITE(); 
    
    IIC_ADDRESS = 0X4F;     // �����������
    SW6301_IIC_READ();
    IIC_DAT &= 0x80;
    IIC_DAT |= 65;
    SW6301_IIC_WRITE();   
    
    
  //  IIC_ADDRESS = 0X2E;     // 
  //  SW6301_IIC_READ();
  //  IIC_DAT &= 0XF0;
  //  IIC_DAT |= (1<<0);      // PD source cap
  //  SW6301_IIC_WRITE(); 
  //  
  //  IIC_ADDRESS = 0X2F;     // 
  //  SW6301_IIC_READ();
  //  IIC_DAT |= (1<<0);      // UFCS source cap
  //  SW6301_IIC_WRITE(); 
  }
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
CODE SIZE        =   1012    ----
CONSTANT SIZE    =   ----    ----
XDATA SIZE       =   ----    ----
PDATA SIZE       =   ----    ----
DATA SIZE        =      9       7
IDATA SIZE       =   ----    ----
BIT SIZE         =   ----    ----
EDATA SIZE       =   ----    ----
HDATA SIZE       =   ----    ----
XDATA CONST SIZE =   ----    ----
FAR CONST SIZE   =   ----    ----
END OF MODULE INFORMATION.
C51 COMPILATION COMPLETE.  0 WARNING(S),  0 ERROR(S)
