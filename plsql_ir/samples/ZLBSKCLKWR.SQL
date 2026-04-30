CREATE OR REPLACE PROCEDURE ZLBSKCLKWR (
--1.1.200.000
                            i_KOKU_SETAI_NO   IN  NUMBER,
                            i_SANTEIDANTAI_CD IN  NUMBER,
                            i_NNUSHI          IN  NUMBER,
                            i_NENDO           IN  NUMBER,
                            i_NENDO_BUN       IN  NUMBER,
                            i_NJIKKOU_KBN     IN  NUMBER,
                            i_VMASIN_NO       IN  NVARCHAR2,
                            i_NTRENBAN        IN  NUMBER,
                            i_MODE            IN  NUMBER,
                            i_KIJUNBI         IN  NUMBER,
                            o_RTN             OUT NUMBER
                                               ) IS
--------------------------------------------------------------------------------
--  業務名       ZLB(国民健康保険税)
--  PG 名        ZLBSKCLKWR
--  名称         緩和措置個人作成
--  処理概要     計算緩和個人を作成, 所得・資産割額を再算出して計算個人を更新
--  引数         i_KOKU_SETAI_NO    国保世帯番号
--               i_SANTEIDANTAI_CD  算定団体コード
--               i_NNUSHI           世帯主個人番号
--               i_NENDO            課税年度
--               i_NENDO_BUN        年度分
--               i_NJIKKOU_KBN      実行区分(0:バッチから起動 本算定/月例...
--                                           1:オンライン起動 即時
--                                           2:税率試算呼出(試算条件TBL使用)
--               i_VMASIN_NO        端末番号
--               i_NTRENBAN         登録連番
--                                           1:基準日時点[H4/HH/C4])
--                                    ※モード=基準日時点のみセット
--               o_RTN              戻り値
--  作成者      ZCZL.LIUCHANGQUAN
--  作成日      2023/08/01
--  VERSION     0.2.000.000
-------------------------------------------------------------------------------------
--変更履歴
--2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
--2024/05/07 ZCZL.RENXIAOFAN ADD 0.3.000.100:国保2次にマージ作業
--2024/09/18 ZCZL.TAOYAN UPDATE 0.3.000.101:国保2次故障対応_IT_ZLB_00016
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
-------------------------------------------------------------------------------------

-- コンスト(定数)定義
    -- 実行区分
    c_JIKKOU_KBN_BAT      NUMBER(2)   := 0;           -- 実行区分(0:バッチから起動 本算定
    c_JIKKOU_KBN_SOK      NUMBER(2)   := 1;           -- 実行区分(1:オンライン起動 即時
    c_JIKKOU_KBN_ZER      NUMBER(2)   := 2;           -- 実行区分(2:税率試算
    -- 戻り値
    c_NRTN_0              NUMBER(2)   := 0;           -- 正常
    c_NRTN_9              NUMBER(2)   := 9;           -- 異常
    bRTN                  BOOLEAN;
    -- ログ連番
    c_LOG_99              NUMBER(2)   := 99;          -- エラー用
--  変数宣言
    IlRTN                 PLS_INTEGER := c_NRTN_0;    -- 戻り値用
    BlRTN                 BOOLEAN;                    -- 戻り値
    VlERRBUF              VARCHAR2(500);              -- エラー用

    NlKANWACNT            NUMBER(2);                  -- 緩和対象者数
    NlSHIKAKU_KBN         NUMBER(2);                  -- 資格区分

    NlSTR_BI              NUMBER(8);                  -- 開始日
    NlEND_BI              NUMBER(8);                  -- 終了日

    NlSHOTOKU_IRY         NUMBER;                     -- 所得医療割率(システム条件)
    NlSHISAN_IRY          NUMBER;                     -- 資産医療割率(システム条件)
    NlSHOTOKU_KAI         NUMBER;                     -- 所得介護割率(システム条件)
    NlSHISAN_KAI          NUMBER;                     -- 資産介護割率(システム条件)
    NlSHOTOKU_SIEN        NUMBER;                     -- 所得支援割率(システム条件)
    NlSHISAN_SIEN         NUMBER;                     -- 資産支援割率(システム条件)
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
    NlSHOTOKU_KDM         NUMBER;                     -- 所得子ども割率(システム条件)
    NlSHISAN_KDM          NUMBER;                     -- 資産子ども割率(システム条件)
--2025/08/11 ZCZL.LIUHUAJUN ADD END
    NlSHOTOKU_2DANKAI     NUMBER;                     -- 所得割２段階[0:無し,1:有り](システム条件)

    TYPE TwKEIGEN IS TABLE OF NUMBER(2) INDEX BY BINARY_INTEGER;
    AwKEIGEN              TwKEIGEN;                   -- 軽減区分

    -- 出力用
    --2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
    --NlKOKU_SETAI_NO       NUMBER(12);                 -- 国世帯番号
    NlKOKU_SETAI_NO       NUMBER;                 -- 国世帯番号
    --2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
    --NlKOJIN_NO            NUMBER(12);                 -- 個人番号
    NlKOJIN_NO            NUMBER;                 -- 個人番号
    NlSANTEIDANTAI_CD     NUMBER(2);                  -- 算定団体コード
    NlCHOTEI_NENDO        NUMBER(4);                  -- 調停年度
    NlNENDO_BUN           NUMBER(4);                  -- 年度分
    NlR_NO                NUMBER(5);                  -- 履歴番号
--2024/09/18 ZCZL.TAOYAN UPDATE 0.3.000.101:国保2次故障対応_IT_ZLB_00016
    --NlTSUCHI_NO           NUMBER(12);                 -- 通知書番号
    NlTSUCHI_NO           NUMBER(20);                 -- 通知書番号
    NlSYS_SAKUSEIBI       NUMBER(8);                  -- 作成日
    NlSYS_KOSHINBI        NUMBER(8);                  -- 更新日
    NlSYS_JIKAN           NUMBER(6);                  -- 時間
    NlSYS_KOJIN_NO        CHAR(12);                   -- 職員個人番号
    VlSYS_TANMATSU_NO     VARCHAR2(63);               -- 端末番号

    TYPE TOUNOU IS TABLE OF NUMBER(5, 2) INDEX BY BINARY_INTEGER;
    TYPE TOUEKI IS TABLE OF NUMBER(5, 2) INDEX BY BINARY_INTEGER;
    AlOUNOU               TOUNOU;                     -- 月別応能係数
    AlOUEKI               TOUEKI;                     -- 月別応益係数
    TYPE TSHITSU IS TABLE OF NUMBER(2)   INDEX BY BINARY_INTEGER;
    AlSHITSU              TSHITSU;                    -- 月別失業者資格
    NSHITSU_KBN           NUMBER;                     -- 失業軽減対象区分
    NOUEKIST_NENDO        NUMBER(4);                  -- 旧被扶養者応益終了日開始年度
    NlKANWACNT_OUEKI      NUMBER(2);                  -- 旧被扶養者応益対象
   --コンスタント情報取得用
    o_ACONSPRM            A_CONS_PRM;                 -- パラメータの配列
    o_NPRMSUM             NUMBER;                     -- パラメータの配列の長度
    o_NSTATUS             PLS_INTEGER;                -- 戻り値

    RZLBTKOJIN_CAL        ZLBTKOJIN_CAL%ROWTYPE;      -- カーソル代入用

    NGENMEN_KOJIN_KBN       NUMBER;             -- ZLBTGENMEN_KOJIN に減免データあり
    type cur_type is ref    cursor;             -- カーソル変数のオブジェクト定義
    cur_DynamicSQL          cur_type;           -- カーソル変数定義
    TYPE type_ZLBTGENMEN_KOJIN_CAL IS RECORD(   -- データをセットする配列の宣言
        --2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
        --KOKU_SETAI_NO            NUMBER(12),
        KOKU_SETAI_NO            NUMBER,
        SANTEIDANTAI_CD          NUMBER(2),
        --2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
        --KOJIN_NO                 NUMBER(12),
        KOJIN_NO                 NUMBER,
        CHOTEI_NENDO             NUMBER(4),
        NENDO_BUN                NUMBER(4),
        R_NO                     NUMBER(5),
--2024/09/18 ZCZL.TAOYAN UPDATE 0.3.000.101:国保2次故障対応_IT_ZLB_00016
        --TSUCHI_NO                NUMBER(12),
        TSUCHI_NO                NUMBER(20),
        SHINSEI_NO               NUMBER(12),
        SHINSEI_BI               NUMBER(8),
        TORIKESHI_BI             NUMBER(8),
        GENMEN_JIYU              NUMBER(2),
        YUSEN_KBN                NUMBER(1),
        TEKIYO_KBN               NUMBER(1),
        I_SHOTOKU_KISO           NUMBER(12),
        I_SISANZEI_KISO          NUMBER(12),
        I_KINTOWARI_KISO         NUMBER(12),
        I_BYODOWARI_KISO         NUMBER(12),
        I_NENZEI_KISO            NUMBER(12),
        K_SHOTOKU_KISO           NUMBER(12),
        K_SISANZEI_KISO          NUMBER(12),
        K_KINTOWARI_KISO         NUMBER(12),
        K_BYODOWARI_KISO         NUMBER(12),
        K_NENZEI_KISO            NUMBER(12),
        S_SHOTOKU_KISO           NUMBER(12),
        S_SISANZEI_KISO          NUMBER(12),
        S_KINTOWARI_KISO         NUMBER(12),
        S_BYODOWARI_KISO         NUMBER(12),
        S_NENZEI_KISO            NUMBER(12),
        IT_SHOTOKU_KISO          NUMBER(12),
        IT_SISANZEI_KISO         NUMBER(12),
        IT_KINTOWARI_KISO        NUMBER(12),
        IT_BYODOWARI_KISO        NUMBER(12),
        IT_NENZEI_KISO           NUMBER(12),
        KT_SHOTOKU_KISO          NUMBER(12),
        KT_SISANZEI_KISO         NUMBER(12),
        KT_KINTOWARI_KISO        NUMBER(12),
        KT_BYODOWARI_KISO        NUMBER(12),
        KT_NENZEI_KISO           NUMBER(12),
        ST_SHOTOKU_KISO          NUMBER(12),
        ST_SISANZEI_KISO         NUMBER(12),
        ST_KINTOWARI_KISO        NUMBER(12),
        ST_BYODOWARI_KISO        NUMBER(12),
        ST_NENZEI_KISO           NUMBER(12),
        I_SHOTOKU_RITSU          NUMBER(3),
        I_SISANZEI_RITSU         NUMBER(3),
        I_KINTOWARI_RITSU        NUMBER(3),
        I_BYODOWARI_RITSU        NUMBER(3),
        I_NENZEI_RITSU           NUMBER(3),
        K_SHOTOKU_RITSU          NUMBER(3),
        K_SISANZEI_RITSU         NUMBER(3),
        K_KINTOWARI_RITSU        NUMBER(3),
        K_BYODOWARI_RITSU        NUMBER(3),
        K_NENZEI_RITSU           NUMBER(3),
        S_SHOTOKU_RITSU          NUMBER(3),
        S_SISANZEI_RITSU         NUMBER(3),
        S_KINTOWARI_RITSU        NUMBER(3),
        S_BYODOWARI_RITSU        NUMBER(3),
        S_NENZEI_RITSU           NUMBER(3),
        I_SHOTOKU_GENGAKU        NUMBER(12),
        I_SISANZEI_GENGAKU       NUMBER(12),
        I_KINTOWARI_GENGAKU      NUMBER(12),
        I_BYODOWARI_GENGAKU      NUMBER(12),
        I_NENZEI_GENGAKU         NUMBER(12),
        I_GENGAKU_KEI            NUMBER(12),
        K_SHOTOKU_GENGAKU        NUMBER(12),
        K_SISANZEI_GENGAKU       NUMBER(12),
        K_KINTOWARI_GENGAKU      NUMBER(12),
        K_BYODOWARI_GENGAKU      NUMBER(12),
        K_NENZEI_GENGAKU         NUMBER(12),
        K_GENGAKU_KEI            NUMBER(12),
        S_SHOTOKU_GENGAKU        NUMBER(12),
        S_SISANZEI_GENGAKU       NUMBER(12),
        S_KINTOWARI_GENGAKU      NUMBER(12),
        S_BYODOWARI_GENGAKU      NUMBER(12),
        S_NENZEI_GENGAKU         NUMBER(12),
        S_GENGAKU_KEI            NUMBER(12),
        IT_SHOTOKU_GENGAKU       NUMBER(12),
        IT_SISANZEI_GENGAKU      NUMBER(12),
        IT_KINTOWARI_GENGAKU     NUMBER(12),
        IT_BYODOWARI_GENGAKU     NUMBER(12),
        IT_NENZEI_GENGAKU        NUMBER(12),
        IT_GENGAKU_KEI           NUMBER(12),
        KT_SHOTOKU_GENGAKU       NUMBER(12),
        KT_SISANZEI_GENGAKU      NUMBER(12),
        KT_KINTOWARI_GENGAKU     NUMBER(12),
        KT_BYODOWARI_GENGAKU     NUMBER(12),
        KT_NENZEI_GENGAKU        NUMBER(12),
        KT_GENGAKU_KEI           NUMBER(12),
        ST_SHOTOKU_GENGAKU       NUMBER(12),
        ST_SISANZEI_GENGAKU      NUMBER(12),
        ST_KINTOWARI_GENGAKU     NUMBER(12),
        ST_BYODOWARI_GENGAKU     NUMBER(12),
        ST_NENZEI_GENGAKU        NUMBER(12),
        ST_GENGAKU_KEI           NUMBER(12),
        I_GENMEN_4               NUMBER(1),
        I_GENMEN_5               NUMBER(1),
        I_GENMEN_6               NUMBER(1),
        I_GENMEN_7               NUMBER(1),
        I_GENMEN_8               NUMBER(1),
        I_GENMEN_9               NUMBER(1),
        I_GENMEN_10              NUMBER(1),
        I_GENMEN_11              NUMBER(1),
        I_GENMEN_12              NUMBER(1),
        I_GENMEN_1               NUMBER(1),
        I_GENMEN_2               NUMBER(1),
        I_GENMEN_3               NUMBER(1),
        K_GENMEN_4               NUMBER(1),
        K_GENMEN_5               NUMBER(1),
        K_GENMEN_6               NUMBER(1),
        K_GENMEN_7               NUMBER(1),
        K_GENMEN_8               NUMBER(1),
        K_GENMEN_9               NUMBER(1),
        K_GENMEN_10              NUMBER(1),
        K_GENMEN_11              NUMBER(1),
        K_GENMEN_12              NUMBER(1),
        K_GENMEN_1               NUMBER(1),
        K_GENMEN_2               NUMBER(1),
        K_GENMEN_3               NUMBER(1),
        S_GENMEN_4               NUMBER(1),
        S_GENMEN_5               NUMBER(1),
        S_GENMEN_6               NUMBER(1),
        S_GENMEN_7               NUMBER(1),
        S_GENMEN_8               NUMBER(1),
        S_GENMEN_9               NUMBER(1),
        S_GENMEN_10              NUMBER(1),
        S_GENMEN_11              NUMBER(1),
        S_GENMEN_12              NUMBER(1),
        S_GENMEN_1               NUMBER(1),
        S_GENMEN_2               NUMBER(1),
        S_GENMEN_3               NUMBER(1),
        SHIKAKU_TUKISU           NUMBER(2),
        SHIKAKU_TUKISU_K         NUMBER(2),
        GENMENGAKU_KEI           NUMBER(12),
        GENMENGAKU_T_KEI         NUMBER(12),
        SAKUJO_KBN               NUMBER(1),
        I_GENGAKU_MAE            NUMBER(12),
        I_GENGAKU                NUMBER(12),
        K_GENGAKU_MAE            NUMBER(12),
        K_GENGAKU                NUMBER(12),
        S_GENGAKU_MAE            NUMBER(12),
        S_GENGAKU                NUMBER(12),
        IT_GENGAKU_MAE           NUMBER(12),
        IT_GENGAKU               NUMBER(12),
        KT_GENGAKU_MAE           NUMBER(12),
        KT_GENGAKU               NUMBER(12),
        ST_GENGAKU_MAE           NUMBER(12),
        ST_GENGAKU               NUMBER(12),
        SYS_SAKUSEIBI            NUMBER(8),
        SYS_KOSHINBI             NUMBER(8),
        SYS_JIKAN                NUMBER(6),
        SYS_SHOKUINKOJIN_NO      CHAR(12),
        SYS_TANMATSU_NO          NVARCHAR2(63)
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
        ,KDM_SHOTOKU_KISO        NUMBER(12)
        ,KDM_SISANZEI_KISO       NUMBER(12)
        ,KDM_KINTOWARI_KISO      NUMBER(12)
        ,KDM_KINTOWARI_18_KISO   NUMBER(12)
        ,KDM_BYODOWARI_KISO      NUMBER(12)
        ,KDM_NENZEI_KISO         NUMBER(12)
        ,KDM_SHOTOKU_RITSU       NUMBER(3)
        ,KDM_SISANZEI_RITSU      NUMBER(3)
        ,KDM_KINTOWARI_RITSU     NUMBER(3)
        ,KDM_KINTOWARI_18_RITSU  NUMBER(3)
        ,KDM_BYODOWARI_RITSU     NUMBER(3)
        ,KDM_NENZEI_RITSU        NUMBER(3)
        ,KDM_SHOTOKU_GENGAKU     NUMBER(12)
        ,KDM_SISANZEI_GENGAKU    NUMBER(12)
        ,KDM_KINTOWARI_GENGAKU   NUMBER(12)
        ,KDM_KINTOWARI_18_GENGAKU NUMBER(12)
        ,KDM_BYODOWARI_GENGAKU   NUMBER(12)
        ,KDM_NENZEI_GENGAKU      NUMBER(12)
        ,KDM_GENGAKU_KEI         NUMBER(12)
        ,KDM_GENMEN_4            NUMBER(1)
        ,KDM_GENMEN_5            NUMBER(1)
        ,KDM_GENMEN_6            NUMBER(1)
        ,KDM_GENMEN_7            NUMBER(1)
        ,KDM_GENMEN_8            NUMBER(1)
        ,KDM_GENMEN_9            NUMBER(1)
        ,KDM_GENMEN_10           NUMBER(1)
        ,KDM_GENMEN_11           NUMBER(1)
        ,KDM_GENMEN_12           NUMBER(1)
        ,KDM_GENMEN_1            NUMBER(1)
        ,KDM_GENMEN_2            NUMBER(1)
        ,KDM_GENMEN_3            NUMBER(1)
        ,KDM_GENGAKU_MAE         NUMBER(12)
        ,KDM_GENGAKU             NUMBER(12)
--2025/08/11 ZCZL.LIUHUAJUN ADD END
    );
    RwGENMENKOJIN                type_ZLBTGENMEN_KOJIN_CAL;
--2024/05/07 ZCZL.RENXIAOFAN Add START 0.3.000.100:国保2次にマージ作業
    TYPE TSAN IS TABLE OF NUMBER(2) INDEX BY BINARY_INTEGER;
    AlSAN                        TSAN;             --各月産前産後区分
    NSAN_KBN                     NUMBER;           --産前産後資格区分
    TYPE TKAI IS TABLE OF NUMBER(2) INDEX BY BINARY_INTEGER;
    AlKAI                        TKAI;             --各月介護資格区分
--2024/05/07 ZCZL.RENXIAOFAN Add END
--  カーソル定義
    CURSOR CwKOJIN IS
    SELECT * FROM ZLBTKOJIN_CAL
     WHERE KOKU_SETAI_NO   = i_KOKU_SETAI_NO
       AND SANTEIDANTAI_CD = i_SANTEIDANTAI_CD
       AND CHOTEI_NENDO    = i_NENDO
       AND NENDO_BUN       = i_NENDO_BUN
       AND TSUCHI_NO       = i_NNUSHI
       AND SYS_TANMATSU_NO = i_VMASIN_NO
       AND NEW_SHIK_KBN   <> 5;
------------------------------------------------------------------------------
--  計算個人 資産割額更新
------------------------------------------------------------------------------
FUNCTION FUNC_UPDATE_SHISANWARI(i_RZLBTKOJIN_CAL IN CwKOJIN%ROWTYPE,
                                 o_VlERRBUF OUT VARCHAR2
                                 ) RETURN NUMBER IS
  IwRTN          PLS_INTEGER := 0;
  IwCNT          PLS_INTEGER := 0;
  NwIDX          NUMBER(2);
  NwIRY          NUMBER(12);          -- 医療資産割額
  NwKAI          NUMBER(12);          -- 介護資産割額
  NwSIEN         NUMBER(12);          -- 支援資産割額
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
  NwKDM          NUMBER(12);          -- 子ども資産割額

BEGIN
  BEGIN
    -- 応能係数が同一の月数をカウント(100%の月)
    FOR NwIDX IN 1..12 LOOP
      IF AlOUNOU(NwIDX) = 100 THEN
        IwCNT := IwCNT + 1;
      END IF;
    END LOOP;
    -- 資産割額算出(課税標準額*システム条件資産割率/12*該当月)
    -- 医療
    NwIRY := TRUNC(
             ((i_RZLBTKOJIN_CAL.SHISANZEI * NlSHISAN_IRY / 100) * IwCNT) / 12
                );
    -- 介護
    NwKAI := TRUNC(
             ((i_RZLBTKOJIN_CAL.SHISANZEI * NlSHISAN_KAI / 100) * IwCNT) / 12
                );
    -- 支援
    NwSIEN := TRUNC(
             ((i_RZLBTKOJIN_CAL.SHISANZEI * NlSHISAN_SIEN / 100) * IwCNT) / 12
                );
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
    -- 子ども
    NwKDM := TRUNC(
             ((i_RZLBTKOJIN_CAL.SHISANZEI * NlSHISAN_KDM / 100) * IwCNT) / 12
                );
--2025/08/11 ZCZL.LIUHUAJUN ADD END
    -- 計算個人 資産割額更新
    UPDATE ZLBTKOJIN_CAL
       SET SHISAN_WARI      = NVL(NwIRY, 0),
           KAI_SHISAN_WARI  = NVL(NwKAI, 0),
           SIEN_SHISAN_WARI = NVL(NwSIEN, 0)
--2025/08/11 ZCZL.LIUHUAJUN ADD 1.1.200.000:子ども子育て支援金対応
           , KDM_SHISAN_WARI = NVL(NwKDM, 0)
     WHERE KOKU_SETAI_NO   = i_RZLBTKOJIN_CAL.KOKU_SETAI_NO
       AND KOJIN_NO        = i_RZLBTKOJIN_CAL.KOJIN_NO
       AND SANTEIDANTAI_CD = i_RZLBTKOJIN_CAL.SANTEIDANTAI_CD
       AND CHOTEI_NENDO    = i_RZLBTKOJIN_CAL.CHOTEI_NENDO
       AND NENDO_BUN       = i_RZLBTKOJIN_CAL.NENDO_BUN
       AND R_NO            = i_RZLBTKOJIN_CAL.R_NO
       AND TSUCHI_NO       = i_RZLBTKOJIN_CAL.TSUCHI_NO
       AND SYS_TANMATSU_NO = i_RZLBTKOJIN_CAL.SYS_TANMATSU_NO
       AND NEW_SHIK_KBN   <> 5;

  EXCEPTION
    WHEN OTHERS THEN
      IwRTN       := c_NRTN_9;
      o_VlERRBUF  := '計算個人 所得割額更新 ' || SQLCODE || SQLERRM ;
  END;
  RETURN( IwRTN );
END FUNC_UPDATE_SHISANWARI ;
------------------------------------------------------------------------------
--  計算個人 所得割額更新
------------------------------------------------------------------------------
FUNCTION FUNC_UPDATE_SHOTOKUWARI(i_RZLBTKOJIN_CAL IN ZLBTKOJIN_CAL%ROWTYPE,
                                 o_VlERRBUF OUT VARCHAR2
                                 ) RETURN NUMBER IS
  IwRTN          PLS_INTEGER := 0;
  IwCNT          PLS_INTEGER := 0;
  NwIDX          NUMBER(2);
  NwIRY          NUMBER(12);          -- 医療所得割額
  NwKAI          NUMBER(12);          -- 介護所得割額
  NwSIEN         NUMBER(12);          -- 支援所得割額
  IwCNT1         PLS_INTEGER := 0;
  IwCNT2         PLS_INTEGER := 0;
--2024/05/07 ZCZL.RENXIAOFAN Add START 0.3.000.100:国保2次にマージ作業
  IｗCNT_SAN1                  PLS_INTEGER := 0; --産前産後月数カウンタ1
  IｗCNT_SAN2                  PLS_INTEGER := 0; --産前産後月数カウンタ2
  NwIRY_SAN_GEN                NUMBER(12)  := 0;       --医療産前産後所得割軽減額
  NwKAI_SAN_GEN                NUMBER(12)  := 0;       --介護産前産後所得割軽減額
  NwSIEN_SAN_GEN               NUMBER(12)  := 0;       --支援産前産後所得割軽減額
  IwCNT_SAN1_K                 PLS_INTEGER := 0; --介護資格月数カウンタ1
  IwCNT_SAN2_K                 PLS_INTEGER := 0; --介護資格月数カウンタ2
--2024/05/07 ZCZL.RENXIAOFAN Add END
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
  NwKDM          NUMBER(12);          -- 子ども所得割額
  NwKDM_SAN_GEN  NUMBER(12);          -- 子ども産前産後所得割軽減額
--2025/08/11 ZCZL.LIUHUAJUN ADD END
BEGIN
  BEGIN
--2024/05/07 ZCZL.RENXIAOFAN Add START 0.3.000.100:国保2次にマージ作業
      AlKAI(1) := i_RZLBTKOJIN_CAL.KAI_SHIK_4;
      AlKAI(2) := i_RZLBTKOJIN_CAL.KAI_SHIK_5;
      AlKAI(3) := i_RZLBTKOJIN_CAL.KAI_SHIK_6;
      AlKAI(4) := i_RZLBTKOJIN_CAL.KAI_SHIK_7;
      AlKAI(5) := i_RZLBTKOJIN_CAL.KAI_SHIK_8;
      AlKAI(6) := i_RZLBTKOJIN_CAL.KAI_SHIK_9;
      AlKAI(7) := i_RZLBTKOJIN_CAL.KAI_SHIK_10;
      AlKAI(8) := i_RZLBTKOJIN_CAL.KAI_SHIK_11;
      AlKAI(9) := i_RZLBTKOJIN_CAL.KAI_SHIK_12;
      AlKAI(10) := i_RZLBTKOJIN_CAL.KAI_SHIK_1;
      AlKAI(11) := i_RZLBTKOJIN_CAL.KAI_SHIK_2;
      AlKAI(12) := i_RZLBTKOJIN_CAL.KAI_SHIK_3;
--2024/05/07 ZCZL.RENXIAOFAN Add END
    -- 応能係数が同一の月数をカウント(100%の月)
    FOR NwIDX IN 1..12 LOOP
      IF AlOUNOU(NwIDX) = 100 THEN
        IwCNT := IwCNT + 1;
      END IF;
      IF AlSHITSU(NwIDX) > 0 THEN
        IwCNT2 := IwCNT2 + 1;
      ELSE
        IwCNT1 := IwCNT1 + 1;
      END IF;
--2024/05/07 ZCZL.RENXIAOFAN Add START 0.3.000.100:国保2次にマージ作業
      --産前産後資格のある月の失業者資格の有無を判定する。
      --変数.各月産前産後区分(ループ回数) > 0
      IF AlSAN(NwIDX) > 0 THEN
        --変数.各月失業者資格区分 > 0　の場合
        IF AlSHITSU(NwIDX) > 0 THEN
          IｗCNT_SAN1 := IｗCNT_SAN1 + 1;
          --変数.各月介護資格区分 > 0　の場合
          IF AlKAI(NwIDX) > 0 THEN
            IwCNT_SAN1_K := IwCNT_SAN1_K + 1;
          END IF;
        --変数.各月失業者資格区分 > 0以外　の場合
        ELSE
          IｗCNT_SAN2 := IｗCNT_SAN2 + 1;
          --変数.各月介護資格区分 > 0　の場合
          IF AlKAI(NwIDX) > 0 THEN
            IwCNT_SAN2_K := IwCNT_SAN2_K + 1;
          END IF;
        END IF;
      END IF;
--2024/05/07 ZCZL.RENXIAOFAN Add END
    END LOOP;
--2024/05/07 ZCZL.RENXIAOFAN Add START 0.3.000.100:国保2次にマージ作業
    --産前産後軽減額の算出
    IF IwCNT > 0 THEN
      NwIRY_SAN_GEN := NVL(CEIL((((i_RZLBTKOJIN_CAL.KAHYO * NlSHOTOKU_IRY / 100) * IｗCNT_SAN2) / 12 +
                               (((i_RZLBTKOJIN_CAL.SHITSU_KAHYO * NlSHOTOKU_IRY  / 100) * IｗCNT_SAN1) / 12))), 0);
      NwKAI_SAN_GEN := NVL(CEIL((((i_RZLBTKOJIN_CAL.KAHYO * NlSHOTOKU_KAI / 100) * IwCNT_SAN2_K) / 12 +
                               (((i_RZLBTKOJIN_CAL.SHITSU_KAHYO * NlSHOTOKU_KAI  / 100) * IwCNT_SAN1_K) / 12))), 0);
      NwSIEN_SAN_GEN := NVL(CEIL((((i_RZLBTKOJIN_CAL.KAHYO * NlSHOTOKU_SIEN / 100) * IｗCNT_SAN2) / 12 +
                               (((i_RZLBTKOJIN_CAL.SHITSU_KAHYO * NlSHOTOKU_SIEN  / 100) * IｗCNT_SAN1) / 12))), 0);
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
      NwKDM_SAN_GEN := NVL(CEIL((((i_RZLBTKOJIN_CAL.KAHYO * NlSHOTOKU_KDM / 100) * IｗCNT_SAN2) / 12 +
                               (((i_RZLBTKOJIN_CAL.SHITSU_KAHYO * NlSHOTOKU_KDM  / 100) * IｗCNT_SAN1) / 12))), 0);
--2025/08/11 ZCZL.LIUHUAJUN ADD END
    END IF;
--2024/05/07 ZCZL.RENXIAOFAN Add END
    -- 所得割額算出(失業資格ありの場合)
    IF IwCNT2 > 0 THEN
      -- 医療
      NwIRY  := TRUNC((((i_RZLBTKOJIN_CAL.KAHYO        * NlSHOTOKU_IRY  / 100) * IwCNT1) / 12) +
--2024/05/07 ZCZL.RENXIAOFAN Update 0.3.000.100:国保2次にマージ作業
--                      (((i_RZLBTKOJIN_CAL.SHITSU_KAHYO * NlSHOTOKU_IRY  / 100) * IwCNT2) / 12));
                      (((i_RZLBTKOJIN_CAL.SHITSU_KAHYO * NlSHOTOKU_IRY  / 100) * IwCNT2) / 12)) - NwIRY_SAN_GEN;
      -- 介護
      NwKAI  := TRUNC((((i_RZLBTKOJIN_CAL.KAHYO        * NlSHOTOKU_KAI  / 100) * IwCNT1) / 12) +
--2024/05/07 ZCZL.RENXIAOFAN Update 0.3.000.100:国保2次にマージ作業
--                      (((i_RZLBTKOJIN_CAL.SHITSU_KAHYO * NlSHOTOKU_KAI  / 100) * IwCNT2) / 12));
                      (((i_RZLBTKOJIN_CAL.SHITSU_KAHYO * NlSHOTOKU_KAI  / 100) * IwCNT2) / 12)) - NwKAI_SAN_GEN;
      -- 支援
      NwSIEN := TRUNC((((i_RZLBTKOJIN_CAL.KAHYO        * NlSHOTOKU_SIEN / 100) * IwCNT1) / 12) +
--2024/05/07 ZCZL.RENXIAOFAN Update 0.3.000.100:国保2次にマージ作業
--                      (((i_RZLBTKOJIN_CAL.SHITSU_KAHYO * NlSHOTOKU_SIEN / 100) * IwCNT2) / 12));
                      (((i_RZLBTKOJIN_CAL.SHITSU_KAHYO * NlSHOTOKU_SIEN / 100) * IwCNT2) / 12)) - NwSIEN_SAN_GEN;
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
      -- 子ども
      NwKDM := TRUNC((((i_RZLBTKOJIN_CAL.KAHYO        * NlSHOTOKU_KDM / 100) * IwCNT1) / 12) +
                      (((i_RZLBTKOJIN_CAL.SHITSU_KAHYO * NlSHOTOKU_KDM / 100) * IwCNT2) / 12)) - NwKDM_SAN_GEN;
--2025/08/11 ZCZL.LIUHUAJUN ADD END
    ELSE
    -- 所得割額算出(課税標準額*システム条件所得割率/12*該当月)
    -- 医療
    NwIRY := TRUNC(
             ((i_RZLBTKOJIN_CAL.KAHYO * NlSHOTOKU_IRY / 100) * IwCNT) / 12
--2024/05/07 ZCZL.RENXIAOFAN Update 0.3.000.100:国保2次にマージ作業
--                );
                ) - NwIRY_SAN_GEN;

    -- 介護
    NwKAI := TRUNC(
             ((i_RZLBTKOJIN_CAL.KAHYO * NlSHOTOKU_KAI / 100) * IwCNT) / 12
--2024/05/07 ZCZL.RENXIAOFAN Update 0.3.000.100:国保2次にマージ作業
--                );
                ) - NwKAI_SAN_GEN;

    -- 支援
    NwSIEN := TRUNC(
             ((i_RZLBTKOJIN_CAL.KAHYO * NlSHOTOKU_SIEN / 100) * IwCNT) / 12
--2024/05/07 ZCZL.RENXIAOFAN Update 0.3.000.100:国保2次にマージ作業
--                );
                ) - NwSIEN_SAN_GEN;
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
    -- 子ども
    NwKDM := TRUNC(
             ((i_RZLBTKOJIN_CAL.KAHYO * NlSHOTOKU_KDM / 100) * IwCNT) / 12
                ) - NwKDM_SAN_GEN;
--2025/08/11 ZCZL.LIUHUAJUN ADD END
    END IF;
    -- 計算個人 所得割額更新
    UPDATE ZLBTKOJIN_CAL
       SET SHOTOKU_WARI      = NVL(NwIRY, 0),
           KAI_SHOTOKU_WARI  = NVL(NwKAI, 0),
           SIEN_SHOTOKU_WARI = NVL(NwSIEN, 0)
--2024/05/07 ZCZL.RENXIAOFAN Add START 0.3.000.100:国保2次にマージ作業
           ,SAN_IRYO_GEN_SHOTOKU = NwIRY_SAN_GEN   --医療産前産後所得割軽減額
           ,SAN_KAI_GEN_SHOTOKU  = NwKAI_SAN_GEN   --介護産前産後所得割軽減額
           ,SAN_SIEN_GEN_SHOTOKU = NwSIEN_SAN_GEN  --支援産前産後所得割軽減額
--2024/05/07 ZCZL.RENXIAOFAN Add END
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
           , KDM_SHOTOKU_WARI = NVL(NwKDM, 0)      --子ども所得割額
           , KDM_SAN_GEN_SHOTOKU = NwKDM_SAN_GEN   --子ども産前産後所得割軽減額
--2025/08/11 ZCZL.LIUHUAJUN ADD END
     WHERE KOKU_SETAI_NO   = i_RZLBTKOJIN_CAL.KOKU_SETAI_NO
       AND KOJIN_NO        = i_RZLBTKOJIN_CAL.KOJIN_NO
       AND SANTEIDANTAI_CD = i_RZLBTKOJIN_CAL.SANTEIDANTAI_CD
       AND CHOTEI_NENDO    = i_RZLBTKOJIN_CAL.CHOTEI_NENDO
       AND NENDO_BUN       = i_RZLBTKOJIN_CAL.NENDO_BUN
       AND R_NO            = i_RZLBTKOJIN_CAL.R_NO
       AND TSUCHI_NO       = i_RZLBTKOJIN_CAL.TSUCHI_NO
       AND SYS_TANMATSU_NO = i_RZLBTKOJIN_CAL.SYS_TANMATSU_NO
       AND NEW_SHIK_KBN   <> 5;
  EXCEPTION
    WHEN OTHERS THEN
      IwRTN       := c_NRTN_9;
      o_VlERRBUF  := '計算個人 所得割額更新 ' || SQLCODE || SQLERRM ;
  END;
  RETURN( IwRTN );
END FUNC_UPDATE_SHOTOKUWARI ;
------------------------------------------------------------------------------
--  計算緩和個人TBL Insert
------------------------------------------------------------------------------
FUNCTION FUNC_INSERT_KANWA_KOJIN(o_VlERRBUF OUT VARCHAR2
                                 ) RETURN NUMBER IS
  IwRTN          PLS_INTEGER := 0;
BEGIN
  BEGIN
      -- 計算緩和個人TBL Insert
      INSERT INTO ZLBTKANWA_KOJIN_CAL VALUES(
        NlKOKU_SETAI_NO,
        NlKOJIN_NO,
        NlSANTEIDANTAI_CD,
        NlCHOTEI_NENDO,
        NlNENDO_BUN,
        NlR_NO,
        NlTSUCHI_NO,
        AlOUNOU(1),
        AlOUNOU(2),
        AlOUNOU(3),
        AlOUNOU(4),
        AlOUNOU(5),
        AlOUNOU(6),
        AlOUNOU(7),
        AlOUNOU(8),
        AlOUNOU(9),
        AlOUNOU(10),
        AlOUNOU(11),
        AlOUNOU(12),
        AlOUEKI(1),
        AlOUEKI(2),
        AlOUEKI(3),
        AlOUEKI(4),
        AlOUEKI(5),
        AlOUEKI(6),
        AlOUEKI(7),
        AlOUEKI(8),
        AlOUEKI(9),
        AlOUEKI(10),
        AlOUEKI(11),
        AlOUEKI(12),
        NlSYS_SAKUSEIBI,
        NlSYS_KOSHINBI,
        NlSYS_JIKAN,
        NlSYS_KOJIN_NO,
        VlSYS_TANMATSU_NO);
  EXCEPTION
    WHEN OTHERS THEN
      IwRTN       := c_NRTN_9;
      o_VlERRBUF  := '計算緩和個人TBL Insert ' || SQLCODE || SQLERRM ;
  END;
  RETURN( IwRTN );
END FUNC_INSERT_KANWA_KOJIN ;
------------------------------------------------------------------------------
--  ループ月情報取得
------------------------------------------------------------------------------
FUNCTION FUNC_GET_SHIKAKU(i_RZLBTKOJIN_CAL IN CwKOJIN%ROWTYPE,
                          i_NwIDX IN NUMBER
                           ) RETURN NUMBER IS
  IwRTN          PLS_INTEGER := 0;
BEGIN
  CASE i_NwIDX                -- 1～12⇒4月～3月
    WHEN 1 THEN
      NlSHIKAKU_KBN := i_RZLBTKOJIN_CAL.SHIK_4;
      NlSTR_BI := i_NENDO_BUN * 10000 + 430;
      NlEND_BI := i_NENDO_BUN * 10000 + 501;
    WHEN 2 THEN
      NlSHIKAKU_KBN := i_RZLBTKOJIN_CAL.SHIK_5;
      NlSTR_BI := i_NENDO_BUN * 10000 + 531;
      NlEND_BI := i_NENDO_BUN * 10000 + 601;
    WHEN 3 THEN
      NlSHIKAKU_KBN := i_RZLBTKOJIN_CAL.SHIK_6;
      NlSTR_BI := i_NENDO_BUN * 10000 + 630;
      NlEND_BI := i_NENDO_BUN * 10000 + 701;
    WHEN 4 THEN
      NlSHIKAKU_KBN := i_RZLBTKOJIN_CAL.SHIK_7;
      NlSTR_BI := i_NENDO_BUN * 10000 + 731;
      NlEND_BI := i_NENDO_BUN * 10000 + 801;
    WHEN 5 THEN
      NlSHIKAKU_KBN := i_RZLBTKOJIN_CAL.SHIK_8;
      NlSTR_BI := i_NENDO_BUN * 10000 + 831;
      NlEND_BI := i_NENDO_BUN * 10000 + 901;
    WHEN 6 THEN
      NlSHIKAKU_KBN := i_RZLBTKOJIN_CAL.SHIK_9;
      NlSTR_BI := i_NENDO_BUN * 10000 + 930;
      NlEND_BI := i_NENDO_BUN * 10000 + 1001;
    WHEN 7 THEN
      NlSHIKAKU_KBN := i_RZLBTKOJIN_CAL.SHIK_10;
      NlSTR_BI := i_NENDO_BUN * 10000 + 1031;
      NlEND_BI := i_NENDO_BUN * 10000 + 1101;
    WHEN 8 THEN
      NlSHIKAKU_KBN := i_RZLBTKOJIN_CAL.SHIK_11;
      NlSTR_BI := i_NENDO_BUN * 10000 + 1130;
      NlEND_BI := i_NENDO_BUN * 10000 + 1201;
    WHEN 9 THEN                                 -- 次年分は年をたす
      NlSHIKAKU_KBN := i_RZLBTKOJIN_CAL.SHIK_12;
      NlSTR_BI := i_NENDO_BUN * 10000 + 1231;
      NlEND_BI := i_NENDO_BUN * 10000 + 10101;
    WHEN 10 THEN
      NlSHIKAKU_KBN := i_RZLBTKOJIN_CAL.SHIK_1;
      NlSTR_BI := i_NENDO_BUN * 10000 + 10131;
      NlEND_BI := i_NENDO_BUN * 10000 + 10201;
    WHEN 11 THEN
      NlSHIKAKU_KBN := i_RZLBTKOJIN_CAL.SHIK_2;
      NlSTR_BI := i_NENDO_BUN * 10000 + 10229;
      NlEND_BI := i_NENDO_BUN * 10000 + 10301;
    WHEN 12 THEN
      NlSHIKAKU_KBN := i_RZLBTKOJIN_CAL.SHIK_3;
      NlSTR_BI := i_NENDO_BUN * 10000 + 10331;
      NlEND_BI := i_NENDO_BUN * 10000 + 10401;
  END CASE;
--H4/HH/C4時は基準日時点で緩和措置対象登録されているか判定
--各月の資格は呼び元で基準日時点の資格が全月セットされている
  IF i_MODE = 1 THEN
      NlSTR_BI := i_KIJUNBI;
      NlEND_BI := i_KIJUNBI;
  END IF;
  RETURN( IwRTN );
END FUNC_GET_SHIKAKU ;
------------------------------------------------------------------------------
--  計算軽減区分TBL取得
------------------------------------------------------------------------------
FUNCTION FUNC_GET_KEIGEN_KBN(o_VlERRBUF OUT VARCHAR2
                             ) RETURN NUMBER IS
  IwRTN          PLS_INTEGER := 0;
BEGIN
  BEGIN
    -- 計算軽減区分TBL取得
    SELECT KEIGEN_4,     KEIGEN_5,     KEIGEN_6,     KEIGEN_7,
           KEIGEN_8,     KEIGEN_9,     KEIGEN_10,    KEIGEN_11,
           KEIGEN_12,    KEIGEN_1,     KEIGEN_2,     KEIGEN_3
      INTO AwKEIGEN(1),  AwKEIGEN(2),  AwKEIGEN(3),  AwKEIGEN(4),
           AwKEIGEN(5),  AwKEIGEN(6),  AwKEIGEN(7),  AwKEIGEN(8),
           AwKEIGEN(9),  AwKEIGEN(10), AwKEIGEN(11), AwKEIGEN(12)
      FROM ZLBTKEIGEN_CAL
     WHERE KOKU_SETAI_NO = i_KOKU_SETAI_NO
       AND SYS_TANMATSU_NO = i_VMASIN_NO;
  EXCEPTION
    WHEN OTHERS THEN
      IwRTN       := c_NRTN_9;
      o_VlERRBUF  := '計算軽減区分TBL取得エラー ' ||SQLCODE||SQLERRM;
  END;
  RETURN( IwRTN );
END FUNC_GET_KEIGEN_KBN ;
------------------------------------------------------------------------------
--  試算システム条件読み込み
------------------------------------------------------------------------------
FUNCTION JOKEN_ZER_READ(o_VlERRBUF OUT VARCHAR2
                           ) RETURN NUMBER IS
  IwRTN          PLS_INTEGER := 0;
  RwJOKEN_ZER     ZLBTJOKEN_ZER%ROWTYPE;      -- 試算システム条件
BEGIN
  BEGIN
    SELECT *
      INTO RwJOKEN_ZER
      FROM ZLBTJOKEN_ZER
     WHERE NENDO           = i_NENDO_BUN
       AND SANTEIDANTAI_CD = i_SANTEIDANTAI_CD;
  EXCEPTION
    WHEN OTHERS THEN
      IwRTN       := c_NRTN_9;
      o_VlERRBUF  := '試算システム条件該当読込エラー ' ||SQLCODE||SQLERRM
                       || ' 算定団体コード＝' || i_SANTEIDANTAI_CD ;
  END;
  IF IwRTN  = c_NRTN_0 THEN
    NlSHOTOKU_IRY        := RwJOKEN_ZER.SHOTOKU_IRY;             -- 医療所得割率（判定額以下）
    NlSHISAN_IRY         := RwJOKEN_ZER.SHISAN_IRY;              -- 医療資産割率
    NlSHOTOKU_KAI        := RwJOKEN_ZER.SHOTOKU_KAI;             -- 介護所得割率（判定額以下）
    NlSHISAN_KAI         := RwJOKEN_ZER.SHISAN_KAI;              -- 介護資産割率
    NlSHOTOKU_SIEN       := RwJOKEN_ZER.SHOTOKU_SIEN;            -- 支援所得割率（判定額以下）
    NlSHISAN_SIEN        := RwJOKEN_ZER.SHISAN_SIEN;             -- 支援資産割率
    NlSHOTOKU_2DANKAI    := RwJOKEN_ZER.SHOTOKU_2DANKAI;         -- 所得割２段階（0:無し、1:有り）
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
    NlSHOTOKU_KDM        := RwJOKEN_ZER.SHOTOKU_KDM;             -- 所得子ども割率(システム条件)
    NlSHISAN_KDM         := RwJOKEN_ZER.SHISAN_KDM;              -- 資産子ども割率(システム条件)
--2025/08/11 ZCZL.LIUHUAJUN ADD END
  END IF ;
  RETURN( IwRTN );
END JOKEN_ZER_READ ;
------------------------------------------------------------------------------
--  システム条件読み込み
------------------------------------------------------------------------------
FUNCTION JOKEN_READ(o_VlERRBUF OUT VARCHAR2
                           ) RETURN NUMBER IS
  IwRTN          PLS_INTEGER := 0;
  RwJOKEN         ZLBTJOKEN%ROWTYPE;          -- システム条件
BEGIN
  BEGIN
    SELECT *
      INTO RwJOKEN
      FROM ZLBTJOKEN
     WHERE NENDO           = i_NENDO_BUN
       AND SANTEIDANTAI_CD = i_SANTEIDANTAI_CD;
  EXCEPTION
      WHEN OTHERS THEN
        IwRTN       := c_NRTN_9;
        o_VlERRBUF  := 'システム条件該当読込エラー ' ||SQLCODE||SQLERRM
                       || ' 算定団体コード＝' || i_SANTEIDANTAI_CD ;
  END;
  IF IwRTN = c_NRTN_0 THEN
    NlSHOTOKU_IRY       := RwJOKEN.SHOTOKU_IRY;            -- 医療所得割率（判定額以下）
    NlSHISAN_IRY        := RwJOKEN.SHISAN_IRY;             -- 医療資産割率
    NlSHOTOKU_KAI       := RwJOKEN.SHOTOKU_KAI;            -- 介護所得割率（判定額以下）
    NlSHISAN_KAI        := RwJOKEN.SHISAN_KAI;             -- 介護資産割率
    NlSHOTOKU_SIEN      := RwJOKEN.SHOTOKU_SIEN;           -- 支援所得割率（判定額以下）
    NlSHISAN_SIEN       := RwJOKEN.SHISAN_SIEN;            -- 支援資産割率
    NlSHOTOKU_2DANKAI   := RwJOKEN.SHOTOKU_2DANKAI;        -- 所得割２段階（0:無し、1:有り）
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
    NlSHOTOKU_KDM       := RwJOKEN.SHOTOKU_KDM;            -- 所得子ども割率(システム条件)
    NlSHISAN_KDM        := RwJOKEN.SHISAN_KDM;             -- 資産子ども割率(システム条件)
--2025/08/11 ZCZL.LIUHUAJUN ADD END
  END IF ;
  RETURN( IwRTN );
END JOKEN_READ ;
-------------------------------------------------------------------------------
-- ZLBTGENMEN_KOJIN_TMP にデータがあれば、減免対象者
-------------------------------------------------------------------------------
    FUNCTION funcGenmenKojinGet(i_RwKOJIN IN ZLBTKOJIN_CAL%ROWTYPE) RETURN NUMBER IS
        nCNT      NUMBER;
        nRTN      NUMBER;
    BEGIN
        nRTN := 0;
        -- ZLBTGENMEN_KOJIN テーブルの存在チェック
        nCNT := 1;
        IF nCNT = 1 THEN
            OPEN cur_DynamicSQL FOR 'SELECT * FROM ZLBTGENMEN_KOJIN_TMP
                                     WHERE KOKU_SETAI_NO   = :KOKU_SETAI_NO
                                     AND   SANTEIDANTAI_CD = :SANTEIDANTAI_CD
                                     AND   NENDO_BUN       = :NENDO_BUN
                                     AND   SYS_TANMATSU_NO = :SYS_TANMATSU_NO'
                                USING i_RwKOJIN.KOKU_SETAI_NO, i_RwKOJIN.SANTEIDANTAI_CD, i_RwKOJIN.NENDO_BUN, i_RwKOJIN.SYS_TANMATSU_NO;
            LOOP
                FETCH cur_DynamicSQL INTO RwGENMENKOJIN;
                EXIT WHEN cur_DynamicSQL%NOTFOUND;
                -- 優先区分が世帯減免の場合
                IF RwGENMENKOJIN.YUSEN_KBN > 0 THEN
                    -- 減免該当
                    nRTN := 1;
                -- 優先区分が個人減免の場合
                ELSE
                    -- 個人番号から減免情報を参照する
                    OPEN cur_DynamicSQL FOR 'SELECT * FROM ZLBTGENMEN_KOJIN_TMP
                                             WHERE KOKU_SETAI_NO   = :KOKU_SETAI_NO
                                             AND   SANTEIDANTAI_CD = :SANTEIDANTAI_CD
                                             AND   NENDO_BUN       = :NENDO_BUN
                                             AND   KOJIN_NO        = :KOJIN_NO
                                             AND   SYS_TANMATSU_NO = :SYS_TANMATSU_NO'
                                        USING i_RwKOJIN.KOKU_SETAI_NO, i_RwKOJIN.SANTEIDANTAI_CD, i_RwKOJIN.NENDO_BUN, i_RwKOJIN.KOJIN_NO, i_RwKOJIN.SYS_TANMATSU_NO;
                    LOOP
                        FETCH cur_DynamicSQL INTO RwGENMENKOJIN;
                        EXIT WHEN cur_DynamicSQL%NOTFOUND;
                        -- 減免該当
                        nRTN := 1;
                    END LOOP;
                END IF;
                -- FETCH FIRST ROWのみ
                EXIT;
            END LOOP;
            CLOSE cur_DynamicSQL;
        END IF;
        RETURN(nRTN);
    EXCEPTION
        WHEN OTHERS THEN
            IlRTN    := c_NRTN_9;
            VlERRBUF := '減免個人 存在チェック(国保世帯番号=' || i_RwKOJIN.KOKU_SETAI_NO || ' 宛名番号=' || i_RwKOJIN.KOJIN_NO || ')' || SQLERRM;
            RETURN(nRTN);
    END;
------------------------------------------------------------------------------
--  メイン処理
------------------------------------------------------------------------------
BEGIN
  -- 初期処理
  -- 計算緩和個人TBL削除
  DELETE ZLBTKANWA_KOJIN_CAL
   WHERE SYS_TANMATSU_NO = i_VMASIN_NO;

  -- システム条件取得
  IF i_NJIKKOU_KBN <> c_JIKKOU_KBN_ZER THEN     --税率試算以外
    IlRTN := JOKEN_READ(VlERRBUF);
  ELSE                                          --税率試算
    IlRTN := JOKEN_ZER_READ(VlERRBUF);
  END IF;
  --旧被扶養者応益終了日判定開始年度の取得
  o_NSTATUS := KKAPK0030.FPRMSHUTOKU('ZLB', '00OUEKIST', 0, o_ACONSPRM, o_NPRMSUM);
  IF o_NSTATUS = 0 THEN
    NOUEKIST_NENDO := o_ACONSPRM(1);
  ELSE
    NOUEKIST_NENDO := 2019;
  END IF;
  IF IlRTN = c_NRTN_0 THEN
    -- 計算軽減区分TBL取得
    IlRTN := FUNC_GET_KEIGEN_KBN(VlERRBUF);
  END IF;
  IF IlRTN = c_NRTN_0 THEN
    -- 計算個人カーソルループ
    FOR RZLBTKOJIN_CAL IN CwKOJIN LOOP
      IF IlRTN = c_NRTN_0 THEN
        -- カーソルより情報を出力エリアにセット
        NlKOKU_SETAI_NO     := RZLBTKOJIN_CAL.KOKU_SETAI_NO;       -- 国保世帯番号
        NlKOJIN_NO          := RZLBTKOJIN_CAL.KOJIN_NO;            -- 個人番号
        NlSANTEIDANTAI_CD   := RZLBTKOJIN_CAL.SANTEIDANTAI_CD;     -- 算定団体コード
        NlCHOTEI_NENDO      := RZLBTKOJIN_CAL.CHOTEI_NENDO;        -- 調定年度
        NlNENDO_BUN         := RZLBTKOJIN_CAL.NENDO_BUN;           -- 年度分
        NlR_NO              := RZLBTKOJIN_CAL.R_NO;                -- 履歴番号
        NlTSUCHI_NO         := RZLBTKOJIN_CAL.TSUCHI_NO;           -- 通知書番号
        NlSYS_SAKUSEIBI     := RZLBTKOJIN_CAL.SYS_SAKUSEIBI;       -- 作成日
        NlSYS_KOSHINBI      := RZLBTKOJIN_CAL.SYS_KOSHINBI;        -- 更新日
        NlSYS_JIKAN         := RZLBTKOJIN_CAL.SYS_JIKAN;           -- 更新時間
        NlSYS_KOJIN_NO      := RZLBTKOJIN_CAL.SYS_SHOKUINKOJIN_NO; -- 更新職員番号
        VlSYS_TANMATSU_NO   := RZLBTKOJIN_CAL.SYS_TANMATSU_NO;     -- 更新端末番号
        -- 応能・応益係数を100で初期化
        FOR NwIx IN 1..12 LOOP
          AlOUNOU(NwIx) := 100;
          AlOUEKI(NwIx) := 100;
        END LOOP;
        FOR NwIx IN 1..12 LOOP
          AlSHITSU(NwIx) := 0;
        END LOOP;
        IF RZLBTKOJIN_CAL.NEW_SHITSU_KBN > 0 THEN
          AlSHITSU(1)  := RZLBTKOJIN_CAL.SHITSU_4;
          AlSHITSU(2)  := RZLBTKOJIN_CAL.SHITSU_5;
          AlSHITSU(3)  := RZLBTKOJIN_CAL.SHITSU_6;
          AlSHITSU(4)  := RZLBTKOJIN_CAL.SHITSU_7;
          AlSHITSU(5)  := RZLBTKOJIN_CAL.SHITSU_8;
          AlSHITSU(6)  := RZLBTKOJIN_CAL.SHITSU_9;
          AlSHITSU(7)  := RZLBTKOJIN_CAL.SHITSU_10;
          AlSHITSU(8)  := RZLBTKOJIN_CAL.SHITSU_11;
          AlSHITSU(9)  := RZLBTKOJIN_CAL.SHITSU_12;
          AlSHITSU(10) := RZLBTKOJIN_CAL.SHITSU_1;
          AlSHITSU(11) := RZLBTKOJIN_CAL.SHITSU_2;
          AlSHITSU(12) := RZLBTKOJIN_CAL.SHITSU_3;
        END IF;
        NSHITSU_KBN := 0;
        -- 失業軽減対象かどうか判定
        FOR NwIx IN 1..12 LOOP
          IF AlSHITSU(NwIx) = 1 THEN
            NSHITSU_KBN := 1;
          END IF;
        END LOOP;
        FOR NwIx IN 1..12 LOOP
          IF NSHITSU_KBN = 1 AND AlSHITSU(NwIx) = 0 THEN
            -- ループ月の情報を取得
            IlRTN := FUNC_GET_SHIKAKU(RZLBTKOJIN_CAL, NwIx);
            -- 資格区分＝資格無しの場合
            IF NlSHIKAKU_KBN NOT IN (1,3,11,13) THEN
              AlSHITSU(NwIx) := 1;
            END IF;
          END IF;
        END LOOP;

        NGENMEN_KOJIN_KBN := funcGenmenKojinGet(RZLBTKOJIN_CAL);   -- 減免対象者か判定する。
        IF NGENMEN_KOJIN_KBN <> 1 AND IlRTN = c_NRTN_0 THEN        -- 減免個人の計算を行わないとき、旧被扶養者の減額計算を行う。
          -- 12回ループ
          FOR NwIx IN 1..12 LOOP
            -- ループ月の情報を取得
            IlRTN := FUNC_GET_SHIKAKU(RZLBTKOJIN_CAL, NwIx);
            -- 資格区分＝資格あり？
            IF NlSHIKAKU_KBN IN (1,3,11,13) THEN
              -- 該当月の緩和対象(被扶養者)設定チェック
              SELECT COUNT(*)
                INTO NlKANWACNT
                FROM ZLBTKANWA_TAISHO_TMP
               WHERE KOJIN_NO        = RZLBTKOJIN_CAL.KOJIN_NO
                 AND TAISHO_KBN      = 2
                 AND KOKU_SETAI_NO   = i_KOKU_SETAI_NO
                 AND SAKUJO_KBN      = 0
                 AND SYS_TANMATSU_NO = i_VMASIN_NO
                 AND TEKIJOGAI_SBI   <= NlSTR_BI
                 AND TEKIJOGAI_EBI   >= NlEND_BI;
              -- 緩和対象チェック
              IF NlKANWACNT > 0 THEN
                -- 応能係数に0設定
                AlOUNOU(NwIx) := 0;
                NlKANWACNT_OUEKI := 0;
                IF NOUEKIST_NENDO > i_NENDO_BUN THEN
                  NlKANWACNT_OUEKI := NlKANWACNT;
                ELSE
                  --基準日の場合、終了日を翌日に調整
                  IF i_MODE = 1 THEN
                    NlEND_BI := KKAPK0020.FDATECAL(NlEND_BI,0,1,0,0);
                  END IF;
                  -- 該当月の緩和対象(被扶養者)設定チェック
                  SELECT COUNT(*)
                    INTO NlKANWACNT_OUEKI
                    FROM ZLBTKANWA_TS_EX_TMP
                   WHERE KOJIN_NO        = RZLBTKOJIN_CAL.KOJIN_NO
                     AND TAISHO_KBN      = 2
                     AND KOKU_SETAI_NO   = i_KOKU_SETAI_NO
                     AND SAKUJO_KBN      = 0
                     AND SYS_TANMATSU_NO = i_VMASIN_NO
                     AND TEKIJOGAI_SBI   <= NlSTR_BI
                     AND TEKIJOGAI_EBI   >= NlEND_BI;
                END IF;
                -- 軽減区分判定
                -- ５割未満で応益対象の場合に判定する
                IF AwKEIGEN(NwIx) < 5 AND NlKANWACNT_OUEKI > 0 THEN
                  IF AwKEIGEN(NwIx) = 4 THEN
                    -- 応益係数に90設定
                    AlOUEKI(NwIx) := 90;
                  ELSIF AwKEIGEN(NwIx) = 2 THEN
                    -- 応益係数に70設定
                    AlOUEKI(NwIx) := 70;
                  ELSE
                    -- 応益係数に50設定
                    AlOUEKI(NwIx) := 50;
                  END IF;
                END IF;     --軽減区分判定IF
              END IF;       --緩和対象判定IF
            END IF;         --資格あり判定IF
          END LOOP;         --個人_月ループ
        END IF;
--2024/05/07 ZCZL.RENXIAOFAN Add START 0.3.000.100:国保2次にマージ作業
        FOR NwIx IN 1..12 LOOP
          AlSAN(NwIX) := 0; --変数.各月産前産後資格区分
        END LOOP;
        --引数.年度分が2023年度以降の場合
        IF i_NENDO_BUN >= 2023 THEN
          --計算個人.最新産前産後資格区分 > 0 の場合
          IF RZLBTKOJIN_CAL.NEW_SAN_KBN > 0 THEN
            AlSAN(1) := RZLBTKOJIN_CAL.SAN_4;
            AlSAN(2) := RZLBTKOJIN_CAL.SAN_5;
            AlSAN(3) := RZLBTKOJIN_CAL.SAN_6;
            AlSAN(4) := RZLBTKOJIN_CAL.SAN_7;
            AlSAN(5) := RZLBTKOJIN_CAL.SAN_8;
            AlSAN(6) := RZLBTKOJIN_CAL.SAN_9;
            AlSAN(7) := RZLBTKOJIN_CAL.SAN_10;
            AlSAN(8) := RZLBTKOJIN_CAL.SAN_11;
            AlSAN(9) := RZLBTKOJIN_CAL.SAN_12;
            AlSAN(10) := RZLBTKOJIN_CAL.SAN_1;
            AlSAN(11) := RZLBTKOJIN_CAL.SAN_2;
            AlSAN(12) := RZLBTKOJIN_CAL.SAN_3;
          END IF;
          NSAN_KBN := 0; --産前産後資格区分
          --産前産後対象かどうか判定
          FOR NwIx IN 1..12 LOOP
            IF AlSAN(NwIx) = 1 THEN
              NSAN_KBN := 1;
              EXIT;
            END IF;
          END LOOP;
          FOR NwIx IN 1..12 LOOP
            IF NSAN_KBN = 1 AND AlSAN(NwIx) = 0 THEN
              --ループ月の情報を取得
              IlRTN := FUNC_GET_SHIKAKU(RZLBTKOJIN_CAL, NwIx);
            END IF;
          END LOOP;
        END IF;
--2024/05/07 ZCZL.RENXIAOFAN Add END
        -- 計算緩和個人TBL Insert
        -- (出力エリアの内容を計算緩和個人TBLにInsert
        IlRTN := FUNC_INSERT_KANWA_KOJIN(VlERRBUF);
        -- カーソルの医療所得割額≠\0
        -- カーソルの課税標準額≠\0 and 所得割２段階無し
        IF RZLBTKOJIN_CAL.KAHYO <> 0 AND NlSHOTOKU_2DANKAI = 0 AND IlRTN = c_NRTN_0 THEN
          -- 所得割額再セット
          IlRTN := FUNC_UPDATE_SHOTOKUWARI(RZLBTKOJIN_CAL, VlERRBUF);
        END IF;
        -- カーソルの医療資産割額≠\0
        -- カーソルの資産税額≠\0
        IF RZLBTKOJIN_CAL.SHISANZEI <> 0 AND IlRTN = c_NRTN_0 THEN
          -- 資産割額再セット
          IlRTN := FUNC_UPDATE_SHISANWARI(RZLBTKOJIN_CAL, VlERRBUF);
        END IF;
      END IF;
    END LOOP;         -- カーソルループ
  END IF;
  -- エラーログ出力
  IF IlRTN <> c_NRTN_0 THEN
      bRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSKCLKWR', 1, '', '',  VlERRBUF||' ZLBSKCLKWR 処理失敗 ' ||' 国保世帯番号='||i_KOKU_SETAI_NO, '', i_VMASIN_NO);
  END IF;
  -- トランザクション処理
  IF IlRTN = c_NRTN_0 THEN
    BEGIN
      COMMIT;         -- コミット
    EXCEPTION
      WHEN OTHERS THEN
        IlRTN       := c_NRTN_9;
         -- ログ出力
         bRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSKCLKWR', 1, SQLCODE, SQLERRM,  VlERRBUF||' ZLBSKCLKWR COMMIT失敗'||' 国保世帯番号='||i_KOKU_SETAI_NO, '', i_VMASIN_NO);
    END;
  ELSE
    BEGIN
      ROLLBACK;       -- ロールバック
    EXCEPTION
      WHEN OTHERS THEN
        IlRTN       := c_NRTN_9;
        -- ログ出力
        bRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSKCLKWR', 1, SQLCODE, SQLERRM,  VlERRBUF||' ZLBSKCLKWR ROLLBACK失敗'||' 国保世帯番号='||i_KOKU_SETAI_NO, '', i_VMASIN_NO);
    END;
  END IF;
  o_RTN := IlRTN;
-- 例外処理
EXCEPTION
  WHEN OTHERS THEN
    -- 異常終了
    IlRTN       := c_NRTN_9;
    -- ログ出力
        bRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSKCLKWR', 1, SQLCODE, SQLERRM,  VlERRBUF|| ' ZLBSKCLKWR 例外エラー ' ||' 国保世帯番号='||i_KOKU_SETAI_NO, '', i_VMASIN_NO);
  o_RTN := IlRTN;
END ZLBSKCLKWR ;
/