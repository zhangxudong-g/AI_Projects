CREATE OR REPLACE FORCE VIEW GKBVEUCSHUGAKUENJO
--1.0.000.000-02.02-02.02
    (児生＿宛名番号,児生＿現存区分,児生＿人格区分,児生＿記載順位,児生＿続柄,
    児生＿氏名カナ,児生＿氏名漢字,児生＿生年月日,児生＿表示用生年月日,児生＿性別,
    児生＿大字コード,児生＿郵便番号,児生＿町名,児生＿番地,児生＿方書,住基＿小学校コード,
    住基＿小学校名,住基＿中学校コード,住基＿中学校名,児生＿地区コード,児生＿行政区コード,
    児生＿班コード,児生＿算定団体コード,児生＿世帯番号,児生＿世帯主カナ,
    児生＿世帯主名,児生＿行政区名,保＿宛名番号,保＿現存区分,保＿人格区分,
    保＿記載順位,保＿続柄,保＿氏名カナ,保＿氏名漢字,保＿生年月日,保＿表示用生年月日,
    保＿性別,保＿大字コード,保＿郵便番号,保＿町名,保＿番地,保＿方書,小学校コード,
    小学校名,中学校コード,中学校名,区域外学校コード,区域外学校名,特別支援学校コード,
    特別支援学校名,学年コード,就援＿年度,就援＿申請日,就援＿認定日,就援＿却下日,
    就援＿消滅日,就援＿資格区分,就援＿認定理由１,就援＿認定理由２,就援＿認定理由３,
    就援＿民委コード,就援＿民委宛名番号,就援＿民委氏名カナ,就援＿民委氏名漢字,
    就援＿民委行政区ＣＤ,就援＿民委行政区名,就援＿備考
    ,学校区分コード,学校区分名, 学級コード,学級名) --- 2019/2/28 学校区分コード,学校区分名, 学級コード,学級名 at Ver 5.2.000.000 )
AS
Select A.KOJIN_NO,
          JA.GENZON_KBN,
          JA.JINKAKU_KBN,
          JJ.KISAI_JUNI,
          NVL(TO_CHAR(GKBFKZKGMGET2(1,A.ZOKUGARA1,A.ZOKUGARA2,A.ZOKUGARA3,A.ZOKUGARA4)),''),
          JA.SHIMEI_KANA,
          JA.SHIMEI_KANJI,
          JA.SEINENGAPI,
          JA.HYOJI_SEINENGAPI,
          JA.SEIBETSU,
          JA.OAZA_CD,
          JA.YUBIN_NO,
          JA.CHOMEI,
          JA.BANCHI,
          JA.KATAGAKI,
          JA.SHOGAKU_CD,
          NVL(TO_CHAR(GAAPK0030.FSHOGAKUMEI(JA.SANTEIDANTAI_CD,JA.SHOGAKU_CD)),''),
          JA.CHUGAKU_CD,
          NVL(TO_CHAR(GAAPK0030.FCHUGAKUMEI(JA.SANTEIDANTAI_CD,JA.CHUGAKU_CD)),''),
          JA.CHIKU_CD,
          JA.GYOSEIKU_CD,
          JA.HAN_CD,
          JA.SANTEIDANTAI_CD,
          JA.SETAI_NO,
          JJ.NUSHI_SHIMEI_KANA,
          JJ.NUSHI_SHIMEI_KANJI,
          NVL(TO_CHAR(GAAPK0030.FGYOSEIKUMEI(JA.SANTEIDANTAI_CD,JA.GYOSEIKU_CD)),''),
          A.HOGOSYA_KOJIN_NO,
          HA.GENZON_KBN,
          HA.JINKAKU_KBN,
          HJ.KISAI_JUNI,
          NVL(TO_CHAR(GKBFKZKGMGET2(2,A.HOGOSYA_ZOKUGARA1,A.HOGOSYA_ZOKUGARA2,A.HOGOSYA_ZOKUGARA3,A.HOGOSYA_ZOKUGARA4)),''),
          HA.SHIMEI_KANA,
          HA.SHIMEI_KANJI,
          HA.SEINENGAPI,
          HA.HYOJI_SEINENGAPI,
          HA.SEIBETSU,
          HA.OAZA_CD,
          HA.YUBIN_NO,
          HA.CHOMEI,
          HA.BANCHI,
          HA.KATAGAKI,
          A.SYOGAKO_CD,
          S.SYOGAKOMEI,
          A.TYUGAKO_CD,
          T.TYUGAKOMEI,
          A.KUIKIGAI_CD,
          K.KUIKIGAIMEI,
          A.YOGOGAKO_CD,
          Y.YOGOGAKOMEI,
          GA.GAKUNEN_CD,
          SE.NENDO,
          SE.SHINSEI_BI,
          SE.NINTEI_BI,
          SE.KYAKKA_BI,
          SE.SHOMETSU_BI,
          NVL(TO_CHAR(KKAPK0030.FCDGetR_SINGLE(1,'GKB',12,0,SE.SHIKAKU_KBN)),''),
          NVL(TO_CHAR(KKAPK0030.FCDGetR_SINGLE(1,'GKB',11,0,SE.NINTEI_RIYU_1)),''),
          NVL(TO_CHAR(KKAPK0030.FCDGetR_SINGLE(1,'GKB',11,0,SE.NINTEI_RIYU_2)),''),
          NVL(TO_CHAR(KKAPK0030.FCDGetR_SINGLE(1,'GKB',11,0,SE.NINTEI_RIYU_3)),''),
          SE.MINSEIIIN_CD,
          MI.MINSEIIIN_KOJIN_NO,
          MA.SHIMEI_KANA,
          MA.SHIMEI_KANJI,
          MA.GYOSEIKU_CD,
          NVL(TO_CHAR(GAAPK0030.FGYOSEIKUMEI(MA.SANTEIDANTAI_CD,MA.GYOSEIKU_CD)),''),
          SE.BIKO
-- 2018/2/28 Ver5.2.000.000 ADD BEGIN
         ,A.GAKKO_KBN_CD
         ,DECODE(A.GAKKO_KBN_CD,1,'小学校',2,'中学校',3,'特別支援学校',4,'区域外', NULL)
         ,A.GAKUKYU_CD  
         ,CASE  NVL(A.GAKKO_KBN_CD,0)
               WHEN 1 THEN (SELECT GAKUKYU_MEI FROM GKBTMSGAKUKYUCD WHERE GAKKO_KBN_CD = NVL(A.GAKKO_KBN_CD,0) AND GAKKO_CD = NVL(A.SYOGAKO_CD,0) AND GAKUKYU_CD =  NVL(A.GAKUKYU_CD,0))
               WHEN 2 THEN (SELECT GAKUKYU_MEI FROM GKBTMSGAKUKYUCD WHERE GAKKO_KBN_CD = NVL(A.GAKKO_KBN_CD,0) AND GAKKO_CD = NVL(A.TYUGAKO_CD,0) AND GAKUKYU_CD =  NVL(A.GAKUKYU_CD,0))
               WHEN 3 THEN (SELECT GAKUKYU_MEI FROM GKBTMSGAKUKYUCD WHERE GAKKO_KBN_CD = NVL(A.GAKKO_KBN_CD,0) AND GAKKO_CD = NVL(A.YOGOGAKO_CD,0) AND GAKUKYU_CD = NVL(A.GAKUKYU_CD,0))
               WHEN 4 THEN (SELECT GAKUKYU_MEI FROM GKBTMSGAKUKYUCD WHERE GAKKO_KBN_CD = NVL(A.GAKKO_KBN_CD,0) AND GAKKO_CD = NVL(A.KUIKIGAI_CD,0) AND GAKUKYU_CD = NVL(A.GAKUKYU_CD,0))
               ELSE NULL
          END
-- 2018/2/28 Ver5.2.000.000 ADD END
  From  GKBTGAKUREIBO A,
        GABTATENAKIHON JA,
        GABTJUKIIDO JJ,
        GABTATENAKIHON HA,
        GABTJUKIIDO HJ,
        GKBTSHOGAKKO S,
        GKBTCHUGAKKO T,
        GKBTKUIKIGAI K,
        GKBTYOGOGAKKO Y,
        GKBTGAKUNENLNK GA,
        GKBTSHUGAKUENJO SE,
        GKBTMINSEIIIN MI,
        GABTATENAKIHON MA
  Where A.HOGOSYA_KOJIN_NO = HA.KOJIN_NO(+)
  And   A.HOGOSYA_KOJIN_NO = HJ.KOJIN_NO(+)
  And   A.SAISHIN_KBN = 0
  And   A.KOJIN_NO = JA.KOJIN_NO(+)
  And   A.KOJIN_NO = JJ.KOJIN_NO(+)
  AND   A.SYOGAKO_CD = S.SYOGAKO_CD(+)
  AND   A.TYUGAKO_CD = T.TYUGAKO_CD(+)
  AND   A.KUIKIGAI_CD = K.KUIKIGAI_CD(+)
  AND   A.YOGOGAKO_CD = Y.YOGOGAKO_CD(+)
  AND   A.KOJIN_NO = GA.KOJIN_NO(+)
  AND   SE.KOJIN_NO = A.KOJIN_NO
  AND   SE.SAISHIN_KBN = 0
  AND   SE.SAKUJO_KBN = 0
  AND   SE.NENDO = MI.NENDO(+)
  AND   SE.MINSEIIIN_CD = MI.MINSEIIIN_CD(+)
  AND   MI.MINSEIIIN_KOJIN_NO = MA.KOJIN_NO(+)
/
