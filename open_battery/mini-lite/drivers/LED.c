#include "LED.h"
#include "IIC.h"
u8 LED_Power_onflag_TIME;
bit Fast_charging;
u8 Electricity;
bit load_IN;
u16 TIME_1S;
u8 LED_BUFF_CNT;
u32 VBAT_Temp5 = 12601;
u8 time_500ms_cnt;
void LED_mode(void) {
  if ((dis_charge) && (!PB1)) {
    if (VBAT_Temp > 5000) {
      if (VBAT_Temp < VBAT_Temp5) {
        VBAT_Temp5 = VBAT_Temp;
      }
    }
    if (VBAT_Temp5 < 6200) {
      time_500ms_cnt++;
      if (time_500ms_cnt >= 5) {
        LED1 = !LED1;
        time_500ms_cnt = 0;
      }
      LED2 = 0;
      LED3 = 0;
      LED4 = 0;
    } else if (VBAT_Temp5 < 6600) {
      LED1 = 1;
      LED2 = 0;
      LED3 = 0;
      LED4 = 0;
    } else if (VBAT_Temp5 < 7200) {
      LED1 = 1;
      LED2 = 1;
      LED3 = 0;
      LED4 = 0;
    } else if (VBAT_Temp5 < 7800) {
      LED1 = 1;
      LED2 = 1;
      LED3 = 1;
      LED4 = 0;
    } else if (VBAT_Temp5 < 15000) {
      LED1 = 1;
      LED2 = 1;
      LED3 = 1;
      LED4 = 1;
    }
  } else if ((dis_charge) || (PB1)) {
    time_500ms_cnt++;
    R_Address = 0x04; // ADC ÅäÖÃ
    IIC_ReadByte();
    if (R_Value & 0x10) {
      R_Address = 0x04; // ADC ÅäÖÃ
      R_Value &= 0XEF;
      IIC_WriteByte();
      time_500ms_cnt = 0;
      LED1 = 1;
      LED2 = 1;
      LED3 = 1;
      LED4 = 1;

    } else {

      if (VBAT_Temp > 3000) {
        if (VBAT_Temp > VBAT_Temp5) {
          VBAT_Temp5 = VBAT_Temp;
        }
      }
      if (VBAT_Temp5 < 6600) {

        if (time_500ms_cnt >= 5) {
          LED1 = !LED1;
          time_500ms_cnt = 0;
        }
        LED2 = 0;
        LED3 = 0;
        LED4 = 0;
      } else if (VBAT_Temp5 < 7200) {
        LED1 = 1;
        if (time_500ms_cnt >= 5) {
          LED2 = !LED2;
          time_500ms_cnt = 0;
        }
        LED3 = 0;
        LED4 = 0;
      } else if (VBAT_Temp5 < 7800) {
        LED1 = 1;
        LED2 = 1;
        if (time_500ms_cnt >= 5) {
          LED3 = !LED3;
          time_500ms_cnt = 0;
        }
        LED4 = 0;
      } else if (VBAT_Temp5 < 15000) {
        LED1 = 1;
        LED2 = 1;
        LED3 = 1;
        if (time_500ms_cnt >= 5) {
          LED4 = !LED4;
          time_500ms_cnt = 0;
        }
      }
    }

  } else {
    LED1 = 0;
    LED2 = 0;
    LED3 = 0;
    LED4 = 0;
  }
}
