CREATE OR REPLACE FORCE VIEW GKBVEUCSEIJIN
--1.0.000.000-02.02-02.02
    (年度,整理番号,宛名番号,氏名かな,氏名漢字,生年月日,表示用生年月日,性別,
    中学校区,行政区,郵便番号,町名,番地,方書,電話番号,出欠区分,算定団体コード,
    宛名＿小学校コード,宛名＿小学校名,宛名＿中学校コード,宛名＿中学校名,
    宛名＿行政区コード,宛名＿行政区名,宛名＿地区コード,宛名＿地区名,世帯主カナ,
    世帯主名)
AS
Select A.NENDO,
          A.SEIRI_NO,
          A.KOJIN_CD,
          A.SHIMEI_KANA,
          A.SHIMEI_KANJI,
          A.SEINENGAPI,
          B.HYOJI_SEINENGAPI,
          A.SEIBETU,
          A.TYUGAKO_KU,
          A.GYOSEI_KU,
          A.YUBIN_NO,
          A.CHOMEI,
          A.BANCHI,
          A.KATAGAKI,
          A.TEL_NO,
          A.SYUKETSU_KBN,
          A.SANTEIDANTAI_CD,
          B.SHOGAKU_CD,
          NVL(TO_CHAR(GAAPK0030.FSHOGAKUMEI(B.SANTEIDANTAI_CD,B.SHOGAKU_CD)),''),
          B.CHUGAKU_CD,
          NVL(TO_CHAR(GAAPK0030.FCHUGAKUMEI(B.SANTEIDANTAI_CD,B.CHUGAKU_CD)),''),
          B.GYOSEIKU_CD,
          NVL(TO_CHAR(GAAPK0030.FGYOSEIKUMEI(B.SANTEIDANTAI_CD,B.GYOSEIKU_CD)),''),
          B.CHIKU_CD,                                                                 --2004/12/02 J.TSUKAMOTO ADD
          NVL(TO_CHAR(GAAPK0030.FCHIKUMEI(B.SANTEIDANTAI_CD,B.CHIKU_CD)),''),        --2004/12/02 J.TSUKAMOTO ADD
          C.NUSHI_SHIMEI_KANA,
          C.NUSHI_SHIMEI_KANJI
  From  GKBTSEIJINSHA A,
        GABTATENAKIHON B,
        GABTJUKIIDO C
  Where A.KOJIN_CD = B.KOJIN_NO(+)
  And   A.KOJIN_CD = C.KOJIN_NO(+)
/
