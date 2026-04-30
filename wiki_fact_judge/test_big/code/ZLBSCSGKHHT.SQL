CREATE OR REPLACE PROCEDURE ZLBSCSGKHHT (i_NRENBAN             IN  NUMBER,     --処理登録連番
--1.1.200.000
                                                           i_NCHOTEI_NENDO        IN  NUMBER,     --調定年度
                                                           i_NNENDO_HANI          IN  NUMBER,     --年度範囲
                                                           i_NSYS_SHOKUINKOJIN_NO IN  CHAR,       --更新職員宛名番号
                                                           i_VMASIN_NO            IN  NVARCHAR2,  --更新端末番号
                                                           o_NRTN                 OUT NUMBER)
-------------------------------------------------------------------------------------
--  業務名        ZLB（国民健康保険税）
--  PG 名         ZLBSCSGKHHT
--  名称          賦課決定期間の制限対象候補世帯判定処理
--  処理概要      賦課決定期間の制限対象候補世帯一覧の作成候補世帯に対して対象世帯かどうか判定を行う。
--  引き数        i_NRENBAN               処理登録連番
--                i_NCHOTEI_NENDO         調定年度
--                i_NNENDO_HANI           年度範囲
--                i_NSYS_SHOKUINKOJIN_NO  更新職員宛名番号
--                i_VMASIN_NO             更新端末番号
--                o_NRTN                  処理結果（0：正常、1：異常）
--  作成者       ZCZL.GUOXU  2023/08/01
--  VERSION      0.2.000.000
-------------------------------------------------------------------------------------
--変更履歴
--2025/08/11 ZCZL.LIUDI UPDATE 1.1.200.000:子ども子育て支援金対応
-------------------------------------------------------------------------------------
IS
  NRTN                           NUMBER;          --戻り値
  NMAX_STEP_NO                   NUMBER := 0;     --最大値のステップ番号
  VMSG                           NVARCHAR2(256);

  NK_KOKU_SETAI_NO               NUMBER;          --計キー国保世帯番号
  NK_SANTEIDANTAI_CD             NUMBER;          --計キー算定団体コード
  NK_CHOTEI_NENDO                NUMBER;          --計キー調定年度
  NK_NENDO_BUN                   NUMBER;          --計キー年度分
  NK_TSUCHI_NO                   NUMBER;          --計キー通知書番号
  NK_NUSHI_KOJIN_NO              NUMBER;          --計キー世帯主宛名番号
  VK_SYS_TANMATSU_NO             NVARCHAR2(256);  --計キー更新端末番号

  FK_KOKU_SETAI_NO               NUMBER;          --賦キー国保世帯番号
  FK_SANTEIDANTAI_CD             NUMBER;          --賦キー算定団体コード
  FK_CHOTEI_NENDO                NUMBER;          --賦キー調定年度
  FK_NENDO_BUN                   NUMBER;          --賦キー年度分
  FK_TSUCHI_NO                   NUMBER;          --賦キー通知書番号

  NKYOTSU_ZO_FLG                 NUMBER := 0;     --共通増フラグ
  NKYOTSU_GEN_FLG                NUMBER := 0;     --共通減フラグ

  --賦課状況
  TYPE KEIKIRECORD IS RECORD(
    KOKU_SETAI_NO                NUMBER,       --国保世帯番号
    SANTEIDANTAI_CD              NUMBER,       --算定団体コード
    CHOTEI_NENDO                 NUMBER,       --調定年度
    NENDO_BUN                    NUMBER,       --年度分
    TSUCHI_NO                    NUMBER,       --通知書番号
    NUSHI_KOJIN_NO               NUMBER,       --世帯主宛名番号
    KINTO_CNT                    NUMBER,       --均等人員
    KAHYO                        NUMBER,       --基準総所得
    SHOTOKU_WARI                 NUMBER,       --所得割額
    SHISANZEI                    NUMBER,       --資産税額
    SHISAN_WARI                  NUMBER,       --資産割額
    KINTO_WARI                   NUMBER,       --均等割額
    BYODO_WARI                   NUMBER,       --平等割額
    SEKISAN                      NUMBER,       --積算合計
    GENDO_CHOKA                  NUMBER,       --限度超過額
    KEIGEN_K_WARI                NUMBER,       --軽減均等
    KEIGEN_B_WARI                NUMBER,       --軽減平等
    TSUKIWARI_GEN                NUMBER,       --月割減額
    GENMEN                       NUMBER,       --減免額
    KANENDO                      NUMBER,       --他年度賦課
    NENZEI                       NUMBER,       --年額
    KEIGEN_4                     NUMBER,       --軽減4月
    KEIGEN_5                     NUMBER,       --軽減5月
    KEIGEN_6                     NUMBER,       --軽減6月
    KEIGEN_7                     NUMBER,       --軽減7月
    KEIGEN_8                     NUMBER,       --軽減8月
    KEIGEN_9                     NUMBER,       --軽減9月
    KEIGEN_10                    NUMBER,       --軽減10月
    KEIGEN_11                    NUMBER,       --軽減11月
    KEIGEN_12                    NUMBER,       --軽減12月
    KEIGEN_1                     NUMBER,       --軽減1月
    KEIGEN_2                     NUMBER,       --軽減2月
    KEIGEN_3                     NUMBER        --軽減3月
    );
--2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
  --賦課状況_子ども
  TYPE KEIKIRECORD_KDM IS RECORD(
    KOKU_SETAI_NO                NUMBER,       --国保世帯番号
    SANTEIDANTAI_CD              NUMBER,       --算定団体コード
    CHOTEI_NENDO                 NUMBER,       --調定年度
    NENDO_BUN                    NUMBER,       --年度分
    TSUCHI_NO                    NUMBER,       --通知書番号
    NUSHI_KOJIN_NO               NUMBER,       --世帯主宛名番号
    KINTO_CNT                    NUMBER,       --均等人員
    KAHYO                        NUMBER,       --基準総所得
    SHOTOKU_WARI                 NUMBER,       --所得割額
    SHISANZEI                    NUMBER,       --資産税額
    SHISAN_WARI                  NUMBER,       --資産割額
    KINTO_WARI                   NUMBER,       --均等割額
    BYODO_WARI                   NUMBER,       --平等割額
    SEKISAN                      NUMBER,       --積算合計
    GENDO_CHOKA                  NUMBER,       --限度超過額 
    KEIGEN_K_WARI                NUMBER,       --軽減均等
    KEIGEN_B_WARI                NUMBER,       --軽減平等
    TSUKIWARI_GEN                NUMBER,       --月割減額
    GENMEN                       NUMBER,       --減免額
    KANENDO                      NUMBER,       --他年度賦課
    NENZEI                       NUMBER,       --年額
    KEIGEN_4                     NUMBER,       --軽減4月
    KEIGEN_5                     NUMBER,       --軽減5月
    KEIGEN_6                     NUMBER,       --軽減6月
    KEIGEN_7                     NUMBER,       --軽減7月
    KEIGEN_8                     NUMBER,       --軽減8月
    KEIGEN_9                     NUMBER,       --軽減9月
    KEIGEN_10                    NUMBER,       --軽減10月
    KEIGEN_11                    NUMBER,       --軽減11月
    KEIGEN_12                    NUMBER,       --軽減12月
    KEIGEN_1                     NUMBER,       --軽減1月
    KEIGEN_2                     NUMBER,       --軽減2月
    KEIGEN_3                     NUMBER,       --軽減3月
    KINTO_CNT_KDM18              NUMBER        --18歳以上均等人員 
    );
--2025/08/11 ZCZL.LIUDI ADD END
  --賦課個人
  TYPE KOJINRECORD IS RECORD(
    KOKU_SETAI_NO                NUMBER,
    SANTEIDANTAI_CD              NUMBER,
    CHOTEI_NENDO                 NUMBER,
    NENDO_BUN                    NUMBER,
    TSUCHI_NO                    NUMBER,
    ISHI_SHIK_4_SUM              NUMBER,
    ISHI_SHIK_5_SUM              NUMBER,
    ISHI_SHIK_6_SUM              NUMBER,
    ISHI_SHIK_7_SUM              NUMBER,
    ISHI_SHIK_8_SUM              NUMBER,
    ISHI_SHIK_9_SUM              NUMBER,
    ISHI_SHIK_10_SUM             NUMBER,
    ISHI_SHIK_11_SUM             NUMBER,
    ISHI_SHIK_12_SUM             NUMBER,
    ISHI_SHIK_1_SUM              NUMBER,
    ISHI_SHIK_2_SUM              NUMBER,
    ISHI_SHIK_3_SUM              NUMBER,
    KAI_SHIK_4_SUM               NUMBER,
    KAI_SHIK_5_SUM               NUMBER,
    KAI_SHIK_6_SUM               NUMBER,
    KAI_SHIK_7_SUM               NUMBER,
    KAI_SHIK_8_SUM               NUMBER,
    KAI_SHIK_9_SUM               NUMBER,
    KAI_SHIK_10_SUM              NUMBER,
    KAI_SHIK_11_SUM              NUMBER,
    KAI_SHIK_12_SUM              NUMBER,
    KAI_SHIK_1_SUM               NUMBER,
    KAI_SHIK_2_SUM               NUMBER,
    KAI_SHIK_3_SUM               NUMBER,
    TD_SHIK_4_SUM                NUMBER,
    TD_SHIK_5_SUM                NUMBER,
    TD_SHIK_6_SUM                NUMBER,
    TD_SHIK_7_SUM                NUMBER,
    TD_SHIK_8_SUM                NUMBER,
    TD_SHIK_9_SUM                NUMBER,
    TD_SHIK_10_SUM               NUMBER,
    TD_SHIK_11_SUM               NUMBER,
    TD_SHIK_12_SUM               NUMBER,
    TD_SHIK_1_SUM                NUMBER,
    TD_SHIK_2_SUM                NUMBER,
    TD_SHIK_3_SUM                NUMBER,
    TK_SHIK_4_SUM                NUMBER,
    TK_SHIK_5_SUM                NUMBER,
    TK_SHIK_6_SUM                NUMBER,
    TK_SHIK_7_SUM                NUMBER,
    TK_SHIK_8_SUM                NUMBER,
    TK_SHIK_9_SUM                NUMBER,
    TK_SHIK_10_SUM               NUMBER,
    TK_SHIK_11_SUM               NUMBER,
    TK_SHIK_12_SUM               NUMBER,
    TK_SHIK_1_SUM                NUMBER,
    TK_SHIK_2_SUM                NUMBER,
    TK_SHIK_3_SUM                NUMBER,
    KYU_SHIK_4_SUM               NUMBER,
    KYU_SHIK_5_SUM               NUMBER,
    KYU_SHIK_6_SUM               NUMBER,
    KYU_SHIK_7_SUM               NUMBER,
    KYU_SHIK_8_SUM               NUMBER,
    KYU_SHIK_9_SUM               NUMBER,
    KYU_SHIK_10_SUM              NUMBER,
    KYU_SHIK_11_SUM              NUMBER,
    KYU_SHIK_12_SUM              NUMBER,
    KYU_SHIK_1_SUM               NUMBER,
    KYU_SHIK_2_SUM               NUMBER,
    KYU_SHIK_3_SUM               NUMBER,
    SHITSU_SHIK_4_SUM            NUMBER,
    SHITSU_SHIK_5_SUM            NUMBER,
    SHITSU_SHIK_6_SUM            NUMBER,
    SHITSU_SHIK_7_SUM            NUMBER,
    SHITSU_SHIK_8_SUM            NUMBER,
    SHITSU_SHIK_9_SUM            NUMBER,
    SHITSU_SHIK_10_SUM           NUMBER,
    SHITSU_SHIK_11_SUM           NUMBER,
    SHITSU_SHIK_12_SUM           NUMBER,
    SHITSU_SHIK_1_SUM            NUMBER,
    SHITSU_SHIK_2_SUM            NUMBER,
    SHITSU_SHIK_3_SUM            NUMBER
    );

  --賦課状況の増フラグと減フラグ
  TYPE JOKYO_ZOGENFLG_RECORD IS RECORD(
    KINTO_ZO_FLG                 NUMBER := 0,
    KINTO_GEN_FLG                NUMBER := 0,
    KAHYO_ZO_FLG                 NUMBER := 0,
    KAHYO_GEN_FLG                NUMBER := 0,
    SHOTOKU_WARI_ZO_FLG          NUMBER := 0,
    SHOTOKU_WARI_GEN_FLG         NUMBER := 0,
    SHISANZEI_ZO_FLG             NUMBER := 0,
    SHISANZEI_GEN_FLG            NUMBER := 0,
    SHISAN_WARI_ZO_FLG           NUMBER := 0,
    SHISAN_WARI_GEN_FLG          NUMBER := 0,
    KINTO_WARI_ZO_FLG            NUMBER := 0,
    KINTO_WARI_GEN_FLG           NUMBER := 0,
    BYODO_WARI_ZO_FLG            NUMBER := 0,
    BYODO_WARI_GEN_FLG           NUMBER := 0,
    SEKISAN_ZO_FLG               NUMBER := 0,
    SEKISAN_GEN_FLG              NUMBER := 0,
    GENDO_CHOKA_ZO_FLG           NUMBER := 0,
    GENDO_CHOKA_GEN_FLG          NUMBER := 0,
    KEIGEN_K_WARI_ZO_FLG         NUMBER := 0,
    KEIGEN_K_WARI_GEN_FLG        NUMBER := 0,
    KEIGEN_B_WARI_ZO_FLG         NUMBER := 0,
    KEIGEN_B_WARI_GEN_FLG        NUMBER := 0,
    TSUKIWARI_GEN_ZO_FLG         NUMBER := 0,
    TSUKIWARI_GEN_GEN_FLG        NUMBER := 0,
    GENMEN_ZO_FLG                NUMBER := 0,
    GENMEN_GEN_FLG               NUMBER := 0,
    KANENDO_ZO_FLG               NUMBER := 0,
    KANENDO_GEN_FLG              NUMBER := 0,
    NENZEI_ZO_FLG                NUMBER := 0,
    NENZEI_GEN_FLG               NUMBER := 0,
    KEIGEN_4_ZO_FLG              NUMBER := 0,
    KEIGEN_4_GEN_FLG             NUMBER := 0,
    KEIGEN_5_ZO_FLG              NUMBER := 0,
    KEIGEN_5_GEN_FLG             NUMBER := 0,
    KEIGEN_6_ZO_FLG              NUMBER := 0,
    KEIGEN_6_GEN_FLG             NUMBER := 0,
    KEIGEN_7_ZO_FLG              NUMBER := 0,
    KEIGEN_7_GEN_FLG             NUMBER := 0,
    KEIGEN_8_ZO_FLG              NUMBER := 0,
    KEIGEN_8_GEN_FLG             NUMBER := 0,
    KEIGEN_9_ZO_FLG              NUMBER := 0,
    KEIGEN_9_GEN_FLG             NUMBER := 0,
    KEIGEN_10_ZO_FLG             NUMBER := 0,
    KEIGEN_10_GEN_FLG            NUMBER := 0,
    KEIGEN_11_ZO_FLG             NUMBER := 0,
    KEIGEN_11_GEN_FLG            NUMBER := 0,
    KEIGEN_12_ZO_FLG             NUMBER := 0,
    KEIGEN_12_GEN_FLG            NUMBER := 0,
    KEIGEN_1_ZO_FLG              NUMBER := 0,
    KEIGEN_1_GEN_FLG             NUMBER := 0,
    KEIGEN_2_ZO_FLG              NUMBER := 0,
    KEIGEN_2_GEN_FLG             NUMBER := 0,
    KEIGEN_3_ZO_FLG              NUMBER := 0,
    KEIGEN_3_GEN_FLG             NUMBER := 0
    );
--2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
--賦課状況の増フラグと減フラグ_子ども
  TYPE JOKYO_ZOGENFLG_RECORD_KDM IS RECORD(
    KINTO_ZO_FLG                 NUMBER := 0,
    KINTO_GEN_FLG                NUMBER := 0,
    KAHYO_ZO_FLG                 NUMBER := 0,
    KAHYO_GEN_FLG                NUMBER := 0,
    SHOTOKU_WARI_ZO_FLG          NUMBER := 0,
    SHOTOKU_WARI_GEN_FLG         NUMBER := 0,
    SHISANZEI_ZO_FLG             NUMBER := 0,
    SHISANZEI_GEN_FLG            NUMBER := 0,
    SHISAN_WARI_ZO_FLG           NUMBER := 0,
    SHISAN_WARI_GEN_FLG          NUMBER := 0,
    KINTO_WARI_ZO_FLG            NUMBER := 0,
    KINTO_WARI_GEN_FLG           NUMBER := 0,
    BYODO_WARI_ZO_FLG            NUMBER := 0,
    BYODO_WARI_GEN_FLG           NUMBER := 0,
    SEKISAN_ZO_FLG               NUMBER := 0,
    SEKISAN_GEN_FLG              NUMBER := 0,
    GENDO_CHOKA_ZO_FLG           NUMBER := 0,
    GENDO_CHOKA_GEN_FLG          NUMBER := 0,
    KEIGEN_K_WARI_ZO_FLG         NUMBER := 0,
    KEIGEN_K_WARI_GEN_FLG        NUMBER := 0,
    KEIGEN_B_WARI_ZO_FLG         NUMBER := 0,
    KEIGEN_B_WARI_GEN_FLG        NUMBER := 0,
    TSUKIWARI_GEN_ZO_FLG         NUMBER := 0,
    TSUKIWARI_GEN_GEN_FLG        NUMBER := 0,
    GENMEN_ZO_FLG                NUMBER := 0,
    GENMEN_GEN_FLG               NUMBER := 0,
    KANENDO_ZO_FLG               NUMBER := 0,
    KANENDO_GEN_FLG              NUMBER := 0,
    NENZEI_ZO_FLG                NUMBER := 0,
    NENZEI_GEN_FLG               NUMBER := 0,
    KEIGEN_4_ZO_FLG              NUMBER := 0,
    KEIGEN_4_GEN_FLG             NUMBER := 0,
    KEIGEN_5_ZO_FLG              NUMBER := 0,
    KEIGEN_5_GEN_FLG             NUMBER := 0,
    KEIGEN_6_ZO_FLG              NUMBER := 0,
    KEIGEN_6_GEN_FLG             NUMBER := 0,
    KEIGEN_7_ZO_FLG              NUMBER := 0,
    KEIGEN_7_GEN_FLG             NUMBER := 0,
    KEIGEN_8_ZO_FLG              NUMBER := 0,
    KEIGEN_8_GEN_FLG             NUMBER := 0,
    KEIGEN_9_ZO_FLG              NUMBER := 0,
    KEIGEN_9_GEN_FLG             NUMBER := 0,
    KEIGEN_10_ZO_FLG             NUMBER := 0,
    KEIGEN_10_GEN_FLG            NUMBER := 0,
    KEIGEN_11_ZO_FLG             NUMBER := 0,
    KEIGEN_11_GEN_FLG            NUMBER := 0,
    KEIGEN_12_ZO_FLG             NUMBER := 0,
    KEIGEN_12_GEN_FLG            NUMBER := 0,
    KEIGEN_1_ZO_FLG              NUMBER := 0,
    KEIGEN_1_GEN_FLG             NUMBER := 0,
    KEIGEN_2_ZO_FLG              NUMBER := 0,
    KEIGEN_2_GEN_FLG             NUMBER := 0,
    KEIGEN_3_ZO_FLG              NUMBER := 0,
    KEIGEN_3_GEN_FLG             NUMBER := 0,
    KINTO_KDM18_ZO_FLG           NUMBER := 0,
    KINTO_KDM18_GEN_FLG          NUMBER := 0
);
--2025/08/11 ZCZL.LIUDI ADD END
  --賦課個人の増フラグと減フラグ
  TYPE KOJIN_ZOGENFLG_RECORD IS RECORD(
    SHIK_4_SUM_ZO_FLG            NUMBER := 0,
    SHIK_4_SUM_GEN_FLG           NUMBER := 0,
    SHIK_5_SUM_ZO_FLG            NUMBER := 0,
    SHIK_5_SUM_GEN_FLG           NUMBER := 0,
    SHIK_6_SUM_ZO_FLG            NUMBER := 0,
    SHIK_6_SUM_GEN_FLG           NUMBER := 0,
    SHIK_7_SUM_ZO_FLG            NUMBER := 0,
    SHIK_7_SUM_GEN_FLG           NUMBER := 0,
    SHIK_8_SUM_ZO_FLG            NUMBER := 0,
    SHIK_8_SUM_GEN_FLG           NUMBER := 0,
    SHIK_9_SUM_ZO_FLG            NUMBER := 0,
    SHIK_9_SUM_GEN_FLG           NUMBER := 0,
    SHIK_10_SUM_ZO_FLG           NUMBER := 0,
    SHIK_10_SUM_GEN_FLG          NUMBER := 0,
    SHIK_11_SUM_ZO_FLG           NUMBER := 0,
    SHIK_11_SUM_GEN_FLG          NUMBER := 0,
    SHIK_12_SUM_ZO_FLG           NUMBER := 0,
    SHIK_12_SUM_GEN_FLG          NUMBER := 0,
    SHIK_1_SUM_ZO_FLG            NUMBER := 0,
    SHIK_1_SUM_GEN_FLG           NUMBER := 0,
    SHIK_2_SUM_ZO_FLG            NUMBER := 0,
    SHIK_2_SUM_GEN_FLG           NUMBER := 0,
    SHIK_3_SUM_ZO_FLG            NUMBER := 0,
    SHIK_3_SUM_GEN_FLG           NUMBER := 0
    );

  --共通増フラグ、共通減フラグ
  TYPE KYOTSU_ZOGENFLG_RECORD IS RECORD(
    KOJIN_NO                     NUMBER,       --宛名番号
    FU_SHIK_4                    NUMBER := 0,  --賦個.資格4月
    FU_SHIK_5                    NUMBER := 0,  --賦個.資格5月
    FU_SHIK_6                    NUMBER := 0,  --賦個.資格6月
    FU_SHIK_7                    NUMBER := 0,  --賦個.資格7月
    FU_SHIK_8                    NUMBER := 0,  --賦個.資格8月
    FU_SHIK_9                    NUMBER := 0,  --賦個.資格9月
    FU_SHIK_10                   NUMBER := 0,  --賦個.資格10月
    FU_SHIK_11                   NUMBER := 0,  --賦個.資格11月
    FU_SHIK_12                   NUMBER := 0,  --賦個.資格12月
    FU_SHIK_1                    NUMBER := 0,  --賦個.資格1月
    FU_SHIK_2                    NUMBER := 0,  --賦個.資格2月
    FU_SHIK_3                    NUMBER := 0,  --賦個.資格３月
    KEI_SHIK_4                   NUMBER := 0,  --計個.資格4月
    KEI_SHIK_5                   NUMBER := 0,  --計個.資格5月
    KEI_SHIK_6                   NUMBER := 0,  --計個.資格6月
    KEI_SHIK_7                   NUMBER := 0,  --計個.資格7月
    KEI_SHIK_8                   NUMBER := 0,  --計個.資格8月
    KEI_SHIK_9                   NUMBER := 0,  --計個.資格9月
    KEI_SHIK_10                  NUMBER := 0,  --計個.資格10月
    KEI_SHIK_11                  NUMBER := 0,  --計個.資格11月
    KEI_SHIK_12                  NUMBER := 0,  --計個.資格12月
    KEI_SHIK_1                   NUMBER := 0,  --計個.資格1月
    KEI_SHIK_2                   NUMBER := 0,  --計個.資格2月
    KEI_SHIK_3                   NUMBER := 0,  --計個.資格３月
    FU_KAI_SHIK_4                NUMBER := 0,  --賦個.介護資格４月
    FU_KAI_SHIK_5                NUMBER := 0,  --賦個.介護資格５月
    FU_KAI_SHIK_6                NUMBER := 0,  --賦個.介護資格６月
    FU_KAI_SHIK_7                NUMBER := 0,  --賦個.介護資格７月
    FU_KAI_SHIK_8                NUMBER := 0,  --賦個.介護資格８月
    FU_KAI_SHIK_9                NUMBER := 0,  --賦個.介護資格９月
    FU_KAI_SHIK_10               NUMBER := 0,  --賦個.介護資格１０月
    FU_KAI_SHIK_11               NUMBER := 0,  --賦個.介護資格１１月
    FU_KAI_SHIK_12               NUMBER := 0,  --賦個.介護資格１２月
    FU_KAI_SHIK_1                NUMBER := 0,  --賦個.介護資格１月
    FU_KAI_SHIK_2                NUMBER := 0,  --賦個.介護資格2月
    FU_KAI_SHIK_3                NUMBER := 0,  --賦個.介護資格3月
    KEI_KAI_SHIK_4               NUMBER := 0,  --計個.介護資格４月
    KEI_KAI_SHIK_5               NUMBER := 0,  --計個.介護資格５月
    KEI_KAI_SHIK_6               NUMBER := 0,  --計個.介護資格６月
    KEI_KAI_SHIK_7               NUMBER := 0,  --計個.介護資格７月
    KEI_KAI_SHIK_8               NUMBER := 0,  --計個.介護資格８月
    KEI_KAI_SHIK_9               NUMBER := 0,  --計個.介護資格９月
    KEI_KAI_SHIK_10              NUMBER := 0,  --計個.介護資格１０月
    KEI_KAI_SHIK_11              NUMBER := 0,  --計個.介護資格１１月
    KEI_KAI_SHIK_12              NUMBER := 0,  --計個.介護資格１２月
    KEI_KAI_SHIK_1               NUMBER := 0,  --計個.介護資格１月
    KEI_KAI_SHIK_2               NUMBER := 0,  --計個.介護資格2月
    KEI_KAI_SHIK_3               NUMBER := 0,  --計個.介護資格3月
    FU_KAHYO                     NUMBER := 0,  --賦個.課税標準額
    FU_SHOTOKU_WARI              NUMBER := 0,  --賦個.所得割額
    FU_KEIGEN_SHOTOKU            NUMBER := 0,  --賦個.軽減判定所得
    KEI_KAHYO                    NUMBER := 0,  --計個.課税標準額
    KEI_SHOTOKU_WARI             NUMBER := 0,  --計個.所得割額
    KEI_KEIGEN_SHOTOKU           NUMBER := 0,  --計個.軽減判定所得
    FU_SHITSU_SHOTOKU            NUMBER := 0,  --賦個.失業軽減適用後所得額
    FU_SHITSU_KAHYO              NUMBER := 0,  --賦個.失業軽減適用後課税標準額
    FU_SHITSU_KEIGEN_SHOTOKU     NUMBER := 0,  --賦個.失業軽減適用後軽減判定所得
    KEI_SHITSU_SHOTOKU           NUMBER := 0,  --計個.失業軽減適用後所得額
    KEI_SHITSU_KAHYO             NUMBER := 0,  --計個.失業軽減適用後課税標準額
    KEI_SHITSU_KEIGEN_SHOTOKU    NUMBER := 0,  --計個.失業軽減適用後軽減判定所得
    FU_SHISANZEI                 NUMBER := 0,  --賦個.資産税額
    FU_SHISAN_WARI               NUMBER := 0,  --賦個.資産割額
    KEI_SHISANZEI                NUMBER := 0,  --計個.資産税額
    KEI_SHISAN_WARI              NUMBER := 0   --計個.資産割額
    );
-------------------------------------------------------------------------------------
--  エラーメッセージ出力
-------------------------------------------------------------------------------------
  PROCEDURE PROCLOGOUT(i_RTN IN NUMBER,i_VERR_MSG IN NVARCHAR2)
  IS
    BRTN            BOOLEAN;
  BEGIN
    --ログを出る時に、ステップ番号を加算する
    NMAX_STEP_NO := NMAX_STEP_NO + 1;
    IF i_RTN = 0 THEN
      IF i_NRENBAN = 0 THEN
        BRTN := KKBPK5551.FSETOLOG (i_VMASIN_NO,TO_CHAR(SYSTIMESTAMP,'YYYY/MM/DD HH24:MI:SS.FF3'),'ZLBSBPGENDOLST',0,0,'','',SUBSTR(i_VERR_MSG, 1, 256));
      ELSE
        BRTN := KKBPK5551.FSETBLOG (i_NRENBAN, 'ZLBSBPGENDOLST', 0, '', '', SUBSTR(i_VERR_MSG, 1, 256), i_NSYS_SHOKUINKOJIN_NO, i_VMASIN_NO);
      END IF;
    ELSE
      IF SQLCODE = 0 THEN
        IF i_NRENBAN = 0 THEN
          BRTN := KKBPK5551.FSETOLOG (i_VMASIN_NO,TO_CHAR(SYSTIMESTAMP,'YYYY/MM/DD HH24:MI:SS.FF3'),'ZLBSBPGENDOLST',1,0,'','',SUBSTR(i_VERR_MSG, 1, 256));
        ELSE
          BRTN := KKBPK5551.FSETBLOG (i_NRENBAN, 'ZLBSBPGENDOLST', 1, '', '', SUBSTR(i_VERR_MSG, 1, 256), i_NSYS_SHOKUINKOJIN_NO, i_VMASIN_NO);
        END IF;
      ELSE
        IF i_NRENBAN = 0 THEN
          BRTN := KKBPK5551.FSETOLOG (i_VMASIN_NO,TO_CHAR(SYSTIMESTAMP,'YYYY/MM/DD HH24:MI:SS.FF3'),'ZLBSBPGENDOLST',1,0,SQLCODE,SQLERRM,SUBSTR(i_VERR_MSG, 1, 256));
        ELSE
          BRTN := KKBPK5551.FSETBLOG (i_NRENBAN, 'ZLBSBPGENDOLST', 1, SQLCODE, SQLERRM, SUBSTR(i_VERR_MSG, 1, 256), i_NSYS_SHOKUINKOJIN_NO, i_VMASIN_NO);
        END IF;
      END IF;
    END IF;
  END PROCLOGOUT;
-------------------------------------------------------------------------------------
--  判定結果ログ出力
-------------------------------------------------------------------------------------
  FUNCTION FUNC_GETHANTEIKEKA_LOG(i_VLOG     IN NVARCHAR2,
                                  i_VRTN_LOG IN NVARCHAR2) RETURN NVARCHAR2
  IS
    VRTN_LOG            NVARCHAR2(1000);
    VSPACE              NVARCHAR2(1) := '　';
  BEGIN
    IF NVL(LENGTH(i_VRTN_LOG),0) = 0 THEN
      --判定結果ログ(戻り値用):=判定結果ログ(引数用)
      VRTN_LOG := i_VLOG;
    ELSIF NVL(LENGTH(i_VRTN_LOG),0) > 0 AND NVL(LENGTH(i_VRTN_LOG),0) < 1000 THEN
      --判定結果ログ(戻り値用):=判定結果ログ(戻り値用)△（全角スペース）判定結果ログ(引数用)
      VRTN_LOG := SUBSTR(i_VRTN_LOG || VSPACE || i_VLOG, 1, 1000);
    ELSE
      --なにもしない
      VRTN_LOG := i_VRTN_LOG;
    END IF;

    RETURN VRTN_LOG;
  END FUNC_GETHANTEIKEKA_LOG;
-------------------------------------------------------------------------------------
--  計算基本と賦課基本の各項目比較（減フラグ）
--  値が増えたときに減と判定されるパターン
-------------------------------------------------------------------------------------
  FUNCTION FUNC_COMPARE_GEN2 (i_KIHON_CAL IN NUMBER,
                             i_KIHON_N   IN NUMBER) RETURN PLS_INTEGER
  IS
  BEGIN
    --計算基本：賦課基本
    IF i_KIHON_CAL > i_KIHON_N THEN
      --比較項目のいずれかの項目減フラグが1の場合
      NKYOTSU_GEN_FLG := 1;
      RETURN 1;
    ELSE
      RETURN 0;
    END IF;
  END FUNC_COMPARE_GEN2;

-------------------------------------------------------------------------------------
--  計算基本と賦課基本の各項目比較（減フラグ）
-------------------------------------------------------------------------------------
  FUNCTION FUNC_COMPARE_GEN (i_KIHON_CAL IN NUMBER,
                             i_KIHON_N   IN NUMBER) RETURN PLS_INTEGER
  IS
  BEGIN
    --計算基本：賦課基本
    IF i_KIHON_CAL < i_KIHON_N THEN
      --比較項目のいずれかの項目減フラグが1の場合
      NKYOTSU_GEN_FLG := 1;
      RETURN 1;
    ELSE
      RETURN 0;
    END IF;
  END FUNC_COMPARE_GEN;
-------------------------------------------------------------------------------------
--  計算基本と賦課基本の各項目比較（増フラグ）
--  値が減ったときに増と判定されるパターン
-------------------------------------------------------------------------------------
  FUNCTION FUNC_COMPARE_ZO2 (i_KIHON_CAL IN NUMBER,
                            i_KIHON_N   IN NUMBER) RETURN NUMBER
  IS
  BEGIN
    --計算基本：賦課基本
    IF i_KIHON_CAL < i_KIHON_N THEN
      --比較項目のいずれかの項目増フラグが1の場合
      NKYOTSU_ZO_FLG := 1;
      RETURN 1;
    ELSE
      RETURN 0;
    END IF;
  END FUNC_COMPARE_ZO2;
-------------------------------------------------------------------------------------
--  計算基本と賦課基本の各項目比較（増フラグ）
-------------------------------------------------------------------------------------
  FUNCTION FUNC_COMPARE_ZO (i_KIHON_CAL IN NUMBER,
                            i_KIHON_N   IN NUMBER) RETURN NUMBER
  IS
  BEGIN
    --計算基本：賦課基本
    IF i_KIHON_CAL > i_KIHON_N THEN
      --比較項目のいずれかの項目増フラグが1の場合
      NKYOTSU_ZO_FLG := 1;
      RETURN 1;
    ELSE
      RETURN 0;
    END IF;
  END FUNC_COMPARE_ZO;
-------------------------------------------------------------------------------------
--  共通増フラグ、共通減フラグ、判定結果ログ出力区分、判定結果ログを登録
-------------------------------------------------------------------------------------
  PROCEDURE PROC_SETKYOTSU_ZOGEN_FLG(i_RKYOTSU_FLG     IN  KYOTSU_ZOGENFLG_RECORD,
                                     io_NHANTEI_KBN    IN OUT NUMBER,
                                     io_VHANTEI_LOG    IN OUT NVARCHAR2,
                                     io_NKOJIN_ZO_FLG  IN OUT NUMBER,
                                     io_NKOJIN_GEN_FLG IN OUT NUMBER)
  IS
    IZO_FLG                          PLS_INTEGER := 0;
    IGEN_FLG                         PLS_INTEGER := 0;
    IHANTEILOG_KBN                   PLS_INTEGER := 0;
    VHANTEI_LOG                      NVARCHAR2(1000);
    -----------------------------------------------------------------------
    --  判定結果ログを編集
    -----------------------------------------------------------------------
    FUNCTION FUNC_EDITHANTEILOG(i_NKOJIN_CAL IN NUMBER,
                                i_NKOJIN_N   IN NUMBER,
                                i_VNAIYO     IN NVARCHAR2,
                                i_NKOJIN_NO  IN NUMBER,
                                i_VHANTEILOG IN NVARCHAR2) RETURN NVARCHAR2
    IS
      VHANTEILOG_RTN            NVARCHAR2(1000);
    BEGIN
      IF i_NKOJIN_CAL > i_NKOJIN_N THEN
        IZO_FLG := 1;
        VHANTEILOG_RTN := FUNC_GETHANTEIKEKA_LOG(i_VNAIYO || '対象増：' || i_NKOJIN_NO,
                                                 i_VHANTEILOG);
      ELSIF i_NKOJIN_CAL < i_NKOJIN_N THEN
        IGEN_FLG := 1;
        VHANTEILOG_RTN := FUNC_GETHANTEIKEKA_LOG(i_VNAIYO || '対象減：' || i_NKOJIN_NO,
                                                 i_VHANTEILOG);
      ELSE
        NULL;
      END IF;
      RETURN VHANTEILOG_RTN;
    END FUNC_EDITHANTEILOG;
  BEGIN
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHIK_4,  i_RKYOTSU_FLG.FU_SHIK_4,  '資格4月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHIK_5,  i_RKYOTSU_FLG.FU_SHIK_5,  '資格5月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHIK_6,  i_RKYOTSU_FLG.FU_SHIK_6,  '資格6月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHIK_7,  i_RKYOTSU_FLG.FU_SHIK_7,  '資格7月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHIK_8,  i_RKYOTSU_FLG.FU_SHIK_8,  '資格8月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHIK_9,  i_RKYOTSU_FLG.FU_SHIK_9,  '資格9月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHIK_10, i_RKYOTSU_FLG.FU_SHIK_10, '資格10月', i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHIK_11, i_RKYOTSU_FLG.FU_SHIK_11, '資格11月', i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHIK_12, i_RKYOTSU_FLG.FU_SHIK_12, '資格12月', i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHIK_1,  i_RKYOTSU_FLG.FU_SHIK_1,  '資格1月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHIK_2,  i_RKYOTSU_FLG.FU_SHIK_2,  '資格2月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHIK_3,  i_RKYOTSU_FLG.FU_SHIK_3,  '資格3月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_KAI_SHIK_4,  i_RKYOTSU_FLG.FU_KAI_SHIK_4,  '介護資格4月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_KAI_SHIK_5,  i_RKYOTSU_FLG.FU_KAI_SHIK_5,  '介護資格5月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_KAI_SHIK_6,  i_RKYOTSU_FLG.FU_KAI_SHIK_6,  '介護資格6月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_KAI_SHIK_7,  i_RKYOTSU_FLG.FU_KAI_SHIK_7,  '介護資格7月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_KAI_SHIK_8,  i_RKYOTSU_FLG.FU_KAI_SHIK_8,  '介護資格8月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_KAI_SHIK_9,  i_RKYOTSU_FLG.FU_KAI_SHIK_9,  '介護資格9月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_KAI_SHIK_10, i_RKYOTSU_FLG.FU_KAI_SHIK_10, '介護資格10月', i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_KAI_SHIK_11, i_RKYOTSU_FLG.FU_KAI_SHIK_11, '介護資格11月', i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_KAI_SHIK_12, i_RKYOTSU_FLG.FU_KAI_SHIK_12, '介護資格12月', i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_KAI_SHIK_1,  i_RKYOTSU_FLG.FU_KAI_SHIK_1,  '介護資格1月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_KAI_SHIK_2,  i_RKYOTSU_FLG.FU_KAI_SHIK_2,  '介護資格2月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_KAI_SHIK_3,  i_RKYOTSU_FLG.FU_KAI_SHIK_3,  '介護資格3月',  i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_KAHYO, i_RKYOTSU_FLG.FU_KAHYO, '課税標準額', i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHOTOKU_WARI, i_RKYOTSU_FLG.FU_SHOTOKU_WARI, '所得割額', i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_KEIGEN_SHOTOKU, i_RKYOTSU_FLG.FU_KEIGEN_SHOTOKU, '軽減判定所得', i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHITSU_SHOTOKU, i_RKYOTSU_FLG.FU_SHITSU_SHOTOKU, '失業課税標準額', i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHITSU_KAHYO, i_RKYOTSU_FLG.FU_SHITSU_KAHYO, '失業軽減所得額', i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHITSU_KEIGEN_SHOTOKU, i_RKYOTSU_FLG.FU_SHITSU_KEIGEN_SHOTOKU, '失業軽減判定所得', i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHISANZEI, i_RKYOTSU_FLG.FU_SHISANZEI, '資産税額', i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);
    VHANTEI_LOG := FUNC_EDITHANTEILOG(i_RKYOTSU_FLG.KEI_SHISAN_WARI, i_RKYOTSU_FLG.FU_SHISAN_WARI, '資産割額', i_RKYOTSU_FLG.KOJIN_NO, VHANTEI_LOG);

    --判定結果ログ出力内容､判定結果ログ出力区分をセット
    IF io_VHANTEI_LOG IS NOT NULL THEN
      IF VHANTEI_LOG IS NOT NULL THEN
        io_VHANTEI_LOG := io_VHANTEI_LOG || '　' || VHANTEI_LOG;
      END IF;
      io_NHANTEI_KBN := 1;
    ELSE
      io_VHANTEI_LOG := VHANTEI_LOG;
    END IF;

    --共通増フラグ
    IF IZO_FLG = 1 THEN
      io_NKOJIN_ZO_FLG := IZO_FLG;
    END IF;
    --共通減フラグ
    IF IGEN_FLG = 1 THEN
      io_NKOJIN_GEN_FLG := IGEN_FLG;
    END IF;

  END PROC_SETKYOTSU_ZOGEN_FLG;
-------------------------------------------------------------------------------------
--  賦課個人比較結果ログに登録
-------------------------------------------------------------------------------------
  FUNCTION FUNC_INSERT_WK_SEIGENKOHO_LOG(i_VHANTEILOG IN NVARCHAR2) RETURN NUMBER
  IS
  BEGIN
    INSERT INTO ZLBWSEIGENKOHO_LOG
         VALUES (NK_KOKU_SETAI_NO                         --国保世帯番号
                ,NK_SANTEIDANTAI_CD                       --算定団体コード
                ,NK_NENDO_BUN                             --年度分
                ,NK_NUSHI_KOJIN_NO                        --世帯主宛名番号
                ,i_VHANTEILOG                             --判定結果ログ
                ,TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'))  --作成日
                ,TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'))  --更新日
                ,TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MIDD'))  --更新時間
                ,i_NSYS_SHOKUINKOJIN_NO                   --更新職員宛名番号
                ,i_VMASIN_NO                              --更新端末番号
                );
    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      VMSG := '制限対象候補世帯の判定でエラーが発生しました（FUNC_GETFUKAKOJIN）';
      VMSG := VMSG || '　年度分：' || NK_NENDO_BUN || '　国保世帯番号：' || NK_KOKU_SETAI_NO;
      VMSG := VMSG || '　算定団体コード：' || NK_SANTEIDANTAI_CD || '　世帯主宛名番号：' || NK_NUSHI_KOJIN_NO;
      VMSG := VMSG || '　SQLエラー：' || SQLERRM;
      PROCLOGOUT(1,VMSG);
      RETURN 1;
  END FUNC_INSERT_WK_SEIGENKOHO_LOG;
-------------------------------------------------------------------------------------
-- 賦課個人比較結果中間ワーク情報に登録
-------------------------------------------------------------------------------------
  FUNCTION FUNC_INSERT_WK_FUKAKOJIN(i_RKEI_KOJIN        IN KOJINRECORD,
                                    i_RFU_KOJIN         IN KOJINRECORD,
                                    i_RISHI_ZOGEN_FLG   IN KOJIN_ZOGENFLG_RECORD,
                                    i_RKAI_ZOGEN_FLG    IN KOJIN_ZOGENFLG_RECORD,
                                    i_RTD_ZOGEN_FLG     IN KOJIN_ZOGENFLG_RECORD,
                                    i_RTK_ZOGEN_FLG     IN KOJIN_ZOGENFLG_RECORD,
                                    i_RKYU_ZOGEN_FLG    IN KOJIN_ZOGENFLG_RECORD,
                                    i_RSHITSU_ZOGEN_FLG IN KOJIN_ZOGENFLG_RECORD,
                                    i_NHANTEILOG_KBN    IN NUMBER,
                                    i_NKOJIN_ZO_FLG     IN NUMBER,
                                    i_NKOJIN_GEN_FLG    IN NUMBER) RETURN NUMBER
  IS
  BEGIN
    INSERT INTO ZLBWSEIGENKOHO_FKJ
         VALUES (NK_KOKU_SETAI_NO                        --国保世帯番号
                ,NK_SANTEIDANTAI_CD                      --算定団体コード
                ,NK_NENDO_BUN                            --年度分
                ,NK_NUSHI_KOJIN_NO                       --世帯主宛名番号
                ,i_RKEI_KOJIN.ISHI_SHIK_4_SUM            --計個_資格該当人数（医・支）_4月
                ,i_RKEI_KOJIN.ISHI_SHIK_5_SUM            --計個_資格該当人数（医・支）_5月
                ,i_RKEI_KOJIN.ISHI_SHIK_6_SUM            --計個_資格該当人数（医・支）_6月
                ,i_RKEI_KOJIN.ISHI_SHIK_7_SUM            --計個_資格該当人数（医・支）_7月
                ,i_RKEI_KOJIN.ISHI_SHIK_8_SUM            --計個_資格該当人数（医・支）_8月
                ,i_RKEI_KOJIN.ISHI_SHIK_9_SUM            --計個_資格該当人数（医・支）_9月
                ,i_RKEI_KOJIN.ISHI_SHIK_10_SUM           --計個_資格該当人数（医・支）_10月
                ,i_RKEI_KOJIN.ISHI_SHIK_11_SUM           --計個_資格該当人数（医・支）_11月
                ,i_RKEI_KOJIN.ISHI_SHIK_12_SUM           --計個_資格該当人数（医・支）_12月
                ,i_RKEI_KOJIN.ISHI_SHIK_1_SUM            --計個_資格該当人数（医・支）_1月
                ,i_RKEI_KOJIN.ISHI_SHIK_2_SUM            --計個_資格該当人数（医・支）_2月
                ,i_RKEI_KOJIN.ISHI_SHIK_3_SUM            --計個_資格該当人数（医・支）_3月
                ,i_RKEI_KOJIN.KAI_SHIK_4_SUM             --計個_資格該当人数（介）_4月
                ,i_RKEI_KOJIN.KAI_SHIK_5_SUM             --計個_資格該当人数（介）_5月
                ,i_RKEI_KOJIN.KAI_SHIK_6_SUM             --計個_資格該当人数（介）_6月
                ,i_RKEI_KOJIN.KAI_SHIK_7_SUM             --計個_資格該当人数（介）_7月
                ,i_RKEI_KOJIN.KAI_SHIK_8_SUM             --計個_資格該当人数（介）_8月
                ,i_RKEI_KOJIN.KAI_SHIK_9_SUM             --計個_資格該当人数（介）_9月
                ,i_RKEI_KOJIN.KAI_SHIK_10_SUM            --計個_資格該当人数（介）_10月
                ,i_RKEI_KOJIN.KAI_SHIK_11_SUM            --計個_資格該当人数（介）_11月
                ,i_RKEI_KOJIN.KAI_SHIK_12_SUM            --計個_資格該当人数（介）_12月
                ,i_RKEI_KOJIN.KAI_SHIK_1_SUM             --計個_資格該当人数（介）_1月
                ,i_RKEI_KOJIN.KAI_SHIK_2_SUM             --計個_資格該当人数（介）_2月
                ,i_RKEI_KOJIN.KAI_SHIK_3_SUM             --計個_資格該当人数（介）_3月
                ,i_RKEI_KOJIN.TD_SHIK_4_SUM              --計個_資格該当人数（特同）_4月
                ,i_RKEI_KOJIN.TD_SHIK_5_SUM              --計個_資格該当人数（特同）_5月
                ,i_RKEI_KOJIN.TD_SHIK_6_SUM              --計個_資格該当人数（特同）_6月
                ,i_RKEI_KOJIN.TD_SHIK_7_SUM              --計個_資格該当人数（特同）_7月
                ,i_RKEI_KOJIN.TD_SHIK_8_SUM              --計個_資格該当人数（特同）_8月
                ,i_RKEI_KOJIN.TD_SHIK_9_SUM              --計個_資格該当人数（特同）_9月
                ,i_RKEI_KOJIN.TD_SHIK_10_SUM             --計個_資格該当人数（特同）_10月
                ,i_RKEI_KOJIN.TD_SHIK_11_SUM             --計個_資格該当人数（特同）_11月
                ,i_RKEI_KOJIN.TD_SHIK_12_SUM             --計個_資格該当人数（特同）_12月
                ,i_RKEI_KOJIN.TD_SHIK_1_SUM              --計個_資格該当人数（特同）_1月
                ,i_RKEI_KOJIN.TD_SHIK_2_SUM              --計個_資格該当人数（特同）_2月
                ,i_RKEI_KOJIN.TD_SHIK_3_SUM              --計個_資格該当人数（特同）_3月
                ,i_RKEI_KOJIN.TK_SHIK_4_SUM              --計個_資格該当人数（特継）_4月
                ,i_RKEI_KOJIN.TK_SHIK_5_SUM              --計個_資格該当人数（特継）_5月
                ,i_RKEI_KOJIN.TK_SHIK_6_SUM              --計個_資格該当人数（特継）_6月
                ,i_RKEI_KOJIN.TK_SHIK_7_SUM              --計個_資格該当人数（特継）_7月
                ,i_RKEI_KOJIN.TK_SHIK_8_SUM              --計個_資格該当人数（特継）_8月
                ,i_RKEI_KOJIN.TK_SHIK_9_SUM              --計個_資格該当人数（特継）_9月
                ,i_RKEI_KOJIN.TK_SHIK_10_SUM             --計個_資格該当人数（特継）_10月
                ,i_RKEI_KOJIN.TK_SHIK_11_SUM             --計個_資格該当人数（特継）_11月
                ,i_RKEI_KOJIN.TK_SHIK_12_SUM             --計個_資格該当人数（特継）_12月
                ,i_RKEI_KOJIN.TK_SHIK_1_SUM              --計個_資格該当人数（特継）_1月
                ,i_RKEI_KOJIN.TK_SHIK_2_SUM              --計個_資格該当人数（特継）_2月
                ,i_RKEI_KOJIN.TK_SHIK_3_SUM              --計個_資格該当人数（特継）_3月
                ,i_RKEI_KOJIN.KYU_SHIK_4_SUM             --計個_資格該当人数（旧）_4月
                ,i_RKEI_KOJIN.KYU_SHIK_5_SUM             --計個_資格該当人数（旧）_5月
                ,i_RKEI_KOJIN.KYU_SHIK_6_SUM             --計個_資格該当人数（旧）_6月
                ,i_RKEI_KOJIN.KYU_SHIK_7_SUM             --計個_資格該当人数（旧）_7月
                ,i_RKEI_KOJIN.KYU_SHIK_8_SUM             --計個_資格該当人数（旧）_8月
                ,i_RKEI_KOJIN.KYU_SHIK_9_SUM             --計個_資格該当人数（旧）_9月
                ,i_RKEI_KOJIN.KYU_SHIK_10_SUM            --計個_資格該当人数（旧）_10月
                ,i_RKEI_KOJIN.KYU_SHIK_11_SUM            --計個_資格該当人数（旧）_11月
                ,i_RKEI_KOJIN.KYU_SHIK_12_SUM            --計個_資格該当人数（旧）_12月
                ,i_RKEI_KOJIN.KYU_SHIK_1_SUM             --計個_資格該当人数（旧）_1月
                ,i_RKEI_KOJIN.KYU_SHIK_2_SUM             --計個_資格該当人数（旧）_2月
                ,i_RKEI_KOJIN.KYU_SHIK_3_SUM             --計個_資格該当人数（旧）_3月
                ,i_RKEI_KOJIN.SHITSU_SHIK_4_SUM          --計個_資格該当人数（非）_4月
                ,i_RKEI_KOJIN.SHITSU_SHIK_5_SUM          --計個_資格該当人数（非）_5月
                ,i_RKEI_KOJIN.SHITSU_SHIK_6_SUM          --計個_資格該当人数（非）_6月
                ,i_RKEI_KOJIN.SHITSU_SHIK_7_SUM          --計個_資格該当人数（非）_7月
                ,i_RKEI_KOJIN.SHITSU_SHIK_8_SUM          --計個_資格該当人数（非）_8月
                ,i_RKEI_KOJIN.SHITSU_SHIK_9_SUM          --計個_資格該当人数（非）_9月
                ,i_RKEI_KOJIN.SHITSU_SHIK_10_SUM         --計個_資格該当人数（非）_10月
                ,i_RKEI_KOJIN.SHITSU_SHIK_11_SUM         --計個_資格該当人数（非）_11月
                ,i_RKEI_KOJIN.SHITSU_SHIK_12_SUM         --計個_資格該当人数（非）_12月
                ,i_RKEI_KOJIN.SHITSU_SHIK_1_SUM          --計個_資格該当人数（非）_1月
                ,i_RKEI_KOJIN.SHITSU_SHIK_2_SUM          --計個_資格該当人数（非）_2月
                ,i_RKEI_KOJIN.SHITSU_SHIK_3_SUM          --計個_資格該当人数（非）_3月
                ,i_RFU_KOJIN.ISHI_SHIK_4_SUM             --賦個_資格該当人数（医・支）_4月
                ,i_RFU_KOJIN.ISHI_SHIK_5_SUM             --賦個_資格該当人数（医・支）_5月
                ,i_RFU_KOJIN.ISHI_SHIK_6_SUM             --賦個_資格該当人数（医・支）_6月
                ,i_RFU_KOJIN.ISHI_SHIK_7_SUM             --賦個_資格該当人数（医・支）_7月
                ,i_RFU_KOJIN.ISHI_SHIK_8_SUM             --賦個_資格該当人数（医・支）_8月
                ,i_RFU_KOJIN.ISHI_SHIK_9_SUM             --賦個_資格該当人数（医・支）_9月
                ,i_RFU_KOJIN.ISHI_SHIK_10_SUM            --賦個_資格該当人数（医・支）_10月
                ,i_RFU_KOJIN.ISHI_SHIK_11_SUM            --賦個_資格該当人数（医・支）_11月
                ,i_RFU_KOJIN.ISHI_SHIK_12_SUM            --賦個_資格該当人数（医・支）_12月
                ,i_RFU_KOJIN.ISHI_SHIK_1_SUM             --賦個_資格該当人数（医・支）_1月
                ,i_RFU_KOJIN.ISHI_SHIK_2_SUM             --賦個_資格該当人数（医・支）_2月
                ,i_RFU_KOJIN.ISHI_SHIK_3_SUM             --賦個_資格該当人数（医・支）_3月
                ,i_RFU_KOJIN.KAI_SHIK_4_SUM              --賦個_資格該当人数（介）_4月
                ,i_RFU_KOJIN.KAI_SHIK_5_SUM              --賦個_資格該当人数（介）_5月
                ,i_RFU_KOJIN.KAI_SHIK_6_SUM              --賦個_資格該当人数（介）_6月
                ,i_RFU_KOJIN.KAI_SHIK_7_SUM              --賦個_資格該当人数（介）_7月
                ,i_RFU_KOJIN.KAI_SHIK_8_SUM              --賦個_資格該当人数（介）_8月
                ,i_RFU_KOJIN.KAI_SHIK_9_SUM              --賦個_資格該当人数（介）_9月
                ,i_RFU_KOJIN.KAI_SHIK_10_SUM             --賦個_資格該当人数（介）_10月
                ,i_RFU_KOJIN.KAI_SHIK_11_SUM             --賦個_資格該当人数（介）_11月
                ,i_RFU_KOJIN.KAI_SHIK_12_SUM             --賦個_資格該当人数（介）_12月
                ,i_RFU_KOJIN.KAI_SHIK_1_SUM              --賦個_資格該当人数（介）_1月
                ,i_RFU_KOJIN.KAI_SHIK_2_SUM              --賦個_資格該当人数（介）_2月
                ,i_RFU_KOJIN.KAI_SHIK_3_SUM              --賦個_資格該当人数（介）_3月
                ,i_RFU_KOJIN.TD_SHIK_4_SUM               --賦個_資格該当人数（特同）_4月
                ,i_RFU_KOJIN.TD_SHIK_5_SUM               --賦個_資格該当人数（特同）_5月
                ,i_RFU_KOJIN.TD_SHIK_6_SUM               --賦個_資格該当人数（特同）_6月
                ,i_RFU_KOJIN.TD_SHIK_7_SUM               --賦個_資格該当人数（特同）_7月
                ,i_RFU_KOJIN.TD_SHIK_8_SUM               --賦個_資格該当人数（特同）_8月
                ,i_RFU_KOJIN.TD_SHIK_9_SUM               --賦個_資格該当人数（特同）_9月
                ,i_RFU_KOJIN.TD_SHIK_10_SUM              --賦個_資格該当人数（特同）_10月
                ,i_RFU_KOJIN.TD_SHIK_11_SUM              --賦個_資格該当人数（特同）_11月
                ,i_RFU_KOJIN.TD_SHIK_12_SUM              --賦個_資格該当人数（特同）_12月
                ,i_RFU_KOJIN.TD_SHIK_1_SUM               --賦個_資格該当人数（特同）_1月
                ,i_RFU_KOJIN.TD_SHIK_2_SUM               --賦個_資格該当人数（特同）_2月
                ,i_RFU_KOJIN.TD_SHIK_3_SUM               --賦個_資格該当人数（特同）_3月
                ,i_RFU_KOJIN.TK_SHIK_4_SUM               --賦個_資格該当人数（特継）_4月
                ,i_RFU_KOJIN.TK_SHIK_5_SUM               --賦個_資格該当人数（特継）_5月
                ,i_RFU_KOJIN.TK_SHIK_6_SUM               --賦個_資格該当人数（特継）_6月
                ,i_RFU_KOJIN.TK_SHIK_7_SUM               --賦個_資格該当人数（特継）_7月
                ,i_RFU_KOJIN.TK_SHIK_8_SUM               --賦個_資格該当人数（特継）_8月
                ,i_RFU_KOJIN.TK_SHIK_9_SUM               --賦個_資格該当人数（特継）_9月
                ,i_RFU_KOJIN.TK_SHIK_10_SUM              --賦個_資格該当人数（特継）_10月
                ,i_RFU_KOJIN.TK_SHIK_11_SUM              --賦個_資格該当人数（特継）_11月
                ,i_RFU_KOJIN.TK_SHIK_12_SUM              --賦個_資格該当人数（特継）_12月
                ,i_RFU_KOJIN.TK_SHIK_1_SUM               --賦個_資格該当人数（特継）_1月
                ,i_RFU_KOJIN.TK_SHIK_2_SUM               --賦個_資格該当人数（特継）_2月
                ,i_RFU_KOJIN.TK_SHIK_3_SUM               --賦個_資格該当人数（特継）_3月
                ,i_RFU_KOJIN.KYU_SHIK_4_SUM              --賦個_資格該当人数（旧）_4月
                ,i_RFU_KOJIN.KYU_SHIK_5_SUM              --賦個_資格該当人数（旧）_5月
                ,i_RFU_KOJIN.KYU_SHIK_6_SUM              --賦個_資格該当人数（旧）_6月
                ,i_RFU_KOJIN.KYU_SHIK_7_SUM              --賦個_資格該当人数（旧）_7月
                ,i_RFU_KOJIN.KYU_SHIK_8_SUM              --賦個_資格該当人数（旧）_8月
                ,i_RFU_KOJIN.KYU_SHIK_9_SUM              --賦個_資格該当人数（旧）_9月
                ,i_RFU_KOJIN.KYU_SHIK_10_SUM             --賦個_資格該当人数（旧）_10月
                ,i_RFU_KOJIN.KYU_SHIK_11_SUM             --賦個_資格該当人数（旧）_11月
                ,i_RFU_KOJIN.KYU_SHIK_12_SUM             --賦個_資格該当人数（旧）_12月
                ,i_RFU_KOJIN.KYU_SHIK_1_SUM              --賦個_資格該当人数（旧）_1月
                ,i_RFU_KOJIN.KYU_SHIK_2_SUM              --賦個_資格該当人数（旧）_2月
                ,i_RFU_KOJIN.KYU_SHIK_3_SUM              --賦個_資格該当人数（旧）_3月
                ,i_RFU_KOJIN.SHITSU_SHIK_4_SUM           --賦個_資格該当人数（非）_4月
                ,i_RFU_KOJIN.SHITSU_SHIK_5_SUM           --賦個_資格該当人数（非）_5月
                ,i_RFU_KOJIN.SHITSU_SHIK_6_SUM           --賦個_資格該当人数（非）_6月
                ,i_RFU_KOJIN.SHITSU_SHIK_7_SUM           --賦個_資格該当人数（非）_7月
                ,i_RFU_KOJIN.SHITSU_SHIK_8_SUM           --賦個_資格該当人数（非）_8月
                ,i_RFU_KOJIN.SHITSU_SHIK_9_SUM           --賦個_資格該当人数（非）_9月
                ,i_RFU_KOJIN.SHITSU_SHIK_10_SUM          --賦個_資格該当人数（非）_10月
                ,i_RFU_KOJIN.SHITSU_SHIK_11_SUM          --賦個_資格該当人数（非）_11月
                ,i_RFU_KOJIN.SHITSU_SHIK_12_SUM          --賦個_資格該当人数（非）_12月
                ,i_RFU_KOJIN.SHITSU_SHIK_1_SUM           --賦個_資格該当人数（非）_1月
                ,i_RFU_KOJIN.SHITSU_SHIK_2_SUM           --賦個_資格該当人数（非）_2月
                ,i_RFU_KOJIN.SHITSU_SHIK_3_SUM           --賦個_資格該当人数（非）_3月
                ,i_RISHI_ZOGEN_FLG.SHIK_4_SUM_ZO_FLG     --資格該当人数（医・支）_4月_増フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_5_SUM_ZO_FLG     --資格該当人数（医・支）_5月_増フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_6_SUM_ZO_FLG     --資格該当人数（医・支）_6月_増フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_7_SUM_ZO_FLG     --資格該当人数（医・支）_7月_増フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_8_SUM_ZO_FLG     --資格該当人数（医・支）_8月_増フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_9_SUM_ZO_FLG     --資格該当人数（医・支）_9月_増フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_10_SUM_ZO_FLG    --資格該当人数（医・支）_10月_増フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_11_SUM_ZO_FLG    --資格該当人数（医・支）_11月_増フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_12_SUM_ZO_FLG    --資格該当人数（医・支）_12月_増フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_1_SUM_ZO_FLG     --資格該当人数（医・支）_1月_増フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_2_SUM_ZO_FLG     --資格該当人数（医・支）_2月_増フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_3_SUM_ZO_FLG     --資格該当人数（医・支）_3月_増フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_4_SUM_ZO_FLG      --資格該当人数（介）_4月_増フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_5_SUM_ZO_FLG      --資格該当人数（介）_5月_増フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_6_SUM_ZO_FLG      --資格該当人数（介）_6月_増フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_7_SUM_ZO_FLG      --資格該当人数（介）_7月_増フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_8_SUM_ZO_FLG      --資格該当人数（介）_8月_増フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_9_SUM_ZO_FLG      --資格該当人数（介）_9月_増フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_10_SUM_ZO_FLG     --資格該当人数（介）_10月_増フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_11_SUM_ZO_FLG     --資格該当人数（介）_11月_増フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_12_SUM_ZO_FLG     --資格該当人数（介）_12月_増フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_1_SUM_ZO_FLG      --資格該当人数（介）_1月_増フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_2_SUM_ZO_FLG      --資格該当人数（介）_2月_増フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_3_SUM_ZO_FLG      --資格該当人数（介）_3月_増フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_4_SUM_ZO_FLG       --資格該当人数（特同）_4月_増フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_5_SUM_ZO_FLG       --資格該当人数（特同）_5月_増フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_6_SUM_ZO_FLG       --資格該当人数（特同）_6月_増フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_7_SUM_ZO_FLG       --資格該当人数（特同）_7月_増フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_8_SUM_ZO_FLG       --資格該当人数（特同）_8月_増フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_9_SUM_ZO_FLG       --資格該当人数（特同）_9月_増フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_10_SUM_ZO_FLG      --資格該当人数（特同）_10月_増フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_11_SUM_ZO_FLG      --資格該当人数（特同）_11月_増フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_12_SUM_ZO_FLG      --資格該当人数（特同）_12月_増フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_1_SUM_ZO_FLG       --資格該当人数（特同）_1月_増フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_2_SUM_ZO_FLG       --資格該当人数（特同）_2月_増フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_3_SUM_ZO_FLG       --資格該当人数（特同）_3月_増フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_4_SUM_ZO_FLG       --資格該当人数（特継）_4月_増フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_5_SUM_ZO_FLG       --資格該当人数（特継）_5月_増フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_6_SUM_ZO_FLG       --資格該当人数（特継）_6月_増フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_7_SUM_ZO_FLG       --資格該当人数（特継）_7月_増フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_8_SUM_ZO_FLG       --資格該当人数（特継）_8月_増フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_9_SUM_ZO_FLG       --資格該当人数（特継）_9月_増フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_10_SUM_ZO_FLG      --資格該当人数（特継）_10月_増フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_11_SUM_ZO_FLG      --資格該当人数（特継）_11月_増フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_12_SUM_ZO_FLG      --資格該当人数（特継）_12月_増フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_1_SUM_ZO_FLG       --資格該当人数（特継）_1月_増フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_2_SUM_ZO_FLG       --資格該当人数（特継）_2月_増フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_3_SUM_ZO_FLG       --資格該当人数（特継）_3月_増フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_4_SUM_ZO_FLG      --資格該当人数（旧）_4月_増フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_5_SUM_ZO_FLG      --資格該当人数（旧）_5月_増フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_6_SUM_ZO_FLG      --資格該当人数（旧）_6月_増フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_7_SUM_ZO_FLG      --資格該当人数（旧）_7月_増フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_8_SUM_ZO_FLG      --資格該当人数（旧）_8月_増フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_9_SUM_ZO_FLG      --資格該当人数（旧）_9月_増フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_10_SUM_ZO_FLG     --資格該当人数（旧）_10月_増フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_11_SUM_ZO_FLG     --資格該当人数（旧）_11月_増フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_12_SUM_ZO_FLG     --資格該当人数（旧）_12月_増フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_1_SUM_ZO_FLG      --資格該当人数（旧）_1月_増フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_2_SUM_ZO_FLG      --資格該当人数（旧）_2月_増フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_3_SUM_ZO_FLG      --資格該当人数（旧）_3月_増フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_4_SUM_ZO_FLG   --資格該当人数（非）_4月_増フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_5_SUM_ZO_FLG   --資格該当人数（非）_5月_増フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_6_SUM_ZO_FLG   --資格該当人数（非）_6月_増フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_7_SUM_ZO_FLG   --資格該当人数（非）_7月_増フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_8_SUM_ZO_FLG   --資格該当人数（非）_8月_増フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_9_SUM_ZO_FLG   --資格該当人数（非）_9月_増フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_10_SUM_ZO_FLG  --資格該当人数（非）_10月_増フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_11_SUM_ZO_FLG  --資格該当人数（非）_11月_増フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_12_SUM_ZO_FLG  --資格該当人数（非）_12月_増フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_1_SUM_ZO_FLG   --資格該当人数（非）_1月_増フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_2_SUM_ZO_FLG   --資格該当人数（非）_2月_増フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_3_SUM_ZO_FLG   --資格該当人数（非）_3月_増フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_4_SUM_GEN_FLG    --資格該当人数（医・支）_4月_減フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_5_SUM_GEN_FLG    --資格該当人数（医・支）_5月_減フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_6_SUM_GEN_FLG    --資格該当人数（医・支）_6月_減フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_7_SUM_GEN_FLG    --資格該当人数（医・支）_7月_減フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_8_SUM_GEN_FLG    --資格該当人数（医・支）_8月_減フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_9_SUM_GEN_FLG    --資格該当人数（医・支）_9月_減フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_10_SUM_GEN_FLG   --資格該当人数（医・支）_10月_減フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_11_SUM_GEN_FLG   --資格該当人数（医・支）_11月_減フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_12_SUM_GEN_FLG   --資格該当人数（医・支）_12月_減フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_1_SUM_GEN_FLG    --資格該当人数（医・支）_1月_減フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_2_SUM_GEN_FLG    --資格該当人数（医・支）_2月_減フラグ
                ,i_RISHI_ZOGEN_FLG.SHIK_3_SUM_GEN_FLG    --資格該当人数（医・支）_3月_減フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_4_SUM_GEN_FLG     --資格該当人数（介）_4月_減フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_5_SUM_GEN_FLG     --資格該当人数（介）_5月_減フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_6_SUM_GEN_FLG     --資格該当人数（介）_6月_減フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_7_SUM_GEN_FLG     --資格該当人数（介）_7月_減フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_8_SUM_GEN_FLG     --資格該当人数（介）_8月_減フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_9_SUM_GEN_FLG     --資格該当人数（介）_9月_減フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_10_SUM_GEN_FLG    --資格該当人数（介）_10月_減フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_11_SUM_GEN_FLG    --資格該当人数（介）_11月_減フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_12_SUM_GEN_FLG    --資格該当人数（介）_12月_減フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_1_SUM_GEN_FLG     --資格該当人数（介）_1月_減フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_2_SUM_GEN_FLG     --資格該当人数（介）_2月_減フラグ
                ,i_RKAI_ZOGEN_FLG.SHIK_3_SUM_GEN_FLG     --資格該当人数（介）_3月_減フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_4_SUM_GEN_FLG      --資格該当人数（特同）_4月_減フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_5_SUM_GEN_FLG      --資格該当人数（特同）_5月_減フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_6_SUM_GEN_FLG      --資格該当人数（特同）_6月_減フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_7_SUM_GEN_FLG      --資格該当人数（特同）_7月_減フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_8_SUM_GEN_FLG      --資格該当人数（特同）_8月_減フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_9_SUM_GEN_FLG      --資格該当人数（特同）_9月_減フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_10_SUM_GEN_FLG     --資格該当人数（特同）_10月_減フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_11_SUM_GEN_FLG     --資格該当人数（特同）_11月_減フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_12_SUM_GEN_FLG     --資格該当人数（特同）_12月_減フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_1_SUM_GEN_FLG      --資格該当人数（特同）_1月_減フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_2_SUM_GEN_FLG      --資格該当人数（特同）_2月_減フラグ
                ,i_RTD_ZOGEN_FLG.SHIK_3_SUM_GEN_FLG      --資格該当人数（特同）_3月_減フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_4_SUM_GEN_FLG      --資格該当人数（特継）_4月_減フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_5_SUM_GEN_FLG      --資格該当人数（特継）_5月_減フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_6_SUM_GEN_FLG      --資格該当人数（特継）_6月_減フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_7_SUM_GEN_FLG      --資格該当人数（特継）_7月_減フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_8_SUM_GEN_FLG      --資格該当人数（特継）_8月_減フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_9_SUM_GEN_FLG      --資格該当人数（特継）_9月_減フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_10_SUM_GEN_FLG     --資格該当人数（特継）_10月_減フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_11_SUM_GEN_FLG     --資格該当人数（特継）_11月_減フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_12_SUM_GEN_FLG     --資格該当人数（特継）_12月_減フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_1_SUM_GEN_FLG      --資格該当人数（特継）_1月_減フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_2_SUM_GEN_FLG      --資格該当人数（特継）_2月_減フラグ
                ,i_RTK_ZOGEN_FLG.SHIK_3_SUM_GEN_FLG      --資格該当人数（特継）_3月_減フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_4_SUM_GEN_FLG     --資格該当人数（旧）_4月_減フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_5_SUM_GEN_FLG     --資格該当人数（旧）_5月_減フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_6_SUM_GEN_FLG     --資格該当人数（旧）_6月_減フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_7_SUM_GEN_FLG     --資格該当人数（旧）_7月_減フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_8_SUM_GEN_FLG     --資格該当人数（旧）_8月_減フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_9_SUM_GEN_FLG     --資格該当人数（旧）_9月_減フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_10_SUM_GEN_FLG    --資格該当人数（旧）_10月_減フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_11_SUM_GEN_FLG    --資格該当人数（旧）_11月_減フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_12_SUM_GEN_FLG    --資格該当人数（旧）_12月_減フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_1_SUM_GEN_FLG     --資格該当人数（旧）_1月_減フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_2_SUM_GEN_FLG     --資格該当人数（旧）_2月_減フラグ
                ,i_RKYU_ZOGEN_FLG.SHIK_3_SUM_GEN_FLG     --資格該当人数（旧）_3月_減フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_4_SUM_GEN_FLG  --資格該当人数（非）_4月_減フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_5_SUM_GEN_FLG  --資格該当人数（非）_5月_減フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_6_SUM_GEN_FLG  --資格該当人数（非）_6月_減フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_7_SUM_GEN_FLG  --資格該当人数（非）_7月_減フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_8_SUM_GEN_FLG  --資格該当人数（非）_8月_減フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_9_SUM_GEN_FLG  --資格該当人数（非）_9月_減フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_10_SUM_GEN_FLG --資格該当人数（非）_10月_減フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_11_SUM_GEN_FLG --資格該当人数（非）_11月_減フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_12_SUM_GEN_FLG --資格該当人数（非）_12月_減フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_1_SUM_GEN_FLG  --資格該当人数（非）_1月_減フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_2_SUM_GEN_FLG  --資格該当人数（非）_2月_減フラグ
                ,i_RSHITSU_ZOGEN_FLG.SHIK_3_SUM_GEN_FLG  --資格該当人数（非）_3月_減フラグ
                ,i_NKOJIN_ZO_FLG                         --共通増フラグ
                ,i_NKOJIN_GEN_FLG                        --共通減フラグ
                ,i_NHANTEILOG_KBN                        --判定結果ログ出力区分
                ,TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')) --作成日
                ,TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')) --更新日
                ,TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MIDD')) --更新時間
                ,i_NSYS_SHOKUINKOJIN_NO                  --更新職員宛名番号
                ,i_VMASIN_NO                             --更新端末番号
                );
    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      VMSG := '制限対象候補世帯の判定でエラーが発生しました（FUNC_GETFUKAKOJIN）';
      VMSG := VMSG || '　年度分：' || NK_NENDO_BUN || '　国保世帯番号：' || NK_KOKU_SETAI_NO;
      VMSG := VMSG || '　算定団体コード：' || NK_SANTEIDANTAI_CD || '　世帯主宛名番号：' || NK_NUSHI_KOJIN_NO;
      VMSG := VMSG || '　SQLエラー：' || SQLERRM;
      PROCLOGOUT(1,VMSG);
      RETURN 1;
  END FUNC_INSERT_WK_FUKAKOJIN;
-------------------------------------------------------------------------------------
--  賦課計算個人、賦課個人（最新）の各項目比較し、増フラグ、減フラグ、共通増フラグ、共通減フラグ設定
-------------------------------------------------------------------------------------
  PROCEDURE PROC_SETKOJIN_ZOGEN_FLG(i_RKEIKOJIN             IN  KOJINRECORD,
                                    i_RFUKOJIN              IN  KOJINRECORD,
                                    o_RISHI_ZOGEN_FLG       OUT KOJIN_ZOGENFLG_RECORD,
                                    o_RKAI_ZOGEN_FLG        OUT KOJIN_ZOGENFLG_RECORD,
                                    o_RTD_ZOGEN_FLG         OUT KOJIN_ZOGENFLG_RECORD,
                                    o_RTK_ZOGEN_FLG         OUT KOJIN_ZOGENFLG_RECORD,
                                    o_RKYU_ZOGEN_FLG        OUT KOJIN_ZOGENFLG_RECORD,
                                    o_RSHITSU_ZOGEN_FLG     OUT KOJIN_ZOGENFLG_RECORD,
                                    o_NKOJIN_ZO_FLG         OUT NUMBER,
                                    o_NKOJIN_GEN_FLG        OUT NUMBER)
  IS
  BEGIN
    --共通増フラグ、共通減フラグを初期化
    NKYOTSU_ZO_FLG := 0;
    NKYOTSU_GEN_FLG := 0;

    --合計資格該当人数（医・支）　増フラグ
    o_RISHI_ZOGEN_FLG.SHIK_4_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.ISHI_SHIK_4_SUM,  i_RFUKOJIN.ISHI_SHIK_4_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_5_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.ISHI_SHIK_5_SUM,  i_RFUKOJIN.ISHI_SHIK_5_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_6_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.ISHI_SHIK_6_SUM,  i_RFUKOJIN.ISHI_SHIK_6_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_7_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.ISHI_SHIK_7_SUM,  i_RFUKOJIN.ISHI_SHIK_7_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_8_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.ISHI_SHIK_8_SUM,  i_RFUKOJIN.ISHI_SHIK_8_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_9_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.ISHI_SHIK_9_SUM,  i_RFUKOJIN.ISHI_SHIK_9_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_10_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.ISHI_SHIK_10_SUM, i_RFUKOJIN.ISHI_SHIK_10_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_11_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.ISHI_SHIK_11_SUM, i_RFUKOJIN.ISHI_SHIK_11_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_12_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.ISHI_SHIK_12_SUM, i_RFUKOJIN.ISHI_SHIK_12_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_1_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.ISHI_SHIK_1_SUM,  i_RFUKOJIN.ISHI_SHIK_1_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_2_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.ISHI_SHIK_2_SUM,  i_RFUKOJIN.ISHI_SHIK_2_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_3_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.ISHI_SHIK_3_SUM,  i_RFUKOJIN.ISHI_SHIK_3_SUM);
    --合計資格該当人数（医・支）　減フラグ
    o_RISHI_ZOGEN_FLG.SHIK_4_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.ISHI_SHIK_4_SUM,  i_RFUKOJIN.ISHI_SHIK_4_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_5_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.ISHI_SHIK_5_SUM,  i_RFUKOJIN.ISHI_SHIK_5_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_6_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.ISHI_SHIK_6_SUM,  i_RFUKOJIN.ISHI_SHIK_6_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_7_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.ISHI_SHIK_7_SUM,  i_RFUKOJIN.ISHI_SHIK_7_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_8_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.ISHI_SHIK_8_SUM,  i_RFUKOJIN.ISHI_SHIK_8_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_9_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.ISHI_SHIK_9_SUM,  i_RFUKOJIN.ISHI_SHIK_9_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_10_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.ISHI_SHIK_10_SUM, i_RFUKOJIN.ISHI_SHIK_10_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_11_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.ISHI_SHIK_11_SUM, i_RFUKOJIN.ISHI_SHIK_11_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_12_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.ISHI_SHIK_12_SUM, i_RFUKOJIN.ISHI_SHIK_12_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_1_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.ISHI_SHIK_1_SUM,  i_RFUKOJIN.ISHI_SHIK_1_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_2_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.ISHI_SHIK_2_SUM,  i_RFUKOJIN.ISHI_SHIK_2_SUM);
    o_RISHI_ZOGEN_FLG.SHIK_3_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.ISHI_SHIK_3_SUM,  i_RFUKOJIN.ISHI_SHIK_3_SUM);

    --合計資格該当人数（介）　増フラグ
    o_RKAI_ZOGEN_FLG.SHIK_4_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KAI_SHIK_4_SUM,  i_RFUKOJIN.KAI_SHIK_4_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_5_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KAI_SHIK_5_SUM,  i_RFUKOJIN.KAI_SHIK_5_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_6_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KAI_SHIK_6_SUM,  i_RFUKOJIN.KAI_SHIK_6_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_7_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KAI_SHIK_7_SUM,  i_RFUKOJIN.KAI_SHIK_7_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_8_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KAI_SHIK_8_SUM,  i_RFUKOJIN.KAI_SHIK_8_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_9_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KAI_SHIK_9_SUM,  i_RFUKOJIN.KAI_SHIK_9_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_10_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.KAI_SHIK_10_SUM, i_RFUKOJIN.KAI_SHIK_10_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_11_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.KAI_SHIK_11_SUM, i_RFUKOJIN.KAI_SHIK_11_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_12_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.KAI_SHIK_12_SUM, i_RFUKOJIN.KAI_SHIK_12_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_1_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KAI_SHIK_1_SUM,  i_RFUKOJIN.KAI_SHIK_1_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_2_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KAI_SHIK_2_SUM,  i_RFUKOJIN.KAI_SHIK_2_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_3_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KAI_SHIK_3_SUM,  i_RFUKOJIN.KAI_SHIK_3_SUM);
    --合計資格該当人数（介）　減フラグ
    o_RKAI_ZOGEN_FLG.SHIK_4_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KAI_SHIK_4_SUM,  i_RFUKOJIN.KAI_SHIK_4_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_5_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KAI_SHIK_5_SUM,  i_RFUKOJIN.KAI_SHIK_5_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_6_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KAI_SHIK_6_SUM,  i_RFUKOJIN.KAI_SHIK_6_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_7_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KAI_SHIK_7_SUM,  i_RFUKOJIN.KAI_SHIK_7_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_8_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KAI_SHIK_8_SUM,  i_RFUKOJIN.KAI_SHIK_8_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_9_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KAI_SHIK_9_SUM,  i_RFUKOJIN.KAI_SHIK_9_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_10_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.KAI_SHIK_10_SUM, i_RFUKOJIN.KAI_SHIK_10_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_11_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.KAI_SHIK_11_SUM, i_RFUKOJIN.KAI_SHIK_11_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_12_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.KAI_SHIK_12_SUM, i_RFUKOJIN.KAI_SHIK_12_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_1_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KAI_SHIK_1_SUM,  i_RFUKOJIN.KAI_SHIK_1_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_2_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KAI_SHIK_2_SUM,  i_RFUKOJIN.KAI_SHIK_2_SUM);
    o_RKAI_ZOGEN_FLG.SHIK_3_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KAI_SHIK_3_SUM,  i_RFUKOJIN.KAI_SHIK_3_SUM);

    --共通増フラグ、共通減フラグ
    o_NKOJIN_ZO_FLG := NKYOTSU_ZO_FLG;
    o_NKOJIN_GEN_FLG := NKYOTSU_GEN_FLG;

    --合計資格該当人数（特同）　増フラグ
    o_RTD_ZOGEN_FLG.SHIK_4_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TD_SHIK_4_SUM,  i_RFUKOJIN.TD_SHIK_4_SUM);
    o_RTD_ZOGEN_FLG.SHIK_5_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TD_SHIK_5_SUM,  i_RFUKOJIN.TD_SHIK_5_SUM);
    o_RTD_ZOGEN_FLG.SHIK_6_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TD_SHIK_6_SUM,  i_RFUKOJIN.TD_SHIK_6_SUM);
    o_RTD_ZOGEN_FLG.SHIK_7_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TD_SHIK_7_SUM,  i_RFUKOJIN.TD_SHIK_7_SUM);
    o_RTD_ZOGEN_FLG.SHIK_8_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TD_SHIK_8_SUM,  i_RFUKOJIN.TD_SHIK_8_SUM);
    o_RTD_ZOGEN_FLG.SHIK_9_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TD_SHIK_9_SUM,  i_RFUKOJIN.TD_SHIK_9_SUM);
    o_RTD_ZOGEN_FLG.SHIK_10_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.TD_SHIK_10_SUM, i_RFUKOJIN.TD_SHIK_10_SUM);
    o_RTD_ZOGEN_FLG.SHIK_11_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.TD_SHIK_11_SUM, i_RFUKOJIN.TD_SHIK_11_SUM);
    o_RTD_ZOGEN_FLG.SHIK_12_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.TD_SHIK_12_SUM, i_RFUKOJIN.TD_SHIK_12_SUM);
    o_RTD_ZOGEN_FLG.SHIK_1_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TD_SHIK_1_SUM,  i_RFUKOJIN.TD_SHIK_1_SUM);
    o_RTD_ZOGEN_FLG.SHIK_2_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TD_SHIK_2_SUM,  i_RFUKOJIN.TD_SHIK_2_SUM);
    o_RTD_ZOGEN_FLG.SHIK_3_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TD_SHIK_3_SUM,  i_RFUKOJIN.TD_SHIK_3_SUM);
    --合計資格該当人数（特同）　減フラグ
    o_RTD_ZOGEN_FLG.SHIK_4_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TD_SHIK_4_SUM,  i_RFUKOJIN.TD_SHIK_4_SUM);
    o_RTD_ZOGEN_FLG.SHIK_5_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TD_SHIK_5_SUM,  i_RFUKOJIN.TD_SHIK_5_SUM);
    o_RTD_ZOGEN_FLG.SHIK_6_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TD_SHIK_6_SUM,  i_RFUKOJIN.TD_SHIK_6_SUM);
    o_RTD_ZOGEN_FLG.SHIK_7_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TD_SHIK_7_SUM,  i_RFUKOJIN.TD_SHIK_7_SUM);
    o_RTD_ZOGEN_FLG.SHIK_8_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TD_SHIK_8_SUM,  i_RFUKOJIN.TD_SHIK_8_SUM);
    o_RTD_ZOGEN_FLG.SHIK_9_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TD_SHIK_9_SUM,  i_RFUKOJIN.TD_SHIK_9_SUM);
    o_RTD_ZOGEN_FLG.SHIK_10_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.TD_SHIK_10_SUM, i_RFUKOJIN.TD_SHIK_10_SUM);
    o_RTD_ZOGEN_FLG.SHIK_11_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.TD_SHIK_11_SUM, i_RFUKOJIN.TD_SHIK_11_SUM);
    o_RTD_ZOGEN_FLG.SHIK_12_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.TD_SHIK_12_SUM, i_RFUKOJIN.TD_SHIK_12_SUM);
    o_RTD_ZOGEN_FLG.SHIK_1_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TD_SHIK_1_SUM,  i_RFUKOJIN.TD_SHIK_1_SUM);
    o_RTD_ZOGEN_FLG.SHIK_2_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TD_SHIK_2_SUM,  i_RFUKOJIN.TD_SHIK_2_SUM);
    o_RTD_ZOGEN_FLG.SHIK_3_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TD_SHIK_3_SUM,  i_RFUKOJIN.TD_SHIK_3_SUM);

    --合計資格該当人数（特継）　増フラグ
    o_RTK_ZOGEN_FLG.SHIK_4_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TK_SHIK_4_SUM,  i_RFUKOJIN.TK_SHIK_4_SUM);
    o_RTK_ZOGEN_FLG.SHIK_5_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TK_SHIK_5_SUM,  i_RFUKOJIN.TK_SHIK_5_SUM);
    o_RTK_ZOGEN_FLG.SHIK_6_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TK_SHIK_6_SUM,  i_RFUKOJIN.TK_SHIK_6_SUM);
    o_RTK_ZOGEN_FLG.SHIK_7_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TK_SHIK_7_SUM,  i_RFUKOJIN.TK_SHIK_7_SUM);
    o_RTK_ZOGEN_FLG.SHIK_8_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TK_SHIK_8_SUM,  i_RFUKOJIN.TK_SHIK_8_SUM);
    o_RTK_ZOGEN_FLG.SHIK_9_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TK_SHIK_9_SUM,  i_RFUKOJIN.TK_SHIK_9_SUM);
    o_RTK_ZOGEN_FLG.SHIK_10_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.TK_SHIK_10_SUM, i_RFUKOJIN.TK_SHIK_10_SUM);
    o_RTK_ZOGEN_FLG.SHIK_11_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.TK_SHIK_11_SUM, i_RFUKOJIN.TK_SHIK_11_SUM);
    o_RTK_ZOGEN_FLG.SHIK_12_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.TK_SHIK_12_SUM, i_RFUKOJIN.TK_SHIK_12_SUM);
    o_RTK_ZOGEN_FLG.SHIK_1_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TK_SHIK_1_SUM,  i_RFUKOJIN.TK_SHIK_1_SUM);
    o_RTK_ZOGEN_FLG.SHIK_2_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TK_SHIK_2_SUM,  i_RFUKOJIN.TK_SHIK_2_SUM);
    o_RTK_ZOGEN_FLG.SHIK_3_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.TK_SHIK_3_SUM,  i_RFUKOJIN.TK_SHIK_3_SUM);
    --合計資格該当人数（特継）　減フラグ
    o_RTK_ZOGEN_FLG.SHIK_4_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TK_SHIK_4_SUM,  i_RFUKOJIN.TK_SHIK_4_SUM);
    o_RTK_ZOGEN_FLG.SHIK_5_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TK_SHIK_5_SUM,  i_RFUKOJIN.TK_SHIK_5_SUM);
    o_RTK_ZOGEN_FLG.SHIK_6_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TK_SHIK_6_SUM,  i_RFUKOJIN.TK_SHIK_6_SUM);
    o_RTK_ZOGEN_FLG.SHIK_7_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TK_SHIK_7_SUM,  i_RFUKOJIN.TK_SHIK_7_SUM);
    o_RTK_ZOGEN_FLG.SHIK_8_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TK_SHIK_8_SUM,  i_RFUKOJIN.TK_SHIK_8_SUM);
    o_RTK_ZOGEN_FLG.SHIK_9_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TK_SHIK_9_SUM,  i_RFUKOJIN.TK_SHIK_9_SUM);
    o_RTK_ZOGEN_FLG.SHIK_10_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.TK_SHIK_10_SUM, i_RFUKOJIN.TK_SHIK_10_SUM);
    o_RTK_ZOGEN_FLG.SHIK_11_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.TK_SHIK_11_SUM, i_RFUKOJIN.TK_SHIK_11_SUM);
    o_RTK_ZOGEN_FLG.SHIK_12_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.TK_SHIK_12_SUM, i_RFUKOJIN.TK_SHIK_12_SUM);
    o_RTK_ZOGEN_FLG.SHIK_1_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TK_SHIK_1_SUM,  i_RFUKOJIN.TK_SHIK_1_SUM);
    o_RTK_ZOGEN_FLG.SHIK_2_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TK_SHIK_2_SUM,  i_RFUKOJIN.TK_SHIK_2_SUM);
    o_RTK_ZOGEN_FLG.SHIK_3_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.TK_SHIK_3_SUM,  i_RFUKOJIN.TK_SHIK_3_SUM);

    --合計資格該当人数（旧）　増フラグ
    o_RKYU_ZOGEN_FLG.SHIK_4_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KYU_SHIK_4_SUM,  i_RFUKOJIN.KYU_SHIK_4_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_5_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KYU_SHIK_5_SUM,  i_RFUKOJIN.KYU_SHIK_5_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_6_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KYU_SHIK_6_SUM,  i_RFUKOJIN.KYU_SHIK_6_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_7_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KYU_SHIK_7_SUM,  i_RFUKOJIN.KYU_SHIK_7_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_8_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KYU_SHIK_8_SUM,  i_RFUKOJIN.KYU_SHIK_8_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_9_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KYU_SHIK_9_SUM,  i_RFUKOJIN.KYU_SHIK_9_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_10_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.KYU_SHIK_10_SUM, i_RFUKOJIN.KYU_SHIK_10_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_11_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.KYU_SHIK_11_SUM, i_RFUKOJIN.KYU_SHIK_11_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_12_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.KYU_SHIK_12_SUM, i_RFUKOJIN.KYU_SHIK_12_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_1_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KYU_SHIK_1_SUM,  i_RFUKOJIN.KYU_SHIK_1_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_2_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KYU_SHIK_2_SUM,  i_RFUKOJIN.KYU_SHIK_2_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_3_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.KYU_SHIK_3_SUM,  i_RFUKOJIN.KYU_SHIK_3_SUM);
    --合計資格該当人数（旧）　減フラグ
    o_RKYU_ZOGEN_FLG.SHIK_4_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KYU_SHIK_4_SUM,  i_RFUKOJIN.KYU_SHIK_4_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_5_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KYU_SHIK_5_SUM,  i_RFUKOJIN.KYU_SHIK_5_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_6_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KYU_SHIK_6_SUM,  i_RFUKOJIN.KYU_SHIK_6_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_7_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KYU_SHIK_7_SUM,  i_RFUKOJIN.KYU_SHIK_7_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_8_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KYU_SHIK_8_SUM,  i_RFUKOJIN.KYU_SHIK_8_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_9_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KYU_SHIK_9_SUM,  i_RFUKOJIN.KYU_SHIK_9_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_10_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.KYU_SHIK_10_SUM, i_RFUKOJIN.KYU_SHIK_10_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_11_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.KYU_SHIK_11_SUM, i_RFUKOJIN.KYU_SHIK_11_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_12_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.KYU_SHIK_12_SUM, i_RFUKOJIN.KYU_SHIK_12_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_1_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KYU_SHIK_1_SUM,  i_RFUKOJIN.KYU_SHIK_1_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_2_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KYU_SHIK_2_SUM,  i_RFUKOJIN.KYU_SHIK_2_SUM);
    o_RKYU_ZOGEN_FLG.SHIK_3_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.KYU_SHIK_3_SUM,  i_RFUKOJIN.KYU_SHIK_3_SUM);

    --合計資格該当人数（非）　増フラグ
    o_RSHITSU_ZOGEN_FLG.SHIK_4_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.SHITSU_SHIK_4_SUM,  i_RFUKOJIN.SHITSU_SHIK_4_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_5_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.SHITSU_SHIK_5_SUM,  i_RFUKOJIN.SHITSU_SHIK_5_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_6_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.SHITSU_SHIK_6_SUM,  i_RFUKOJIN.SHITSU_SHIK_6_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_7_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.SHITSU_SHIK_7_SUM,  i_RFUKOJIN.SHITSU_SHIK_7_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_8_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.SHITSU_SHIK_8_SUM,  i_RFUKOJIN.SHITSU_SHIK_8_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_9_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.SHITSU_SHIK_9_SUM,  i_RFUKOJIN.SHITSU_SHIK_9_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_10_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.SHITSU_SHIK_10_SUM, i_RFUKOJIN.SHITSU_SHIK_10_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_11_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.SHITSU_SHIK_11_SUM, i_RFUKOJIN.SHITSU_SHIK_11_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_12_SUM_ZO_FLG := FUNC_COMPARE_ZO(i_RKEIKOJIN.SHITSU_SHIK_12_SUM, i_RFUKOJIN.SHITSU_SHIK_12_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_1_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.SHITSU_SHIK_1_SUM,  i_RFUKOJIN.SHITSU_SHIK_1_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_2_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.SHITSU_SHIK_2_SUM,  i_RFUKOJIN.SHITSU_SHIK_2_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_3_SUM_ZO_FLG  := FUNC_COMPARE_ZO(i_RKEIKOJIN.SHITSU_SHIK_3_SUM,  i_RFUKOJIN.SHITSU_SHIK_3_SUM);
    --合計資格該当人数（非）　減フラグ
    o_RSHITSU_ZOGEN_FLG.SHIK_4_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.SHITSU_SHIK_4_SUM,  i_RFUKOJIN.SHITSU_SHIK_4_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_5_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.SHITSU_SHIK_5_SUM,  i_RFUKOJIN.SHITSU_SHIK_5_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_6_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.SHITSU_SHIK_6_SUM,  i_RFUKOJIN.SHITSU_SHIK_6_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_7_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.SHITSU_SHIK_7_SUM,  i_RFUKOJIN.SHITSU_SHIK_7_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_8_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.SHITSU_SHIK_8_SUM,  i_RFUKOJIN.SHITSU_SHIK_8_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_9_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.SHITSU_SHIK_9_SUM,  i_RFUKOJIN.SHITSU_SHIK_9_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_10_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.SHITSU_SHIK_10_SUM, i_RFUKOJIN.SHITSU_SHIK_10_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_11_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.SHITSU_SHIK_11_SUM, i_RFUKOJIN.SHITSU_SHIK_11_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_12_SUM_GEN_FLG := FUNC_COMPARE_GEN(i_RKEIKOJIN.SHITSU_SHIK_12_SUM, i_RFUKOJIN.SHITSU_SHIK_12_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_1_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.SHITSU_SHIK_1_SUM,  i_RFUKOJIN.SHITSU_SHIK_1_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_2_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.SHITSU_SHIK_2_SUM,  i_RFUKOJIN.SHITSU_SHIK_2_SUM);
    o_RSHITSU_ZOGEN_FLG.SHIK_3_SUM_GEN_FLG  := FUNC_COMPARE_GEN(i_RKEIKOJIN.SHITSU_SHIK_3_SUM,  i_RFUKOJIN.SHITSU_SHIK_3_SUM);
  END PROC_SETKOJIN_ZOGEN_FLG;
-------------------------------------------------------------------------------------
--  （計算個人、賦課個人（最新））テーブルより、増減判定に必要な各月毎の資格該当人数を算出
-------------------------------------------------------------------------------------
  FUNCTION FUNC_MAKESQL_KOJIN(i_NTABLENAME IN NVARCHAR2,
                              i_NKBN       IN NUMBER) RETURN VARCHAR2
  IS
    VSQL                      VARCHAR2(10000);
  BEGIN
    VSQL := NULL;
    VSQL := VSQL || 'SELECT KOKU_SETAI_NO,';                                                     --国保世帯番号
    VSQL := VSQL || '       SANTEIDANTAI_CD,';                                                   --算定団体コード
    VSQL := VSQL || '       CHOTEI_NENDO,';                                                      --調定年度
    VSQL := VSQL || '       NENDO_BUN,';                                                         --年度分
    VSQL := VSQL || '       TSUCHI_NO,';                                                         --通知書番号
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_4, 1))  ISHI_SHIK_4_SUM,';    --資格該当人数（医・支）_4月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_5, 1))  ISHI_SHIK_5_SUM,';    --資格該当人数（医・支）_5月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_6, 1))  ISHI_SHIK_6_SUM,';    --資格該当人数（医・支）_6月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_7, 1))  ISHI_SHIK_7_SUM,';    --資格該当人数（医・支）_7月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_8, 1))  ISHI_SHIK_8_SUM,';    --資格該当人数（医・支）_8月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_9, 1))  ISHI_SHIK_9_SUM,';    --資格該当人数（医・支）_9月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_10, 1)) ISHI_SHIK_10_SUM,';   --資格該当人数（医・支）_10月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_11, 1)) ISHI_SHIK_11_SUM,';   --資格該当人数（医・支）_11月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_12, 1)) ISHI_SHIK_12_SUM,';   --資格該当人数（医・支）_12月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_1, 1))  ISHI_SHIK_1_SUM,';    --資格該当人数（医・支）_1月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_2, 1))  ISHI_SHIK_2_SUM,';    --資格該当人数（医・支）_2月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_3, 1))  ISHI_SHIK_3_SUM,';    --資格該当人数（医・支）_3月
    VSQL := VSQL || '       SUM(CASE WHEN KAI_SHIK_4 = 1 THEN 1 ELSE 0 END)  KAI_SHIK_4_SUM,';   --資格該当人数（介）_4月
    VSQL := VSQL || '       SUM(CASE WHEN KAI_SHIK_5 = 1 THEN 1 ELSE 0 END)  KAI_SHIK_5_SUM,';   --資格該当人数（介）_5月
    VSQL := VSQL || '       SUM(CASE WHEN KAI_SHIK_6 = 1 THEN 1 ELSE 0 END)  KAI_SHIK_6_SUM,';   --資格該当人数（介）_6月
    VSQL := VSQL || '       SUM(CASE WHEN KAI_SHIK_7 = 1 THEN 1 ELSE 0 END)  KAI_SHIK_7_SUM,';   --資格該当人数（介）_7月
    VSQL := VSQL || '       SUM(CASE WHEN KAI_SHIK_8 = 1 THEN 1 ELSE 0 END)  KAI_SHIK_8_SUM,';   --資格該当人数（介）_8月
    VSQL := VSQL || '       SUM(CASE WHEN KAI_SHIK_9 = 1 THEN 1 ELSE 0 END)  KAI_SHIK_9_SUM,';   --資格該当人数（介）_9月
    VSQL := VSQL || '       SUM(CASE WHEN KAI_SHIK_10 = 1 THEN 1 ELSE 0 END) KAI_SHIK_10_SUM,';  --資格該当人数（介）_10月
    VSQL := VSQL || '       SUM(CASE WHEN KAI_SHIK_11 = 1 THEN 1 ELSE 0 END) KAI_SHIK_11_SUM,';  --資格該当人数（介）_11月
    VSQL := VSQL || '       SUM(CASE WHEN KAI_SHIK_12 = 1 THEN 1 ELSE 0 END) KAI_SHIK_12_SUM,';  --資格該当人数（介）_12月
    VSQL := VSQL || '       SUM(CASE WHEN KAI_SHIK_1 = 1 THEN 1 ELSE 0 END)  KAI_SHIK_1_SUM,';   --資格該当人数（介）_1月
    VSQL := VSQL || '       SUM(CASE WHEN KAI_SHIK_2 = 1 THEN 1 ELSE 0 END)  KAI_SHIK_2_SUM,';   --資格該当人数（介）_2月
    VSQL := VSQL || '       SUM(CASE WHEN KAI_SHIK_3 = 1 THEN 1 ELSE 0 END)  KAI_SHIK_3_SUM,';   --資格該当人数（介）_3月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_4, 3))  TD_SHIK_4_SUM,';      --資格該当人数（特同）_4月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_5, 3))  TD_SHIK_5_SUM,';      --資格該当人数（特同）_5月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_6, 3))  TD_SHIK_6_SUM,';      --資格該当人数（特同）_6月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_7, 3))  TD_SHIK_7_SUM,';      --資格該当人数（特同）_7月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_8, 3))  TD_SHIK_8_SUM,';      --資格該当人数（特同）_8月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_9, 3))  TD_SHIK_9_SUM,';      --資格該当人数（特同）_9月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_10, 3)) TD_SHIK_10_SUM,';     --資格該当人数（特同）_10月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_11, 3)) TD_SHIK_11_SUM,';     --資格該当人数（特同）_11月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_12, 3)) TD_SHIK_12_SUM,';     --資格該当人数（特同）_12月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_1, 3))  TD_SHIK_1_SUM,';      --資格該当人数（特同）_1月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_2, 3))  TD_SHIK_2_SUM,';      --資格該当人数（特同）_2月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_3, 3))  TD_SHIK_3_SUM,';      --資格該当人数（特同）_3月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_4, 5))  TK_SHIK_4_SUM,';      --資格該当人数（特継）_4月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_5, 5))  TK_SHIK_5_SUM,';      --資格該当人数（特継）_5月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_6, 5))  TK_SHIK_6_SUM,';      --資格該当人数（特継）_6月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_7, 5))  TK_SHIK_7_SUM,';      --資格該当人数（特継）_7月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_8, 5))  TK_SHIK_8_SUM,';      --資格該当人数（特継）_8月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_9, 5))  TK_SHIK_9_SUM,';      --資格該当人数（特継）_9月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_10, 5)) TK_SHIK_10_SUM,';     --資格該当人数（特継）_10月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_11, 5)) TK_SHIK_11_SUM,';     --資格該当人数（特継）_11月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_12, 5)) TK_SHIK_12_SUM,';     --資格該当人数（特継）_12月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_1, 5))  TK_SHIK_1_SUM,';      --資格該当人数（特継）_1月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_2, 5))  TK_SHIK_2_SUM,';      --資格該当人数（特継）_2月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_3, 5))  TK_SHIK_3_SUM,';      --資格該当人数（特継）_3月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_4, 4))  KYU_SHIK_4_SUM,';     --資格該当人数（旧）_4月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_5, 4))  KYU_SHIK_5_SUM,';     --資格該当人数（旧）_5月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_6, 4))  KYU_SHIK_6_SUM,';     --資格該当人数（旧）_6月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_7, 4))  KYU_SHIK_7_SUM,';     --資格該当人数（旧）_7月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_8, 4))  KYU_SHIK_8_SUM,';     --資格該当人数（旧）_8月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_9, 4))  KYU_SHIK_9_SUM,';     --資格該当人数（旧）_9月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_10, 4)) KYU_SHIK_10_SUM,';    --資格該当人数（旧）_10月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_11, 4)) KYU_SHIK_11_SUM,';    --資格該当人数（旧）_11月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_12, 4)) KYU_SHIK_12_SUM,';    --資格該当人数（旧）_12月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_1, 4))  KYU_SHIK_1_SUM,';     --資格該当人数（旧）_1月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_2, 4))  KYU_SHIK_2_SUM,';     --資格該当人数（旧）_2月
    VSQL := VSQL || '       SUM(ZLBPK00010.FCSHIKAKUHANTEI(SHIK_3, 4))  KYU_SHIK_3_SUM,';     --資格該当人数（旧）_3月
    VSQL := VSQL || '       SUM(NVL(SHITSU_4, 0))  SHITSU_SHIK_4_SUM,';                          --資格該当人数（非）_4月
    VSQL := VSQL || '       SUM(NVL(SHITSU_5, 0))  SHITSU_SHIK_5_SUM,';                          --資格該当人数（非）_5月
    VSQL := VSQL || '       SUM(NVL(SHITSU_6, 0))  SHITSU_SHIK_6_SUM,';                          --資格該当人数（非）_6月
    VSQL := VSQL || '       SUM(NVL(SHITSU_7, 0))  SHITSU_SHIK_7_SUM,';                          --資格該当人数（非）_7月
    VSQL := VSQL || '       SUM(NVL(SHITSU_8, 0))  SHITSU_SHIK_8_SUM,';                          --資格該当人数（非）_8月
    VSQL := VSQL || '       SUM(NVL(SHITSU_9, 0))  SHITSU_SHIK_9_SUM,';                          --資格該当人数（非）_9月
    VSQL := VSQL || '       SUM(NVL(SHITSU_10, 0)) SHITSU_SHIK_10_SUM,';                         --資格該当人数（非）_10月
    VSQL := VSQL || '       SUM(NVL(SHITSU_11, 0)) SHITSU_SHIK_11_SUM,';                         --資格該当人数（非）_11月
    VSQL := VSQL || '       SUM(NVL(SHITSU_12, 0)) SHITSU_SHIK_12_SUM,';                         --資格該当人数（非）_12月
    VSQL := VSQL || '       SUM(NVL(SHITSU_1, 0))  SHITSU_SHIK_1_SUM,';                          --資格該当人数（非）_1月
    VSQL := VSQL || '       SUM(NVL(SHITSU_2, 0))  SHITSU_SHIK_2_SUM,';                          --資格該当人数（非）_2月
    VSQL := VSQL || '       SUM(NVL(SHITSU_3, 0))  SHITSU_SHIK_3_SUM';                           --資格該当人数（非）_3月
    VSQL := VSQL || '  FROM ' || i_NTABLENAME;
    IF i_NKBN = 1 THEN
    VSQL := VSQL || ' WHERE KOKU_SETAI_NO = '     || NK_KOKU_SETAI_NO;
    VSQL := VSQL || '   AND SANTEIDANTAI_CD = '   || NK_SANTEIDANTAI_CD;
    VSQL := VSQL || '   AND CHOTEI_NENDO = '      || NK_CHOTEI_NENDO;
    VSQL := VSQL || '   AND NENDO_BUN = '         || NK_NENDO_BUN;
    VSQL := VSQL || '   AND TSUCHI_NO = '         || NK_TSUCHI_NO;
    VSQL := VSQL || '   AND SYS_TANMATSU_NO = ''' || VK_SYS_TANMATSU_NO || '''';
    ELSE
    VSQL := VSQL || ' WHERE KOKU_SETAI_NO = '     || FK_KOKU_SETAI_NO;
    VSQL := VSQL || '   AND SANTEIDANTAI_CD = '   || FK_SANTEIDANTAI_CD;
    VSQL := VSQL || '   AND CHOTEI_NENDO = '      || FK_CHOTEI_NENDO;
    VSQL := VSQL || '   AND NENDO_BUN = '         || FK_NENDO_BUN;
    VSQL := VSQL || '   AND TSUCHI_NO = '         || FK_TSUCHI_NO;
    END IF;
    VSQL := VSQL || ' GROUP BY KOKU_SETAI_NO';
    VSQL := VSQL || '         ,SANTEIDANTAI_CD';
    VSQL := VSQL || '         ,CHOTEI_NENDO';
    VSQL := VSQL || '         ,NENDO_BUN';
    VSQL := VSQL || '         ,TSUCHI_NO';

    RETURN VSQL;
  END FUNC_MAKESQL_KOJIN;
-------------------------------------------------------------------------------------
--  賦課個人の中間ワーク情報作成処理
-------------------------------------------------------------------------------------
  FUNCTION FUNC_GETFUKAKOJIN RETURN NUMBER
  IS
    --計算個人が存在し、賦課個人(最新)に存在しない対象を取得
    CURSOR CKEISAN IS
      SELECT JKC.KOJIN_NO
        FROM  ZLBWKOJIN_CAL_SKH JKC
       WHERE JKC.KOKU_SETAI_NO = NK_KOKU_SETAI_NO
         AND JKC.SANTEIDANTAI_CD = NK_SANTEIDANTAI_CD
         AND JKC.CHOTEI_NENDO = NK_CHOTEI_NENDO
         AND JKC.NENDO_BUN = NK_NENDO_BUN
         AND JKC.TSUCHI_NO = NK_TSUCHI_NO
         AND JKC.SYS_TANMATSU_NO = VK_SYS_TANMATSU_NO
         AND JKC.NEW_SHIK_KBN IN (1, 3, 7, 9)
         AND NOT EXISTS (SELECT 1
                           FROM ZLBTKOJIN_N JKN
                          WHERE JKN.KOKU_SETAI_NO = JKC.KOKU_SETAI_NO
                            AND JKN.SANTEIDANTAI_CD = JKC.SANTEIDANTAI_CD
                            AND JKN.CHOTEI_NENDO = FK_CHOTEI_NENDO
                            AND JKN.NENDO_BUN = JKC.NENDO_BUN
                            AND JKN.TSUCHI_NO = FK_TSUCHI_NO
                            AND JKN.SYS_TANMATSU_NO = JKC.SYS_TANMATSU_NO
                            AND JKN.KOJIN_NO = JKC.KOJIN_NO
                            AND JKN.NEW_SHIK_KBN IN (1, 3, 7, 9));
    --賦課個人(最新)が存在し、計算個人が存在しない対象を取得
    CURSOR CFUKA IS
      SELECT JKN.KOJIN_NO
        FROM ZLBTKOJIN_N JKN
       WHERE JKN.KOKU_SETAI_NO = FK_KOKU_SETAI_NO
         AND JKN.SANTEIDANTAI_CD = FK_SANTEIDANTAI_CD
         AND JKN.CHOTEI_NENDO = FK_CHOTEI_NENDO
         AND JKN.NENDO_BUN = FK_NENDO_BUN
         AND JKN.TSUCHI_NO = FK_TSUCHI_NO
         AND JKN.NEW_SHIK_KBN IN (1, 3, 7, 9)
         AND NOT EXISTS (SELECT 1
                           FROM  ZLBWKOJIN_CAL_SKH JKC
                          WHERE JKC.KOKU_SETAI_NO = JKN.KOKU_SETAI_NO
                            AND JKC.SANTEIDANTAI_CD = JKN.SANTEIDANTAI_CD
                            AND JKC.CHOTEI_NENDO = FK_CHOTEI_NENDO
                            AND JKC.NENDO_BUN = JKN.NENDO_BUN
                            AND JKC.TSUCHI_NO = FK_TSUCHI_NO
                            AND JKC.KOJIN_NO = JKN.KOJIN_NO
                            AND JKC.NEW_SHIK_KBN IN (1, 3, 7, 9));
    --賦課個人(最新)及び計算個人どちらにも対象が存在する対象を取得
    CURSOR CKEISAN_FUKA IS
      SELECT JKN.KOJIN_NO                                  AS KOJIN_NO                     --賦個.宛名番号
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_4, 1)  AS FU_SHIK_4                    --賦個.資格4月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_5, 1)  AS FU_SHIK_5                    --賦個.資格5月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_6, 1)  AS FU_SHIK_6                    --賦個.資格6月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_7, 1)  AS FU_SHIK_7                    --賦個.資格7月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_8, 1)  AS FU_SHIK_8                    --賦個.資格8月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_9, 1)  AS FU_SHIK_9                    --賦個.資格9月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_10, 1) AS FU_SHIK_10                   --賦個.資格10月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_11, 1) AS FU_SHIK_11                   --賦個.資格11月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_12, 1) AS FU_SHIK_12                   --賦個.資格12月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_1, 1)  AS FU_SHIK_1                    --賦個.資格1月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_2, 1)  AS FU_SHIK_2                    --賦個.資格2月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_3, 1)  AS FU_SHIK_3                    --賦個.資格３月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_4, 1)  AS KEI_SHIK_4                   --計個.資格4月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_5, 1)  AS KEI_SHIK_5                   --計個.資格5月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_6, 1)  AS KEI_SHIK_6                   --計個.資格6月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_7, 1)  AS KEI_SHIK_7                   --計個.資格7月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_8, 1)  AS KEI_SHIK_8                   --計個.資格8月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_9, 1)  AS KEI_SHIK_9                   --計個.資格9月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_10, 1) AS KEI_SHIK_10                  --計個.資格10月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_11, 1) AS KEI_SHIK_11                  --計個.資格11月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_12, 1) AS KEI_SHIK_12                  --計個.資格12月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_1, 1)  AS KEI_SHIK_1                   --計個.資格1月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_2, 1)  AS KEI_SHIK_2                   --計個.資格2月
            ,ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_3, 1)  AS KEI_SHIK_3                   --計個.資格３月
            ,JKN.KAI_SHIK_4                                AS FU_KAI_SHIK_4                --賦個.介護資格４月
            ,JKN.KAI_SHIK_5                                AS FU_KAI_SHIK_5                --賦個.介護資格５月
            ,JKN.KAI_SHIK_6                                AS FU_KAI_SHIK_6                --賦個.介護資格６月
            ,JKN.KAI_SHIK_7                                AS FU_KAI_SHIK_7                --賦個.介護資格７月
            ,JKN.KAI_SHIK_8                                AS FU_KAI_SHIK_8                --賦個.介護資格８月
            ,JKN.KAI_SHIK_9                                AS FU_KAI_SHIK_9                --賦個.介護資格９月
            ,JKN.KAI_SHIK_10                               AS FU_KAI_SHIK_10               --賦個.介護資格１０月
            ,JKN.KAI_SHIK_11                               AS FU_KAI_SHIK_11               --賦個.介護資格１１月
            ,JKN.KAI_SHIK_12                               AS FU_KAI_SHIK_12               --賦個.介護資格１２月
            ,JKN.KAI_SHIK_1                                AS FU_KAI_SHIK_1                --賦個.介護資格１月
            ,JKN.KAI_SHIK_2                                AS FU_KAI_SHIK_2                --賦個.介護資格2月
            ,JKN.KAI_SHIK_3                                AS FU_KAI_SHIK_3                --賦個.介護資格3月
            ,JKC.KAI_SHIK_4                                AS KEI_KAI_SHIK_4               --計個.介護資格４月
            ,JKC.KAI_SHIK_5                                AS KEI_KAI_SHIK_5               --計個.介護資格５月
            ,JKC.KAI_SHIK_6                                AS KEI_KAI_SHIK_6               --計個.介護資格６月
            ,JKC.KAI_SHIK_7                                AS KEI_KAI_SHIK_7               --計個.介護資格７月
            ,JKC.KAI_SHIK_8                                AS KEI_KAI_SHIK_8               --計個.介護資格８月
            ,JKC.KAI_SHIK_9                                AS KEI_KAI_SHIK_9               --計個.介護資格９月
            ,JKC.KAI_SHIK_10                               AS KEI_KAI_SHIK_10              --計個.介護資格１０月
            ,JKC.KAI_SHIK_11                               AS KEI_KAI_SHIK_11              --計個.介護資格１１月
            ,JKC.KAI_SHIK_12                               AS KEI_KAI_SHIK_12              --計個.介護資格１２月
            ,JKC.KAI_SHIK_1                                AS KEI_KAI_SHIK_1               --計個.介護資格１月
            ,JKC.KAI_SHIK_2                                AS KEI_KAI_SHIK_2               --計個.介護資格2月
            ,JKC.KAI_SHIK_3                                AS KEI_KAI_SHIK_3               --計個.介護資格3月
            ,JKN.KAHYO                                     AS FU_KAHYO                     --賦個.課税標準額
            ,JKN.SHOTOKU_WARI                              AS FU_SHOTOKU_WARI              --賦個.所得割額
            ,JKN.KEIGEN_SHOTOKU                            AS FU_KEIGEN_SHOTOKU            --賦個.軽減判定所得
            ,JKC.KAHYO                                     AS KEI_KAHYO                    --計個.課税標準額
            ,JKC.SHOTOKU_WARI                              AS KEI_SHOTOKU_WARI             --計個.所得割額
            ,JKC.KEIGEN_SHOTOKU                            AS KEI_KEIGEN_SHOTOKU           --計個.軽減判定所得
            ,JKN.SHITSU_SHOTOKU                            AS FU_SHITSU_SHOTOKU            --賦個.失業軽減適用後所得額
            ,JKN.SHITSU_KAHYO                              AS FU_SHITSU_KAHYO              --賦個.失業軽減適用後課税標準額
            ,JKN.SHITSU_KEIGEN_SHOTOKU                     AS FU_SHITSU_KEIGEN_SHOTOKU     --賦個.失業軽減適用後軽減判定所得
            ,JKC.SHITSU_SHOTOKU                            AS KEI_SHITSU_SHOTOKU           --計個.失業軽減適用後所得額
            ,JKC.SHITSU_KAHYO                              AS KEI_SHITSU_KAHYO             --計個.失業軽減適用後課税標準額
            ,JKC.SHITSU_KEIGEN_SHOTOKU                     AS KEI_SHITSU_KEIGEN_SHOTOKU    --計個.失業軽減適用後軽減判定所得
            ,JKN.SHISANZEI                                 AS FU_SHISANZEI                 --賦個.資産税額
            ,JKN.SHISAN_WARI                               AS FU_SHISAN_WARI               --賦個.資産割額
            ,JKC.SHISANZEI                                 AS KEI_SHISANZEI                --計個.資産税額
            ,JKC.SHISAN_WARI                               AS KEI_SHISAN_WARI              --計個.資産割額
        FROM ZLBWKOJIN_CAL_SKH JKC                                                         --計算個人
            ,ZLBTKOJIN_N   JKN                                                             --賦課個人(最新)
       WHERE JKN.KOKU_SETAI_NO = FK_KOKU_SETAI_NO
         AND JKN.SANTEIDANTAI_CD = FK_SANTEIDANTAI_CD
         AND JKN.CHOTEI_NENDO = FK_CHOTEI_NENDO
         AND JKN.NENDO_BUN = FK_NENDO_BUN
         AND JKN.TSUCHI_NO = FK_TSUCHI_NO
         AND JKC.KOKU_SETAI_NO = NK_KOKU_SETAI_NO
         AND JKC.SANTEIDANTAI_CD = NK_SANTEIDANTAI_CD
         AND JKC.CHOTEI_NENDO = NK_CHOTEI_NENDO
         AND JKC.NENDO_BUN = NK_NENDO_BUN
         AND JKC.TSUCHI_NO = NK_TSUCHI_NO
         AND JKC.SYS_TANMATSU_NO = VK_SYS_TANMATSU_NO
         AND JKC.KOJIN_NO = JKN.KOJIN_NO
         AND (JKN.NEW_SHIK_KBN IN (1, 3, 7, 9) OR JKC.NEW_SHIK_KBN IN (1, 3, 7, 9))
         AND (ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_4, 1)  <> ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_4, 1)
          OR  ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_5, 1)  <> ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_5, 1)
          OR  ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_6, 1)  <> ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_6, 1)
          OR  ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_7, 1)  <> ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_7, 1)
          OR  ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_8, 1)  <> ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_8, 1)
          OR  ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_9, 1)  <> ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_9, 1)
          OR  ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_10, 1) <> ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_10, 1)
          OR  ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_11, 1) <> ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_11, 1)
          OR  ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_12, 1) <> ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_12, 1)
          OR  ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_1, 1)  <> ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_1, 1)
          OR  ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_2, 1)  <> ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_2, 1)
          OR  ZLBPK00010.FCSHIKAKUHANTEI(JKN.SHIK_3, 1)  <> ZLBPK00010.FCSHIKAKUHANTEI(JKC.SHIK_3, 1)
          OR  JKN.KAI_SHIK_4  <> JKC.KAI_SHIK_4
          OR  JKN.KAI_SHIK_5  <> JKC.KAI_SHIK_5
          OR  JKN.KAI_SHIK_6  <> JKC.KAI_SHIK_6
          OR  JKN.KAI_SHIK_7  <> JKC.KAI_SHIK_7
          OR  JKN.KAI_SHIK_8  <> JKC.KAI_SHIK_8
          OR  JKN.KAI_SHIK_9  <> JKC.KAI_SHIK_9
          OR  JKN.KAI_SHIK_10 <> JKC.KAI_SHIK_10
          OR  JKN.KAI_SHIK_11 <> JKC.KAI_SHIK_11
          OR  JKN.KAI_SHIK_12 <> JKC.KAI_SHIK_12
          OR  JKN.KAI_SHIK_1  <> JKC.KAI_SHIK_1
          OR  JKN.KAI_SHIK_2  <> JKC.KAI_SHIK_2
          OR  JKN.KAI_SHIK_3  <> JKC.KAI_SHIK_3
          OR  JKN.KAHYO <> JKC.KAHYO
          OR  JKN.SHOTOKU_WARI <> JKC.SHOTOKU_WARI
          OR  JKN.KEIGEN_SHOTOKU <> JKC.KEIGEN_SHOTOKU
          OR  JKN.SHITSU_KAHYO <> JKC.SHITSU_KAHYO
          OR  JKN.SHITSU_SHOTOKU <> JKC.SHITSU_SHOTOKU
          OR  JKN.SHITSU_KEIGEN_SHOTOKU <> JKC.SHITSU_KEIGEN_SHOTOKU
          OR  JKN.SHISANZEI <> JKC.SHISANZEI
          OR  JKN.SHISAN_WARI <> JKC.SHISAN_WARI);
    VSQL                     VARCHAR2(10000);
    RKEI_KOJIN               KOJINRECORD;            --計算個人
    RFU_KOJIN                KOJINRECORD;            --賦課個人
    RISHI_ZOGEN_FLG          KOJIN_ZOGENFLG_RECORD;  --医・支
    RKAI_ZOGEN_FLG           KOJIN_ZOGENFLG_RECORD;  --介
    RTD_ZOGEN_FLG            KOJIN_ZOGENFLG_RECORD;  --特同
    RTK_ZOGEN_FLG            KOJIN_ZOGENFLG_RECORD;  --特継
    RKYU_ZOGEN_FLG           KOJIN_ZOGENFLG_RECORD;  --旧
    RSHITSU_ZOGEN_FLG        KOJIN_ZOGENFLG_RECORD;  --非
    RKYOTSU_FLG              KYOTSU_ZOGENFLG_RECORD;
    NHANTEILOG_KBN           NUMBER;                 --判定結果ログ出力区分
    VHANTEILOG_RTN           NVARCHAR2(1000);        --判定結果ログ(戻り値用)
    VHANTEILOG_IN            NVARCHAR2(1000);        --判定結果ログ(引数用)
    NKOJIN_ZO_FLG            NUMBER := 0;
    NKOJIN_GEN_FLG           NUMBER := 0;
    BCKEISAN_FLG             BOOLEAN := FALSE;       --計算個人が存在し、賦課個人(最新)に存在しないフラグ
    BCFUKA_FLG               BOOLEAN := FALSE;       --賦課個人(最新)が存在し、計算個人が存在しないフラグ
  BEGIN
    BEGIN
      VSQL := FUNC_MAKESQL_KOJIN('ZLBWKOJIN_CAL_SKH', 1);
      EXECUTE IMMEDIATE VSQL INTO RKEI_KOJIN;
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '賦課状況の中間ワーク情報作成でZLBWKOJIN_CAL_SKHの各種項目の取得に失敗しました（FUNC_GETFUKAKOJIN）';
        PROCLOGOUT(1,VMSG);
        RETURN 1;
    END;
    BEGIN
      VSQL := FUNC_MAKESQL_KOJIN('ZLBTKOJIN_N', 0);
      EXECUTE IMMEDIATE VSQL INTO RFU_KOJIN;
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '賦課状況の中間ワーク情報作成でZLBTKOJIN_Nの各種項目の取得に失敗しました（FUNC_GETFUKAKOJIN）';
        PROCLOGOUT(1,VMSG);
        RETURN 1;
    END;
    --取得した結果を元に賦課計算個人テーブル、賦課個人（最新）テーブルの各項目比較し、増フラグ、減フラグ、共通増フラグ、共通減フラグ設定
    PROC_SETKOJIN_ZOGEN_FLG(RKEI_KOJIN,
                            RFU_KOJIN,
                            RISHI_ZOGEN_FLG,
                            RKAI_ZOGEN_FLG,
                            RTD_ZOGEN_FLG,
                            RTK_ZOGEN_FLG,
                            RKYU_ZOGEN_FLG,
                            RSHITSU_ZOGEN_FLG,
                            NKOJIN_ZO_FLG,
                            NKOJIN_GEN_FLG);

    --判定結果ログ出力区分に0をセットし、判定結果ログ(戻り値用)に空白をセットする
    NHANTEILOG_KBN := 0;  --判定結果ログ出力区分
    VHANTEILOG_RTN := ''; --判定結果ログ

    --共通増フラグ、減フラグのどちらか一方が0の場合、以下の処理を実行する
    IF NKOJIN_ZO_FLG = 0 OR NKOJIN_GEN_FLG = 0 THEN
      --計算個人が存在し、賦課個人(最新)に存在しない対象が取得できた場合、共通増フラグをセットする
      FOR CRKEISAN IN CKEISAN LOOP
        BCKEISAN_FLG := TRUE;
        NKOJIN_ZO_FLG := 1;
        NHANTEILOG_KBN := 1;
        VHANTEILOG_IN := '対象増：' || CRKEISAN.KOJIN_NO;
        VHANTEILOG_RTN := FUNC_GETHANTEIKEKA_LOG(VHANTEILOG_IN,
                                                 VHANTEILOG_RTN);
      END LOOP;
      --計算個人が存在し、賦課個人(最新)に存在しない対象が取得できなかった場合
      IF NOT BCKEISAN_FLG THEN
        --賦課個人(最新)が存在し、計算個人が存在しない対象が取得できた場合、共通減フラグをセットする
        FOR CRFUKA IN CFUKA LOOP
          BCFUKA_FLG := TRUE;
          NKOJIN_GEN_FLG := 1;
          NHANTEILOG_KBN := 1;
          VHANTEILOG_IN := '対象減：' || CRFUKA.KOJIN_NO;
          VHANTEILOG_RTN := FUNC_GETHANTEIKEKA_LOG(VHANTEILOG_IN,
                                                   VHANTEILOG_RTN);
        END LOOP;
        --賦課個人(最新)が存在し、計算個人に存在しない対象が取得できなかった場合
        IF NOT BCFUKA_FLG THEN
          --賦課個人(最新)及び計算個人どちらにも対象が存在する対象が取得できた場合
          FOR CRKEISAN_FUKA IN CKEISAN_FUKA LOOP
            RKYOTSU_FLG := CRKEISAN_FUKA;
            --取得した項目を元に共通増フラグ、共通減フラグ、判定結果ログ出力区分、判定結果ログを登録する
            PROC_SETKYOTSU_ZOGEN_FLG(RKYOTSU_FLG,
                                     NHANTEILOG_KBN,
                                     VHANTEILOG_RTN,
                                     NKOJIN_ZO_FLG,
                                     NKOJIN_GEN_FLG);
          END LOOP;
        END IF;
      END IF;
    END IF;

    --取得した結果を賦課個人比較結果中間ワーク情報に登録する
    NRTN := FUNC_INSERT_WK_FUKAKOJIN(RKEI_KOJIN,
                                     RFU_KOJIN,
                                     RISHI_ZOGEN_FLG,
                                     RKAI_ZOGEN_FLG,
                                     RTD_ZOGEN_FLG,
                                     RTK_ZOGEN_FLG,
                                     RKYU_ZOGEN_FLG,
                                     RSHITSU_ZOGEN_FLG,
                                     NHANTEILOG_KBN,
                                     NKOJIN_ZO_FLG,
                                     NKOJIN_GEN_FLG);
    IF NRTN <> 0 THEN
      RETURN 1;
    END IF;

    --取得した判定結果ログ出力区分が1の場合のみ判定結果ログを賦課個人比較結果ログに登録する
    IF NHANTEILOG_KBN = 1 THEN
      NRTN := FUNC_INSERT_WK_SEIGENKOHO_LOG(VHANTEILOG_RTN);
      IF NRTN <> 0 THEN
        RETURN 1;
      END IF;
    END IF;

    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      VMSG := '制限対象候補世帯の判定でエラーが発生しました（FUNC_GETFUKAKOJIN）';
      VMSG := VMSG || '　年度分：' || NK_NENDO_BUN || '　国保世帯番号：' || NK_KOKU_SETAI_NO;
      VMSG := VMSG || '　算定団体コード：' || NK_SANTEIDANTAI_CD || '　世帯主宛名番号：' || NK_NUSHI_KOJIN_NO;
      VMSG := VMSG || '　SQLエラー：' || SQLERRM;
      PROCLOGOUT(1,VMSG);
      RETURN 1;
  END FUNC_GETFUKAKOJIN;
-------------------------------------------------------------------------------------
--  賦課状況比較結果中間ワーク情報に登録
-------------------------------------------------------------------------------------
  FUNCTION FUNC_INSERT_WK_FUKAJOKYO(i_RKIHON_CAL           IN KEIKIRECORD,
                                    i_RSIEN_KIHON_CAL      IN KEIKIRECORD,
--2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                                    i_RKDM_KIHON_CAL       IN  KEIKIRECORD_KDM,
                                    i_RKAI_KIHON_CAL       IN KEIKIRECORD,
                                    i_RKIHON_N             IN KEIKIRECORD,
                                    i_RSIEN_KIHON_N        IN KEIKIRECORD,
--2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                                    i_RKDM_KIHON_N         IN  KEIKIRECORD_KDM,
                                    i_RKAI_KIHON_N         IN KEIKIRECORD,
                                    i_RKIHON_ZOGENFLG      IN JOKYO_ZOGENFLG_RECORD,
                                    i_RSIEN_KIHON_ZOGENFLG IN JOKYO_ZOGENFLG_RECORD,
--2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                                    i_RKDM_FUKA_FLG        IN JOKYO_ZOGENFLG_RECORD_KDM,
                                    i_RKAI_KIHON_ZOGENFLG  IN JOKYO_ZOGENFLG_RECORD,
                                    i_NJOKYO_ZO_FLG        IN NUMBER,
                                    i_NJOKYO_GEN_FLG       IN NUMBER)
    RETURN NUMBER
  IS
  BEGIN
    INSERT INTO ZLBWSEIGENKOHO_FJK
         VALUES (NK_KOKU_SETAI_NO                             --計キー国保世帯番号
                ,NK_SANTEIDANTAI_CD                           --計キー算定団体コード
                ,NK_NENDO_BUN                                 --計キー年度分
                ,NK_NUSHI_KOJIN_NO                            --計キー世帯主宛名番号
                ,i_RKIHON_CAL.KINTO_CNT                       --計基.均等人員
                ,i_RKIHON_CAL.KAHYO                           --計基.基準総所得
                ,i_RKIHON_CAL.SHOTOKU_WARI                    --計基.所得割額
                ,i_RKIHON_CAL.SHISANZEI                       --計基.資産税額
                ,i_RKIHON_CAL.SHISAN_WARI                     --計基.資産割額
                ,i_RKIHON_CAL.KINTO_WARI                      --計基.均等割額
                ,i_RKIHON_CAL.BYODO_WARI                      --計基.平等割額
                ,i_RKIHON_CAL.SEKISAN                         --計基.積算合計
                ,i_RKIHON_CAL.GENDO_CHOKA                     --計基.限度超過額
                ,i_RKIHON_CAL.KEIGEN_K_WARI                   --計基.軽減均等
                ,i_RKIHON_CAL.KEIGEN_B_WARI                   --計基.軽減平等
                ,i_RKIHON_CAL.TSUKIWARI_GEN                   --計基.月割減額
                ,i_RKIHON_CAL.GENMEN                          --計基.減免額
                ,i_RKIHON_CAL.KANENDO                         --計基.他年度賦課
                ,i_RKIHON_CAL.NENZEI                          --計基.年額
                ,i_RKIHON_CAL.KEIGEN_4                        --計基.軽減4月
                ,i_RKIHON_CAL.KEIGEN_5                        --計基.軽減5月
                ,i_RKIHON_CAL.KEIGEN_6                        --計基.軽減6月
                ,i_RKIHON_CAL.KEIGEN_7                        --計基.軽減7月
                ,i_RKIHON_CAL.KEIGEN_8                        --計基.軽減8月
                ,i_RKIHON_CAL.KEIGEN_9                        --計基.軽減9月
                ,i_RKIHON_CAL.KEIGEN_10                       --計基.軽減10月
                ,i_RKIHON_CAL.KEIGEN_11                       --計基.軽減11月
                ,i_RKIHON_CAL.KEIGEN_12                       --計基.軽減12月
                ,i_RKIHON_CAL.KEIGEN_1                        --計基.軽減1月
                ,i_RKIHON_CAL.KEIGEN_2                        --計基.軽減2月
                ,i_RKIHON_CAL.KEIGEN_3                        --計基.軽減3月
                ,i_RSIEN_KIHON_CAL.KINTO_CNT                  --計支.均等人員
                ,i_RSIEN_KIHON_CAL.KAHYO                      --計支.基準総所得
                ,i_RSIEN_KIHON_CAL.SHOTOKU_WARI               --計支.所得割額
                ,i_RSIEN_KIHON_CAL.SHISANZEI                  --計支.資産税額
                ,i_RSIEN_KIHON_CAL.SHISAN_WARI                --計支.資産割額
                ,i_RSIEN_KIHON_CAL.KINTO_WARI                 --計支.均等割額
                ,i_RSIEN_KIHON_CAL.BYODO_WARI                 --計支.平等割額
                ,i_RSIEN_KIHON_CAL.SEKISAN                    --計支.積算合計
                ,i_RSIEN_KIHON_CAL.GENDO_CHOKA                --計支.限度超過額
                ,i_RSIEN_KIHON_CAL.KEIGEN_K_WARI              --計支.軽減均等
                ,i_RSIEN_KIHON_CAL.KEIGEN_B_WARI              --計支.軽減平等
                ,i_RSIEN_KIHON_CAL.TSUKIWARI_GEN              --計支.月割減額
                ,i_RSIEN_KIHON_CAL.GENMEN                     --計支.減免額
                ,i_RSIEN_KIHON_CAL.KANENDO                    --計支.他年度賦課
                ,i_RSIEN_KIHON_CAL.NENZEI                     --計支.年額
                ,i_RSIEN_KIHON_CAL.KEIGEN_4                   --計支.軽減4月
                ,i_RSIEN_KIHON_CAL.KEIGEN_5                   --計支.軽減5月
                ,i_RSIEN_KIHON_CAL.KEIGEN_6                   --計支.軽減6月
                ,i_RSIEN_KIHON_CAL.KEIGEN_7                   --計支.軽減7月
                ,i_RSIEN_KIHON_CAL.KEIGEN_8                   --計支.軽減8月
                ,i_RSIEN_KIHON_CAL.KEIGEN_9                   --計支.軽減9月
                ,i_RSIEN_KIHON_CAL.KEIGEN_10                  --計支.軽減10月
                ,i_RSIEN_KIHON_CAL.KEIGEN_11                  --計支.軽減11月
                ,i_RSIEN_KIHON_CAL.KEIGEN_12                  --計支.軽減12月
                ,i_RSIEN_KIHON_CAL.KEIGEN_1                   --計支.軽減1月
                ,i_RSIEN_KIHON_CAL.KEIGEN_2                   --計支.軽減2月
                ,i_RSIEN_KIHON_CAL.KEIGEN_3                   --計支.軽減3月
                ,i_RKAI_KIHON_CAL.KINTO_CNT                   --計介.均等人員
                ,i_RKAI_KIHON_CAL.KAHYO                       --計介.基準総所得
                ,i_RKAI_KIHON_CAL.SHOTOKU_WARI                --計介.所得割額
                ,i_RKAI_KIHON_CAL.SHISANZEI                   --計介.資産税額
                ,i_RKAI_KIHON_CAL.SHISAN_WARI                 --計介.資産割額
                ,i_RKAI_KIHON_CAL.KINTO_WARI                  --計介.均等割額
                ,i_RKAI_KIHON_CAL.BYODO_WARI                  --計介.平等割額
                ,i_RKAI_KIHON_CAL.SEKISAN                     --計介.積算合計
                ,i_RKAI_KIHON_CAL.GENDO_CHOKA                 --計介.限度超過額
                ,i_RKAI_KIHON_CAL.KEIGEN_K_WARI               --計介.軽減均等
                ,i_RKAI_KIHON_CAL.KEIGEN_B_WARI               --計介.軽減平等
                ,i_RKAI_KIHON_CAL.TSUKIWARI_GEN               --計介.月割減額
                ,i_RKAI_KIHON_CAL.GENMEN                      --計介.減免額
                ,i_RKAI_KIHON_CAL.KANENDO                     --計介.他年度賦課
                ,i_RKAI_KIHON_CAL.NENZEI                      --計介.年額
                ,i_RKAI_KIHON_CAL.KEIGEN_4                    --計介.軽減4月
                ,i_RKAI_KIHON_CAL.KEIGEN_5                    --計介.軽減5月
                ,i_RKAI_KIHON_CAL.KEIGEN_6                    --計介.軽減6月
                ,i_RKAI_KIHON_CAL.KEIGEN_7                    --計介.軽減7月
                ,i_RKAI_KIHON_CAL.KEIGEN_8                    --計介.軽減8月
                ,i_RKAI_KIHON_CAL.KEIGEN_9                    --計介.軽減9月
                ,i_RKAI_KIHON_CAL.KEIGEN_10                   --計介.軽減10月
                ,i_RKAI_KIHON_CAL.KEIGEN_11                   --計介.軽減11月
                ,i_RKAI_KIHON_CAL.KEIGEN_12                   --計介.軽減12月
                ,i_RKAI_KIHON_CAL.KEIGEN_1                    --計介.軽減1月
                ,i_RKAI_KIHON_CAL.KEIGEN_2                    --計介.軽減2月
                ,i_RKAI_KIHON_CAL.KEIGEN_3                    --計介.軽減3月
                ,i_RKIHON_N.KINTO_CNT                         --賦基.均等人員
                ,i_RKIHON_N.KAHYO                             --賦基.基準総所得
                ,i_RKIHON_N.SHOTOKU_WARI                      --賦基.所得割額
                ,i_RKIHON_N.SHISANZEI                         --賦基.資産税額
                ,i_RKIHON_N.SHISAN_WARI                       --賦基.資産割額
                ,i_RKIHON_N.KINTO_WARI                        --賦基.均等割額
                ,i_RKIHON_N.BYODO_WARI                        --賦基.平等割額
                ,i_RKIHON_N.SEKISAN                           --賦基.積算合計
                ,i_RKIHON_N.GENDO_CHOKA                       --賦基.限度超過額
                ,i_RKIHON_N.KEIGEN_K_WARI                     --賦基.軽減均等
                ,i_RKIHON_N.KEIGEN_B_WARI                     --賦基.軽減平等
                ,i_RKIHON_N.TSUKIWARI_GEN                     --賦基.月割減額
                ,i_RKIHON_N.GENMEN                            --賦基.減免額
                ,i_RKIHON_N.KANENDO                           --賦基.他年度賦課
                ,i_RKIHON_N.NENZEI                            --賦基.年額
                ,i_RKIHON_N.KEIGEN_4                          --賦基.軽減4月
                ,i_RKIHON_N.KEIGEN_5                          --賦基.軽減5月
                ,i_RKIHON_N.KEIGEN_6                          --賦基.軽減6月
                ,i_RKIHON_N.KEIGEN_7                          --賦基.軽減7月
                ,i_RKIHON_N.KEIGEN_8                          --賦基.軽減8月
                ,i_RKIHON_N.KEIGEN_9                          --賦基.軽減9月
                ,i_RKIHON_N.KEIGEN_10                         --賦基.軽減10月
                ,i_RKIHON_N.KEIGEN_11                         --賦基.軽減11月
                ,i_RKIHON_N.KEIGEN_12                         --賦基.軽減12月
                ,i_RKIHON_N.KEIGEN_1                          --賦基.軽減1月
                ,i_RKIHON_N.KEIGEN_2                          --賦基.軽減2月
                ,i_RKIHON_N.KEIGEN_3                          --賦基.軽減3月
                ,i_RSIEN_KIHON_N.KINTO_CNT                    --賦支.均等人員
                ,i_RSIEN_KIHON_N.KAHYO                        --賦支.基準総所得
                ,i_RSIEN_KIHON_N.SHOTOKU_WARI                 --賦支.所得割額
                ,i_RSIEN_KIHON_N.SHISANZEI                    --賦支.資産税額
                ,i_RSIEN_KIHON_N.SHISAN_WARI                  --賦支.資産割額
                ,i_RSIEN_KIHON_N.KINTO_WARI                   --賦支.均等割額
                ,i_RSIEN_KIHON_N.BYODO_WARI                   --賦支.平等割額
                ,i_RSIEN_KIHON_N.SEKISAN                      --賦支.積算合計
                ,i_RSIEN_KIHON_N.GENDO_CHOKA                  --賦支.限度超過額
                ,i_RSIEN_KIHON_N.KEIGEN_K_WARI                --賦支.軽減均等
                ,i_RSIEN_KIHON_N.KEIGEN_B_WARI                --賦支.軽減平等
                ,i_RSIEN_KIHON_N.TSUKIWARI_GEN                --賦支.月割減額
                ,i_RSIEN_KIHON_N.GENMEN                       --賦支.減免額
                ,i_RSIEN_KIHON_N.KANENDO                      --賦支.他年度賦課
                ,i_RSIEN_KIHON_N.NENZEI                       --賦支.年額
                ,i_RSIEN_KIHON_N.KEIGEN_4                     --賦支.軽減4月
                ,i_RSIEN_KIHON_N.KEIGEN_5                     --賦支.軽減5月
                ,i_RSIEN_KIHON_N.KEIGEN_6                     --賦支.軽減6月
                ,i_RSIEN_KIHON_N.KEIGEN_7                     --賦支.軽減7月
                ,i_RSIEN_KIHON_N.KEIGEN_8                     --賦支.軽減8月
                ,i_RSIEN_KIHON_N.KEIGEN_9                     --賦支.軽減9月
                ,i_RSIEN_KIHON_N.KEIGEN_10                    --賦支.軽減10月
                ,i_RSIEN_KIHON_N.KEIGEN_11                    --賦支.軽減11月
                ,i_RSIEN_KIHON_N.KEIGEN_12                    --賦支.軽減12月
                ,i_RSIEN_KIHON_N.KEIGEN_1                     --賦支.軽減1月
                ,i_RSIEN_KIHON_N.KEIGEN_2                     --賦支.軽減2月
                ,i_RSIEN_KIHON_N.KEIGEN_3                     --賦支.軽減3月
                ,i_RKAI_KIHON_N.KINTO_CNT                     --賦介.均等人員
                ,i_RKAI_KIHON_N.KAHYO                         --賦介.基準総所得
                ,i_RKAI_KIHON_N.SHOTOKU_WARI                  --賦介.所得割額
                ,i_RKAI_KIHON_N.SHISANZEI                     --賦介.資産税額
                ,i_RKAI_KIHON_N.SHISAN_WARI                   --賦介.資産割額
                ,i_RKAI_KIHON_N.KINTO_WARI                    --賦介.均等割額
                ,i_RKAI_KIHON_N.BYODO_WARI                    --賦介.平等割額
                ,i_RKAI_KIHON_N.SEKISAN                       --賦介.積算合計
                ,i_RKAI_KIHON_N.GENDO_CHOKA                   --賦介.限度超過額
                ,i_RKAI_KIHON_N.KEIGEN_K_WARI                 --賦介.軽減均等
                ,i_RKAI_KIHON_N.KEIGEN_B_WARI                 --賦介.軽減平等
                ,i_RKAI_KIHON_N.TSUKIWARI_GEN                 --賦介.月割減額
                ,i_RKAI_KIHON_N.GENMEN                        --賦介.減免額
                ,i_RKAI_KIHON_N.KANENDO                       --賦介.他年度賦課
                ,i_RKAI_KIHON_N.NENZEI                        --賦介.年額
                ,i_RKAI_KIHON_N.KEIGEN_4                      --賦介.軽減4月
                ,i_RKAI_KIHON_N.KEIGEN_5                      --賦介.軽減5月
                ,i_RKAI_KIHON_N.KEIGEN_6                      --賦介.軽減6月
                ,i_RKAI_KIHON_N.KEIGEN_7                      --賦介.軽減7月
                ,i_RKAI_KIHON_N.KEIGEN_8                      --賦介.軽減8月
                ,i_RKAI_KIHON_N.KEIGEN_9                      --賦介.軽減9月
                ,i_RKAI_KIHON_N.KEIGEN_10                     --賦介.軽減10月
                ,i_RKAI_KIHON_N.KEIGEN_11                     --賦介.軽減11月
                ,i_RKAI_KIHON_N.KEIGEN_12                     --賦介.軽減12月
                ,i_RKAI_KIHON_N.KEIGEN_1                      --賦介.軽減1月
                ,i_RKAI_KIHON_N.KEIGEN_2                      --賦介.軽減2月
                ,i_RKAI_KIHON_N.KEIGEN_3                      --賦介.軽減3月
                ,i_RKIHON_ZOGENFLG.KINTO_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KAHYO_ZO_FLG
                ,i_RKIHON_ZOGENFLG.SHOTOKU_WARI_ZO_FLG
                ,i_RKIHON_ZOGENFLG.SHISANZEI_ZO_FLG
                ,i_RKIHON_ZOGENFLG.SHISAN_WARI_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KINTO_WARI_ZO_FLG
                ,i_RKIHON_ZOGENFLG.BYODO_WARI_ZO_FLG
                ,i_RKIHON_ZOGENFLG.SEKISAN_ZO_FLG
                ,i_RKIHON_ZOGENFLG.GENDO_CHOKA_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_K_WARI_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_B_WARI_ZO_FLG
                ,i_RKIHON_ZOGENFLG.TSUKIWARI_GEN_ZO_FLG
                ,i_RKIHON_ZOGENFLG.GENMEN_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KANENDO_ZO_FLG
                ,i_RKIHON_ZOGENFLG.NENZEI_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_4_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_5_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_6_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_7_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_8_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_9_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_10_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_11_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_12_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_1_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_2_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_3_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KINTO_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KAHYO_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.SHOTOKU_WARI_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.SHISANZEI_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.SHISAN_WARI_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KINTO_WARI_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.BYODO_WARI_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.SEKISAN_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.GENDO_CHOKA_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_K_WARI_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_B_WARI_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.TSUKIWARI_GEN_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.GENMEN_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KANENDO_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.NENZEI_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_4_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_5_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_6_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_7_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_8_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_9_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_10_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_11_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_12_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_1_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_2_ZO_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_3_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KINTO_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KAHYO_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.SHOTOKU_WARI_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.SHISANZEI_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.SHISAN_WARI_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KINTO_WARI_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.BYODO_WARI_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.SEKISAN_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.GENDO_CHOKA_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_K_WARI_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_B_WARI_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.TSUKIWARI_GEN_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.GENMEN_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KANENDO_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.NENZEI_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_4_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_5_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_6_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_7_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_8_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_9_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_10_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_11_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_12_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_1_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_2_ZO_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_3_ZO_FLG
                ,i_RKIHON_ZOGENFLG.KINTO_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KAHYO_GEN_FLG
                ,i_RKIHON_ZOGENFLG.SHOTOKU_WARI_GEN_FLG
                ,i_RKIHON_ZOGENFLG.SHISANZEI_GEN_FLG
                ,i_RKIHON_ZOGENFLG.SHISAN_WARI_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KINTO_WARI_GEN_FLG
                ,i_RKIHON_ZOGENFLG.BYODO_WARI_GEN_FLG
                ,i_RKIHON_ZOGENFLG.SEKISAN_GEN_FLG
                ,i_RKIHON_ZOGENFLG.GENDO_CHOKA_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_K_WARI_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_B_WARI_GEN_FLG
                ,i_RKIHON_ZOGENFLG.TSUKIWARI_GEN_GEN_FLG
                ,i_RKIHON_ZOGENFLG.GENMEN_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KANENDO_GEN_FLG
                ,i_RKIHON_ZOGENFLG.NENZEI_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_4_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_5_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_6_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_7_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_8_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_9_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_10_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_11_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_12_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_1_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_2_GEN_FLG
                ,i_RKIHON_ZOGENFLG.KEIGEN_3_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KINTO_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KAHYO_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.SHOTOKU_WARI_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.SHISANZEI_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.SHISAN_WARI_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KINTO_WARI_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.BYODO_WARI_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.SEKISAN_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.GENDO_CHOKA_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_K_WARI_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_B_WARI_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.TSUKIWARI_GEN_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.GENMEN_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KANENDO_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.NENZEI_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_4_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_5_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_6_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_7_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_8_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_9_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_10_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_11_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_12_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_1_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_2_GEN_FLG
                ,i_RSIEN_KIHON_ZOGENFLG.KEIGEN_3_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KINTO_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KAHYO_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.SHOTOKU_WARI_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.SHISANZEI_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.SHISAN_WARI_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KINTO_WARI_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.BYODO_WARI_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.SEKISAN_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.GENDO_CHOKA_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_K_WARI_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_B_WARI_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.TSUKIWARI_GEN_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.GENMEN_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KANENDO_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.NENZEI_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_4_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_5_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_6_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_7_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_8_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_9_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_10_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_11_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_12_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_1_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_2_GEN_FLG
                ,i_RKAI_KIHON_ZOGENFLG.KEIGEN_3_GEN_FLG
                ,i_NJOKYO_ZO_FLG
                ,i_NJOKYO_GEN_FLG
                ,TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'))
                ,TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'))
                ,TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MIDD'))
                ,i_NSYS_SHOKUINKOJIN_NO
                ,i_VMASIN_NO
--2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
                ,i_RKDM_KIHON_CAL.KINTO_CNT
                ,i_RKDM_KIHON_CAL.KAHYO
                ,i_RKDM_KIHON_CAL.SHOTOKU_WARI 
                ,i_RKDM_KIHON_CAL.SHISANZEI
                ,i_RKDM_KIHON_CAL.SHISAN_WARI
                ,i_RKDM_KIHON_CAL.KINTO_WARI 
                ,i_RKDM_KIHON_CAL.BYODO_WARI 
                ,i_RKDM_KIHON_CAL.SEKISAN
                ,i_RKDM_KIHON_CAL.GENDO_CHOKA
                ,i_RKDM_KIHON_CAL.KEIGEN_K_WARI
                ,i_RKDM_KIHON_CAL.KEIGEN_B_WARI
                ,i_RKDM_KIHON_CAL.TSUKIWARI_GEN
                ,i_RKDM_KIHON_CAL.GENMEN 
                ,i_RKDM_KIHON_CAL.KANENDO
                ,i_RKDM_KIHON_CAL.NENZEI 
                ,i_RKDM_KIHON_CAL.KEIGEN_4 
                ,i_RKDM_KIHON_CAL.KEIGEN_5 
                ,i_RKDM_KIHON_CAL.KEIGEN_6 
                ,i_RKDM_KIHON_CAL.KEIGEN_7 
                ,i_RKDM_KIHON_CAL.KEIGEN_8 
                ,i_RKDM_KIHON_CAL.KEIGEN_9 
                ,i_RKDM_KIHON_CAL.KEIGEN_10
                ,i_RKDM_KIHON_CAL.KEIGEN_11
                ,i_RKDM_KIHON_CAL.KEIGEN_12
                ,i_RKDM_KIHON_CAL.KEIGEN_1 
                ,i_RKDM_KIHON_CAL.KEIGEN_2 
                ,i_RKDM_KIHON_CAL.KEIGEN_3 
                ,i_RKDM_KIHON_N.KINTO_CNT
                ,i_RKDM_KIHON_N.KAHYO
                ,i_RKDM_KIHON_N.SHOTOKU_WARI 
                ,i_RKDM_KIHON_N.SHISANZEI
                ,i_RKDM_KIHON_N.SHISAN_WARI
                ,i_RKDM_KIHON_N.KINTO_WARI 
                ,i_RKDM_KIHON_N.BYODO_WARI 
                ,i_RKDM_KIHON_N.SEKISAN
                ,i_RKDM_KIHON_N.GENDO_CHOKA
                ,i_RKDM_KIHON_N.KEIGEN_K_WARI
                ,i_RKDM_KIHON_N.KEIGEN_B_WARI
                ,i_RKDM_KIHON_N.TSUKIWARI_GEN
                ,i_RKDM_KIHON_N.GENMEN 
                ,i_RKDM_KIHON_N.KANENDO
                ,i_RKDM_KIHON_N.NENZEI 
                ,i_RKDM_KIHON_N.KEIGEN_4 
                ,i_RKDM_KIHON_N.KEIGEN_5 
                ,i_RKDM_KIHON_N.KEIGEN_6 
                ,i_RKDM_KIHON_N.KEIGEN_7 
                ,i_RKDM_KIHON_N.KEIGEN_8 
                ,i_RKDM_KIHON_N.KEIGEN_9 
                ,i_RKDM_KIHON_N.KEIGEN_10
                ,i_RKDM_KIHON_N.KEIGEN_11
                ,i_RKDM_KIHON_N.KEIGEN_12
                ,i_RKDM_KIHON_N.KEIGEN_1 
                ,i_RKDM_KIHON_N.KEIGEN_2 
                ,i_RKDM_KIHON_N.KEIGEN_3 
                ,i_RKDM_FUKA_FLG.KINTO_ZO_FLG
                ,i_RKDM_FUKA_FLG.KAHYO_ZO_FLG
                ,i_RKDM_FUKA_FLG.SHOTOKU_WARI_ZO_FLG 
                ,i_RKDM_FUKA_FLG.SHISANZEI_ZO_FLG
                ,i_RKDM_FUKA_FLG.SHISAN_WARI_ZO_FLG
                ,i_RKDM_FUKA_FLG.KINTO_WARI_ZO_FLG 
                ,i_RKDM_FUKA_FLG.BYODO_WARI_ZO_FLG 
                ,i_RKDM_FUKA_FLG.SEKISAN_ZO_FLG
                ,i_RKDM_FUKA_FLG.GENDO_CHOKA_ZO_FLG
                ,i_RKDM_FUKA_FLG.KEIGEN_K_WARI_ZO_FLG
                ,i_RKDM_FUKA_FLG.KEIGEN_B_WARI_ZO_FLG
                ,i_RKDM_FUKA_FLG.TSUKIWARI_GEN_ZO_FLG
                ,i_RKDM_FUKA_FLG.GENMEN_ZO_FLG 
                ,i_RKDM_FUKA_FLG.KANENDO_ZO_FLG
                ,i_RKDM_FUKA_FLG.NENZEI_ZO_FLG 
                ,i_RKDM_FUKA_FLG.KEIGEN_4_ZO_FLG 
                ,i_RKDM_FUKA_FLG.KEIGEN_5_ZO_FLG 
                ,i_RKDM_FUKA_FLG.KEIGEN_6_ZO_FLG 
                ,i_RKDM_FUKA_FLG.KEIGEN_7_ZO_FLG 
                ,i_RKDM_FUKA_FLG.KEIGEN_8_ZO_FLG 
                ,i_RKDM_FUKA_FLG.KEIGEN_9_ZO_FLG 
                ,i_RKDM_FUKA_FLG.KEIGEN_10_ZO_FLG
                ,i_RKDM_FUKA_FLG.KEIGEN_11_ZO_FLG
                ,i_RKDM_FUKA_FLG.KEIGEN_12_ZO_FLG
                ,i_RKDM_FUKA_FLG.KEIGEN_1_ZO_FLG 
                ,i_RKDM_FUKA_FLG.KEIGEN_2_ZO_FLG 
                ,i_RKDM_FUKA_FLG.KEIGEN_3_ZO_FLG 
                ,i_RKDM_FUKA_FLG.KINTO_GEN_FLG 
                ,i_RKDM_FUKA_FLG.KAHYO_GEN_FLG 
                ,i_RKDM_FUKA_FLG.SHOTOKU_WARI_GEN_FLG
                ,i_RKDM_FUKA_FLG.SHISANZEI_GEN_FLG 
                ,i_RKDM_FUKA_FLG.SHISAN_WARI_GEN_FLG 
                ,i_RKDM_FUKA_FLG.KINTO_WARI_GEN_FLG
                ,i_RKDM_FUKA_FLG.BYODO_WARI_GEN_FLG
                ,i_RKDM_FUKA_FLG.SEKISAN_GEN_FLG 
                ,i_RKDM_FUKA_FLG.GENDO_CHOKA_GEN_FLG 
                ,i_RKDM_FUKA_FLG.KEIGEN_K_WARI_GEN_FLG 
                ,i_RKDM_FUKA_FLG.KEIGEN_B_WARI_GEN_FLG 
                ,i_RKDM_FUKA_FLG.TSUKIWARI_GEN_GEN_FLG 
                ,i_RKDM_FUKA_FLG.GENMEN_GEN_FLG
                ,i_RKDM_FUKA_FLG.KANENDO_GEN_FLG 
                ,i_RKDM_FUKA_FLG.NENZEI_GEN_FLG
                ,i_RKDM_FUKA_FLG.KEIGEN_4_GEN_FLG
                ,i_RKDM_FUKA_FLG.KEIGEN_5_GEN_FLG
                ,i_RKDM_FUKA_FLG.KEIGEN_6_GEN_FLG
                ,i_RKDM_FUKA_FLG.KEIGEN_7_GEN_FLG
                ,i_RKDM_FUKA_FLG.KEIGEN_8_GEN_FLG
                ,i_RKDM_FUKA_FLG.KEIGEN_9_GEN_FLG
                ,i_RKDM_FUKA_FLG.KEIGEN_10_GEN_FLG 
                ,i_RKDM_FUKA_FLG.KEIGEN_11_GEN_FLG 
                ,i_RKDM_FUKA_FLG.KEIGEN_12_GEN_FLG 
                ,i_RKDM_FUKA_FLG.KEIGEN_1_GEN_FLG
                ,i_RKDM_FUKA_FLG.KEIGEN_2_GEN_FLG
                ,i_RKDM_FUKA_FLG.KEIGEN_3_GEN_FLG
                ,i_RKDM_KIHON_CAL.KINTO_CNT_KDM18
                ,i_RKDM_KIHON_N.KINTO_CNT_KDM18
                ,i_RKDM_FUKA_FLG.KINTO_KDM18_ZO_FLG
                ,i_RKDM_FUKA_FLG.KINTO_KDM18_GEN_FLG
--2025/08/11 ZCZL.LIUDI ADD END
                );

    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      VMSG := '賦課状況の中間ワーク情報作成でエラーが発生しました（FUNC_GETFUKAJOKYO）';
      VMSG := VMSG || '年度分：' || NK_NENDO_BUN || '　国保世帯番号：' || NK_KOKU_SETAI_NO;
      VMSG := VMSG || '　算定団体コード：' || NK_SANTEIDANTAI_CD || '　世帯主宛名番号：' || NK_NUSHI_KOJIN_NO;
      VMSG := VMSG || '　SQLエラー：' || SQLERRM;
      PROCLOGOUT(1,VMSG);
      RETURN 1;
  END FUNC_INSERT_WK_FUKAJOKYO;
-------------------------------------------------------------------------------------
--  各種計算基本、賦課基本の各項目比較し、増フラグ、減フラグ、共通増フラグ、共通減フラグ設定
-------------------------------------------------------------------------------------
  PROCEDURE PROC_SETJOKYO_ZOGEN_FLG(i_RKIHON_CAL           IN  KEIKIRECORD,
                                    i_RSIEN_KIHON_CAL      IN  KEIKIRECORD,
--2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                                    i_RKDM_KIHON_CAL       IN  KEIKIRECORD_KDM,
                                    i_RKAI_KIHON_CAL       IN  KEIKIRECORD,
                                    i_RKIHON_N             IN  KEIKIRECORD,
                                    i_RSIEN_KIHON_N        IN  KEIKIRECORD,
--2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                                    i_RKDM_KIHON_N         IN  KEIKIRECORD_KDM,
                                    i_RKAI_KIHON_N         IN  KEIKIRECORD,
                                    o_RKIHON_ZOGENFLG      OUT JOKYO_ZOGENFLG_RECORD,
                                    o_RSIEN_KIHON_ZOGENFLG OUT JOKYO_ZOGENFLG_RECORD,
--2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                                    o_RKDM_FUKA_FLG        OUT JOKYO_ZOGENFLG_RECORD_KDM,
                                    o_RKAI_KIHON_ZOGENFLG  OUT JOKYO_ZOGENFLG_RECORD,
                                    o_NJOKYO_ZO_FLG        OUT NUMBER,
                                    o_NJOKYO_GEN_FLG       OUT NUMBER)
  IS
  BEGIN
    --共通増フラグ、共通減フラグを初期化
    NKYOTSU_ZO_FLG := 0;
    NKYOTSU_GEN_FLG := 0;

    --基本 増フラグ（計算基本 ＞ 賦課基本の場合、増フラグ）
    o_RKIHON_ZOGENFLG.KINTO_ZO_FLG         := FUNC_COMPARE_ZO(i_RKIHON_CAL.KINTO_CNT, i_RKIHON_N.KINTO_CNT);
    o_RKIHON_ZOGENFLG.KAHYO_ZO_FLG         := FUNC_COMPARE_ZO(i_RKIHON_CAL.KAHYO, i_RKIHON_N.KAHYO);
    o_RKIHON_ZOGENFLG.SHOTOKU_WARI_ZO_FLG  := FUNC_COMPARE_ZO(i_RKIHON_CAL.SHOTOKU_WARI, i_RKIHON_N.SHOTOKU_WARI);
    o_RKIHON_ZOGENFLG.SHISANZEI_ZO_FLG     := FUNC_COMPARE_ZO(i_RKIHON_CAL.SHISANZEI, i_RKIHON_N.SHISANZEI);
    o_RKIHON_ZOGENFLG.SHISAN_WARI_ZO_FLG   := FUNC_COMPARE_ZO(i_RKIHON_CAL.SHISAN_WARI, i_RKIHON_N.SHISAN_WARI);
    o_RKIHON_ZOGENFLG.KINTO_WARI_ZO_FLG    := FUNC_COMPARE_ZO(i_RKIHON_CAL.KINTO_WARI, i_RKIHON_N.KINTO_WARI);
    o_RKIHON_ZOGENFLG.BYODO_WARI_ZO_FLG    := FUNC_COMPARE_ZO(i_RKIHON_CAL.BYODO_WARI, i_RKIHON_N.BYODO_WARI);
    o_RKIHON_ZOGENFLG.SEKISAN_ZO_FLG       := FUNC_COMPARE_ZO(i_RKIHON_CAL.SEKISAN, i_RKIHON_N.SEKISAN);
    o_RKIHON_ZOGENFLG.GENDO_CHOKA_ZO_FLG   := FUNC_COMPARE_ZO(i_RKIHON_CAL.GENDO_CHOKA, i_RKIHON_N.GENDO_CHOKA);
    o_RKIHON_ZOGENFLG.KEIGEN_K_WARI_ZO_FLG := FUNC_COMPARE_ZO2(i_RKIHON_CAL.KEIGEN_K_WARI, i_RKIHON_N.KEIGEN_K_WARI);
    o_RKIHON_ZOGENFLG.KEIGEN_B_WARI_ZO_FLG := FUNC_COMPARE_ZO2(i_RKIHON_CAL.KEIGEN_B_WARI, i_RKIHON_N.KEIGEN_B_WARI);
    o_RKIHON_ZOGENFLG.TSUKIWARI_GEN_ZO_FLG := FUNC_COMPARE_ZO2(i_RKIHON_CAL.TSUKIWARI_GEN, i_RKIHON_N.TSUKIWARI_GEN);
    o_RKIHON_ZOGENFLG.GENMEN_ZO_FLG        := FUNC_COMPARE_ZO2(i_RKIHON_CAL.GENMEN, i_RKIHON_N.GENMEN);
    o_RKIHON_ZOGENFLG.KANENDO_ZO_FLG       := FUNC_COMPARE_ZO2(i_RKIHON_CAL.KANENDO, i_RKIHON_N.KANENDO);
    o_RKIHON_ZOGENFLG.NENZEI_ZO_FLG        := FUNC_COMPARE_ZO(i_RKIHON_CAL.NENZEI, i_RKIHON_N.NENZEI);
    o_RKIHON_ZOGENFLG.KEIGEN_4_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKIHON_CAL.KEIGEN_4, i_RKIHON_N.KEIGEN_4);
    o_RKIHON_ZOGENFLG.KEIGEN_5_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKIHON_CAL.KEIGEN_5, i_RKIHON_N.KEIGEN_5);
    o_RKIHON_ZOGENFLG.KEIGEN_6_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKIHON_CAL.KEIGEN_6, i_RKIHON_N.KEIGEN_6);
    o_RKIHON_ZOGENFLG.KEIGEN_7_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKIHON_CAL.KEIGEN_7, i_RKIHON_N.KEIGEN_7);
    o_RKIHON_ZOGENFLG.KEIGEN_8_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKIHON_CAL.KEIGEN_8, i_RKIHON_N.KEIGEN_8);
    o_RKIHON_ZOGENFLG.KEIGEN_9_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKIHON_CAL.KEIGEN_9, i_RKIHON_N.KEIGEN_9);
    o_RKIHON_ZOGENFLG.KEIGEN_10_ZO_FLG     := FUNC_COMPARE_ZO2(i_RKIHON_CAL.KEIGEN_10, i_RKIHON_N.KEIGEN_10);
    o_RKIHON_ZOGENFLG.KEIGEN_11_ZO_FLG     := FUNC_COMPARE_ZO2(i_RKIHON_CAL.KEIGEN_11, i_RKIHON_N.KEIGEN_11);
    o_RKIHON_ZOGENFLG.KEIGEN_12_ZO_FLG     := FUNC_COMPARE_ZO2(i_RKIHON_CAL.KEIGEN_12, i_RKIHON_N.KEIGEN_12);
    o_RKIHON_ZOGENFLG.KEIGEN_1_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKIHON_CAL.KEIGEN_1, i_RKIHON_N.KEIGEN_1);
    o_RKIHON_ZOGENFLG.KEIGEN_2_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKIHON_CAL.KEIGEN_2, i_RKIHON_N.KEIGEN_2);
    o_RKIHON_ZOGENFLG.KEIGEN_3_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKIHON_CAL.KEIGEN_3, i_RKIHON_N.KEIGEN_3);

    --支援基本 増フラグ（計算基本 ＞ 賦課基本の場合、増フラグ）
    o_RSIEN_KIHON_ZOGENFLG.KINTO_ZO_FLG         := FUNC_COMPARE_ZO(i_RSIEN_KIHON_CAL.KINTO_CNT, i_RSIEN_KIHON_N.KINTO_CNT);
    o_RSIEN_KIHON_ZOGENFLG.KAHYO_ZO_FLG         := FUNC_COMPARE_ZO(i_RSIEN_KIHON_CAL.KAHYO, i_RSIEN_KIHON_N.KAHYO);
    o_RSIEN_KIHON_ZOGENFLG.SHOTOKU_WARI_ZO_FLG  := FUNC_COMPARE_ZO(i_RSIEN_KIHON_CAL.SHOTOKU_WARI, i_RSIEN_KIHON_N.SHOTOKU_WARI);
    o_RSIEN_KIHON_ZOGENFLG.SHISANZEI_ZO_FLG     := FUNC_COMPARE_ZO(i_RSIEN_KIHON_CAL.SHISANZEI, i_RSIEN_KIHON_N.SHISANZEI);
    o_RSIEN_KIHON_ZOGENFLG.SHISAN_WARI_ZO_FLG   := FUNC_COMPARE_ZO(i_RSIEN_KIHON_CAL.SHISAN_WARI, i_RSIEN_KIHON_N.SHISAN_WARI);
    o_RSIEN_KIHON_ZOGENFLG.KINTO_WARI_ZO_FLG    := FUNC_COMPARE_ZO(i_RSIEN_KIHON_CAL.KINTO_WARI, i_RSIEN_KIHON_N.KINTO_WARI);
    o_RSIEN_KIHON_ZOGENFLG.BYODO_WARI_ZO_FLG    := FUNC_COMPARE_ZO(i_RSIEN_KIHON_CAL.BYODO_WARI, i_RSIEN_KIHON_N.BYODO_WARI);
    o_RSIEN_KIHON_ZOGENFLG.SEKISAN_ZO_FLG       := FUNC_COMPARE_ZO(i_RSIEN_KIHON_CAL.SEKISAN, i_RSIEN_KIHON_N.SEKISAN);
    o_RSIEN_KIHON_ZOGENFLG.GENDO_CHOKA_ZO_FLG   := FUNC_COMPARE_ZO(i_RSIEN_KIHON_CAL.GENDO_CHOKA, i_RSIEN_KIHON_N.GENDO_CHOKA);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_K_WARI_ZO_FLG := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.KEIGEN_K_WARI, i_RSIEN_KIHON_N.KEIGEN_K_WARI);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_B_WARI_ZO_FLG := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.KEIGEN_B_WARI, i_RSIEN_KIHON_N.KEIGEN_B_WARI);
    o_RSIEN_KIHON_ZOGENFLG.TSUKIWARI_GEN_ZO_FLG := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.TSUKIWARI_GEN, i_RSIEN_KIHON_N.TSUKIWARI_GEN);
    o_RSIEN_KIHON_ZOGENFLG.GENMEN_ZO_FLG        := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.GENMEN, i_RSIEN_KIHON_N.GENMEN);
    o_RSIEN_KIHON_ZOGENFLG.KANENDO_ZO_FLG       := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.KANENDO, i_RSIEN_KIHON_N.KANENDO);

    o_RSIEN_KIHON_ZOGENFLG.NENZEI_ZO_FLG        := FUNC_COMPARE_ZO(i_RSIEN_KIHON_CAL.NENZEI, i_RSIEN_KIHON_N.NENZEI);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_4_ZO_FLG      := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.KEIGEN_4, i_RSIEN_KIHON_N.KEIGEN_4);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_5_ZO_FLG      := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.KEIGEN_5, i_RSIEN_KIHON_N.KEIGEN_5);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_6_ZO_FLG      := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.KEIGEN_6, i_RSIEN_KIHON_N.KEIGEN_6);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_7_ZO_FLG      := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.KEIGEN_7, i_RSIEN_KIHON_N.KEIGEN_7);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_8_ZO_FLG      := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.KEIGEN_8, i_RSIEN_KIHON_N.KEIGEN_8);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_9_ZO_FLG      := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.KEIGEN_9, i_RSIEN_KIHON_N.KEIGEN_9);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_10_ZO_FLG     := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.KEIGEN_10, i_RSIEN_KIHON_N.KEIGEN_10);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_11_ZO_FLG     := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.KEIGEN_11, i_RSIEN_KIHON_N.KEIGEN_11);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_12_ZO_FLG     := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.KEIGEN_12, i_RSIEN_KIHON_N.KEIGEN_12);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_1_ZO_FLG      := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.KEIGEN_1, i_RSIEN_KIHON_N.KEIGEN_1);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_2_ZO_FLG      := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.KEIGEN_2, i_RSIEN_KIHON_N.KEIGEN_2);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_3_ZO_FLG      := FUNC_COMPARE_ZO2(i_RSIEN_KIHON_CAL.KEIGEN_3, i_RSIEN_KIHON_N.KEIGEN_3);
--2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
    --子ども基本 増フラグ（計算基本 ＞ 賦課基本の場合、増フラグ）
    o_RKDM_FUKA_FLG.KINTO_ZO_FLG                := FUNC_COMPARE_ZO(i_RKDM_KIHON_CAL.KINTO_CNT, i_RKDM_KIHON_N.KINTO_CNT);
    o_RKDM_FUKA_FLG.KAHYO_ZO_FLG                := FUNC_COMPARE_ZO(i_RKDM_KIHON_CAL.KAHYO, i_RKDM_KIHON_N.KAHYO);
    o_RKDM_FUKA_FLG.SHOTOKU_WARI_ZO_FLG         := FUNC_COMPARE_ZO(i_RKDM_KIHON_CAL.SHOTOKU_WARI, i_RKDM_KIHON_N.SHOTOKU_WARI);
    o_RKDM_FUKA_FLG.SHISANZEI_ZO_FLG            := FUNC_COMPARE_ZO(i_RKDM_KIHON_CAL.SHISANZEI, i_RKDM_KIHON_N.SHISANZEI);
    o_RKDM_FUKA_FLG.SHISAN_WARI_ZO_FLG          := FUNC_COMPARE_ZO(i_RKDM_KIHON_CAL.SHISAN_WARI, i_RKDM_KIHON_N.SHISAN_WARI);
    o_RKDM_FUKA_FLG.KINTO_WARI_ZO_FLG           := FUNC_COMPARE_ZO(i_RKDM_KIHON_CAL.KINTO_WARI, i_RKDM_KIHON_N.KINTO_WARI);
    o_RKDM_FUKA_FLG.BYODO_WARI_ZO_FLG           := FUNC_COMPARE_ZO(i_RKDM_KIHON_CAL.BYODO_WARI, i_RKDM_KIHON_N.BYODO_WARI);
    o_RKDM_FUKA_FLG.SEKISAN_ZO_FLG              := FUNC_COMPARE_ZO(i_RKDM_KIHON_CAL.SEKISAN, i_RKDM_KIHON_N.SEKISAN);
    o_RKDM_FUKA_FLG.GENDO_CHOKA_ZO_FLG          := FUNC_COMPARE_ZO(i_RKDM_KIHON_CAL.GENDO_CHOKA, i_RKDM_KIHON_N.GENDO_CHOKA);
    o_RKDM_FUKA_FLG.KEIGEN_K_WARI_ZO_FLG        := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.KEIGEN_K_WARI, i_RKDM_KIHON_N.KEIGEN_K_WARI);
    o_RKDM_FUKA_FLG.KEIGEN_B_WARI_ZO_FLG        := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.KEIGEN_B_WARI, i_RKDM_KIHON_N.KEIGEN_B_WARI);
    o_RKDM_FUKA_FLG.TSUKIWARI_GEN_ZO_FLG        := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.TSUKIWARI_GEN, i_RKDM_KIHON_N.TSUKIWARI_GEN);
    o_RKDM_FUKA_FLG.GENMEN_ZO_FLG               := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.GENMEN, i_RKDM_KIHON_N.GENMEN);
    o_RKDM_FUKA_FLG.KANENDO_ZO_FLG              := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.KANENDO, i_RKDM_KIHON_N.KANENDO);
    o_RKDM_FUKA_FLG.NENZEI_ZO_FLG               := FUNC_COMPARE_ZO(i_RKDM_KIHON_CAL.NENZEI, i_RKDM_KIHON_N.NENZEI);
    o_RKDM_FUKA_FLG.KEIGEN_4_ZO_FLG             := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.KEIGEN_4, i_RKDM_KIHON_N.KEIGEN_4);
    o_RKDM_FUKA_FLG.KEIGEN_5_ZO_FLG             := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.KEIGEN_5, i_RKDM_KIHON_N.KEIGEN_5);
    o_RKDM_FUKA_FLG.KEIGEN_6_ZO_FLG             := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.KEIGEN_6, i_RKDM_KIHON_N.KEIGEN_6);
    o_RKDM_FUKA_FLG.KEIGEN_7_ZO_FLG             := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.KEIGEN_7, i_RKDM_KIHON_N.KEIGEN_7);
    o_RKDM_FUKA_FLG.KEIGEN_8_ZO_FLG             := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.KEIGEN_8, i_RKDM_KIHON_N.KEIGEN_8);
    o_RKDM_FUKA_FLG.KEIGEN_9_ZO_FLG             := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.KEIGEN_9, i_RKDM_KIHON_N.KEIGEN_9);
    o_RKDM_FUKA_FLG.KEIGEN_10_ZO_FLG            := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.KEIGEN_10, i_RKDM_KIHON_N.KEIGEN_10);
    o_RKDM_FUKA_FLG.KEIGEN_11_ZO_FLG            := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.KEIGEN_11, i_RKDM_KIHON_N.KEIGEN_11);
    o_RKDM_FUKA_FLG.KEIGEN_12_ZO_FLG            := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.KEIGEN_12, i_RKDM_KIHON_N.KEIGEN_12);
    o_RKDM_FUKA_FLG.KEIGEN_1_ZO_FLG             := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.KEIGEN_1, i_RKDM_KIHON_N.KEIGEN_1);
    o_RKDM_FUKA_FLG.KEIGEN_2_ZO_FLG             := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.KEIGEN_2, i_RKDM_KIHON_N.KEIGEN_2);
    o_RKDM_FUKA_FLG.KEIGEN_3_ZO_FLG             := FUNC_COMPARE_ZO2(i_RKDM_KIHON_CAL.KEIGEN_3, i_RKDM_KIHON_N.KEIGEN_3);
    o_RKDM_FUKA_FLG.KINTO_KDM18_ZO_FLG          := FUNC_COMPARE_ZO(i_RKDM_KIHON_CAL.KINTO_CNT_KDM18, i_RKDM_KIHON_N.KINTO_CNT_KDM18);
--2025/08/11 ZCZL.LIUDI ADD END
    --介護基本 増フラグ（計算基本 ＞ 賦課基本の場合、増フラグ）
    o_RKAI_KIHON_ZOGENFLG.KINTO_ZO_FLG         := FUNC_COMPARE_ZO(i_RKAI_KIHON_CAL.KINTO_CNT, i_RKAI_KIHON_N.KINTO_CNT);
    o_RKAI_KIHON_ZOGENFLG.KAHYO_ZO_FLG         := FUNC_COMPARE_ZO(i_RKAI_KIHON_CAL.KAHYO, i_RKAI_KIHON_N.KAHYO);
    o_RKAI_KIHON_ZOGENFLG.SHOTOKU_WARI_ZO_FLG  := FUNC_COMPARE_ZO(i_RKAI_KIHON_CAL.SHOTOKU_WARI, i_RKAI_KIHON_N.SHOTOKU_WARI);
    o_RKAI_KIHON_ZOGENFLG.SHISANZEI_ZO_FLG     := FUNC_COMPARE_ZO(i_RKAI_KIHON_CAL.SHISANZEI, i_RKAI_KIHON_N.SHISANZEI);
    o_RKAI_KIHON_ZOGENFLG.SHISAN_WARI_ZO_FLG   := FUNC_COMPARE_ZO(i_RKAI_KIHON_CAL.SHISAN_WARI, i_RKAI_KIHON_N.SHISAN_WARI);
    o_RKAI_KIHON_ZOGENFLG.KINTO_WARI_ZO_FLG    := FUNC_COMPARE_ZO(i_RKAI_KIHON_CAL.KINTO_WARI, i_RKAI_KIHON_N.KINTO_WARI);
    o_RKAI_KIHON_ZOGENFLG.BYODO_WARI_ZO_FLG    := FUNC_COMPARE_ZO(i_RKAI_KIHON_CAL.BYODO_WARI, i_RKAI_KIHON_N.BYODO_WARI);
    o_RKAI_KIHON_ZOGENFLG.SEKISAN_ZO_FLG       := FUNC_COMPARE_ZO(i_RKAI_KIHON_CAL.SEKISAN, i_RKAI_KIHON_N.SEKISAN);
    o_RKAI_KIHON_ZOGENFLG.GENDO_CHOKA_ZO_FLG   := FUNC_COMPARE_ZO(i_RKAI_KIHON_CAL.GENDO_CHOKA, i_RKAI_KIHON_N.GENDO_CHOKA);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_K_WARI_ZO_FLG := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.KEIGEN_K_WARI, i_RKAI_KIHON_N.KEIGEN_K_WARI);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_B_WARI_ZO_FLG := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.KEIGEN_B_WARI, i_RKAI_KIHON_N.KEIGEN_B_WARI);
    o_RKAI_KIHON_ZOGENFLG.TSUKIWARI_GEN_ZO_FLG := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.TSUKIWARI_GEN, i_RKAI_KIHON_N.TSUKIWARI_GEN);
    o_RKAI_KIHON_ZOGENFLG.GENMEN_ZO_FLG        := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.GENMEN, i_RKAI_KIHON_N.GENMEN);
    o_RKAI_KIHON_ZOGENFLG.KANENDO_ZO_FLG       := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.KANENDO, i_RKAI_KIHON_N.KANENDO);
    o_RKAI_KIHON_ZOGENFLG.NENZEI_ZO_FLG        := FUNC_COMPARE_ZO(i_RKAI_KIHON_CAL.NENZEI, i_RKAI_KIHON_N.NENZEI);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_4_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.KEIGEN_4, i_RKAI_KIHON_N.KEIGEN_4);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_5_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.KEIGEN_5, i_RKAI_KIHON_N.KEIGEN_5);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_6_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.KEIGEN_6, i_RKAI_KIHON_N.KEIGEN_6);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_7_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.KEIGEN_7, i_RKAI_KIHON_N.KEIGEN_7);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_8_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.KEIGEN_8, i_RKAI_KIHON_N.KEIGEN_8);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_9_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.KEIGEN_9, i_RKAI_KIHON_N.KEIGEN_9);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_10_ZO_FLG     := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.KEIGEN_10, i_RKAI_KIHON_N.KEIGEN_10);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_11_ZO_FLG     := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.KEIGEN_11, i_RKAI_KIHON_N.KEIGEN_11);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_12_ZO_FLG     := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.KEIGEN_12, i_RKAI_KIHON_N.KEIGEN_12);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_1_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.KEIGEN_1, i_RKAI_KIHON_N.KEIGEN_1);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_2_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.KEIGEN_2, i_RKAI_KIHON_N.KEIGEN_2);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_3_ZO_FLG      := FUNC_COMPARE_ZO2(i_RKAI_KIHON_CAL.KEIGEN_3, i_RKAI_KIHON_N.KEIGEN_3);
    --基本 減フラグ（計算基本 ＜ 賦課基本の場合、減フラグ）
    o_RKIHON_ZOGENFLG.KINTO_GEN_FLG         := FUNC_COMPARE_GEN(i_RKIHON_CAL.KINTO_CNT, i_RKIHON_N.KINTO_CNT);
    o_RKIHON_ZOGENFLG.KAHYO_GEN_FLG         := FUNC_COMPARE_GEN(i_RKIHON_CAL.KAHYO, i_RKIHON_N.KAHYO);
    o_RKIHON_ZOGENFLG.SHOTOKU_WARI_GEN_FLG  := FUNC_COMPARE_GEN(i_RKIHON_CAL.SHOTOKU_WARI, i_RKIHON_N.SHOTOKU_WARI);
    o_RKIHON_ZOGENFLG.SHISANZEI_GEN_FLG     := FUNC_COMPARE_GEN(i_RKIHON_CAL.SHISANZEI, i_RKIHON_N.SHISANZEI);
    o_RKIHON_ZOGENFLG.SHISAN_WARI_GEN_FLG   := FUNC_COMPARE_GEN(i_RKIHON_CAL.SHISAN_WARI, i_RKIHON_N.SHISAN_WARI);
    o_RKIHON_ZOGENFLG.KINTO_WARI_GEN_FLG    := FUNC_COMPARE_GEN(i_RKIHON_CAL.KINTO_WARI, i_RKIHON_N.KINTO_WARI);
    o_RKIHON_ZOGENFLG.BYODO_WARI_GEN_FLG    := FUNC_COMPARE_GEN(i_RKIHON_CAL.BYODO_WARI, i_RKIHON_N.BYODO_WARI);
    o_RKIHON_ZOGENFLG.SEKISAN_GEN_FLG       := FUNC_COMPARE_GEN(i_RKIHON_CAL.SEKISAN, i_RKIHON_N.SEKISAN);
    o_RKIHON_ZOGENFLG.GENDO_CHOKA_GEN_FLG   := FUNC_COMPARE_GEN(i_RKIHON_CAL.GENDO_CHOKA, i_RKIHON_N.GENDO_CHOKA);
    o_RKIHON_ZOGENFLG.KEIGEN_K_WARI_GEN_FLG := FUNC_COMPARE_GEN2(i_RKIHON_CAL.KEIGEN_K_WARI, i_RKIHON_N.KEIGEN_K_WARI);
    o_RKIHON_ZOGENFLG.KEIGEN_B_WARI_GEN_FLG := FUNC_COMPARE_GEN2(i_RKIHON_CAL.KEIGEN_B_WARI, i_RKIHON_N.KEIGEN_B_WARI);
    o_RKIHON_ZOGENFLG.TSUKIWARI_GEN_GEN_FLG := FUNC_COMPARE_GEN2(i_RKIHON_CAL.TSUKIWARI_GEN, i_RKIHON_N.TSUKIWARI_GEN);
    o_RKIHON_ZOGENFLG.GENMEN_GEN_FLG        := FUNC_COMPARE_GEN2(i_RKIHON_CAL.GENMEN, i_RKIHON_N.GENMEN);
    o_RKIHON_ZOGENFLG.KANENDO_GEN_FLG       := FUNC_COMPARE_GEN2(i_RKIHON_CAL.KANENDO, i_RKIHON_N.KANENDO);
    o_RKIHON_ZOGENFLG.NENZEI_GEN_FLG        := FUNC_COMPARE_GEN(i_RKIHON_CAL.NENZEI, i_RKIHON_N.NENZEI);
    o_RKIHON_ZOGENFLG.KEIGEN_4_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKIHON_CAL.KEIGEN_4, i_RKIHON_N.KEIGEN_4);
    o_RKIHON_ZOGENFLG.KEIGEN_5_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKIHON_CAL.KEIGEN_5, i_RKIHON_N.KEIGEN_5);
    o_RKIHON_ZOGENFLG.KEIGEN_6_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKIHON_CAL.KEIGEN_6, i_RKIHON_N.KEIGEN_6);
    o_RKIHON_ZOGENFLG.KEIGEN_7_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKIHON_CAL.KEIGEN_7, i_RKIHON_N.KEIGEN_7);
    o_RKIHON_ZOGENFLG.KEIGEN_8_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKIHON_CAL.KEIGEN_8, i_RKIHON_N.KEIGEN_8);
    o_RKIHON_ZOGENFLG.KEIGEN_9_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKIHON_CAL.KEIGEN_9, i_RKIHON_N.KEIGEN_9);
    o_RKIHON_ZOGENFLG.KEIGEN_10_GEN_FLG     := FUNC_COMPARE_GEN2(i_RKIHON_CAL.KEIGEN_10, i_RKIHON_N.KEIGEN_10);
    o_RKIHON_ZOGENFLG.KEIGEN_11_GEN_FLG     := FUNC_COMPARE_GEN2(i_RKIHON_CAL.KEIGEN_11, i_RKIHON_N.KEIGEN_11);
    o_RKIHON_ZOGENFLG.KEIGEN_12_GEN_FLG     := FUNC_COMPARE_GEN2(i_RKIHON_CAL.KEIGEN_12, i_RKIHON_N.KEIGEN_12);
    o_RKIHON_ZOGENFLG.KEIGEN_1_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKIHON_CAL.KEIGEN_1, i_RKIHON_N.KEIGEN_1);
    o_RKIHON_ZOGENFLG.KEIGEN_2_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKIHON_CAL.KEIGEN_2, i_RKIHON_N.KEIGEN_2);
    o_RKIHON_ZOGENFLG.KEIGEN_3_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKIHON_CAL.KEIGEN_3, i_RKIHON_N.KEIGEN_3);
    --支援基本 減フラグ（計算基本 ＜ 賦課基本の場合、減フラグ）
    o_RSIEN_KIHON_ZOGENFLG.KINTO_GEN_FLG         := FUNC_COMPARE_GEN(i_RSIEN_KIHON_CAL.KINTO_CNT, i_RSIEN_KIHON_N.KINTO_CNT);
    o_RSIEN_KIHON_ZOGENFLG.KAHYO_GEN_FLG         := FUNC_COMPARE_GEN(i_RSIEN_KIHON_CAL.KAHYO, i_RSIEN_KIHON_N.KAHYO);
    o_RSIEN_KIHON_ZOGENFLG.SHOTOKU_WARI_GEN_FLG  := FUNC_COMPARE_GEN(i_RSIEN_KIHON_CAL.SHOTOKU_WARI, i_RSIEN_KIHON_N.SHOTOKU_WARI);
    o_RSIEN_KIHON_ZOGENFLG.SHISANZEI_GEN_FLG     := FUNC_COMPARE_GEN(i_RSIEN_KIHON_CAL.SHISANZEI, i_RSIEN_KIHON_N.SHISANZEI);
    o_RSIEN_KIHON_ZOGENFLG.SHISAN_WARI_GEN_FLG   := FUNC_COMPARE_GEN(i_RSIEN_KIHON_CAL.SHISAN_WARI, i_RSIEN_KIHON_N.SHISAN_WARI);
    o_RSIEN_KIHON_ZOGENFLG.KINTO_WARI_GEN_FLG    := FUNC_COMPARE_GEN(i_RSIEN_KIHON_CAL.KINTO_WARI, i_RSIEN_KIHON_N.KINTO_WARI);
    o_RSIEN_KIHON_ZOGENFLG.BYODO_WARI_GEN_FLG    := FUNC_COMPARE_GEN(i_RSIEN_KIHON_CAL.BYODO_WARI, i_RSIEN_KIHON_N.BYODO_WARI);
    o_RSIEN_KIHON_ZOGENFLG.SEKISAN_GEN_FLG       := FUNC_COMPARE_GEN(i_RSIEN_KIHON_CAL.SEKISAN, i_RSIEN_KIHON_N.SEKISAN);
    o_RSIEN_KIHON_ZOGENFLG.GENDO_CHOKA_GEN_FLG   := FUNC_COMPARE_GEN(i_RSIEN_KIHON_CAL.GENDO_CHOKA, i_RSIEN_KIHON_N.GENDO_CHOKA);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_K_WARI_GEN_FLG := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.KEIGEN_K_WARI, i_RSIEN_KIHON_N.KEIGEN_K_WARI);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_B_WARI_GEN_FLG := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.KEIGEN_B_WARI, i_RSIEN_KIHON_N.KEIGEN_B_WARI);
    o_RSIEN_KIHON_ZOGENFLG.TSUKIWARI_GEN_GEN_FLG := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.TSUKIWARI_GEN, i_RSIEN_KIHON_N.TSUKIWARI_GEN);
    o_RSIEN_KIHON_ZOGENFLG.GENMEN_GEN_FLG        := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.GENMEN, i_RSIEN_KIHON_N.GENMEN);
    o_RSIEN_KIHON_ZOGENFLG.KANENDO_GEN_FLG       := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.KANENDO, i_RSIEN_KIHON_N.KANENDO);
    o_RSIEN_KIHON_ZOGENFLG.NENZEI_GEN_FLG        := FUNC_COMPARE_GEN(i_RSIEN_KIHON_CAL.NENZEI, i_RSIEN_KIHON_N.NENZEI);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_4_GEN_FLG      := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.KEIGEN_4, i_RSIEN_KIHON_N.KEIGEN_4);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_5_GEN_FLG      := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.KEIGEN_5, i_RSIEN_KIHON_N.KEIGEN_5);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_6_GEN_FLG      := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.KEIGEN_6, i_RSIEN_KIHON_N.KEIGEN_6);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_7_GEN_FLG      := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.KEIGEN_7, i_RSIEN_KIHON_N.KEIGEN_7);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_8_GEN_FLG      := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.KEIGEN_8, i_RSIEN_KIHON_N.KEIGEN_8);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_9_GEN_FLG      := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.KEIGEN_9, i_RSIEN_KIHON_N.KEIGEN_9);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_10_GEN_FLG     := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.KEIGEN_10, i_RSIEN_KIHON_N.KEIGEN_10);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_11_GEN_FLG     := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.KEIGEN_11, i_RSIEN_KIHON_N.KEIGEN_11);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_12_GEN_FLG     := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.KEIGEN_12, i_RSIEN_KIHON_N.KEIGEN_12);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_1_GEN_FLG      := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.KEIGEN_1, i_RSIEN_KIHON_N.KEIGEN_1);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_2_GEN_FLG      := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.KEIGEN_2, i_RSIEN_KIHON_N.KEIGEN_2);
    o_RSIEN_KIHON_ZOGENFLG.KEIGEN_3_GEN_FLG      := FUNC_COMPARE_GEN2(i_RSIEN_KIHON_CAL.KEIGEN_3, i_RSIEN_KIHON_N.KEIGEN_3);
--2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
    --子ども基本 減フラグ（計算基本 ＜ 賦課基本の場合、減フラグ）
    o_RKDM_FUKA_FLG.KINTO_GEN_FLG               := FUNC_COMPARE_GEN(i_RKDM_KIHON_CAL.KINTO_CNT, i_RKDM_KIHON_N.KINTO_CNT);
    o_RKDM_FUKA_FLG.KAHYO_GEN_FLG               := FUNC_COMPARE_GEN(i_RKDM_KIHON_CAL.KAHYO, i_RKDM_KIHON_N.KAHYO);
    o_RKDM_FUKA_FLG.SHOTOKU_WARI_GEN_FLG        := FUNC_COMPARE_GEN(i_RKDM_KIHON_CAL.SHOTOKU_WARI, i_RKDM_KIHON_N.SHOTOKU_WARI);
    o_RKDM_FUKA_FLG.SHISANZEI_GEN_FLG           := FUNC_COMPARE_GEN(i_RKDM_KIHON_CAL.SHISANZEI, i_RKDM_KIHON_N.SHISANZEI);
    o_RKDM_FUKA_FLG.SHISAN_WARI_GEN_FLG         := FUNC_COMPARE_GEN(i_RKDM_KIHON_CAL.SHISAN_WARI, i_RKDM_KIHON_N.SHISAN_WARI);
    o_RKDM_FUKA_FLG.KINTO_WARI_GEN_FLG          := FUNC_COMPARE_GEN(i_RKDM_KIHON_CAL.KINTO_WARI, i_RKDM_KIHON_N.KINTO_WARI);
    o_RKDM_FUKA_FLG.BYODO_WARI_GEN_FLG          := FUNC_COMPARE_GEN(i_RKDM_KIHON_CAL.BYODO_WARI, i_RKDM_KIHON_N.BYODO_WARI);
    o_RKDM_FUKA_FLG.SEKISAN_GEN_FLG             := FUNC_COMPARE_GEN(i_RKDM_KIHON_CAL.SEKISAN, i_RKDM_KIHON_N.SEKISAN);
    o_RKDM_FUKA_FLG.GENDO_CHOKA_GEN_FLG         := FUNC_COMPARE_GEN(i_RKDM_KIHON_CAL.GENDO_CHOKA, i_RKDM_KIHON_N.GENDO_CHOKA);
    o_RKDM_FUKA_FLG.KEIGEN_K_WARI_GEN_FLG       := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.KEIGEN_K_WARI, i_RKDM_KIHON_N.KEIGEN_K_WARI);
    o_RKDM_FUKA_FLG.KEIGEN_B_WARI_GEN_FLG       := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.KEIGEN_B_WARI, i_RKDM_KIHON_N.KEIGEN_B_WARI);
    o_RKDM_FUKA_FLG.TSUKIWARI_GEN_GEN_FLG       := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.TSUKIWARI_GEN, i_RKDM_KIHON_N.TSUKIWARI_GEN);
    o_RKDM_FUKA_FLG.GENMEN_GEN_FLG              := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.GENMEN, i_RKDM_KIHON_N.GENMEN);
    o_RKDM_FUKA_FLG.KANENDO_GEN_FLG             := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.KANENDO, i_RKDM_KIHON_N.KANENDO);
    o_RKDM_FUKA_FLG.NENZEI_GEN_FLG              := FUNC_COMPARE_GEN(i_RKDM_KIHON_CAL.NENZEI, i_RKDM_KIHON_N.NENZEI);
    o_RKDM_FUKA_FLG.KEIGEN_4_GEN_FLG            := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.KEIGEN_4, i_RKDM_KIHON_N.KEIGEN_4);
    o_RKDM_FUKA_FLG.KEIGEN_5_GEN_FLG            := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.KEIGEN_5, i_RKDM_KIHON_N.KEIGEN_5);
    o_RKDM_FUKA_FLG.KEIGEN_6_GEN_FLG            := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.KEIGEN_6, i_RKDM_KIHON_N.KEIGEN_6);
    o_RKDM_FUKA_FLG.KEIGEN_7_GEN_FLG            := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.KEIGEN_7, i_RKDM_KIHON_N.KEIGEN_7);
    o_RKDM_FUKA_FLG.KEIGEN_8_GEN_FLG            := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.KEIGEN_8, i_RKDM_KIHON_N.KEIGEN_8);
    o_RKDM_FUKA_FLG.KEIGEN_9_GEN_FLG            := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.KEIGEN_9, i_RKDM_KIHON_N.KEIGEN_9);
    o_RKDM_FUKA_FLG.KEIGEN_10_GEN_FLG           := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.KEIGEN_10, i_RKDM_KIHON_N.KEIGEN_10);
    o_RKDM_FUKA_FLG.KEIGEN_11_GEN_FLG           := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.KEIGEN_11, i_RKDM_KIHON_N.KEIGEN_11);
    o_RKDM_FUKA_FLG.KEIGEN_12_GEN_FLG           := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.KEIGEN_12, i_RKDM_KIHON_N.KEIGEN_12);
    o_RKDM_FUKA_FLG.KEIGEN_1_GEN_FLG            := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.KEIGEN_1, i_RKDM_KIHON_N.KEIGEN_1);
    o_RKDM_FUKA_FLG.KEIGEN_2_GEN_FLG            := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.KEIGEN_2, i_RKDM_KIHON_N.KEIGEN_2);
    o_RKDM_FUKA_FLG.KEIGEN_3_GEN_FLG            := FUNC_COMPARE_GEN2(i_RKDM_KIHON_CAL.KEIGEN_3, i_RKDM_KIHON_N.KEIGEN_3);
    o_RKDM_FUKA_FLG.KINTO_KDM18_GEN_FLG         := FUNC_COMPARE_GEN(i_RKDM_KIHON_CAL.KINTO_CNT_KDM18, i_RKDM_KIHON_N.KINTO_CNT_KDM18);
--2025/08/11 ZCZL.LIUDI ADD END
    --介護基本 減フラグ（計算基本 ＜ 賦課基本の場合、減フラグ）
    o_RKAI_KIHON_ZOGENFLG.KINTO_GEN_FLG         := FUNC_COMPARE_GEN(i_RKAI_KIHON_CAL.KINTO_CNT, i_RKAI_KIHON_N.KINTO_CNT);
    o_RKAI_KIHON_ZOGENFLG.KAHYO_GEN_FLG         := FUNC_COMPARE_GEN(i_RKAI_KIHON_CAL.KAHYO, i_RKAI_KIHON_N.KAHYO);
    o_RKAI_KIHON_ZOGENFLG.SHOTOKU_WARI_GEN_FLG  := FUNC_COMPARE_GEN(i_RKAI_KIHON_CAL.SHOTOKU_WARI, i_RKAI_KIHON_N.SHOTOKU_WARI);
    o_RKAI_KIHON_ZOGENFLG.SHISANZEI_GEN_FLG     := FUNC_COMPARE_GEN(i_RKAI_KIHON_CAL.SHISANZEI, i_RKAI_KIHON_N.SHISANZEI);
    o_RKAI_KIHON_ZOGENFLG.SHISAN_WARI_GEN_FLG   := FUNC_COMPARE_GEN(i_RKAI_KIHON_CAL.SHISAN_WARI, i_RKAI_KIHON_N.SHISAN_WARI);
    o_RKAI_KIHON_ZOGENFLG.KINTO_WARI_GEN_FLG    := FUNC_COMPARE_GEN(i_RKAI_KIHON_CAL.KINTO_WARI, i_RKAI_KIHON_N.KINTO_WARI);
    o_RKAI_KIHON_ZOGENFLG.BYODO_WARI_GEN_FLG    := FUNC_COMPARE_GEN(i_RKAI_KIHON_CAL.BYODO_WARI, i_RKAI_KIHON_N.BYODO_WARI);
    o_RKAI_KIHON_ZOGENFLG.SEKISAN_GEN_FLG       := FUNC_COMPARE_GEN(i_RKAI_KIHON_CAL.SEKISAN, i_RKAI_KIHON_N.SEKISAN);
    o_RKAI_KIHON_ZOGENFLG.GENDO_CHOKA_GEN_FLG   := FUNC_COMPARE_GEN(i_RKAI_KIHON_CAL.GENDO_CHOKA, i_RKAI_KIHON_N.GENDO_CHOKA);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_K_WARI_GEN_FLG := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.KEIGEN_K_WARI, i_RKAI_KIHON_N.KEIGEN_K_WARI);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_B_WARI_GEN_FLG := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.KEIGEN_B_WARI, i_RKAI_KIHON_N.KEIGEN_B_WARI);
    o_RKAI_KIHON_ZOGENFLG.TSUKIWARI_GEN_GEN_FLG := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.TSUKIWARI_GEN, i_RKAI_KIHON_N.TSUKIWARI_GEN);
    o_RKAI_KIHON_ZOGENFLG.GENMEN_GEN_FLG        := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.GENMEN, i_RKAI_KIHON_N.GENMEN);
    o_RKAI_KIHON_ZOGENFLG.KANENDO_GEN_FLG       := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.KANENDO, i_RKAI_KIHON_N.KANENDO);
    o_RKAI_KIHON_ZOGENFLG.NENZEI_GEN_FLG        := FUNC_COMPARE_GEN(i_RKAI_KIHON_CAL.NENZEI, i_RKAI_KIHON_N.NENZEI);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_4_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.KEIGEN_4, i_RKAI_KIHON_N.KEIGEN_4);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_5_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.KEIGEN_5, i_RKAI_KIHON_N.KEIGEN_5);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_6_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.KEIGEN_6, i_RKAI_KIHON_N.KEIGEN_6);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_7_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.KEIGEN_7, i_RKAI_KIHON_N.KEIGEN_7);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_8_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.KEIGEN_8, i_RKAI_KIHON_N.KEIGEN_8);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_9_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.KEIGEN_9, i_RKAI_KIHON_N.KEIGEN_9);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_10_GEN_FLG     := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.KEIGEN_10, i_RKAI_KIHON_N.KEIGEN_10);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_11_GEN_FLG     := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.KEIGEN_11, i_RKAI_KIHON_N.KEIGEN_11);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_12_GEN_FLG     := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.KEIGEN_12, i_RKAI_KIHON_N.KEIGEN_12);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_1_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.KEIGEN_1, i_RKAI_KIHON_N.KEIGEN_1);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_2_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.KEIGEN_2, i_RKAI_KIHON_N.KEIGEN_2);
    o_RKAI_KIHON_ZOGENFLG.KEIGEN_3_GEN_FLG      := FUNC_COMPARE_GEN2(i_RKAI_KIHON_CAL.KEIGEN_3, i_RKAI_KIHON_N.KEIGEN_3);

    --共通増フラグ、共通減フラグ
    o_NJOKYO_ZO_FLG := NKYOTSU_ZO_FLG;
    o_NJOKYO_GEN_FLG := NKYOTSU_GEN_FLG;
  END PROC_SETJOKYO_ZOGEN_FLG;
-------------------------------------------------------------------------------------
--  各種賦課基本（賦課基本（最新）、賦課支援基本（最新）、賦課介護基本（最新））情報を抽出するSQL文
-------------------------------------------------------------------------------------
  FUNCTION FUNC_MAKESQL_KIHON(i_NTABLENAME IN NVARCHAR2,
                              i_NKBN       IN NUMBER)
    RETURN VARCHAR2
  IS
    VSQL              VARCHAR2(5000);
  BEGIN
    VSQL := NULL;
    VSQL := VSQL || 'SELECT KOKU_SETAI_NO';   --国保世帯番号
    VSQL := VSQL || '      ,SANTEIDANTAI_CD'; --算定団体コード
    VSQL := VSQL || '      ,CHOTEI_NENDO';    --調定年度
    VSQL := VSQL || '      ,NENDO_BUN';       --年度分
    VSQL := VSQL || '      ,TSUCHI_NO';       --通知書番号
    VSQL := VSQL || '      ,NUSHI_KOJIN_NO';  --世帯主宛名番号
    VSQL := VSQL || '      ,KINTO_CNT';       --均等人員
    VSQL := VSQL || '      ,KAHYO';           --基準総所得
    VSQL := VSQL || '      ,SHOTOKU_WARI';    --所得割額
    VSQL := VSQL || '      ,SHISANZEI';       --資産税額
    VSQL := VSQL || '      ,SHISAN_WARI';     --資産割額
    VSQL := VSQL || '      ,KINTO_WARI';      --均等割額
    VSQL := VSQL || '      ,BYODO_WARI';      --平等割額
    VSQL := VSQL || '      ,SEKISAN';         --積算合計
    VSQL := VSQL || '      ,GENDO_CHOKA';     --限度超過額
    VSQL := VSQL || '      ,KEIGEN_K_WARI';   --軽減均等
    VSQL := VSQL || '      ,KEIGEN_B_WARI';   --軽減平等
    VSQL := VSQL || '      ,TSUKIWARI_GEN';   --月割減額
    VSQL := VSQL || '      ,GENMEN';          --減免額
    VSQL := VSQL || '      ,KANENDO';         --他年度賦課
    VSQL := VSQL || '      ,NENZEI';          --年額
    VSQL := VSQL || '      ,KEIGEN_4';        --軽減4月
    VSQL := VSQL || '      ,KEIGEN_5';        --軽減5月
    VSQL := VSQL || '      ,KEIGEN_6';        --軽減6月
    VSQL := VSQL || '      ,KEIGEN_7';        --軽減7月
    VSQL := VSQL || '      ,KEIGEN_8';        --軽減8月
    VSQL := VSQL || '      ,KEIGEN_9';        --軽減9月
    VSQL := VSQL || '      ,KEIGEN_10';       --軽減10月
    VSQL := VSQL || '      ,KEIGEN_11';       --軽減11月
    VSQL := VSQL || '      ,KEIGEN_12';       --軽減12月
    VSQL := VSQL || '      ,KEIGEN_1';        --軽減1月
    VSQL := VSQL || '      ,KEIGEN_2';        --軽減2月
    VSQL := VSQL || '      ,KEIGEN_3';        --軽減3月
--2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
  IF i_NTABLENAME = 'ZLBTKDM_KIHON_CAL' OR i_NTABLENAME = 'ZLBTKDM_KIHON_N' THEN
    VSQL := VSQL || '      ,KINTO_CNT_KDM18'; --18歳以上均等人員
  END IF;
--2025/08/11 ZCZL.LIUDI ADD END
    VSQL := VSQL ||'   FROM '|| i_NTABLENAME;
    IF i_NKBN = 1 THEN
    VSQL := VSQL ||'  WHERE KOKU_SETAI_NO = '     || NK_KOKU_SETAI_NO;
    VSQL := VSQL ||'    AND SANTEIDANTAI_CD = '   || NK_SANTEIDANTAI_CD;
    VSQL := VSQL ||'    AND CHOTEI_NENDO = '      || NK_CHOTEI_NENDO;
    VSQL := VSQL ||'    AND NENDO_BUN = '         || NK_NENDO_BUN;
    VSQL := VSQL ||'    AND TSUCHI_NO = '         || NK_TSUCHI_NO;
    VSQL := VSQL ||'    AND SYS_TANMATSU_NO = ''' || VK_SYS_TANMATSU_NO || '''';
    ELSE
    VSQL := VSQL ||'  WHERE KOKU_SETAI_NO = '     || FK_KOKU_SETAI_NO;
    VSQL := VSQL ||'    AND SANTEIDANTAI_CD = '   || FK_SANTEIDANTAI_CD;
    VSQL := VSQL ||'    AND CHOTEI_NENDO = '      || FK_CHOTEI_NENDO;
    VSQL := VSQL ||'    AND NENDO_BUN = '         || FK_NENDO_BUN;
    VSQL := VSQL ||'    AND TSUCHI_NO = '         || FK_TSUCHI_NO;
    END IF;

    RETURN VSQL;
  END FUNC_MAKESQL_KIHON;
-------------------------------------------------------------------------------------
--  賦課状況の中間ワーク情報作成処理を実行する
-------------------------------------------------------------------------------------
  FUNCTION FUNC_GETFUKAJOKYO RETURN NUMBER
  IS
    NRTN                     NUMBER;
    VSQL                     VARCHAR2(5000);  --動的SQL文変数

    RKIHON_CAL               KEIKIRECORD;
    RSIEN_KIHON_CAL          KEIKIRECORD;
    RKAI_KIHON_CAL           KEIKIRECORD;
    RKIHON_N                 KEIKIRECORD;
    RSIEN_KIHON_N            KEIKIRECORD;
    RKAI_KIHON_N             KEIKIRECORD;
    RKIHON_ZOGENFLG          JOKYO_ZOGENFLG_RECORD;
    RSIEN_KIHON_ZOGENFLG     JOKYO_ZOGENFLG_RECORD;
    RKAI_KIHON_ZOGENFLG      JOKYO_ZOGENFLG_RECORD;
    NJOKYO_ZO_FLG            NUMBER;
    NJOKYO_GEN_FLG           NUMBER;
--2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
    RKDM_KIHON_CAL               KEIKIRECORD_KDM;
    RKDM_KIHON_N          KEIKIRECORD_KDM;
    RKDM_FUKA_FLG            JOKYO_ZOGENFLG_RECORD_KDM;
--2025/08/11 ZCZL.LIUDI ADD END
  BEGIN
    --計算基本情報を抽出する
    BEGIN
      VSQL := FUNC_MAKESQL_KIHON('ZLBTKIHON_CAL', 1);
      EXECUTE IMMEDIATE VSQL INTO RKIHON_CAL;
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '賦課状況の中間ワーク情報作成でZLBTKIHON_CALの各種項目の取得に失敗しました（FUNC_GETFUKAJOKYO）';
        PROCLOGOUT(1,VMSG);
        RETURN 1;
    END;

    --計算支援基本情報を抽出する
    BEGIN
      VSQL := FUNC_MAKESQL_KIHON('ZLBTSIEN_KIHON_CAL', 1);
      EXECUTE IMMEDIATE VSQL INTO RSIEN_KIHON_CAL;
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '賦課状況の中間ワーク情報作成でZLBTSIEN_KIHON_CALの各種項目の取得に失敗しました（FUNC_GETFUKAJOKYO）';
        PROCLOGOUT(1,VMSG);
        RETURN 1;
    END;
--2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
    --計算子ども基本情報を抽出
    BEGIN
      VSQL := FUNC_MAKESQL_KIHON('ZLBTKDM_KIHON_CAL', 1);
      EXECUTE IMMEDIATE VSQL INTO RKDM_KIHON_CAL;
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '賦課状況の中間ワーク情報作成でZLBTKDM_KIHON_CALの各種項目の取得に失敗しました（FUNC_GETFUKAJOKYO）';
        PROCLOGOUT(1,VMSG);
        RETURN 1;
    END;
--2025/08/11 ZCZL.LIUDI ADD END
    --計算介護基本情報を抽出する
    BEGIN
      VSQL := FUNC_MAKESQL_KIHON('ZLBTKAI_KIHON_CAL', 1);
      EXECUTE IMMEDIATE VSQL INTO RKAI_KIHON_CAL;
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '賦課状況の中間ワーク情報作成でZLBTKAI_KIHON_CALの各種項目の取得に失敗しました（FUNC_GETFUKAJOKYO）';
        PROCLOGOUT(1,VMSG);
        RETURN 1;
    END;

    --賦課基本(最新)情報を抽出する
    BEGIN
      VSQL := FUNC_MAKESQL_KIHON('ZLBTKIHON_N', 0);
      EXECUTE IMMEDIATE VSQL INTO RKIHON_N;
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '賦課状況の中間ワーク情報作成でZLBTKIHON_Nの各種項目の取得に失敗しました（FUNC_GETFUKAJOKYO）';
        PROCLOGOUT(1,VMSG);
        RETURN 1;
    END;

    --賦課支援基本(最新)情報を抽出する
    BEGIN
      VSQL := FUNC_MAKESQL_KIHON('ZLBTSIEN_KIHON_N', 0);
      EXECUTE IMMEDIATE VSQL INTO RSIEN_KIHON_N;
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '賦課状況の中間ワーク情報作成でZLBTSIEN_KIHON_Nの各種項目の取得に失敗しました（FUNC_GETFUKAJOKYO）';
        PROCLOGOUT(1,VMSG);
        RETURN 1;
    END;
--2025/08/11 ZCZL.LIUDI ADD START 1.1.200.000:子ども子育て支援金対応
    --賦課子ども基本(最新)情報を抽出
    BEGIN
      VSQL := FUNC_MAKESQL_KIHON('ZLBTKDM_KIHON_N', 0);
      EXECUTE IMMEDIATE VSQL INTO RKDM_KIHON_N;
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '賦課状況の中間ワーク情報作成でZLBTKDM_KIHON_Nの各種項目の取得に失敗しました（FUNC_GETFUKAJOKYO）';
        PROCLOGOUT(1,VMSG);
        RETURN 1;
    END;
--2025/08/11 ZCZL.LIUDI ADD END
    --賦課介護基本(最新)情報を抽出する
    BEGIN
      VSQL := FUNC_MAKESQL_KIHON('ZLBTKAI_KIHON_N', 0);
      EXECUTE IMMEDIATE VSQL INTO RKAI_KIHON_N;
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '賦課状況の中間ワーク情報作成でZLBTKAI_KIHON_Nの各種項目の取得に失敗しました（FUNC_GETFUKAJOKYO）';
        PROCLOGOUT(1,VMSG);
        RETURN 1;
    END;

    --各種計算基本、各種賦課基本の各項目比較し、増フラグ、減フラグ、共通増フラグ、共通減フラグ設定
    PROC_SETJOKYO_ZOGEN_FLG(RKIHON_CAL,
                            RSIEN_KIHON_CAL,
--2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                            RKDM_KIHON_CAL,
                            RKAI_KIHON_CAL,
                            RKIHON_N,
                            RSIEN_KIHON_N,
--2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                            RKDM_KIHON_N,
                            RKAI_KIHON_N,
                            RKIHON_ZOGENFLG,
                            RSIEN_KIHON_ZOGENFLG,
--2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                            RKDM_FUKA_FLG,
                            RKAI_KIHON_ZOGENFLG,
                            NJOKYO_ZO_FLG,
                            NJOKYO_GEN_FLG);

    --取得した結果を賦課状況比較結果中間ワーク情報に登録する
    NRTN := FUNC_INSERT_WK_FUKAJOKYO(RKIHON_CAL,
                                     RSIEN_KIHON_CAL,
--2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                                     RKDM_KIHON_CAL,
                                     RKAI_KIHON_CAL,
                                     RKIHON_N,
                                     RSIEN_KIHON_N,
--2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                                     RKDM_KIHON_N,
                                     RKAI_KIHON_N,
                                     RKIHON_ZOGENFLG,
                                     RSIEN_KIHON_ZOGENFLG,
--2025/08/11 ZCZL.LIUDI ADD 1.1.200.000:子ども子育て支援金対応
                                     RKDM_FUKA_FLG,
                                     RKAI_KIHON_ZOGENFLG,
                                     NJOKYO_ZO_FLG,
                                     NJOKYO_GEN_FLG);
    IF NRTN <> 0 THEN
      RETURN 1;
    END IF;

    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      VMSG := '賦課状況の中間ワーク情報作成でエラーが発生しました（FUNC_GETFUKAJOKYO）';
      VMSG := VMSG || '年度分：' || NK_NENDO_BUN || '　国保世帯番号：' || NK_KOKU_SETAI_NO;
      VMSG := VMSG || '　算定団体コード：' || NK_SANTEIDANTAI_CD || '　世帯主宛名番号：' || NK_NUSHI_KOJIN_NO;
      VMSG := VMSG || '　SQLエラー：' || SQLERRM;
      PROCLOGOUT(1,VMSG);
      RETURN 1;
  END FUNC_GETFUKAJOKYO;
-------------------------------------------------------------------------------------
--  賦課決定期間の制限対象候補世帯判定処理
-------------------------------------------------------------------------------------
  FUNCTION FUNC_HANTEI_TAISHO RETURN NUMBER
  IS
    NK_CNT                    NUMBER := 0;  --計基_件数
    NF_CNT                    NUMBER := 0;  --賦基_件数
    NS_CNT                    NUMBER := 0;  --制候_件数
    RKIHON_CAL                ZLBTKIHON_CAL%ROWTYPE;
    RKIHON_N                  ZLBTKIHON_N%ROWTYPE;
    NFUKI_KAZEI               NUMBER;      --不均一課税
    NNUSHI_KAZEI              NUMBER;      --主課税条件
    NKAZEI_KBN                NUMBER;      --主課税区分
  BEGIN
    --計算基本テーブルより、年度範囲内の賦課データが存在するか確認する
    BEGIN
      SELECT COUNT(*)
        INTO NK_CNT
        FROM ZLBTKIHON_CAL
       WHERE NENDO_BUN <= (i_NCHOTEI_NENDO - i_NNENDO_HANI)
         AND SYS_TANMATSU_NO = i_VMASIN_NO;
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '制限対象候補世帯の判定でZLBTKIHON_CALの件数取得に失敗しました（FUNC_HANTEI_TAISHO）';
        PROCLOGOUT(1,VMSG);
        RETURN 1;
    END;

    --計基_件数 ＞０ 以外の場合
    IF NK_CNT = 0 THEN
      RETURN 9;
    END IF;

    --計算基本テーブルより、各種キー項目を抽出する。対象データが複数抽出できた場合ははじめに抽出した1件のみ対象とする。
    BEGIN
      SELECT *
        INTO RKIHON_CAL
        FROM (SELECT *
                FROM ZLBTKIHON_CAL
               WHERE NENDO_BUN <= (i_NCHOTEI_NENDO - i_NNENDO_HANI)
                 AND SYS_TANMATSU_NO = i_VMASIN_NO
               ORDER BY CHOTEI_NENDO DESC)
       WHERE ROWNUM = 1;

      --取得したキー項目情報を退避する
      NK_KOKU_SETAI_NO := RKIHON_CAL.KOKU_SETAI_NO;
      NK_SANTEIDANTAI_CD := RKIHON_CAL.SANTEIDANTAI_CD;
      NK_CHOTEI_NENDO := RKIHON_CAL.CHOTEI_NENDO;
      NK_NENDO_BUN := RKIHON_CAL.NENDO_BUN;
      NK_TSUCHI_NO := RKIHON_CAL.TSUCHI_NO;
      NK_NUSHI_KOJIN_NO := RKIHON_CAL.NUSHI_KOJIN_NO;
      VK_SYS_TANMATSU_NO := RKIHON_CAL.SYS_TANMATSU_NO;
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '制限対象候補世帯の判定でZLBTKIHON_CALのキー項目取得に失敗しました（FUNC_HANTEI_TAISHO）';
        PROCLOGOUT(1,VMSG);
        RETURN 1;
    END;

    --システム条件より不均一課税及び主課税条件を取得する
    BEGIN
      SELECT FUKI_KAZEI,
       NUSHI_KAZEI
        INTO NFUKI_KAZEI,
             NNUSHI_KAZEI
        FROM ZLBTJOKEN
       WHERE NENDO = NK_NENDO_BUN
         AND SANTEIDANTAI_CD = 1;

      --取得した不均一課税が1の場合、以下の条件で再度主課税条件を取得する
      IF NFUKI_KAZEI = 1 THEN
        SELECT NUSHI_KAZEI
          INTO NNUSHI_KAZEI
          FROM ZLBTJOKEN
         WHERE NENDO = NK_NENDO_BUN
     AND SANTEIDANTAI_CD = NK_SANTEIDANTAI_CD;
      END IF;

      --取得した主課税条件を主課税区分にセットする
      NKAZEI_KBN := NNUSHI_KAZEI;
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '制限対象候補世帯の判定でシステム条件の取得に失敗しました（FUNC_HANTEI_TAISHO）';
        VMSG := VMSG || '年度分：' || NK_NENDO_BUN || '　算定団体コード：' || NK_SANTEIDANTAI_CD;
        PROCLOGOUT(1,VMSG);
        RETURN 1;
    END;

    --賦課基本（最新）テーブルより、各種キー項目を抽出する。対象データが複数抽出できた場合、はじめに抽出した1件のみ対象とする。
    BEGIN
      SELECT COUNT(*)
        INTO NF_CNT
        FROM ZLBTKIHON_N
       WHERE NENDO_BUN = NK_NENDO_BUN
         AND KOKU_SETAI_NO = NK_KOKU_SETAI_NO
         AND SANTEIDANTAI_CD = NK_SANTEIDANTAI_CD
   AND ((NKAZEI_KBN = 1 AND NUSHI_KOJIN_NO = NK_NUSHI_KOJIN_NO) OR NKAZEI_KBN <> 1);

      --賦基_件数　＞　0以外の場合
      IF NF_CNT = 0 THEN
        RETURN 9;
      END IF;

      --賦課基本（最新）テーブルより、各種キー項目を抽出する。対象データが複数抽出できた場合、はじめに抽出した1件のみ対象とする。
      SELECT *
        INTO RKIHON_N
        FROM (SELECT *
                FROM ZLBTKIHON_N
               WHERE NENDO_BUN = NK_NENDO_BUN
                 AND KOKU_SETAI_NO = NK_KOKU_SETAI_NO
                 AND SANTEIDANTAI_CD = NK_SANTEIDANTAI_CD
                 AND ((NKAZEI_KBN = 1 AND NUSHI_KOJIN_NO = NK_NUSHI_KOJIN_NO) OR NKAZEI_KBN <> 1)
               ORDER BY CHOTEI_NENDO DESC)
       WHERE ROWNUM = 1;

      --取得したキー項目情報を退避する
      FK_KOKU_SETAI_NO := RKIHON_N.KOKU_SETAI_NO;
      FK_SANTEIDANTAI_CD := RKIHON_N.SANTEIDANTAI_CD;
      FK_CHOTEI_NENDO := RKIHON_N.CHOTEI_NENDO;
      FK_NENDO_BUN := RKIHON_N.NENDO_BUN;
      FK_TSUCHI_NO := RKIHON_N.TSUCHI_NO;

    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '制限対象候補世帯の判定でZLBTKIHON_Nの件数取得に失敗しました（FUNC_HANTEI_TAISHO）';
        VMSG := VMSG || '年度分：' || NK_NENDO_BUN || '　国保世帯番号：' || NK_KOKU_SETAI_NO;
        VMSG := VMSG || '　世帯主宛名番号：' || NK_NUSHI_KOJIN_NO || '　算定団体コード：' || NK_SANTEIDANTAI_CD;
        PROCLOGOUT(1,VMSG);
        RETURN 1;
    END;

    --制限対象候補世帯に登録済みかどうか判定する
    BEGIN
      SELECT COUNT(*)
        INTO NS_CNT
        FROM ZLBWSEIGENKOHO_SETAI
       WHERE NENDO_BUN = NK_NENDO_BUN
         AND KOKU_SETAI_NO = NK_KOKU_SETAI_NO
         AND SANTEIDANTAI_CD = NK_SANTEIDANTAI_CD
         AND ((NKAZEI_KBN = 1 AND NUSHI_KOJIN_NO = NK_NUSHI_KOJIN_NO) OR NKAZEI_KBN <> 1);
    EXCEPTION
      WHEN OTHERS THEN
        VMSG := '制限対象候補世帯の判定でZLBWSEIGENKOHO_SETAIの件数取得に失敗しました（FUNC_HANTEI_TAISHO）';
        VMSG := VMSG || '年度分：' || NK_NENDO_BUN || '　国保世帯番号：' || NK_KOKU_SETAI_NO;
        VMSG := VMSG || '　世帯主宛名番号：' || NK_NUSHI_KOJIN_NO || '　算定団体コード：' || NK_SANTEIDANTAI_CD;
        PROCLOGOUT(1,VMSG);
        RETURN 1;
    END;

    --制候_件数　＞０　の場合
    IF NS_CNT > 0 THEN
      RETURN 9;
    END IF;

    --制限対象候補世帯に登録する
    INSERT INTO ZLBWSEIGENKOHO_SETAI
         VALUES (NK_KOKU_SETAI_NO
                ,NK_SANTEIDANTAI_CD
                ,NK_NENDO_BUN
                ,NK_NUSHI_KOJIN_NO
                ,TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'))
                ,TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'))
                ,TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MIDD'))
                ,i_NSYS_SHOKUINKOJIN_NO
                ,VK_SYS_TANMATSU_NO);

    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      VMSG := '賦課状況の中間ワーク情報作成でエラーが発生しました（FUNC_HANTEI_TAISHO）';
      VMSG := VMSG || '年度分：' || NK_NENDO_BUN || '　国保世帯番号：' || NK_KOKU_SETAI_NO;
      VMSG := VMSG || '　世帯主宛名番号：' || NK_NUSHI_KOJIN_NO || '　算定団体コード：' || NK_SANTEIDANTAI_CD;
      VMSG := VMSG || '　SQLエラー：' || SQLERRM;
      PROCLOGOUT(1,VMSG);
      RETURN 1;
  END FUNC_HANTEI_TAISHO;
-------------------------------------------------------------------------------------
--  計算個人ワークテーブル（ZLBWKOJIN_CAL_SKH）の作成
-------------------------------------------------------------------------------------
  FUNCTION FUNC_MAKEDATA
    RETURN NUMBER
  IS
    VERROR NVARCHAR2(256);  --エラーメッセージ
  BEGIN
    --計算個人ワークテーブル（ZLBWKOJIN_CAL_SKH）の削除
    NRTN := KKAPK3000.FTRUNCATE('ZLBWKOJIN_CAL_SKH', VERROR);
    --異常終了の場合
    IF NRTN <> 0 THEN
      VMSG  := '計算個人ワークテーブルの初期化に失敗しました（FUNC_MAKEDATA)';
      PROCLOGOUT(1,VMSG);
      RETURN 1;
    END IF;
    --計算個人から計算個人ワークテーブルへデータを退避
    INSERT INTO ZLBWKOJIN_CAL_SKH SELECT * FROM ZLBTKOJIN_CAL;
    RETURN 0;
  EXCEPTION
  WHEN OTHERS THEN
    VMSG := '計算個人ワークテーブル作成でエラーが発生しました（FUNC_MAKEDATA）';
    VMSG := VMSG || '　SQLエラー：' || SQLERRM;
    PROCLOGOUT(1,VMSG);
    RETURN 1;
  END FUNC_MAKEDATA;
-------------------------------------------------------------------------------------
--  各月資格区分変換処理の実行
-------------------------------------------------------------------------------------
  FUNCTION FUNC_CHANGEKBN
    RETURN NUMBER
  IS
    --コンスタント定義
    C_NBATCH CONSTANT NUMBER(1)  := 0;  --実行区分（バッチ）
    C_NTAISHO_KBN CONSTANT NUMBER(1)  := 1; --各月資格区分変換の対象テーブル制御(1:ZLBWKOJIN_CAL_SKH)
    --ログ出力用変数定義
    NLOG_NENDO_BUN       NUMBER; --ログ出力用年度分
    NLOG_KOKU_SETAI_NO   NUMBER; --ログ出力用国保世帯番号
    NLOG_SANTEIDANTAI_CD NUMBER; --ログ出力用算定団体コード
    NLOG_KOJIN_NO        NUMBER; --ログ出力用世帯主宛名番号
    --カーソル定義
    CURSOR CKOJIN
    IS
      SELECT JKC.*
      FROM ZLBWKOJIN_CAL_SKH JKC ,
        ZLBTKANWA_TAISHO_TMP JKT
      WHERE JKC.KOKU_SETAI_NO = JKT.KOKU_SETAI_NO
      AND JKC.KOJIN_NO        = JKT.KOJIN_NO
      AND JKC.SYS_TANMATSU_NO = I_VMASIN_NO;
    --レコード定義
    CRKOJIN CKOJIN%ROWTYPE;
  BEGIN
  --ループ処理
    FOR CRKOJIN IN CKOJIN
    LOOP
      --ログ出力用の情報を取得
      NLOG_NENDO_BUN       := CRKOJIN.NENDO_BUN;               --年度分
      NLOG_KOKU_SETAI_NO   := CRKOJIN.KOKU_SETAI_NO;           --国保世帯番号
      NLOG_SANTEIDANTAI_CD := CRKOJIN.SANTEIDANTAI_CD;         --算定団体コード
      NLOG_KOJIN_NO        := CRKOJIN.KOJIN_NO;                --宛名番号
      --各月資格区分変換処理を呼び出し
      ZLBSKCALCGKBN(CRKOJIN.CHOTEI_NENDO,                      --調定年度
                       CRKOJIN.NENDO_BUN,                      --年度分
                       CRKOJIN.KOKU_SETAI_NO,                  --国保世帯番号
                       CRKOJIN.KOJIN_NO,                       --宛名番号
                       CRKOJIN.TSUCHI_NO,                      --通知書番号
                       C_NBATCH,                               --実行区分(バッチ)
                       I_VMASIN_NO,                            --端末番号
                       i_NRENBAN,                              --登録連番
                       NRTN,                                   --戻り値(0:OK 1:ERROR)
                       C_NTAISHO_KBN);                         --各月資格変換の更新対象テーブル制御(1:ZLBWKOJIN_CAL_SKH)
      --異常終了の場合
      IF NRTN <> 0 THEN
        VMSG  := '各月資格区分変換処理の実行でエラーが発生しました（FUNC_CHANGEKBN）';
        VMSG := VMSG || '　年度分：' || NLOG_NENDO_BUN || '　国保世帯番号：' || NLOG_KOKU_SETAI_NO;
        VMSG := VMSG || '　算定団体コード：' || NLOG_SANTEIDANTAI_CD || '　宛名番号：' || NLOG_KOJIN_NO;
        VMSG := VMSG || '　SQLエラー：' || SQLERRM;
        PROCLOGOUT(1,VMSG);
        RETURN 1;
      END IF;
    END LOOP ;
    --正常終了の場合
    RETURN 0;
  --例外発生時
  EXCEPTION
  WHEN OTHERS THEN
    VMSG := '各月資格区分変換処理の実行でエラーが発生しました（FUNC_CHANGEKBN）';
    VMSG := VMSG || '　年度分：' || NLOG_NENDO_BUN || '　国保世帯番号：' || NLOG_KOKU_SETAI_NO;
    VMSG := VMSG || '　算定団体コード：' || NLOG_SANTEIDANTAI_CD || '　宛名番号：' || NLOG_KOJIN_NO;
    VMSG := VMSG || '　SQLエラー：' || SQLERRM;
    PROCLOGOUT(1,VMSG);
    RETURN 1;
  END FUNC_CHANGEKBN;
-------------------------------------------------------------------------------------
--  メイン処理
-------------------------------------------------------------------------------------
BEGIN
  --ログ情報よりステップ番号を取得する
  SELECT MAX(STEPNUM)
    INTO NMAX_STEP_NO
    FROM KKBTJLOG
   WHERE JOBNUM = i_NRENBAN;
  --計算個人ワークテーブルの作成を実行する
  NRTN    := FUNC_MAKEDATA;
  IF NRTN <> 0 THEN
    VMSG  := '計算個人ワークテーブル作成に失敗しました（FUNC_MAKEDATA）';
    PROCLOGOUT(1,VMSG);
    o_NRTN := 1;
    RETURN;
  END IF;
  --各月資格区分の変換処理を実行する
  NRTN    := FUNC_CHANGEKBN;
  IF NRTN <> 0 THEN
    VMSG  := '各月資格区分変換処理の実行に失敗しました（FUNC_CHANGEKBN）';
    PROCLOGOUT(1,VMSG);
    o_NRTN := 1;
    RETURN;
  END IF;
  --賦課決定期間の制限対象候補世帯判定処理を実行する
  NRTN := FUNC_HANTEI_TAISHO;
  IF NRTN = 0 THEN
    --賦課状況の中間ワーク情報作成処理を実行する
    NRTN := FUNC_GETFUKAJOKYO;
    IF NRTN <> 0 THEN
      VMSG := 'ZLBSCSGKHHT 賦課状況の中間ワーク情報作成に失敗しました（FUNC_GETFUKAJOKYO）';
      PROCLOGOUT(1,VMSG);
      o_NRTN := 1;
      RETURN;
    END IF;
    --賦課個人の中間ワーク情報作成処理を実行する
    NRTN := FUNC_GETFUKAKOJIN;
    IF NRTN <> 0 THEN
      VMSG := 'ZLBSCSGKHHT 賦課個人の中間ワーク情報作成に失敗しました（FUNC_GETFUKAKOJIN）';
      PROCLOGOUT(1,VMSG);
      o_NRTN := 1;
      RETURN;
    END IF;
    o_NRTN := 0;
  ELSIF NRTN = 9 THEN
    o_NRTN := 0;
  ELSE
    VMSG := 'ZLBSCSGKHHT 制限対象候補世帯判定処理に失敗しました（FUNC_HANTEI_TAISHO）';
    PROCLOGOUT(1,VMSG);
    o_NRTN := 1;
  END IF;

  RETURN;
EXCEPTION
  WHEN OTHERS THEN
    VMSG := 'ZLBSCSGKHHT　賦課決定期間の制限対象候補世帯判定処理でエラーが発生しました';
    VMSG := VMSG || '　年度分：' || NK_NENDO_BUN || '　国保世帯番号：' || NK_KOKU_SETAI_NO;
    VMSG := VMSG || '　算定団体コード：' || NK_SANTEIDANTAI_CD || '　世帯主宛名番号：' || NK_NUSHI_KOJIN_NO;
    VMSG := VMSG || '　SQLエラー：' || SQLERRM;
    PROCLOGOUT(1,VMSG);
    o_NRTN := 1;
    RETURN;
END ZLBSCSGKHHT;
/
