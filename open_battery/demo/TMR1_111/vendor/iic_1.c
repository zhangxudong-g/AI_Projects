#include "iic_1.h"
#include "config.h"
 
 
 
 
 
static void IIC1_Start(void)
{
    IIC1_SCL_Out();
    IIC1_SDA_Out();   //Set SDA Output
    IIC1_SDA = 1;   //SDA HIGH
    IIC1_SCL = 1;   //SCL HIGH  
    DelayUs(3);
    
    IIC1_SDA = 0;   //SDA LOW //��SCL�ߵ�ƽʱ����SDA
    DelayUs(3);
    IIC1_SCL = 0;     //SCL LOW //������ʼ�ź�֮��͸�����SCL����ֹ���ݴ���
  }
 
static void IIC1_Stop(void)
{
    IIC1_SDA_Out();   //Set SDA Output
    IIC1_SDA = 0;   //SDA LOW
    IIC1_SCL = 1;   //SCL HIGH
    DelayUs(3);
    IIC1_SDA = 1;   //SDA HIGH  ��SCL�ߵ�ƽʱ����SDA
  }
 
 
/*-------------------------------------------------
*  ��������IIC1_Wait_Ack
*  ���ܣ�  �ȴ�Ӧ���źŵ���
*  ���룺  ��
*  �����  ����ֵ��1������Ӧ��ʧ��
*                  0������Ӧ��ɹ�
--------------------------------------------------*/
 
static unsigned char IIC1_Wait_Ack(void)
{
    unsigned char i=0;   
      IIC1_SDA=1;  
    IIC1_SDA_In();               //SDA����Ϊ����  
    
    DelayUs(3);    
    IIC1_SCL=1;
    DelayUs(3);  
    while(IIC1_SDA)
    {
      i++;
      if(i>250) //�ȴ���ʱ
      {
        IIC1_Stop();
        return 1;
      }
    }
    IIC1_SCL=0;            //ʱ�����0     
    return 0;  
  } 
 
/*-------------------------------------------------
*  ��������IIC1_Ack
*  ���ܣ�  ����ACKӦ��
*  ���룺  ��
*  �����  ��
--------------------------------------------------*/
//static void IIC1_Ack(void)
//{
//  IIC1_SCL=0;
//  IIC1_SDA_Out();   //Set SDA Output
//  IIC1_SDA=0;
//  DelayUs(3); 
//  IIC1_SCL=1;
//  DelayUs(3); 
//  IIC1_SCL=0;
//}
 
/*-------------------------------------------------
*  ��������IIC1_NAck
*  ���ܣ�  ������ACKӦ��
*  ���룺  ��
*  �����  ��
--------------------------------------------------*/     
static void IIC1_NAck(void)
{
    IIC1_SCL=0;
    IIC1_SDA_Out();   //Set SDA Output
    IIC1_SDA=1;
    DelayUs(3); 
    IIC1_SCL=1;
    DelayUs(3); 
    IIC1_SCL=0;
  } 
 
/*-------------------------------------------------
*  ��������IIC1_Send_Byte
*  ���ܣ�  IIC����һ���ֽ�
*  ���룺  д��Ҫ���͵�һ���ֽ�����txd
*  �����  ��
--------------------------------------------------*/ 
 
static void IIC1_Send_Byte(unsigned char txd)
{
    unsigned char i;
    IIC1_SDA_Out();   //Set SDA Output 
      IIC1_SCL=0;            //����ʱ�ӿ�ʼ���ݴ���
      for(i=0;i<8;i++)
      {              
      if(txd&0x80)
        IIC1_SDA=1;
      else
        IIC1_SDA=0;
      txd<<=1;    
      DelayUs(3);         
      IIC1_SCL=1;
      DelayUs(3); 
      IIC1_SCL=0; 
      DelayUs(3);
      }  
  } 
 
/*-------------------------------------------------
*  ��������IIC1_Read_Byte
*  ���ܣ�  IIC��һ���ֽ�
*  ���룺  ��
*  �����  �����洢����������ݲ�����receive
--------------------------------------------------*/
 
static unsigned char IIC1_Read_Byte(void)
{
    unsigned char i;
    unsigned char dat=0;
    IIC1_SDA_In();               //SDA����Ϊ����  
      for(i=0;i<8;i++ )
    {
          IIC1_SCL=0; 
          DelayUs(3); 
        IIC1_SCL=1;
          dat<<=1;
          if(IIC1_SDA)dat++;   
      DelayUs(3); 
      }          
      IIC1_NAck();           //����nACK
    
      return dat;
  }
 
 
void IIC1_WRITE(void)
{
    unsigned char i=0;
  IIC1_WRITE_Begin:
    IIC1_Start();
    IIC1_Send_Byte(IIC1_ADDRESS0<<1);
    if(IIC1_Wait_Ack() && i<2)
      {   
      i++;
      goto IIC1_WRITE_Begin; 
      }
  
    IIC1_Send_Byte(IIC_ADDRESS);
    if(IIC1_Wait_Ack() && i<2)
      {
          i++;
      goto IIC1_WRITE_Begin; 
      }
  
    IIC1_Send_Byte(IIC_DAT);
    if(IIC1_Wait_Ack() && i<2)
      {
          i++;
      goto IIC1_WRITE_Begin; 
      }
  
    IIC1_Stop();  
  }
 
void IIC1_READ(void)
{
    unsigned char i=0;
  IIC1_READ_Begin:
    IIC1_Start();
    IIC1_Send_Byte(IIC1_ADDRESS0<<1);
    if(IIC1_Wait_Ack() && i<2)
      {
      i++;
      goto IIC1_READ_Begin;
      }
    IIC1_Send_Byte(IIC_ADDRESS);        //��Ҫ�������ݵ�ַ
    if(IIC1_Wait_Ack() && i<2)
      {
      i++;
      goto IIC1_READ_Begin;
      }
    IIC1_Start();
    IIC1_Send_Byte((IIC1_ADDRESS0<<1)|0x01);
    if(IIC1_Wait_Ack() && i<2)
      {
      i++;
      goto IIC1_READ_Begin;
      }
    IIC_DAT = IIC1_Read_Byte();
    IIC1_Stop();    
  
  }
 
CODE SIZE        =    479    ----
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
