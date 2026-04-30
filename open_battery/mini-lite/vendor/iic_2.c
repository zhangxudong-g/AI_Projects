#include "iic_2.h"
#include "config.h"
 
 
 
 
 
static void IIC2_Start(void)
{
    IIC2_SCL_Out();
    IIC2_SDA_Out();   //Set SDA Output
    IIC2_SDA = 1;   //SDA HIGH
    IIC2_SCL = 1;   //SCL HIGH  
    DelayUs(3);
    
    IIC2_SDA = 0;   //SDA LOW //��SCL�ߵ�ƽʱ����SDA
    DelayUs(3);
    IIC2_SCL = 0;     //SCL LOW //������ʼ�ź�֮��͸�����SCL����ֹ���ݴ���
  }
 
static void IIC2_Stop(void)
{
    IIC2_SDA_Out();   //Set SDA Output
    IIC2_SDA = 0;   //SDA LOW
    IIC2_SCL = 1;   //SCL HIGH
    DelayUs(3);
    IIC2_SDA = 1;   //SDA HIGH  ��SCL�ߵ�ƽʱ����SDA
  }
 
 
/*-------------------------------------------------
*  ��������IIC2_Wait_Ack
*  ���ܣ�  �ȴ�Ӧ���źŵ���
*  ���룺  ��
*  �����  ����ֵ��1������Ӧ��ʧ��
*                  0������Ӧ��ɹ�
--------------------------------------------------*/
 
static unsigned char IIC2_Wait_Ack(void)
{
    unsigned char i=0;   
      IIC2_SDA=1;  
    IIC2_SDA_In();               //SDA����Ϊ����  
    
    DelayUs(3);    
    IIC2_SCL=1;
    DelayUs(3);  
    while(IIC2_SDA)
    {
      i++;
      if(i>250) //�ȴ���ʱ
      {
        IIC2_Stop();
        return 1;
      }
    }
    IIC2_SCL=0;            //ʱ�����0     
    return 0;  
  } 
 
/*-------------------------------------------------
*  ��������IIC2_Ack
*  ���ܣ�  ����ACKӦ��
*  ���룺  ��
*  �����  ��
--------------------------------------------------*/
//static void IIC2_Ack(void)
//{
//  IIC2_SCL=0;
//  IIC2_SDA_Out();   //Set SDA Output
//  IIC2_SDA=0;
//  DelayUs(3); 
//  IIC2_SCL=1;
//  DelayUs(3); 
//  IIC2_SCL=0;
//}
 
/*-------------------------------------------------
*  ��������IIC2_NAck
*  ���ܣ�  ������ACKӦ��
*  ���룺  ��
*  �����  ��
--------------------------------------------------*/     
static void IIC2_NAck(void)
{
    IIC2_SCL=0;
    IIC2_SDA_Out();   //Set SDA Output
    IIC2_SDA=1;
    DelayUs(3); 
    IIC2_SCL=1;
    DelayUs(3); 
    IIC2_SCL=0;
  } 
 
/*-------------------------------------------------
*  ��������IIC2_Send_Byte
*  ���ܣ�  IIC����һ���ֽ�
*  ���룺  д��Ҫ���͵�һ���ֽ�����txd
*  �����  ��
--------------------------------------------------*/ 
 
static void IIC2_Send_Byte(unsigned char txd)
{
    unsigned char i;
    IIC2_SDA_Out();   //Set SDA Output 
      IIC2_SCL=0;            //����ʱ�ӿ�ʼ���ݴ���
      for(i=0;i<8;i++)
      {              
      if(txd&0x80)
        IIC2_SDA=1;
      else
        IIC2_SDA=0;
      txd<<=1;    
      DelayUs(3);         
      IIC2_SCL=1;
      DelayUs(3); 
      IIC2_SCL=0; 
      DelayUs(3);
      }  
  } 
 
/*-------------------------------------------------
*  ��������IIC2_Read_Byte
*  ���ܣ�  IIC��һ���ֽ�
*  ���룺  ��
*  �����  �����洢����������ݲ�����receive
--------------------------------------------------*/
 
static unsigned char IIC2_Read_Byte(void)
{
    unsigned char i;
    unsigned char dat=0;
    IIC2_SDA_In();               //SDA����Ϊ����  
      for(i=0;i<8;i++ )
    {
          IIC2_SCL=0; 
          DelayUs(3); 
        IIC2_SCL=1;
          dat<<=1;
          if(IIC2_SDA)dat++;   
      DelayUs(3); 
      }          
      IIC2_NAck();           //����nACK
    
      return dat;
  }
 
 
void IIC2_WRITE(void)
{
    unsigned char i=0;
  IIC1_WRITE_Begin:
    IIC2_Start();
    IIC2_Send_Byte(IIC2_ADDRESS0<<1);
    if(IIC2_Wait_Ack() && i<50)
      {   
      i++;
      goto IIC1_WRITE_Begin; 
      }
  
    IIC2_Send_Byte(IIC_ADDRESS);
    if(IIC2_Wait_Ack() && i<100)
      {
          i++;
      goto IIC1_WRITE_Begin; 
      }
  
    IIC2_Send_Byte(IIC_DAT);
    if(IIC2_Wait_Ack() && i<150)
      {
          i++;
      goto IIC1_WRITE_Begin; 
      }
  
    IIC2_Stop();  
  }
 
void IIC2_READ(void)
{
    unsigned char i=0;
  IIC1_READ_Begin:
    IIC2_Start();
    IIC2_Send_Byte(IIC2_ADDRESS0<<1);
    if(IIC2_Wait_Ack() && i<50)
      {
      i++;
      goto IIC1_READ_Begin;
      }
    IIC2_Send_Byte(IIC_ADDRESS);        //��Ҫ�������ݵ�ַ
    if(IIC2_Wait_Ack() && i<50)
      {
      i++;
      goto IIC1_READ_Begin;
      }
    IIC2_Start();
    IIC2_Send_Byte((IIC2_ADDRESS0<<1)|0x01);
    if(IIC2_Wait_Ack() && i<50)
      {
      i++;
      goto IIC1_READ_Begin;
      }
    IIC_DAT = IIC2_Read_Byte();
    IIC2_Stop();    
  
  }
 
CODE SIZE        =    478    ----
CONSTANT SIZE    =   ----    ----
XDATA SIZE       =   ----    ----
PDATA SIZE       =   ----    ----
DATA SIZE        =   ----       7
IDATA SIZE       =   ----    ----
BIT SIZE         =   ----    ----
EDATA SIZE       =   ----    ----
HDATA SIZE       =   ----    ----
XDATA CONST SIZE =   ----    ----
FAR CONST SIZE   =   ----    ----
END OF MODULE INFORMATION.
C51 COMPILATION COMPLETE.  0 WARNING(S),  0 ERROR(S)
