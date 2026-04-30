#include "IIC.h"

idata bit f_ack;
idata u8 R_Address;
idata u8 R_Value;

void NOP3() {
  NOP();
  NOP();
  NOP();
}
void NOP8() {
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
  NOP();
}
void IIC_Start() {

  SCL_OUT;
  NOP3();
  SCL = 0;
  NOP();
  // PxT_SDA=IO_OUTPUT;
  SDA_OUT;
  NOP();
  SDA = 1; /*发送起始条件的数据信号*/
  NOP3();
  SCL = 1;
  NOP3();
  NOP();
  SDA = 0; /*发送起始信号*/
  NOP3();
  SCL = 0; /*钳住I2C总线，准备发送或接收数据 */
}
/*******************************************************************
                      结束总线函数
函数原型: void  IIC_Stop();
功能:     结束I2C总线,即发送I2C结束条件.
********************************************************************/
void IIC_Stop() {
  SCL = 0;
  // PxT_SDA=IO_OUTPUT;
  SDA_OUT;
  NOP3();
  SDA = 0; /*发送结束条件的数据信号*/
  NOP();   /*发送结束条件的时钟信号*/
  SCL = 1; /*结束条件建立时间大于4μs*/
  NOP3();
  SDA = 1; /*发送I2C总线结束信号*/
  NOP3();
  SCL = 1;
  NOP3();
}
/*******************************************************************
                 字节数据发送函数
函数原型: void  SendByte(UCHAR c);
功能:     将数据c发送出去,可以是地址,也可以是数据,发完后等待应答,并对
          此状态位进行操作.(不应答或非应答都使ack=0)
           发送数据正常，ack=1; ack=0表示被控器无应答或损坏。
********************************************************************/
void SendByte(u8 IIC_Byte) {
  u8 i;

  SDA_OUT;
  NOP();
  SCL = 0; // scl=0
  NOP3();
  //  R_Value=IIC_Byte;
  i = 8;
  while (i--) {
    if (IIC_Byte & 0x80)
      SDA = 1; // sda=1
    else
      SDA = 0; // sda=0

    NOP8();
    SCL = 1; // scl=1
    NOP8();
    SCL = 0; // scl=0
    NOP3();

    IIC_Byte <<= 1;
  }
  SDA = 0;
  SDA_IN;
  NOP8();
  SCL = 1;
  NOP8();
  if (SDA)
    f_ack = 0;
  else /*???????????*/
    f_ack = 1;
  SCL = 0;
  SDA_OUT;
  //		SDA=0;
}

/*******************************************************************
                 字节数据接收函数
函数原型: UCHAR  RcvByte();
功能:        用来接收从器件传来的数据,并判断总线错误(不发应答信号)，
          发完后请用应答函数应答从机。
********************************************************************/
void RcvByte() //(u8 chn)
{
  u8 iii;

  SDA_IN; // sda input
  iii = 8;
  R_Value = 0;
  while (iii--) {
    R_Value <<= 1;
    SCL = 1; // scl=1
    NOP8();
    if (SDA)
      R_Value |= 0x01; // delay 3us
    SCL = 0;           // scl=0
    NOP8();
  }
  SCL = 0; // scl=0
  NOP8();
}

/********************************************************************
                     应答子函数
函数原型:  void IIC_Ack(bit a);
功能:      主控器进行应答信号(可以是应答或非应答信号，由位参数a决定)
********************************************************************/
void IIC_Ack() {
  SDA_OUT;
  NOP8();

  if (f_ack) /*???????????? */
    SDA = 0;
  else
    SDA = 1;
  SCL = 1;
  NOP8();
  SCL = 0; /*????,??I2C????????*/
}

void IIC_ReadByte() {

  R_Value = 0;

  IIC_Start();          /*启动总线*/
  SendByte(ADR_SW6124); /*发送器件地址,写*/
  NOP();
  NOP();
  NOP();
  if (!f_ack) {

    return;
  }
  SendByte(R_Address); /*发送器件子地址*/
  NOP3();
  if (!f_ack) {

    return;
  }
  IIC_Start(); /*重新启动总线*/
  SendByte(ADR_SW6124 + 1);
  NOP3();
  if (!f_ack) {

    return;
  }
  RcvByte();
  NOP3();
  f_ack = 0;  // 发送ack
  IIC_Ack();  /*发送非应位*/
  IIC_Stop(); /*结束总线*/
}

void IIC_WriteByte() {
  IIC_Start(); /*启动总线*/
  NOP3();
  SendByte(ADR_SW6124); /*发送器件地址,写*/
  if (!f_ack) {
    return;
  }
  NOP3();
  SendByte(R_Address); /*发送器件子地址*/
  if (!f_ack) {
    return;
  }
  NOP3();
  SendByte(R_Value); /*发送器件地址,写*/
  if (!f_ack) {
    return;
  }
  IIC_Stop(); /*结束总线*/
}
