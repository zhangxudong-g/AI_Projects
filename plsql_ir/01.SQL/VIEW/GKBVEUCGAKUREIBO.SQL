CREATE OR REPLACE FORCE VIEW GKBVEUCGAKUREIBO
--1.0.106.001-02.02-02.02
--2024/06/03 ZCZL.chenying Update start 0.3.000.000:新WizLIFE２次開発
--2025/07/15 CTC.GL UPDATE 1.0.010.001:GKB_QA18128対応
--2025/09/24 CTC.XIAOMINGBO UPDATE 1.0.106.001:GKB_QA21378対応
--    (児生＿宛名番号,児生＿現存区分,児生＿人格区分,児生＿記載順位,児生＿続柄,児生＿氏名カナ,児生＿氏名漢字,児生＿生年月日,児生＿表示用生年月日,
--    児生＿性別,児生＿大字コード,児生＿郵便番号,児生＿町名,児生＿番地,児生＿方書,住基＿小学校コード,住基＿小学校名,住基＿中学校コード,
--    住基＿中学校名,児生＿地区コード,児生＿行政区コード,児生＿班コード,児生＿算定団体コード,児生＿世帯番号,児生＿世帯主カナ,児生＿世帯主名,
--    児生＿行政区名,保＿宛名番号,保＿現存区分,保＿人格区分,保＿記載順位,保＿続柄,保＿氏名カナ,保＿氏名漢字,保＿生年月日,保＿表示用生年月日,
--    保＿性別,保＿大字コード,保＿郵便番号,保＿町名,保＿番地,保＿方書,小学校コード,小学校名,中学校コード,中学校名,区域外学校コード,
--    区域外学校名,特別支援学校コード,特別支援学校名,学年コード,履歴連番,現存区分,最新区分,増年月日,減事由名称,減年月日,小学校入学年月日,
--    小学校転入学年月日,小学校転学年月日,小学校卒業年月日,中学校入学年月日,中学校転入学年月日,中学校転学年月日,中学校卒業年月日,督促年月日1,
--    督促年月日２,督促内容1,督促内容２,督促年月日３,督促内容３,督促年月日４,督促内容４,督促年月日５,督促内容５,区域外設置者名,区域外入学年月日,
--    区域外転入学年月日,区域外転学年月日,区域外退学年月日,区域外卒業年月日,支援設置者名,支援学校入学年月日,支援学校転入学年月日,支援学校転学年月日,
--    支援学校退学年月日,支援学校卒業年月日,就学猶予許可年月日,就学猶予事由,就学猶予開始年月日,就学猶予終了年月日,就学猶予復学年月日,
--    就学免除許可年月日,就学免除事由,就学免除復学年月日,異動日1,異動事由1,異動日２,異動事由２,異動日３,異動事由３,異動日４,異動事由４,
--    異動日５,異動事由５,異動日６,異動事由６,異動日７,異動事由７,異動日８,異動事由８,異動日９,異動事由９,異動日１０,異動事由１０,
--    作成日,更新日,更新時間,更新職員宛名番号,更新端末番号,学年＿学齢簿,処理日,就学状況,異動事項,帳票連番,小学校転入学＿学年,小学校転学＿学年,
--    中学校転入学＿学年,中学校転学＿学年,区域外転入学＿学年,区域外転学＿学年,区域外退学＿学年,支援学校転入学＿学年,支援学校転学＿学年,
--    支援学校退学＿学年,任意ビット1,任意ビット2,任意ビット3,任意ビット4,任意ビット5,任意ビット6,任意ビット7,任意ビット8,任意ビット9,
--    任意ビット10,任意ビット11,任意ビット12,任意ビット13,任意ビット14,任意ビット15,任意ビット16,任意ビット17,任意ビット18,
--    任意ビット19,任意ビット20,学校区分コード,学校区分名, 学級コード,学級名) --- 2019/2/28 学校区分コード,学校区分名, 学級コード,学級名 at Ver 5.2.000.000 
    (児生＿宛名番号,児生＿現存区分,児生＿人格区分,児生＿記載順位,児生＿続柄,児生＿氏名カナ,児生＿氏名漢字,児生＿生年月日,児生＿表示用生年月日,
    児生＿性別,児生＿大字コード,児生＿郵便番号,児生＿町名,児生＿番地,児生＿方書,住基＿小学校コード,住基＿小学校名,住基＿中学校コード,
    住基＿中学校名,児生＿地区コード,児生＿行政区コード,児生＿班コード,児生＿算定団体コード,児生＿世帯番号,児生＿世帯主カナ,児生＿世帯主名,
    児生＿行政区名,保＿宛名番号,保＿現存区分,保＿人格区分,保＿記載順位,保＿続柄,保＿氏名カナ,保＿氏名漢字,保＿生年月日,保＿表示用生年月日,
    保＿性別,保＿大字コード,保＿郵便番号,保＿町名,保＿番地,保＿方書,小学校コード,小学校名,中学校コード,中学校名,区域外学校コード,
    区域外学校名,特別支援学校コード,特別支援学校名,履歴連番,現存区分,最新区分,増年月日,減事由名称,減年月日,小学校入学年月日,
    小学校転入学年月日,小学校転学年月日,小学校卒業年月日,中学校入学年月日,中学校転入学年月日,中学校転学年月日,中学校卒業年月日,督促年月日1,
    督促年月日２,督促内容1,督促内容２,督促年月日３,督促内容３,督促年月日４,督促内容４,督促年月日５,督促内容５,区域外設置者名,区域外入学年月日,
    区域外転入学年月日,区域外転学年月日,区域外退学年月日,区域外卒業年月日,支援設置者名,支援学校入学年月日,支援学校転入学年月日,支援学校転学年月日,
    支援学校退学年月日,支援学校卒業年月日,就学猶予許可年月日,就学猶予事由,就学猶予開始年月日,就学猶予終了年月日,就学猶予復学年月日,
    就学免除許可年月日,就学免除事由,就学免除復学年月日,異動日1,異動事由1,異動日２,異動事由２,異動日３,異動事由３,異動日４,異動事由４,
    異動日５,異動事由５,異動日６,異動事由６,異動日７,異動事由７,異動日８,異動事由８,異動日９,異動事由９,異動日１０,異動事由１０,
    作成日,更新日,更新時間,更新職員宛名番号,更新端末番号,学年＿学齢簿,処理日,就学状況,異動事項,帳票連番,小学校転入学＿学年,小学校転学＿学年,
    中学校転入学＿学年,中学校転学＿学年,区域外転入学＿学年,区域外転学＿学年,区域外退学＿学年,支援学校転入学＿学年,支援学校転学＿学年,
    支援学校退学＿学年,学校区分コード,学校区分名, 学級コード,学級名,児童生徒_個人履歴番号枝番,児童生徒_性別,状態,転入前学校,転入前学年,原級留置_対象者フラグ,
    原級留置_決定年月日,原級留置_開始年月日,原級留置_終了年月日,原級留置_理由,就学指定校_小学校,就学指定校_中学校,就学校変更_開始学年_小学校,就学校変更_開始学年_中学校,
    就学校変更_申請年月日,就学校変更_許可年月日,就学校変更_区分,就学校変更_開始年月日,就学校変更_終了年月日,就学校変更_許可理由,就学校変更_事由,就学校変更_不許可理由,
    希望就学校_学校区分コード,希望就学校_小学校,希望就学校_中学校,希望就学校_受付年月日_小学校,希望就学校_受付年月日_中学校,区域外就学フラグ,区域外就学_申請年月日,
    区域外就学_許可年月日,区域外就学_開始年月日,区域外就学_終了年月日,区域外就学_事由,区域外就学_許可理由,区域外就学_不許可理由,不就学_開始年月日,不就学_終了年月日,
    不就学_理由,督促年月日６,督促年月日７,督促年月日８,督促年月日９,督促年月日１０,督促内容６,督促内容７,督促内容８,督促内容９,督促内容１０,督促事由１,督促事由２,
    督促事由３,督促事由４,督促事由５,督促事由６,督促事由７,督促事由８,督促事由９,督促事由１０,督促受理年月日１,督促受理年月日２,督促受理年月日３,督促受理年月日４,
    督促受理年月日５,督促受理年月日６,督促受理年月日７,督促受理年月日８,督促受理年月日９,督促受理年月日１０,就学猶予事由コード,就学免除事由コード,就学免除_開始年月日,就学免除_終了年月日,
    就学猶予_年数,就学免除_年数,国私立学校コード,国私立学校名,国私立入学年月日,国私立転入学年月日,国私立転学年月日,国私立卒業年月日,国私立転学_学年,国私立退学_学年,
    学齢簿変更_届出年月日,学齢簿変更_年月日,学齢簿変更_事由,備考,異動年月日,届出年月日,申請管理連番,異動時宛名基本履歴連番,異動時保護者宛名基本履歴連番,削除フラグ,入力端末_入力場所,
    児生＿通称名カナ,児生＿通称名,保＿通称名カナ,保＿通称名)
--2024/06/03 ZCZL.chenying Update end
AS
Select A.KOJIN_NO,
          JA.GENZON_KBN,
          JA.JINKAKU_KBN,
          JJ.KISAI_JUNI,
          --2006/02/01 Mod Start
          --NVL(TO_CHAR(AAPBSUB.EAPFZOKUGARA2(A.ZOKUGARA1,A.ZOKUGARA2,A.ZOKUGARA3,A.ZOKUGARA4,JA.SEIBETSU,0,1)),''),
          NVL(TO_CHAR(GKBFKZKGMGET2(1,A.ZOKUGARA1,A.ZOKUGARA2,A.ZOKUGARA3,A.ZOKUGARA4)),''),
          --2006/02/01 Mod End
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
          --A.HOGOSYA_KOJIN_NO,  2005/12/15 Del
          --2005/12/15 Mod Start
          --HA.CHIKU_CD,
          --HA.GYOSEIKU_CD,
          --HA.HAN_CD,
          --HA.SANTEIDANTAI_CD,
          --HA.SETAI_NO,
          JA.CHIKU_CD,
          JA.GYOSEIKU_CD,
          JA.HAN_CD,
          JA.SANTEIDANTAI_CD,
          JA.SETAI_NO,
          JJ.NUSHI_SHIMEI_KANA,
          JJ.NUSHI_SHIMEI_KANJI,
          NVL(TO_CHAR(GAAPK0030.FGYOSEIKUMEI(JA.SANTEIDANTAI_CD,JA.GYOSEIKU_CD)),''),
          --2005/12/15 Mod End
          A.HOGOSYA_KOJIN_NO,  --2005/12/15 Add
          HA.GENZON_KBN,
          HA.JINKAKU_KBN,
          HJ.KISAI_JUNI,
          --2006/02/01 Mod Start
          --NVL(TO_CHAR(AAPBSUB.EAPFZOKUGARA2(A.HOGOSYA_ZOKUGARA1,A.HOGOSYA_ZOKUGARA2,A.HOGOSYA_ZOKUGARA3,A.HOGOSYA_ZOKUGARA4,JA.SEIBETSU,0,1)),''),  --2005/12/15 Del
          --NVL(TO_CHAR(AAPBSUB.EAPFZOKUGARA2(A.HOGOSYA_ZOKUGARA1,A.HOGOSYA_ZOKUGARA2,A.HOGOSYA_ZOKUGARA3,A.HOGOSYA_ZOKUGARA4,HA.SEIBETSU,0,1)),''),    --2005/12/15 Add
          NVL(TO_CHAR(GKBFKZKGMGET2(2,A.HOGOSYA_ZOKUGARA1,A.HOGOSYA_ZOKUGARA2,A.HOGOSYA_ZOKUGARA3,A.HOGOSYA_ZOKUGARA4)),''),    --2005/12/15 Add
          --2006/02/01 Mod End
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
          --2005/12/15 Del Start
          --HJ.NUSHI_SHIMEI_KANA,
          --HJ.NUSHI_SHIMEI_KANJI,
          --NVL(TO_CHAR(AAPBSUB.AAPFGYOSEIKUMEI(HA.SANTEIDANTAI_CD,HA.GYOSEIKU_CD)),''),
          --2005/12/15 Del End
          A.SYOGAKO_CD,
          S.SYOGAKOMEI,
          A.TYUGAKO_CD,
          T.TYUGAKOMEI,
          A.KUIKIGAI_CD,
          K.KUIKIGAIMEI,
          A.YOGOGAKO_CD,
          Y.YOGOGAKOMEI,
--2024/06/03 ZCZL.chenying Delete 0.3.000.000:新WizLIFE２次開発
--          GA.GAKUNEN_CD,      --2005/12/15 Add
-- 2017/07/06 Ver5.0.000.000 ADD START
          A.RIREKI_RENBAN,
          A.GENZON_KBN,
          A.SAISHIN_KBN,
          A.ZO_NENGAPI,
          DECODE(A.GEN_JIYU_CD, 21,'転出' , 22,'死亡' ,23,'職権消除' ,24,'国籍喪失' ,25,'失踪宣告' , 31,'全員転居' ,32,'合併転居' ,33,'分離転居' ,34,'一部転居' ,50,'卒業' ,52,'中学校卒業' ,' '),  -- 減事由コードより減事由名称を表示
          A.GEN_NENGAPI,
          A.SYOGAKO_NYUGAKU_BI,
          A.SYOGAKO_TENNYUGAKU_BI,
          A.SYOGAKO_TENGAKU_BI,
          A.SYOGAKO_SOTSUGYO_BI,
          A.TYUGAKO_NYUGAKU_BI,
          A.TYUGAKO_TENNYUGAKU_BI,
          A.TYUGAKO_TENGAKU_BI,
          A.TYUGAKO_SOTSUGYO_BI,
          A.TOKUSOKU_BI1,
          A.TOKUSOKU_BI2,
          A.TOKUSOKU_NAIYO1,
          A.TOKUSOKU_NAIYO2,
          A.TOKUSOKU_BI3,
          A.TOKUSOKU_NAIYO3,
          A.TOKUSOKU_BI4,
          A.TOKUSOKU_NAIYO4,
          A.TOKUSOKU_BI5,
          A.TOKUSOKU_NAIYO5,
          A.KUIKIGAI_SETISYA,
          A.KUIKIGAI_NYUGAKU_BI,
          A.KUIKIGAI_TENNYUGAKU_BI,
          A.KUIKIGAI_TENGAKU_BI,
          A.KUIKIGAI_TAIGAKU_BI,
          A.KUIKIGAI_SOTSUGYO_BI,
          A.YOGOGAKO_SETISYA,
          A.YOGOGAKO_NYUGAKU_BI,
          A.YOGOGAKO_TENNYUGAKU_BI,
          A.YOGOGAKO_TENGAKU_BI,
          A.YOGOGAKO_TAIGAKU_BI,
          A.YOGOGAKO_SOTSUGYO_BI,
          A.YUYO_KYOKA_BI,
          A.YUYO_JIYU,
          A.YUYO_KAISI_BI,
          A.YUYO_SYURYO_BI,
          A.YUYO_FUKUGAKU_BI,
          A.MENJO_KYOKA_BI,
          A.MENJO_JIYU,
          A.MENJO_FUKUGAKU_BI,
          A.IDO_BI1,
          A.IDO_JIYU1,
          A.IDO_BI2,
          A.IDO_JIYU2,
          A.IDO_BI3,
          A.IDO_JIYU3,
          A.IDO_BI4,
          A.IDO_JIYU4,
          A.IDO_BI5,
          A.IDO_JIYU5,
          A.IDO_BI6,
          A.IDO_JIYU6,
          A.IDO_BI7,
          A.IDO_JIYU7,
          A.IDO_BI8,
          A.IDO_JIYU8,
          A.IDO_BI9,
          A.IDO_JIYU9,
          A.IDO_BI10,
          A.IDO_JIYU10,
          A.SYS_SAKUSEIBI,
          A.SYS_KOSHINBI,
          A.SYS_JIKAN,
          A.SYS_SHOKUINKOJIN_NO,
          A.SYS_TANMATU_NO,
          A.GAKUNEN,
          A.SHORIBI,
          A.SHUGAKU,
          A.IDOJIKO,
          A.CHOHYO_NO,
          A.SYOGAKO_TENNYUGAKU_GAKUNEN,
          A.SYOGAKO_TENGAKU_GAKUNEN,
          A.TYUGAKO_TENNYUGAKU_GAKUNEN,
          A.TYUGAKO_TENGAKU_GAKUNEN,
          A.KUIKIGAI_TENNYUGAKU_GAKUNEN,
          A.KUIKIGAI_TENGAKU_GAKUNEN,
          A.KUIKIGAI_TAIGAKU_GAKUNEN,
          A.YOGOGAKO_TENNYUGAKU_GAKUNEN,
          A.YOGOGAKO_TENGAKU_GAKUNEN,
          A.YOGOGAKO_TAIGAKU_GAKUNEN,
--2024/06/03 ZCZL.chenying Delete start 0.3.000.000:新WizLIFE２次開発
--          B.NINIBIT1,
--          B.NINIBIT2,
--          B.NINIBIT3,
--          B.NINIBIT4,
--          B.NINIBIT5,
--          B.NINIBIT6,
--          B.NINIBIT7,
--          B.NINIBIT8,
--          B.NINIBIT9,
--          B.NINIBIT10,
--          B.NINIBIT11,
--          B.NINIBIT12,
--          B.NINIBIT13,
--          B.NINIBIT14,
--          B.NINIBIT15,
--          B.NINIBIT16,
--          B.NINIBIT17,
--          B.NINIBIT18,
--          B.NINIBIT19,
--          B.NINIBIT20
--2024/06/03 ZCZL.chenying Delete end
-- 2017/07/06 Ver5.0.000.000 ADD END
-- 2018/2/28 Ver5.2.000.000 ADD BEGIN
--2024/06/03 ZCZL.chenying Update start 0.3.000.000:新WizLIFE２次開発
         --,A.GAKKO_KBN_CD
--         ,DECODE(A.GAKKO_KBN_CD,1,'小学校',2,'中学校',3,'特別支援学校',4,'区域外', NULL)
         A.GAKKO_KBN_CD
         ,DECODE(A.GAKKO_KBN_CD,1,'小学校',2,'中学校',3,'特別支援学校',4,'区域外',5,'国私立', NULL)
--2024/06/03 ZCZL.chenying Update end
         ,A.GAKUKYU_CD  
         ,CASE  NVL(A.GAKKO_KBN_CD,0)
               WHEN 1 THEN (SELECT GAKUKYU_MEI FROM GKBTMSGAKUKYUCD WHERE GAKKO_KBN_CD = NVL(A.GAKKO_KBN_CD,0) AND GAKKO_CD = NVL(A.SYOGAKO_CD,0) AND GAKUKYU_CD =  NVL(A.GAKUKYU_CD,0))
               WHEN 2 THEN (SELECT GAKUKYU_MEI FROM GKBTMSGAKUKYUCD WHERE GAKKO_KBN_CD = NVL(A.GAKKO_KBN_CD,0) AND GAKKO_CD = NVL(A.TYUGAKO_CD,0) AND GAKUKYU_CD =  NVL(A.GAKUKYU_CD,0))
               WHEN 3 THEN (SELECT GAKUKYU_MEI FROM GKBTMSGAKUKYUCD WHERE GAKKO_KBN_CD = NVL(A.GAKKO_KBN_CD,0) AND GAKKO_CD = NVL(A.YOGOGAKO_CD,0) AND GAKUKYU_CD = NVL(A.GAKUKYU_CD,0))
               WHEN 4 THEN (SELECT GAKUKYU_MEI FROM GKBTMSGAKUKYUCD WHERE GAKKO_KBN_CD = NVL(A.GAKKO_KBN_CD,0) AND GAKKO_CD = NVL(A.KUIKIGAI_CD,0) AND GAKUKYU_CD = NVL(A.GAKUKYU_CD,0))
--2024/06/03 ZCZL.chenying Add 0.3.000.000:新WizLIFE２次開発
               WHEN 5 THEN (SELECT GAKUKYU_MEI FROM GKBTMSGAKUKYUCD WHERE GAKKO_KBN_CD = NVL(A.GAKKO_KBN_CD,0) AND GAKKO_CD = NVL(A.KUNISHIRITSU_CD,0) AND GAKUKYU_CD = NVL(A.GAKUKYU_CD,0))
               ELSE NULL
          END
-- 2018/2/28 Ver5.2.000.000 ADD END
--2024/06/03 ZCZL.chenying Add start 0.3.000.000:新WizLIFE２次開発
         ,A.RIREKI_RENBAN_EDA
         ,A.SEIBETSU
         ,A.JOTAI
         ,A.TENNYUMAE_GAKKO_CD
         ,A.TENNYUMAE_GAKUNEN
         ,A.GENKYURYUCHI_FLG
         ,A.GENKYURYUCHI_KETTEI_BI
         ,A.GENKYURYUCHI_KAISI_BI
         ,A.GENKYURYUCHI_SYURYOBI
         ,A.GENKYURYUCHI_RIYU
         ,A.SHITEI_SYOGAKO_CD
         ,A.SHITEI_TYUGAKO_CD
         ,A.HENKO_GAKUNEN_SYOGAKO
         ,A.HENKO_GAKUNEN_TYUGAKO
         ,A.HENKO_SHINSEI_BI
         ,A.HENKO_KYOKA_BI
         ,A.HENKO_KBN
         ,A.HENKO_KAISI_BI
         ,A.HENKO_SYURYO_BI
         ,A.HENKO_KYOKA_RIYU
         ,A.HENKO_JIYU
         ,A.HENKO_HUKYOKA_RIYU
         ,A.KIBO_GAKKO_KBN_CD
         ,A.KIBO_SYOGAKKO_CD
         ,A.KIBO_TYUGAKKO_CD
         ,A.KIBO_UKETSUKE_BI_SYOGAKO
         ,A.KIBO_UKETSUKE_BI_TYUGAKO
         ,A.KUIKIGAISHUGAKU_FLG
         ,A.KUIKIGAISHUGAKU_SHINSEI_BI
         ,A.KUIKIGAISHUGAKU_KYOKA_BI
         ,A.KUIKIGAISHUGAKU_KAISI_BI
         ,A.KUIKIGAISHUGAKU_SYURYO_BI
         ,A.KUIKIGAISHUGAKU_JIYU
         ,A.KUIKIGAISHUGAKU_KYOKA_RIYU
         ,A.KUIKIGAISHUGAKU_HUKYOKA_RIYU
         ,A.HUSHUGAKU_KAISI_BI
         ,A.HUSHUGAKU_SYURYO_BI
         ,A.HUSHUGAKU_RIYU
         ,A.TOKUSOKU_BI6
         ,A.TOKUSOKU_BI7
         ,A.TOKUSOKU_BI8
         ,A.TOKUSOKU_BI9
         ,A.TOKUSOKU_BI10
         ,A.TOKUSOKU_NAIYO6
         ,A.TOKUSOKU_NAIYO7
         ,A.TOKUSOKU_NAIYO8
         ,A.TOKUSOKU_NAIYO9
         ,A.TOKUSOKU_NAIYO10
         ,A.TOKUSOKU_JIYU1
         ,A.TOKUSOKU_JIYU2
         ,A.TOKUSOKU_JIYU3
         ,A.TOKUSOKU_JIYU4
         ,A.TOKUSOKU_JIYU5
         ,A.TOKUSOKU_JIYU6
         ,A.TOKUSOKU_JIYU7
         ,A.TOKUSOKU_JIYU8
         ,A.TOKUSOKU_JIYU9
         ,A.TOKUSOKU_JIYU10
         ,A.TOKUSOKU_JURI_BI1
         ,A.TOKUSOKU_JURI_BI2
         ,A.TOKUSOKU_JURI_BI3
         ,A.TOKUSOKU_JURI_BI4
         ,A.TOKUSOKU_JURI_BI5
         ,A.TOKUSOKU_JURI_BI6
         ,A.TOKUSOKU_JURI_BI7
         ,A.TOKUSOKU_JURI_BI8
         ,A.TOKUSOKU_JURI_BI9
         ,A.TOKUSOKU_JURI_BI10
         ,A.YUYO_JIYU_CD
         ,A.MENJO_JIYU_CD
         ,A.MENJO_KAISI_BI
         ,A.MENJO_SYURYO_BI
         ,A.YUYO_NENSU
         ,A.MENJO_NENSU
         ,A.KUNISHIRITSU_CD
         ,KN.KUNISHIRITSUGAKKOMEI
         ,A.KUNISHIRITSU_NYUGAKU_BI
         ,A.KUNISHIRITSU_TENNYUGAKU_BI
         ,A.KUNISHIRITSU_TENGAKU_BI
         ,A.KUNISHIRITSU_SOTSUGYO_BI
         ,A.KUNISHIRITSU_TENGAKU_GAKUNEN
         ,A.KUNISHIRITSU_TAIGAKU_GAKUNEN
         ,A.GRB_HENKO_TODOKEDE_BI
         ,A.GRB_HENKO_BI
         ,A.GRB_HENKO_JIYU
         ,A.BIKO
         ,A.IDO_BI
         ,A.TODOKEDE_BI
         ,A.SHINSEI_KANRI_RENBAN
         ,A.IDOJI_ATENA_RIREKI_RENBAN
         ,A.HOGOSYA_IDOJI_RIREKI_RENBAN
         ,A.SAKUJO_FLG
         ,A.SYS_TANMATU_BASHO
         ,NVL(A.TSUSHOMEI_KANA, JA.TSUSHOMEI_KANA)
         ,NVL(A.TSUSHOMEI_KANJI, JA.TSUSHOMEI_KANJI)
         ,NVL(A.TSUSHOMEI_KANA, HA.TSUSHOMEI_KANA)
         ,NVL(A.TSUSHOMEI_KANJI, HA.TSUSHOMEI_KANJI)
--2024/06/03 ZCZL.chenying Add end
  From  GKBTGAKUREIBO A,
        GABTATENAKIHON JA,
        GABTJUKIIDO JJ,
        GABTATENAKIHON HA,
        GABTJUKIIDO HJ,
        GKBTSHOGAKKO S,
        GKBTCHUGAKKO T,
        GKBTKUIKIGAI K,
        GKBTYOGOGAKKO Y,
--2024/06/03 ZCZL.chenying Update start 0.3.000.000:新WizLIFE２次開発
--        GKBTGAKUNENLNK GA,   --2005/12/15 Add
--  GKBTNINIBIT B        --2017/07/06 Ver5.0.000.000 ADD
--  Where A.HOGOSYA_KOJIN_NO = HA.KOJIN_NO(+)
        GKBTKUNISIRITSUGAKKO KN,
        GKBTMSGAKUKYUCD GK
  Where A.HOGOSYA_KOJIN_NO = HA.KOJIN_NO
--2025/09/24 CTC.XIAOMINGBO UPDATE START 1.0.106.001:GKB_QA21378対応
--  And   A.HOGOSYA_IDOJI_RIREKI_RENBAN = HA.RIREKI_RENBAN
--2025/09/24 CTC.XIAOMINGBO UPDATE END 
--2024/06/03 ZCZL.chenying Update end
  And   A.HOGOSYA_KOJIN_NO = HJ.KOJIN_NO(+)
  And   A.SAISHIN_KBN = 0
--2024/06/03 ZCZL.chenying Update start 0.3.000.000:新WizLIFE２次開発
--  And   A.KOJIN_NO = JA.KOJIN_NO(+)
  And   A.KOJIN_NO = JA.KOJIN_NO
--2025/09/24 CTC.XIAOMINGBO UPDATE START 1.0.106.001:GKB_QA21378対応
--  And   A.IDOJI_ATENA_RIREKI_RENBAN = JA.RIREKI_RENBAN
--2025/09/24 CTC.XIAOMINGBO UPDATE END 
--2024/06/03 ZCZL.chenying Update end
  And   A.KOJIN_NO = JJ.KOJIN_NO(+)
  AND   A.SYOGAKO_CD = S.SYOGAKO_CD(+)
  AND   A.TYUGAKO_CD = T.TYUGAKO_CD(+)
  AND   A.KUIKIGAI_CD = K.KUIKIGAI_CD(+)
  AND   A.YOGOGAKO_CD = Y.YOGOGAKO_CD(+)
--2024/06/03 ZCZL.chenying Update start 0.3.000.000:新WizLIFE２次開発
--  AND   A.KOJIN_NO = GA.KOJIN_NO(+)     --2005/12/15 Add
--  AND  A.KOJIN_NO = B.KOJIN_NO AND A.RIREKI_RENBAN = B.RIREKI_RENBAN   --2017/07/06 Ver5.0.000.000 ADD
  AND   A.KUNISHIRITSU_CD = KN.KUNISHIRITSUGAKKO_CD(+)
  AND   A.GAKKO_KBN_CD = GK.GAKKO_KBN_CD(+)
  AND  (CASE WHEN A.GAKKO_KBN_CD = 1 THEN  A.SYOGAKO_CD
             WHEN A.GAKKO_KBN_CD = 2 THEN  A.TYUGAKO_CD
             WHEN A.GAKKO_KBN_CD = 3 THEN  A.YOGOGAKO_CD
             WHEN A.GAKKO_KBN_CD = 4 THEN  A.KUIKIGAI_CD 
             WHEN A.GAKKO_KBN_CD = 5 THEN  A.KUNISHIRITSU_CD END)= GK.GAKKO_CD(+)
  AND  A.GAKUKYU_CD       = GK.GAKUKYU_CD(+)
--  2025/07/15 CTC.GL UPDATE Start 1.0.010.001:GKB_QA18128対応
  AND  A.SAKUJO_FLG = 0
--  2025/07/15 CTC.GL UPDATE End
--2024/06/03 ZCZL.chenying Update end
/
