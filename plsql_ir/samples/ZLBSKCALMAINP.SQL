CREATE OR REPLACE PROCEDURE ZLBSKCALMAINP (i_NSETAI        IN  NUMBER,
--1.1.200.000
                                            i_NDANTAI       IN  NUMBER,
                                            i_NNENDO        IN  NUMBER,
                                            i_NNENDO_BUN    IN  NUMBER,
                                            i_NTSUCHI_NO    IN  NUMBER,
                                            i_NSYS_SHOKUIN  IN  CHAR,
                                            i_NJIKKOU_KBN   IN  NUMBER,
                                            i_VTANMATSU     IN  NVARCHAR2,
                                            i_NTRENBAN      IN  NUMBER,
                                            o_NRESULT       OUT NUMBER)
-------------------------------------------------------------------------------
-- 業務名   ZLB（国保税）
-- ＰＧ名   ZLBSKCALMAINP
-- 名称     過年度分年税額算出
-- 処理概要 作成した計算基本/退職/介護基本/介護退職TBLの各レコードより
--          過年度分、年税額を算出する。
-- 引き数   i_NSETAI            国保世帯番号
--          i_NDANTAI           算定団体コード
--          i_NNENDO            調定年度
--          i_NNENDO_BUN        年度分
--          i_NSYS_SHOKUIN      職員個人番号
--          i_NJIKKOU_KBN       実行区分(0:バッチから起動 本算定/月例...
--                                       1:オンライン起動 即時)
--          i_VTANMATSU         端末番号
--          i_NTRENBAN          登録連番
--          o_NRESULT           処理結果(0:正常 8:減額処理不可能 9:異常)
-- 作成者   ZCZL.FUBOYU
-- 作成日   2023/08/01
-- Version  0.2.000.000
-------------------------------------------------------------------------------
--  変更履歴
--  2025/08/11 ZCZL.HAODAPENG UPDATE 1.1.200.000:子ども子育て支援金対応
-------------------------------------------------------------------------------
IS
-------------------------------------------------------------------------------
-- 定数の定義
-------------------------------------------------------------------------------
    c_NOK           CONSTANT NUMBER := 0;
    c_NERR          CONSTANT NUMBER := 9;

    -- 実行区分
    c_NBATCH        CONSTANT NUMBER := 0;


    -- 処理TBL種別
    c_NKIHON        CONSTANT NUMBER := 0;           -- 基本
    c_NTAI          CONSTANT NUMBER := 1;           -- 退職
    c_NKAIKIHON     CONSTANT NUMBER := 2;           -- 介護基本
    c_NKAITAI       CONSTANT NUMBER := 3;           -- 介護退職
    c_NSIENKIHON    CONSTANT NUMBER := 4;           -- 支援基本
    c_NSIENTAI      CONSTANT NUMBER := 5;           -- 支援退職
    --  2025/08/11 ZCZL.HAODAPENG ADD 1.1.200.000:子ども子育て支援金対応
    c_NKDMKIHON     CONSTANT NUMBER := 6;           -- 子ども基本


    -- 年税額端数
    c_NHASU_1           CONSTANT NUMBER := 1000;
    c_NHASU_2           CONSTANT NUMBER := 100;
    c_NHASU_3           CONSTANT NUMBER := 1;
    c_NHASU_10          CONSTANT NUMBER := 10;
    c_NHASU_KBN_1       CONSTANT NUMBER := 1;       -- c_NHASU_1に対応
    c_NHASU_KBN_2       CONSTANT NUMBER := 0;       -- c_NHASU_2に対応
    c_NHASU_KBN_3       CONSTANT NUMBER := 2;       -- c_NHASU_3に対応
    c_NHASU_KBN_10      CONSTANT NUMBER := 3;

    c_NRNO_CNT          CONSTANT NUMBER := 10;      -- 履歴番号カウントアップ値

    -- 算定団体コード
    c_NDANTAI           CONSTANT NUMBER(2) := 1;    -- 合併後算定団体コード

    -- 不均一課税
    c_NFKAZEI           CONSTANT NUMBER := 1;       -- 不均一課税を行なう

    c_NZO               CONSTANT NUMBER := 0;       -- 増
    c_NGEN              CONSTANT NUMBER := 1;       -- 減

    IR_NENZEI           NUMBER := 0;                -- 医療全体_年税額(課税計算結果)
    KAI_NENZEI          NUMBER := 0;                -- 介護全体_年税額(課税計算結果)
    SIEN_NENZEI         NUMBER := 0;                -- 支援全体_年税額(課税計算結果)
    IR_NENZEI_KEI       NUMBER := 0;                -- 医療全体_年税額(前回賦課)
    KAI_NENZEI_KEI      NUMBER := 0;                -- 介護全体_年税額(前回賦課)
    SIEN_NENZEI_KEI     NUMBER := 0;                -- 支援全体_年税額(前回賦課)
    TOTAL_GEN_FLG       NUMBER := 0;                -- 総額減額フラグ
    --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
    KDM_NENZEI         NUMBER := 0;                -- 子ども全体_年税額(課税計算結果)
    KDM_NENZEI_KEI     NUMBER := 0;                -- 子ども全体_年税額(前回賦課)
    --  2025/08/11 ZCZL.HAODAPENG ADD END

-------------------------------------------------------------------------------
-- ワークエリアの定義
-------------------------------------------------------------------------------
    NlRTN                   NUMBER;             -- 戻り値
    VlMSG                   NVARCHAR2(256);     -- ログ用メッセージ
    BlRTN                   BOOLEAN;            -- ログ出力用戻り値

    NlHASU_IRY              NUMBER;     -- 医療端数金額
    NlHASU_KAI              NUMBER;     -- 介護端数金額
    NlHASU_SIEN             NUMBER;     --支援端数金額
    NlNENZEI                NUMBER;     -- 今回計算した結果の年税額
    NlHASU                  NUMBER;     --                   端数金額
    NlNENZEI_KEI            NUMBER;     -- 賦課を集計した年税額(過計)
    NlHASU_KEI              NUMBER;     --               端数金額(過計)
    NlNENZEI_SO             NUMBER;     -- 賦課を集計した年税額(総計)
    NlHASU_SO               NUMBER;     --               端数金額(総計)

    NlDATE                  NUMBER;
    NlTIME                  NUMBER;
    NlIRYHANTEI             NUMBER;
    NlKAIHANTEI             NUMBER;
    NlSIENHANTEI            NUMBER;

    NwIRYSAGAKU             NUMBER;     -- 医療差額
    NwKAISAGAKU             NUMBER;     -- 介護差額
    NwSIENSAGAKU            NUMBER;     --支援差額

    NlIRY_ZOGEN             NUMBER;     -- 医療増減判定
    NlKAI_ZOGEN             NUMBER;     -- 介護増減判定
    NlSIEN_ZOGEN            NUMBER;     --支援増減判定
    NlGENDOGAKU_IRY         NUMBER;     -- 医療賦課限度額
    NlGENDOGAKU_KAI         NUMBER;     -- 医療賦課限度額
    NlGENDOGAKU_SIEN        NUMBER;     --支援賦課限度額

    NlNUSHI_KOJIN_NO        NUMBER;     -- 世帯主個人番号

    NlNUSHI_KAZEI           NUMBER;     -- 主課税条件

    NlCNT                   NUMBER;     --減免個人有無
    --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
    NlHASU_KDM              NUMBER;     -- 子ども端数金額
    NlKDMHANTEI             NUMBER;     -- 子ども判定
    NwKDMSAGAKU             NUMBER;     -- 子ども差額
    NlKDM_ZOGEN             NUMBER;     -- 子ども増減判定
    NlGENDOGAKU_KDM         NUMBER;     -- 子ども賦課限度額
    --  2025/08/11 ZCZL.HAODAPENG ADD END

-------------------------------------------------------------------------------
--  17 不要情報削除
-------------------------------------------------------------------------------
    PROCEDURE subDeleteCal IS

        -- 対象者把握（新規過年度で全体年税額＝0）
        CURSOR CwTAISHO IS
            SELECT KIHON.*
            FROM   ZLBTKIHON_CAL KIHON,
                   ZLBTKAI_KIHON_CAL KAI,
                   ZLBTSIEN_KIHON_CAL SIEN
                   --  2025/08/11 ZCZL.HAODAPENG ADD 1.1.200.000:子ども子育て支援金対応
                   ,ZLBTKDM_KIHON_CAL KDM
            WHERE  KIHON.KOKU_SETAI_NO = KAI.KOKU_SETAI_NO
              AND  KIHON.SANTEIDANTAI_CD = KAI.SANTEIDANTAI_CD
              AND  KIHON.CHOTEI_NENDO = KAI.CHOTEI_NENDO
              AND  KIHON.NENDO_BUN = KAI.NENDO_BUN
              AND  KIHON.TSUCHI_NO = KAI.TSUCHI_NO
              AND  KIHON.SYS_TANMATSU_NO = KAI.SYS_TANMATSU_NO
              AND  KIHON.KOKU_SETAI_NO = SIEN.KOKU_SETAI_NO
              AND  KIHON.SANTEIDANTAI_CD = SIEN.SANTEIDANTAI_CD
              AND  KIHON.CHOTEI_NENDO = SIEN.CHOTEI_NENDO
              AND  KIHON.NENDO_BUN = SIEN.NENDO_BUN
              AND  KIHON.TSUCHI_NO = SIEN.TSUCHI_NO
              AND  KIHON.SYS_TANMATSU_NO = SIEN.SYS_TANMATSU_NO
              --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
              AND  KIHON.KOKU_SETAI_NO = KDM.KOKU_SETAI_NO
              AND  KIHON.SANTEIDANTAI_CD = KDM.SANTEIDANTAI_CD
              AND  KIHON.CHOTEI_NENDO = KDM.CHOTEI_NENDO
              AND  KIHON.NENDO_BUN = KDM.NENDO_BUN
              AND  KIHON.TSUCHI_NO = KDM.TSUCHI_NO
              AND  KIHON.SYS_TANMATSU_NO = KDM.SYS_TANMATSU_NO
              --  2025/08/11 ZCZL.HAODAPENG ADD END
              AND  KIHON.CHOTEI_NENDO <> KIHON.NENDO_BUN
              AND  KIHON.R_NO = 10
              --  2025/08/11 ZCZL.HAODAPENG UPDATE 1.1.200.000:子ども子育て支援金対応
              --  AND  KIHON.NENZEI + KAI.NENZEI + SIEN.NENZEI = 0;
              AND  KIHON.NENZEI + KAI.NENZEI + SIEN.NENZEI + KDM.NENZEI = 0;

    BEGIN

        -- 対象データから各情報を削除
        FOR RwTAISHO IN CwTAISHO LOOP
            -- 計算基本
            DELETE FROM ZLBTKIHON_CAL
            WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
              AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
              AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
              AND  NENDO_BUN = RwTAISHO.NENDO_BUN
              AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
              AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
            -- 計算退職
            DELETE FROM ZLBTTAI_CAL
            WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
              AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
              AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
              AND  NENDO_BUN = RwTAISHO.NENDO_BUN
              AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
              AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
            -- 計算介護基本
            DELETE FROM ZLBTKAI_KIHON_CAL
            WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
              AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
              AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
              AND  NENDO_BUN = RwTAISHO.NENDO_BUN
              AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
              AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
            -- 計算介護退職
            DELETE FROM ZLBTKAI_TAI_CAL
            WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
              AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
              AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
              AND  NENDO_BUN = RwTAISHO.NENDO_BUN
              AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
              AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
            -- 計算支援基本
            DELETE FROM ZLBTSIEN_KIHON_CAL
            WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
              AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
              AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
              AND  NENDO_BUN = RwTAISHO.NENDO_BUN
              AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
              AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
            -- 計算支援退職
            DELETE FROM ZLBTSIEN_TAI_CAL
            WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
              AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
              AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
              AND  NENDO_BUN = RwTAISHO.NENDO_BUN
              AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
              AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
            -- 計算個人
            DELETE FROM ZLBTKOJIN_CAL
            WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
              AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
              AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
              AND  NENDO_BUN = RwTAISHO.NENDO_BUN
              AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
              AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
            -- 計算所得
            DELETE FROM ZLBTSHOTOKU_CAL
            WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
              AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
              AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
              AND  NENDO_BUN = RwTAISHO.NENDO_BUN
              AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
              AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
            -- 計算期別
            DELETE FROM ZLBTKIBETSU_CAL
            WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
              AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
              AND  CHOTEINENDO = RwTAISHO.CHOTEI_NENDO
              AND  NENDOBUN = RwTAISHO.NENDO_BUN
              AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
              AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
            -- 計算拡張
            DELETE FROM ZLBTEXT_CAL
            WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
              AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
              AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
              AND  NENDO_BUN = RwTAISHO.NENDO_BUN
              AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
              AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
            -- 計算特徴対象者
            DELETE FROM ZLBTTOKU_KIHON_CAL
            WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
              AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
              AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
              AND  NENDO_BUN = RwTAISHO.NENDO_BUN
              AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
              AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
            -- 計算緩和世帯
            DELETE FROM ZLBTKANWA_SETAI_CAL
            WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
              AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
              AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
              AND  NENDO_BUN = RwTAISHO.NENDO_BUN
              AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
              AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
            -- 計算緩和個人
            DELETE FROM ZLBTKANWA_KOJIN_CAL
            WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
              AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
              AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
              AND  NENDO_BUN = RwTAISHO.NENDO_BUN
              AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
              AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
            --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
            DELETE FROM ZLBTKDM_KIHON_CAL
            WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
              AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
              AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
              AND  NENDO_BUN = RwTAISHO.NENDO_BUN
              AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
              AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
            --  2025/08/11 ZCZL.HAODAPENG ADD END
            -- 計算減免個人
            IF NlCNT > 0 THEN
              DELETE FROM ZLBTGENMEN_KOJIN_CAL
              WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
                AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
                AND  CHOTEI_NENDO = RwTAISHO.NENDO_BUN
                AND  NENDO_BUN = RwTAISHO.NENDO_BUN
                AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
                AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
            END IF;
            -- FIRST_FETCH_ROWのみ
            EXIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subDeleteCal 不要情報削除' || SQLERRM;
    END subDeleteCal;
-------------------------------------------------------------------------------
--  16 退職税額補正処理
-------------------------------------------------------------------------------
    PROCEDURE subUpdTai IS

      NwKENSU             NUMBER;                   -- 件数
      NwSAGAKU            NUMBER;                   -- 差額
      NwTAI_NENZEI        NUMBER;                   -- 退職税額
      NwTAI_NENZEI_MAE    NUMBER;                   --更正前退職税額

        -- 対象者把握（全体税額＜退職税額）
        CURSOR CwTAISHO IS
            SELECT SUM(KENSU) KENSU
            FROM  (SELECT NVL(COUNT(*),0) KENSU
                   FROM   ZLBTKIHON_CAL KIHON,
                          ZLBTTAI_CAL TAI
                   WHERE  KIHON.KOKU_SETAI_NO = TAI.KOKU_SETAI_NO
                     AND  KIHON.SANTEIDANTAI_CD = TAI.SANTEIDANTAI_CD
                     AND  KIHON.CHOTEI_NENDO = TAI.CHOTEI_NENDO
                     AND  KIHON.NENDO_BUN = TAI.NENDO_BUN
                     AND  KIHON.TSUCHI_NO = TAI.TSUCHI_NO
                     AND  KIHON.SYS_TANMATSU_NO = TAI.SYS_TANMATSU_NO
                     AND  KIHON.KOKU_SETAI_NO = i_NSETAI
                     AND  KIHON.SANTEIDANTAI_CD = i_NDANTAI
                     AND  KIHON.NENDO_BUN = i_NNENDO_BUN
                     AND  KIHON.SYS_TANMATSU_NO = i_VTANMATSU
                     AND  KIHON.NENZEI < TAI.NENZEI
                   UNION
                   SELECT NVL(COUNT(*),0) KENSU
                   FROM   ZLBTKAI_KIHON_CAL KIHON,
                          ZLBTKAI_TAI_CAL TAI
                   WHERE  KIHON.KOKU_SETAI_NO = TAI.KOKU_SETAI_NO
                     AND  KIHON.SANTEIDANTAI_CD = TAI.SANTEIDANTAI_CD
                     AND  KIHON.CHOTEI_NENDO = TAI.CHOTEI_NENDO
                     AND  KIHON.NENDO_BUN = TAI.NENDO_BUN
                     AND  KIHON.TSUCHI_NO = TAI.TSUCHI_NO
                     AND  KIHON.SYS_TANMATSU_NO = TAI.SYS_TANMATSU_NO
                     AND  KIHON.KOKU_SETAI_NO = i_NSETAI
                     AND  KIHON.SANTEIDANTAI_CD = i_NDANTAI
                     AND  KIHON.NENDO_BUN = i_NNENDO_BUN
                     AND  KIHON.SYS_TANMATSU_NO = i_VTANMATSU
                     AND  KIHON.NENZEI < TAI.NENZEI
                   UNION
                   SELECT NVL(COUNT(*),0) KENSU
                   FROM   ZLBTSIEN_KIHON_CAL KIHON,
                          ZLBTSIEN_TAI_CAL TAI
                   WHERE  KIHON.KOKU_SETAI_NO = TAI.KOKU_SETAI_NO
                     AND  KIHON.SANTEIDANTAI_CD = TAI.SANTEIDANTAI_CD
                     AND  KIHON.CHOTEI_NENDO = TAI.CHOTEI_NENDO
                     AND  KIHON.NENDO_BUN = TAI.NENDO_BUN
                     AND  KIHON.TSUCHI_NO = TAI.TSUCHI_NO
                     AND  KIHON.SYS_TANMATSU_NO = TAI.SYS_TANMATSU_NO
                     AND  KIHON.KOKU_SETAI_NO = i_NSETAI
                     AND  KIHON.SANTEIDANTAI_CD = i_NDANTAI
                     AND  KIHON.NENDO_BUN = i_NNENDO_BUN
                     AND  KIHON.SYS_TANMATSU_NO = i_VTANMATSU
                     AND  KIHON.NENZEI < TAI.NENZEI);

        -- 全体税額／退職税額カーソル（医療）
        CURSOR CwTAISHO_IRY IS
            SELECT KIHON.KOKU_SETAI_NO   KOKU_SETAI_NO,
                   KIHON.SANTEIDANTAI_CD SANTEIDANTAI_CD,
                   KIHON.CHOTEI_NENDO    CHOTEI_NENDO,
                   KIHON.NENDO_BUN       NENDO_BUN,
                   KIHON.TSUCHI_NO       TSUCHI_NO,
                   KIHON.SYS_TANMATSU_NO SYS_TANMATSU_NO,
                   KIHON.KANENDO         ZEN_KANENDO,
                   KIHON.NENZEI          ZEN_NENZEI,
                   TAI.SEKISAN           TAI_SEKISAN,
                   TAI.GENGAKU_KEI       TAI_GENGAKU_KEI,
                   TAI.GENMEN            TAI_GENMEN,
                   TAI.NENZEI            TAI_NENZEI
            FROM   ZLBTKIHON_CAL KIHON,
                   ZLBTTAI_CAL TAI
            WHERE  KIHON.KOKU_SETAI_NO = TAI.KOKU_SETAI_NO
              AND  KIHON.SANTEIDANTAI_CD = TAI.SANTEIDANTAI_CD
              AND  KIHON.CHOTEI_NENDO = TAI.CHOTEI_NENDO
              AND  KIHON.NENDO_BUN = TAI.NENDO_BUN
              AND  KIHON.TSUCHI_NO = TAI.TSUCHI_NO
              AND  KIHON.SYS_TANMATSU_NO = TAI.SYS_TANMATSU_NO
              AND  KIHON.KOKU_SETAI_NO = i_NSETAI
              AND  KIHON.SANTEIDANTAI_CD = i_NDANTAI
              AND  KIHON.NENDO_BUN = i_NNENDO_BUN
              AND  KIHON.SYS_TANMATSU_NO = i_VTANMATSU
              AND  KIHON.NENZEI + TAI.NENZEI > 0
            ORDER  BY KOKU_SETAI_NO,
                      SANTEIDANTAI_CD,
                      CHOTEI_NENDO DESC,
                      NENDO_BUN DESC,
                      TSUCHI_NO;

        -- 全体税額／退職税額カーソル（介護）
        CURSOR CwTAISHO_KAI IS
            SELECT KIHON.KOKU_SETAI_NO   KOKU_SETAI_NO,
                   KIHON.SANTEIDANTAI_CD SANTEIDANTAI_CD,
                   KIHON.CHOTEI_NENDO    CHOTEI_NENDO,
                   KIHON.NENDO_BUN       NENDO_BUN,
                   KIHON.TSUCHI_NO       TSUCHI_NO,
                   KIHON.SYS_TANMATSU_NO SYS_TANMATSU_NO,
                   KIHON.KANENDO         ZEN_KANENDO,
                   KIHON.NENZEI          ZEN_NENZEI,
                   TAI.SEKISAN           TAI_SEKISAN,
                   TAI.GENGAKU_KEI       TAI_GENGAKU_KEI,
                   TAI.GENMEN            TAI_GENMEN,
                   TAI.NENZEI            TAI_NENZEI
            FROM   ZLBTKAI_KIHON_CAL KIHON,
                   ZLBTKAI_TAI_CAL TAI
            WHERE  KIHON.KOKU_SETAI_NO = TAI.KOKU_SETAI_NO
              AND  KIHON.SANTEIDANTAI_CD = TAI.SANTEIDANTAI_CD
              AND  KIHON.CHOTEI_NENDO = TAI.CHOTEI_NENDO
              AND  KIHON.NENDO_BUN = TAI.NENDO_BUN
              AND  KIHON.TSUCHI_NO = TAI.TSUCHI_NO
              AND  KIHON.SYS_TANMATSU_NO = TAI.SYS_TANMATSU_NO
              AND  KIHON.KOKU_SETAI_NO = i_NSETAI
              AND  KIHON.SANTEIDANTAI_CD = i_NDANTAI
              AND  KIHON.NENDO_BUN = i_NNENDO_BUN
              AND  KIHON.SYS_TANMATSU_NO = i_VTANMATSU
              AND  KIHON.NENZEI + TAI.NENZEI > 0
            ORDER  BY KOKU_SETAI_NO,
                      SANTEIDANTAI_CD,
                      CHOTEI_NENDO DESC,
                      NENDO_BUN DESC,
                      TSUCHI_NO;

        -- 全体税額／退職税額カーソル（支援）
        CURSOR CwTAISHO_SIEN IS
            SELECT KIHON.KOKU_SETAI_NO   KOKU_SETAI_NO,
                   KIHON.SANTEIDANTAI_CD SANTEIDANTAI_CD,
                   KIHON.CHOTEI_NENDO    CHOTEI_NENDO,
                   KIHON.NENDO_BUN       NENDO_BUN,
                   KIHON.TSUCHI_NO       TSUCHI_NO,
                   KIHON.SYS_TANMATSU_NO SYS_TANMATSU_NO,
                   KIHON.KANENDO         ZEN_KANENDO,
                   KIHON.NENZEI          ZEN_NENZEI,
                   TAI.SEKISAN           TAI_SEKISAN,
                   TAI.GENGAKU_KEI       TAI_GENGAKU_KEI,
                   TAI.GENMEN            TAI_GENMEN,
                   TAI.NENZEI            TAI_NENZEI
            FROM   ZLBTSIEN_KIHON_CAL KIHON,
                   ZLBTSIEN_TAI_CAL TAI
            WHERE  KIHON.KOKU_SETAI_NO = TAI.KOKU_SETAI_NO
              AND  KIHON.SANTEIDANTAI_CD = TAI.SANTEIDANTAI_CD
              AND  KIHON.CHOTEI_NENDO = TAI.CHOTEI_NENDO
              AND  KIHON.NENDO_BUN = TAI.NENDO_BUN
              AND  KIHON.TSUCHI_NO = TAI.TSUCHI_NO
              AND  KIHON.SYS_TANMATSU_NO = TAI.SYS_TANMATSU_NO
              AND  KIHON.KOKU_SETAI_NO = i_NSETAI
              AND  KIHON.SANTEIDANTAI_CD = i_NDANTAI
              AND  KIHON.NENDO_BUN = i_NNENDO_BUN
              AND  KIHON.SYS_TANMATSU_NO = i_VTANMATSU
              AND  KIHON.NENZEI + TAI.NENZEI > 0
            ORDER  BY KOKU_SETAI_NO,
                      SANTEIDANTAI_CD,
                      CHOTEI_NENDO DESC,
                      NENDO_BUN DESC,
                      TSUCHI_NO;

    BEGIN

        -- 対象件数を取得
        FOR RwTAISHO IN CwTAISHO LOOP
            NwKENSU := RwTAISHO.KENSU;
            -- FIRST_FETCH_ROWのみ
            EXIT;
        END LOOP;

        -- 対象者が存在する場合のみ処理を行う
        IF NwKENSU > 0 THEN
            -- 変数初期化
            NwSAGAKU := 0;
            -- 医療カーソルデータ分までLOOP
            FOR RwTAISHO IN CwTAISHO_IRY LOOP
                -- 退職税額変数の初期化
                NwTAI_NENZEI := 0;
                -- FIRST_FETCH_ROWで退職税額＞全体税額の場合
                IF NwSAGAKU = 0 AND RwTAISHO.TAI_NENZEI >= RwTAISHO.ZEN_NENZEI THEN
                    -- 退職税額－全体税額の差額を算出する
                    NwSAGAKU := NVL(RwTAISHO.TAI_NENZEI,0) - NVL(RwTAISHO.ZEN_NENZEI,0);
                    -- 全体税額を退職税額とする
                    NwTAI_NENZEI := RwTAISHO.ZEN_NENZEI;
                ELSE
                    -- 2件目以降で退職税額－全体税額の差額＞全体税額の場合
                    IF NwSAGAKU > RwTAISHO.ZEN_NENZEI THEN
                        -- 差額を再算出する
                        NwSAGAKU := NwSAGAKU - RwTAISHO.ZEN_NENZEI;
                        -- 全体税額を退職税額とする
                        NwTAI_NENZEI := RwTAISHO.ZEN_NENZEI;
                    ELSE
--                        -- 差額を退職税額とする
--                        -- 差額の初期化
                        -- 差額が端数金額以上の場合
                        IF NwSAGAKU >= NlHASU_IRY THEN
                            -- 更正前退職税額を取得する
                            NwTAI_NENZEI_MAE := 0;
                            FOR vRec IN (SELECT NENZEI
                                         FROM   ZLBTTAI_N
                                         WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
                                           AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
                                           AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
                                           AND  NENDO_BUN = RwTAISHO.NENDO_BUN
                                           AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
                                           ) LOOP
                                NwTAI_NENZEI_MAE := vRec.NENZEI;
                                EXIT;
                            END LOOP;
                            -- 更正前退職税額に差額を加算する
                            NwTAI_NENZEI := NwTAI_NENZEI_MAE + NwSAGAKU;
                            -- 差額の初期化
                            NwSAGAKU := 0;
                        END IF;
                    END IF;
                END IF;
                -- 退職税額変数＞0の場合
                IF  NwTAI_NENZEI > 0 OR RwTAISHO.ZEN_NENZEI = 0 THEN
                    -- 退職税額を更新する
                    UPDATE ZLBTTAI_CAL
                    SET    NENZEI = NwTAI_NENZEI
                    WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
                      AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
                      AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
                      AND  NENDO_BUN = RwTAISHO.NENDO_BUN
                      AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
                      AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
                    -- 差額が年税額端数条件未満の場合、差額を端数により調整する
                    IF NwSAGAKU > 0 AND NwSAGAKU < NlHASU_IRY THEN
                        UPDATE ZLBTTAI_CAL
                        SET    HASU = HASU + NwSAGAKU,
                               GENGAKU_KEI = GENGAKU_KEI + NwSAGAKU
                        WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
                          AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
                          AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
                          AND  NENDO_BUN = RwTAISHO.NENDO_BUN
                          AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
                          AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
                        -- 差額の初期化
                        NwSAGAKU := 0;
                    END IF;
                ELSE
                    EXIT;
                END IF;
            END LOOP;

            -- 変数初期化
            NwSAGAKU := 0;
            -- 介護カーソルデータ分までLOOP
            FOR RwTAISHO IN CwTAISHO_KAI LOOP
                -- 退職税額変数の初期化
                NwTAI_NENZEI := 0;
                -- FIRST_FETCH_ROWで退職税額＞全体税額の場合
                IF NwSAGAKU = 0 AND RwTAISHO.TAI_NENZEI >= RwTAISHO.ZEN_NENZEI THEN
                    -- 退職税額－全体税額の差額を算出する
                    NwSAGAKU := NVL(RwTAISHO.TAI_NENZEI,0) - NVL(RwTAISHO.ZEN_NENZEI,0);
                    -- 全体税額を退職税額とする
                    NwTAI_NENZEI := RwTAISHO.ZEN_NENZEI;
                ELSE
                    -- 2件目以降で退職税額－全体税額の差額＞全体税額の場合
                    IF NwSAGAKU > RwTAISHO.ZEN_NENZEI THEN
                        -- 差額を再算出する
                        NwSAGAKU := NwSAGAKU - RwTAISHO.ZEN_NENZEI;
                        -- 全体税額を退職税額とする
                        NwTAI_NENZEI := RwTAISHO.ZEN_NENZEI;
                    ELSE
--                        -- 差額を退職税額とする
--                        -- 差額の初期化
                        -- 差額が端数金額以上の場合
                        IF NwSAGAKU >= NlHASU_KAI THEN
                            -- 更正前退職税額を取得する
                            NwTAI_NENZEI_MAE := 0;
                            FOR vRec IN (SELECT NENZEI
                                         FROM   ZLBTKAI_TAI_N
                                         WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
                                           AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
                                           AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
                                           AND  NENDO_BUN = RwTAISHO.NENDO_BUN
                                           AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
                                           ) LOOP
                                NwTAI_NENZEI_MAE := vRec.NENZEI;
                                EXIT;
                            END LOOP;
                            -- 更正前退職税額に差額を加算する
                            NwTAI_NENZEI := NwTAI_NENZEI_MAE + NwSAGAKU;
                            -- 差額の初期化
                            NwSAGAKU := 0;
                        END IF;
                    END IF;
                END IF;
                -- 退職税額変数＞0の場合
                IF  NwTAI_NENZEI > 0 OR RwTAISHO.ZEN_NENZEI = 0 THEN
                    -- 退職税額を更新する
                    UPDATE ZLBTKAI_TAI_CAL
                    SET    NENZEI = NwTAI_NENZEI
                    WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
                      AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
                      AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
                      AND  NENDO_BUN = RwTAISHO.NENDO_BUN
                      AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
                      AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
                    -- 差額が年税額端数条件未満の場合、差額を端数により調整する
                    IF NwSAGAKU > 0 AND NwSAGAKU < NlHASU_KAI THEN
                        UPDATE ZLBTKAI_TAI_CAL
                        SET    HASU = HASU + NwSAGAKU,
                               GENGAKU_KEI = GENGAKU_KEI + NwSAGAKU
                        WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
                          AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
                          AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
                          AND  NENDO_BUN = RwTAISHO.NENDO_BUN
                          AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
                          AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
                          -- 差額の初期化
                        NwSAGAKU := 0;
                    END IF;
                ELSE
                    EXIT;
                END IF;
            END LOOP;

            -- 変数初期化
            NwSAGAKU := 0;
            -- 支援カーソルデータ分までLOOP
            FOR RwTAISHO IN CwTAISHO_SIEN LOOP
                -- 退職税額変数の初期化
                NwTAI_NENZEI := 0;
                -- FIRST_FETCH_ROWで退職税額＞全体税額の場合
                IF NwSAGAKU = 0 AND RwTAISHO.TAI_NENZEI >= RwTAISHO.ZEN_NENZEI THEN
                    -- 退職税額－全体税額の差額を算出する
                    NwSAGAKU := NVL(RwTAISHO.TAI_NENZEI,0) - NVL(RwTAISHO.ZEN_NENZEI,0);
                    -- 全体税額を退職税額とする
                    NwTAI_NENZEI := RwTAISHO.ZEN_NENZEI;
                ELSE
                    -- 2件目以降で退職税額－全体税額の差額＞全体税額の場合
                    IF NwSAGAKU > RwTAISHO.ZEN_NENZEI THEN
                        -- 差額を再算出する
                        NwSAGAKU := NwSAGAKU - RwTAISHO.ZEN_NENZEI;
                        -- 全体税額を退職税額とする
                        NwTAI_NENZEI := RwTAISHO.ZEN_NENZEI;
                    ELSE
--                        -- 差額を退職税額とする
--                        -- 差額の初期化
                        -- 差額が端数金額以上の場合
                        IF NwSAGAKU >= NlHASU_SIEN THEN
                            -- 更正前退職税額を取得する
                            NwTAI_NENZEI_MAE := 0;
                            FOR vRec IN (SELECT NENZEI
                                         FROM   ZLBTSIEN_TAI_N
                                         WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
                                           AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
                                           AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
                                           AND  NENDO_BUN = RwTAISHO.NENDO_BUN
                                           AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
                                           ) LOOP
                                NwTAI_NENZEI_MAE := vRec.NENZEI;
                                EXIT;
                            END LOOP;
                            -- 更正前退職税額に差額を加算する
                            NwTAI_NENZEI := NwTAI_NENZEI_MAE + NwSAGAKU;
                            -- 差額の初期化
                            NwSAGAKU := 0;
                        END IF;
                    END IF;
                END IF;
                -- 退職税額変数＞0の場合
                IF  NwTAI_NENZEI > 0 OR RwTAISHO.ZEN_NENZEI = 0 THEN
                    -- 退職税額を更新する
                    UPDATE ZLBTSIEN_TAI_CAL
                    SET    NENZEI = NwTAI_NENZEI
                    WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
                      AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
                      AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
                      AND  NENDO_BUN = RwTAISHO.NENDO_BUN
                      AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
                      AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
                    -- 差額が年税額端数条件未満の場合、差額を端数により調整する
                    IF NwSAGAKU > 0 AND NwSAGAKU < NlHASU_SIEN THEN
                        UPDATE ZLBTSIEN_TAI_CAL
                        SET    HASU = HASU + NwSAGAKU,
                               GENGAKU_KEI = GENGAKU_KEI + NwSAGAKU
                        WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
                          AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
                          AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
                          AND  NENDO_BUN = RwTAISHO.NENDO_BUN
                          AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
                          AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
                        -- 差額の初期化
                        NwSAGAKU := 0;
                    END IF;
                ELSE
                    EXIT;
                END IF;
            END LOOP;

            -- 過年度税額の算出
            -- 医療カーソルデータ分までLOOP
            FOR RwTAISHO IN CwTAISHO_IRY LOOP
--                -- 退職税額変数の初期化
--                -- 指定年度以外の年税を算出する
                -- 退職税額変数＞0の場合
                IF RwTAISHO.TAI_SEKISAN - RwTAISHO.TAI_GENGAKU_KEI - RwTAISHO.TAI_GENMEN <> RwTAISHO.TAI_NENZEI THEN
                    -- 過年度退職税額を更新する
                    UPDATE ZLBTTAI_CAL
                    SET    KANENDO = RwTAISHO.TAI_SEKISAN - RwTAISHO.TAI_GENGAKU_KEI - RwTAISHO.TAI_GENMEN - RwTAISHO.TAI_NENZEI
                    WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
                      AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
                      AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
                      AND  NENDO_BUN = RwTAISHO.NENDO_BUN
                      AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
                      AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
                END IF;
            END LOOP;

            -- 過年度税額の算出
            -- 介護カーソルデータ分までLOOP
            FOR RwTAISHO IN CwTAISHO_KAI LOOP
--                -- 退職税額変数の初期化
--                -- 指定年度以外の年税を算出する
                -- 退職税額変数＞0の場合
                IF RwTAISHO.TAI_SEKISAN - RwTAISHO.TAI_GENGAKU_KEI - RwTAISHO.TAI_GENMEN <> RwTAISHO.TAI_NENZEI THEN
                    -- 過年度退職税額を更新する
                    UPDATE ZLBTKAI_TAI_CAL
                    SET    KANENDO = RwTAISHO.TAI_SEKISAN - RwTAISHO.TAI_GENGAKU_KEI - RwTAISHO.TAI_GENMEN - RwTAISHO.TAI_NENZEI
                    WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
                      AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
                      AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
                      AND  NENDO_BUN = RwTAISHO.NENDO_BUN
                      AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
                      AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
                END IF;
            END LOOP;

            -- 過年度税額の算出
            -- 支援カーソルデータ分までLOOP
            FOR RwTAISHO IN CwTAISHO_SIEN LOOP
--                -- 退職税額変数の初期化
--                -- 指定年度以外の年税を算出する
                -- 退職税額変数＞0の場合
                IF RwTAISHO.TAI_SEKISAN - RwTAISHO.TAI_GENGAKU_KEI - RwTAISHO.TAI_GENMEN <> RwTAISHO.TAI_NENZEI THEN
                    -- 過年度退職税額を更新する
                    UPDATE ZLBTSIEN_TAI_CAL
                    SET    KANENDO = RwTAISHO.TAI_SEKISAN - RwTAISHO.TAI_GENGAKU_KEI - RwTAISHO.TAI_GENMEN - RwTAISHO.TAI_NENZEI
                    WHERE  KOKU_SETAI_NO = RwTAISHO.KOKU_SETAI_NO
                      AND  SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
                      AND  CHOTEI_NENDO = RwTAISHO.CHOTEI_NENDO
                      AND  NENDO_BUN = RwTAISHO.NENDO_BUN
                      AND  TSUCHI_NO = RwTAISHO.TSUCHI_NO
                      AND  SYS_TANMATSU_NO = RwTAISHO.SYS_TANMATSU_NO;
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subUpdTai 退職税額補正処理' || SQLERRM;
    END subUpdTai;
-------------------------------------------------------------------------------
--  15-2 計算減免個人の追加
-------------------------------------------------------------------------------
    PROCEDURE subInsGENMENKOJIN(i_NwNENDO     IN NUMBER,
                                i_NwR_NO      IN NUMBER,
                                i_NwTSUCHI_NO IN NUMBER) IS

        NwCNT               NUMBER;

        -- 計算減免個人ｶｰｿﾙ
        CURSOR CwGKOJIN IS
            SELECT * FROM ZLBTGENMEN_KOJIN_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NTSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;

    BEGIN

        -- 既に登録済みかチェック
        SELECT COUNT(*) INTO NwCNT FROM ZLBTGENMEN_KOJIN_CAL
         WHERE KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND NENDO_BUN       = i_NNENDO_BUN
           AND TSUCHI_NO       = i_NwTSUCHI_NO
           AND SYS_TANMATSU_NO = i_VTANMATSU;

        -- 存在する場合は戻る
        IF NwCNT > 0 THEN
            RETURN;
        END IF;

        FOR RwExt IN CwGKOJIN LOOP

            -- 調定年度,履歴番号,通知書番号のセット
            RwExt.TSUCHI_NO           := i_NwTSUCHI_NO;
            RwExt.SYS_SAKUSEIBI       := NlDATE;
            RwExt.SYS_KOSHINBI        := NlDATE;
            RwExt.SYS_JIKAN           := NlTIME;
            RwExt.SYS_SHOKUINKOJIN_NO := i_NSYS_SHOKUIN;
            RwExt.SYS_TANMATSU_NO     := i_VTANMATSU;

            INSERT INTO ZLBTGENMEN_KOJIN_CAL VALUES RwExt;

        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subInsExt  計算減免個人作成' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;
    END subInsGENMENKOJIN;
-------------------------------------------------------------------------------
--  15 計算特徴対象者の追加
-------------------------------------------------------------------------------
    PROCEDURE subInsTokukihon(i_NwNENDO     IN NUMBER,
                              i_NwR_NO      IN NUMBER,
                              i_NwTSUCHI_NO IN NUMBER) IS

        NwCNT               NUMBER;

        -- 計算特徴対象者ｶｰｿﾙ
        CURSOR CwExt IS
            SELECT * FROM ZLBTTOKU_KIHON_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND CHOTEI_NENDO    = i_NNENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NTSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;

    BEGIN
        -- 既に登録済みかチェック
        SELECT COUNT(*) INTO NwCNT FROM ZLBTTOKU_KIHON_CAL
         WHERE KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND CHOTEI_NENDO    = i_NwNENDO
           AND NENDO_BUN       = i_NNENDO_BUN
           AND TSUCHI_NO       = i_NwTSUCHI_NO
           AND SYS_TANMATSU_NO = i_VTANMATSU;

        -- 存在する場合は戻る
        IF NwCNT > 0 THEN
            RETURN;
        END IF;

        FOR RwExt IN CwExt LOOP

            -- 調定年度,履歴番号,通知書番号のセット
            RwExt.CHOTEI_NENDO        := i_NwNENDO;
            RwExt.R_NO                := i_NwR_NO;
            RwExt.TSUCHI_NO           := i_NwTSUCHI_NO;
            RwExt.SYS_SAKUSEIBI       := NlDATE;
            RwExt.SYS_KOSHINBI        := NlDATE;
            RwExt.SYS_JIKAN           := NlTIME;
            RwExt.SYS_SHOKUINKOJIN_NO := i_NSYS_SHOKUIN;
            RwExt.SYS_TANMATSU_NO     := i_VTANMATSU;

            INSERT INTO ZLBTTOKU_KIHON_CAL VALUES RwExt;

        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subInsTokukihon 計算特徴対象者作成' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;
    END subInsTokukihon;

-------------------------------------------------------------------------------
--  14 計算拡張の追加
-------------------------------------------------------------------------------
    PROCEDURE subInsExt(i_NwNENDO     IN NUMBER,
                          i_NwR_NO      IN NUMBER,
                          i_NwTSUCHI_NO IN NUMBER) IS

        NwCNT               NUMBER;

        -- 計算賦課拡張ｶｰｿﾙ
        CURSOR CwExt IS
            SELECT * FROM ZLBTEXT_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND CHOTEI_NENDO    = i_NNENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NTSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;

    BEGIN

        -- 既に登録済みかチェック
        SELECT COUNT(*) INTO NwCNT FROM ZLBTEXT_CAL
         WHERE KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND CHOTEI_NENDO    = i_NwNENDO
           AND NENDO_BUN       = i_NNENDO_BUN
           AND TSUCHI_NO       = i_NwTSUCHI_NO
           AND SYS_TANMATSU_NO = i_VTANMATSU;

        -- 存在する場合は戻る
        IF NwCNT > 0 THEN
            RETURN;
        END IF;

        FOR RwExt IN CwExt LOOP

            -- 調定年度,履歴番号,通知書番号のセット
            RwExt.CHOTEI_NENDO        := i_NwNENDO;
            RwExt.R_NO                := i_NwR_NO;
            RwExt.TSUCHI_NO           := i_NwTSUCHI_NO;
            RwExt.SYS_SAKUSEIBI       := NlDATE;
            RwExt.SYS_KOSHINBI        := NlDATE;
            RwExt.SYS_JIKAN           := NlTIME;
            RwExt.SYS_SHOKUINKOJIN_NO := i_NSYS_SHOKUIN;
            RwExt.SYS_TANMATSU_NO     := i_VTANMATSU;

            INSERT INTO ZLBTEXT_CAL VALUES RwExt;

        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subInsExt 計算賦課拡張作成' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;
    END subInsExt;

-------------------------------------------------------------------------------
--  13 計算所得の追加
-------------------------------------------------------------------------------
    PROCEDURE subInsShotoku(i_NwNENDO       IN NUMBER,
                            i_NwR_NO        IN NUMBER,
                            i_NwTSUCHI_NO IN NUMBER) IS

        NwCNT               NUMBER;

        -- 計算所得ｶｰｿﾙ
        CURSOR CwSHOTOKU IS
            SELECT * FROM ZLBTSHOTOKU_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND CHOTEI_NENDO    = i_NNENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NTSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;

    BEGIN

        -- 既に登録済みかチェック
        SELECT COUNT(*) INTO NwCNT FROM ZLBTSHOTOKU_CAL
         WHERE KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND CHOTEI_NENDO    = i_NwNENDO
           AND NENDO_BUN       = i_NNENDO_BUN
           AND TSUCHI_NO       = i_NwTSUCHI_NO
           AND SYS_TANMATSU_NO = i_VTANMATSU;

        -- 存在する場合は戻る
        IF NwCNT > 0 THEN
            RETURN;
        END IF;

        FOR RwSHOTOKU IN CwSHOTOKU LOOP

            -- 調定年度,履歴番号,通知書番号のセット
            RwSHOTOKU.CHOTEI_NENDO        := i_NwNENDO;
            RwSHOTOKU.R_NO                := i_NwR_NO;
            RwSHOTOKU.TSUCHI_NO           := i_NwTSUCHI_NO;
            RwSHOTOKU.SYS_SAKUSEIBI       := NlDATE;
            RwSHOTOKU.SYS_KOSHINBI        := NlDATE;
            RwSHOTOKU.SYS_JIKAN           := NlTIME;
            RwSHOTOKU.SYS_SHOKUINKOJIN_NO := i_NSYS_SHOKUIN;
            RwSHOTOKU.SYS_TANMATSU_NO     := i_VTANMATSU;

            INSERT INTO ZLBTSHOTOKU_CAL VALUES RwSHOTOKU;

        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subInsShotoku 計算所得作成' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;
    END subInsShotoku;
-------------------------------------------------------------------------------
--  12 計算個人の追加
-------------------------------------------------------------------------------
    PROCEDURE subInsKojin(i_NwNENDO     IN NUMBER,
                          i_NwR_NO      IN NUMBER,
                          i_NwTSUCHI_NO IN NUMBER) IS

        NwCNT               NUMBER;

        -- 計算個人ｶｰｿﾙ
        CURSOR CwKOJIN IS
            SELECT * FROM ZLBTKOJIN_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND CHOTEI_NENDO    = i_NNENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NTSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;

    BEGIN

        -- 既に登録済みかチェック
        SELECT COUNT(*) INTO NwCNT FROM ZLBTKOJIN_CAL
         WHERE KOKU_SETAI_NO   = i_NSETAI
           AND SANTEIDANTAI_CD = i_NDANTAI
           AND CHOTEI_NENDO    = i_NwNENDO
           AND NENDO_BUN       = i_NNENDO_BUN
           AND TSUCHI_NO       = i_NwTSUCHI_NO
           AND SYS_TANMATSU_NO = i_VTANMATSU;

        -- 存在する場合は戻る
        IF NwCNT > 0 THEN
            RETURN;
        END IF;

        FOR RwKOJIN IN CwKOJIN LOOP

            -- 調定年度,履歴番号,通知書番号のセット
            RwKOJIN.CHOTEI_NENDO        := i_NwNENDO;
            RwKOJIN.R_NO                := i_NwR_NO;
            RwKOJIN.TSUCHI_NO           := i_NwTSUCHI_NO;
            RwKOJIN.SYS_SAKUSEIBI       := NlDATE;
            RwKOJIN.SYS_KOSHINBI        := NlDATE;
            RwKOJIN.SYS_JIKAN           := NlTIME;
            RwKOJIN.SYS_SHOKUINKOJIN_NO := i_NSYS_SHOKUIN;
            RwKOJIN.SYS_TANMATSU_NO     := i_VTANMATSU;

            INSERT INTO ZLBTKOJIN_CAL VALUES RwKOJIN;

        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subInsKojin 計算個人作成' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;
    END subInsKojin;
-------------------------------------------------------------------------------
--  11 テーブル名取得
-------------------------------------------------------------------------------
    FUNCTION funcGetTblnm(i_NwTBL IN NUMBER, i_NwKBN IN NUMBER) RETURN NVARCHAR2 IS
        VwTBL           NVARCHAR2(30);

    BEGIN
        VwTBL := NULL;

        CASE i_NwTBL
            WHEN c_NKIHON    THEN VwTBL := 'ZLBTKIHON';
            WHEN c_NTAI      THEN VwTBL := 'ZLBTTAI';
            WHEN c_NKAIKIHON THEN VwTBL := 'ZLBTKAI_KIHON';
            WHEN c_NKAITAI   THEN VwTBL := 'ZLBTKAI_TAI';
            WHEN c_NSIENKIHON THEN VwTBL := 'ZLBTSIEN_KIHON';
            WHEN c_NSIENTAI   THEN VwTBL := 'ZLBTSIEN_TAI';
            --  2025/08/11 ZCZL.HAODAPENG ADD 1.1.200.000:子ども子育て支援金対応
            WHEN c_NKDMKIHON  THEN VwTBL := 'ZLBTKDM_KIHON';
            ELSE NULL;
        END CASE;

        IF VwTBL IS NULL THEN
            NULL;
        ELSE
            IF i_NwKBN = 0 THEN
                VwTBL := VwTBL || '_CAL';
            ELSIF i_NwKBN = 1 THEN
                VwTBL := VwTBL || '_N';
            ELSE
                VwTBL := NULL;
            END IF;
        END IF;

        RETURN(VwTBL);

    END funcGetTblnm;
-------------------------------------------------------------------------------
--  10 端数金額取得処理
-------------------------------------------------------------------------------
    FUNCTION funcGetHasu(i_NwHASU_KBN IN NUMBER) RETURN NUMBER IS
    BEGIN
        CASE i_NwHASU_KBN
            WHEN c_NHASU_KBN_1 THEN RETURN(c_NHASU_1);
            WHEN c_NHASU_KBN_2 THEN RETURN(c_NHASU_2);
            WHEN c_NHASU_KBN_3 THEN RETURN(c_NHASU_3);
            WHEN c_NHASU_KBN_10 THEN RETURN(c_NHASU_10);
            ELSE RETURN(0);
        END CASE;
    END funcGetHasu;
-------------------------------------------------------------------------------
--  09 計算TBL存在チェックおよび追加更新
--      1.指定された計算TBLに該当レコードが存在するかチェック
--      2.存在しなければ賦課(最新)TBLの該当レコードを追加
-------------------------------------------------------------------------------
    PROCEDURE subSetFusokuCal(i_NwTBL       IN  NUMBER,
                              i_NwNENDO     IN  NUMBER,
                              i_NwR_NO      IN  NUMBER,
                              i_NwTSUCHI_NO IN  NUMBER) IS

        VwCALTBL            NVARCHAR2(30);      -- 計算TBL名
        VwNEWTBL            NVARCHAR2(30);      -- 賦課(最新)TBL名
        VwSQL               VARCHAR2(2048);     -- SQL文
        NwCNT               NUMBER;             -- レコード件数

        RwKIHON             ZLBTKIHON_CAL%ROWTYPE;
        RwKIHON_KIHON       ZLBTKIHON_N%ROWTYPE;
        RwTAI               ZLBTTAI_N%ROWTYPE;
        RwKKIHON            ZLBTKAI_KIHON_CAL%ROWTYPE;
        RwKKIHON_KIHON      ZLBTKAI_KIHON_N%ROWTYPE;
        RwKTAI              ZLBTKAI_TAI_N%ROWTYPE;
        RwSKIHON            ZLBTSIEN_KIHON_CAL%ROWTYPE;
        RwSKIHON_KIHON      ZLBTSIEN_KIHON_N%ROWTYPE;
        RwSTAI              ZLBTSIEN_TAI_N%ROWTYPE;
        NNENZEI_KEI         NUMBER(10,0) := 0;
        NNENZEI_KEI_KAI     NUMBER(10,0) := 0;
        NNENZEI_KEI_SIEN    NUMBER(10,0) := 0;
        --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
        RwKDMKIHON          ZLBTKDM_KIHON_CAL%ROWTYPE;
        RwKDMKIHON_KIHON    ZLBTKDM_KIHON_N%ROWTYPE;
        NNENZEI_KEI_KDM     NUMBER(10,0) := 0;
        --  2025/08/11 ZCZL.HAODAPENG ADD END
    BEGIN

        VwCALTBL := funcGetTblnm(i_NwTBL, 0);       -- 11 テーブル名取得(計算TBL)
        VwNEWTBL := funcGetTblnm(i_NwTBL, 1);       -- 11 テーブル名取得(賦課(最新)TBL)

        IF VwCALTBL IS NULL OR VwNEWTBL IS NULL THEN
            NlRTN := c_NERR;
            VlMSG := 'subSetFusokuCal ' || 'テーブル名取得' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;
        ELSE

            -- 1.指定された計算TBLに該当レコードが存在するかチェック
            VwSQL := 'SELECT COUNT(*) FROM '     || VwCALTBL      ||
                     ' WHERE KOKU_SETAI_NO = '   || i_NSETAI      ||
                     ' AND SANTEIDANTAI_CD = '   || i_NDANTAI     ||
                     ' AND CHOTEI_NENDO = '      || i_NwNENDO     ||
                     ' AND NENDO_BUN = '         || i_NNENDO_BUN  ||
                     ' AND TSUCHI_NO = '         || i_NwTSUCHI_NO ||
                     ' AND SYS_TANMATSU_NO = ''' || i_VTANMATSU   || '''';

            EXECUTE IMMEDIATE VwSQL INTO NwCNT;

            -- 取得したレコード件数をチェック
            IF NwCNT = 0 THEN

                -- 2.存在しなければ賦課(最新)TBLの該当レコードを追加
                CASE i_NwTBL
                    WHEN c_NKIHON    THEN       -- 賦課基本(最新)
                        -- データ取得
                        SELECT * INTO RwKIHON_KIHON FROM ZLBTKIHON_N
                         WHERE KOKU_SETAI_NO   = i_NSETAI
                           AND SANTEIDANTAI_CD = i_NDANTAI
                           AND CHOTEI_NENDO    = i_NwNENDO
                           AND NENDO_BUN       = i_NNENDO_BUN
                           AND TSUCHI_NO       = i_NwTSUCHI_NO;
                        SELECT * INTO RwKIHON FROM ZLBTKIHON_CAL
                         WHERE KOKU_SETAI_NO   = i_NSETAI
                           AND SANTEIDANTAI_CD = i_NDANTAI
                           AND CHOTEI_NENDO    = i_NNENDO
                           AND NENDO_BUN       = i_NNENDO_BUN
                           AND TSUCHI_NO       = i_NTSUCHI_NO
                           AND   SYS_TANMATSU_NO = i_VTANMATSU;

                        -- 履歴番号等を変更
                        RwKIHON.CHOTEI_NENDO        := RwKIHON_KIHON.CHOTEI_NENDO;
                        RwKIHON.TSUCHI_NO           := RwKIHON_KIHON.TSUCHI_NO;
                        RwKIHON.R_NO                := RwKIHON_KIHON.R_NO + c_NRNO_CNT;
                        NNENZEI_KEI                 := RwKIHON.KANENDO + RwKIHON.NENZEI;
                        RwKIHON.NENZEI              := RwKIHON_KIHON.NENZEI;
                        RwKIHON.KANENDO             := NNENZEI_KEI - RwKIHON.NENZEI;
                        RwKIHON.SYS_SAKUSEIBI       := NlDATE;
                        RwKIHON.SYS_SAKUSEIBI       := NlDATE;
                        RwKIHON.SYS_KOSHINBI        := NlDATE;
                        RwKIHON.SYS_JIKAN           := NlTIME;
                        RwKIHON.SYS_SHOKUINKOJIN_NO := i_NSYS_SHOKUIN;
                        RwKIHON.SYS_TANMATSU_NO     := i_VTANMATSU;

                        -- 計算TBLに追加
                        INSERT INTO ZLBTKIHON_CAL VALUES RwKIHON;

                        NlIRYHANTEI := 1;

                    WHEN c_NTAI      THEN       -- 賦課退職(最新)
                        BEGIN
                            -- データ取得
                            SELECT * INTO RwTAI FROM ZLBTTAI_N
                             WHERE KOKU_SETAI_NO   = i_NSETAI
                               AND SANTEIDANTAI_CD = i_NDANTAI
                               AND CHOTEI_NENDO    = i_NwNENDO
                               AND NENDO_BUN       = i_NNENDO_BUN
                               AND TSUCHI_NO       = i_NwTSUCHI_NO;
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                -- 空の計算退職を作成
                                RwTAI.KOKU_SETAI_NO     := i_NSETAI;
                                RwTAI.SANTEIDANTAI_CD   := i_NDANTAI;
                                RwTAI.CHOTEI_NENDO      := i_NwNENDO;
                                RwTAI.NENDO_BUN         := i_NNENDO_BUN;
                                RwTAI.R_NO              := i_NwR_NO - c_NRNO_CNT;
                                RwTAI.TSUCHI_NO         := i_NwTSUCHI_NO;
                                RwTAI.KEIGEN_SHOTOKU    := 0;
                                RwTAI.FUKA_KIJITSU_CNT  := 0;
                                RwTAI.KINTO_CNT         := 0;
                                RwTAI.GENZAI_CNT        := 0;
                                RwTAI.YU_SHOTOKU_CNT    := 0;
                                RwTAI.SHOTOKU           := 0;
                                RwTAI.KAHYO             := 0;
                                RwTAI.SHOTOKU_WARI      := 0;
                                RwTAI.SHISANZEI         := 0;
                                RwTAI.SHISAN_WARI       := 0;
                                RwTAI.KINTO_WARI        := 0;
                                RwTAI.BYODO_WARI        := 0;
                                RwTAI.SEKISAN           := 0;
                                RwTAI.GENDO_CHOKA       := 0;
                                RwTAI.KEIGEN_K_WARI     := 0;
                                RwTAI.KEIGEN_B_WARI     := 0;
                                RwTAI.KEIGEN_K_6        := 0;
                                RwTAI.KEIGEN_B_6        := 0;
                                RwTAI.KEIGEN_K_4        := 0;
                                RwTAI.KEIGEN_B_4        := 0;
                                RwTAI.KEIGEN_K_2        := 0;
                                RwTAI.KEIGEN_B_2        := 0;
                                RwTAI.TSUKIWARI_GEN     := 0;
                                RwTAI.HASU              := 0;
                                RwTAI.GENGAKU_KEI       := 0;
                                RwTAI.GENMEN            := 0;
                                RwTAI.KANENDO           := 0;
                                RwTAI.NENZEI            := 0;
                        END;

                        -- 履歴番号等を変更
                        RwTAI.R_NO                := RwTAI.R_NO + c_NRNO_CNT;
                        RwTAI.SYS_SAKUSEIBI       := NlDATE;
                        RwTAI.SYS_SAKUSEIBI       := NlDATE;
                        RwTAI.SYS_KOSHINBI        := NlDATE;
                        RwTAI.SYS_JIKAN           := NlTIME;
                        RwTAI.SYS_SHOKUINKOJIN_NO := i_NSYS_SHOKUIN;
                        RwTAI.SYS_TANMATSU_NO     := i_VTANMATSU;

                        -- 計算TBLに追加
                        INSERT INTO ZLBTTAI_CAL VALUES RwTAI;

                    WHEN c_NKAIKIHON THEN       -- 賦課介護基本(最新)
                        BEGIN
                            -- データ取得
                            SELECT * INTO RwKKIHON_KIHON FROM ZLBTKAI_KIHON_N
                             WHERE KOKU_SETAI_NO   = i_NSETAI
                               AND SANTEIDANTAI_CD = i_NDANTAI
                               AND CHOTEI_NENDO    = i_NwNENDO
                               AND NENDO_BUN       = i_NNENDO_BUN
                               AND TSUCHI_NO       = i_NwTSUCHI_NO;
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                RETURN;
                        END;
                        BEGIN
                            -- データ取得
                            SELECT * INTO RwKKIHON FROM ZLBTKAI_KIHON_CAL
                             WHERE KOKU_SETAI_NO   = i_NSETAI
                               AND SANTEIDANTAI_CD = i_NDANTAI
                               AND CHOTEI_NENDO    = i_NNENDO
                               AND NENDO_BUN       = i_NNENDO_BUN
                               AND TSUCHI_NO       = i_NTSUCHI_NO
                               AND SYS_TANMATSU_NO = i_VTANMATSU;
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                RETURN;
                        END;
                        -- 履歴番号等を変更
                        RwKKIHON.CHOTEI_NENDO        := RwKKIHON_KIHON.CHOTEI_NENDO;
                        RwKKIHON.TSUCHI_NO           := RwKKIHON_KIHON.TSUCHI_NO;
                        RwKKIHON.R_NO                := RwKKIHON_KIHON.R_NO + c_NRNO_CNT;
                        NNENZEI_KEI_KAI              := RwKKIHON.KANENDO + RwKKIHON.NENZEI;
                        RwKKIHON.NENZEI              := RwKKIHON_KIHON.NENZEI;
                        RwKKIHON.KANENDO             := NNENZEI_KEI_KAI - RwKKIHON.NENZEI;
                        RwKKIHON.SYS_SAKUSEIBI       := NlDATE;
                        RwKKIHON.SYS_SAKUSEIBI       := NlDATE;
                        RwKKIHON.SYS_KOSHINBI        := NlDATE;
                        RwKKIHON.SYS_JIKAN           := NlTIME;
                        RwKKIHON.SYS_SHOKUINKOJIN_NO := i_NSYS_SHOKUIN;
                        RwKKIHON.SYS_TANMATSU_NO     := i_VTANMATSU;

                        -- 計算TBLに追加
                        INSERT INTO ZLBTKAI_KIHON_CAL VALUES RwKKIHON;

                        NlKAIHANTEI := 1;

                    WHEN c_NKAITAI   THEN       -- 賦課介護退職(最新)
                        BEGIN
                            -- データ取得
                            SELECT * INTO RwKTAI FROM ZLBTKAI_TAI_N
                             WHERE KOKU_SETAI_NO   = i_NSETAI
                               AND SANTEIDANTAI_CD = i_NDANTAI
                               AND CHOTEI_NENDO    = i_NwNENDO
                               AND NENDO_BUN       = i_NNENDO_BUN
                               AND TSUCHI_NO       = i_NwTSUCHI_NO;
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                -- 空の計算介護退職を作成
                                RwKTAI.KOKU_SETAI_NO    := i_NSETAI;
                                RwKTAI.SANTEIDANTAI_CD  := i_NDANTAI;
                                RwKTAI.CHOTEI_NENDO     := i_NwNENDO;
                                RwKTAI.NENDO_BUN        := i_NNENDO_BUN;
                                RwKTAI.R_NO             := i_NwR_NO - c_NRNO_CNT;
                                RwKTAI.TSUCHI_NO        := i_NwTSUCHI_NO;
                                RwKTAI.KEIGEN_SHOTOKU   := 0;
                                RwKTAI.FUKA_KIJITSU_CNT := 0;
                                RwKTAI.KINTO_CNT        := 0;
                                RwKTAI.GENZAI_CNT       := 0;
                                RwKTAI.YU_SHOTOKU_CNT   := 0;
                                RwKTAI.SHOTOKU          := 0;
                                RwKTAI.KAHYO            := 0;
                                RwKTAI.SHOTOKU_WARI     := 0;
                                RwKTAI.SHISANZEI        := 0;
                                RwKTAI.SHISAN_WARI      := 0;
                                RwKTAI.KINTO_WARI       := 0;
                                RwKTAI.BYODO_WARI       := 0;
                                RwKTAI.SEKISAN          := 0;
                                RwKTAI.GENDO_CHOKA      := 0;
                                RwKTAI.KEIGEN_K_WARI    := 0;
                                RwKTAI.KEIGEN_B_WARI    := 0;
                                RwKTAI.KEIGEN_K_6       := 0;
                                RwKTAI.KEIGEN_B_6       := 0;
                                RwKTAI.KEIGEN_K_4       := 0;
                                RwKTAI.KEIGEN_B_4       := 0;
                                RwKTAI.KEIGEN_K_2       := 0;
                                RwKTAI.KEIGEN_B_2       := 0;
                                RwKTAI.TSUKIWARI_GEN    := 0;
                                RwKTAI.HASU             := 0;
                                RwKTAI.GENGAKU_KEI      := 0;
                                RwKTAI.GENMEN           := 0;
                                RwKTAI.KANENDO          := 0;
                                RwKTAI.NENZEI           := 0;
                        END;

                        -- 履歴番号等を変更
                        RwKTAI.R_NO                := RwKTAI.R_NO + c_NRNO_CNT;
                        RwKTAI.SYS_SAKUSEIBI       := NlDATE;
                        RwKTAI.SYS_SAKUSEIBI       := NlDATE;
                        RwKTAI.SYS_KOSHINBI        := NlDATE;
                        RwKTAI.SYS_JIKAN           := NlTIME;
                        RwKTAI.SYS_SHOKUINKOJIN_NO := i_NSYS_SHOKUIN;
                        RwKTAI.SYS_TANMATSU_NO     := i_VTANMATSU;

                        -- 計算TBLに追加
                        INSERT INTO ZLBTKAI_TAI_CAL VALUES RwKTAI;

                    WHEN c_NSIENKIHON THEN       -- 賦課支援基本(最新)
                        BEGIN
                            -- データ取得
                            SELECT * INTO RwSKIHON_KIHON FROM ZLBTSIEN_KIHON_N
                             WHERE KOKU_SETAI_NO   = i_NSETAI
                               AND SANTEIDANTAI_CD = i_NDANTAI
                               AND CHOTEI_NENDO    = i_NwNENDO
                               AND NENDO_BUN       = i_NNENDO_BUN
                               AND TSUCHI_NO       = i_NwTSUCHI_NO;
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                RETURN;
                        END;

                        BEGIN
                            -- データ取得
                            SELECT * INTO RwSKIHON FROM ZLBTSIEN_KIHON_CAL
                             WHERE KOKU_SETAI_NO   = i_NSETAI
                               AND SANTEIDANTAI_CD = i_NDANTAI
                               AND CHOTEI_NENDO    = i_NNENDO
                               AND NENDO_BUN       = i_NNENDO_BUN
                               AND TSUCHI_NO       = i_NTSUCHI_NO
                               AND SYS_TANMATSU_NO = i_VTANMATSU;
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                RETURN;
                        END;


                        -- 履歴番号等を変更
                        RwSKIHON.CHOTEI_NENDO        := RwSKIHON_KIHON.CHOTEI_NENDO;
                        RwSKIHON.TSUCHI_NO           := RwSKIHON_KIHON.TSUCHI_NO;
                        RwSKIHON.R_NO                := RwSKIHON_KIHON.R_NO + c_NRNO_CNT;
                        NNENZEI_KEI_SIEN             := RwSKIHON.KANENDO + RwSKIHON.NENZEI;
                        RwSKIHON.NENZEI              := RwSKIHON_KIHON.NENZEI;
                        RwSKIHON.KANENDO             := NNENZEI_KEI_SIEN - RwSKIHON.NENZEI;
                        RwSKIHON.SYS_SAKUSEIBI       := NlDATE;
                        RwSKIHON.SYS_SAKUSEIBI       := NlDATE;
                        RwSKIHON.SYS_KOSHINBI        := NlDATE;
                        RwSKIHON.SYS_JIKAN           := NlTIME;
                        RwSKIHON.SYS_SHOKUINKOJIN_NO := i_NSYS_SHOKUIN;
                        RwSKIHON.SYS_TANMATSU_NO     := i_VTANMATSU;

                        -- 計算TBLに追加
                        INSERT INTO ZLBTSIEN_KIHON_CAL VALUES RwSKIHON;

                        NlSIENHANTEI := 1;

                    WHEN c_NSIENTAI   THEN       -- 賦課支援退職(最新)
                        BEGIN
                            -- データ取得
                            SELECT * INTO RwSTAI FROM ZLBTSIEN_TAI_N
                             WHERE KOKU_SETAI_NO   = i_NSETAI
                               AND SANTEIDANTAI_CD = i_NDANTAI
                               AND CHOTEI_NENDO    = i_NwNENDO
                               AND NENDO_BUN       = i_NNENDO_BUN
                               AND TSUCHI_NO       = i_NwTSUCHI_NO;
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                -- 空の計算介護退職を作成
                                RwSTAI.KOKU_SETAI_NO    := i_NSETAI;
                                RwSTAI.SANTEIDANTAI_CD  := i_NDANTAI;
                                RwSTAI.CHOTEI_NENDO     := i_NwNENDO;
                                RwSTAI.NENDO_BUN        := i_NNENDO_BUN;
                                RwSTAI.R_NO             := i_NwR_NO - c_NRNO_CNT;
                                RwSTAI.TSUCHI_NO        := i_NwTSUCHI_NO;
                                RwSTAI.KEIGEN_SHOTOKU   := 0;
                                RwSTAI.FUKA_KIJITSU_CNT := 0;
                                RwSTAI.KINTO_CNT        := 0;
                                RwSTAI.GENZAI_CNT       := 0;
                                RwSTAI.YU_SHOTOKU_CNT   := 0;
                                RwSTAI.SHOTOKU          := 0;
                                RwSTAI.KAHYO            := 0;
                                RwSTAI.SHOTOKU_WARI     := 0;
                                RwSTAI.SHISANZEI        := 0;
                                RwSTAI.SHISAN_WARI      := 0;
                                RwSTAI.KINTO_WARI       := 0;
                                RwSTAI.BYODO_WARI       := 0;
                                RwSTAI.SEKISAN          := 0;
                                RwSTAI.GENDO_CHOKA      := 0;
                                RwSTAI.KEIGEN_K_WARI    := 0;
                                RwSTAI.KEIGEN_B_WARI    := 0;
                                RwSTAI.KEIGEN_K_6       := 0;
                                RwSTAI.KEIGEN_B_6       := 0;
                                RwSTAI.KEIGEN_K_4       := 0;
                                RwSTAI.KEIGEN_B_4       := 0;
                                RwSTAI.KEIGEN_K_2       := 0;
                                RwSTAI.KEIGEN_B_2       := 0;
                                RwSTAI.TSUKIWARI_GEN    := 0;
                                RwSTAI.HASU             := 0;
                                RwSTAI.GENGAKU_KEI      := 0;
                                RwSTAI.GENMEN           := 0;
                                RwSTAI.KANENDO          := 0;
                                RwSTAI.NENZEI           := 0;
                        END;

                        -- 履歴番号等を変更
                        RwSTAI.R_NO                := RwSTAI.R_NO + c_NRNO_CNT;
                        RwSTAI.SYS_SAKUSEIBI       := NlDATE;
                        RwSTAI.SYS_SAKUSEIBI       := NlDATE;
                        RwSTAI.SYS_KOSHINBI        := NlDATE;
                        RwSTAI.SYS_JIKAN           := NlTIME;
                        RwSTAI.SYS_SHOKUINKOJIN_NO := i_NSYS_SHOKUIN;
                        RwSTAI.SYS_TANMATSU_NO     := i_VTANMATSU;

                        -- 計算TBLに追加
                        INSERT INTO ZLBTSIEN_TAI_CAL VALUES RwSTAI;
                    --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
                    WHEN c_NKDMKIHON   THEN       -- 子ども
                        BEGIN
                          -- データ取得
                          SELECT * INTO RwKDMKIHON_KIHON FROM ZLBTKDM_KIHON_N
                            WHERE KOKU_SETAI_NO   = i_NSETAI
                            AND SANTEIDANTAI_CD = i_NDANTAI
                            AND CHOTEI_NENDO    = i_NwNENDO
                            AND NENDO_BUN       = i_NNENDO_BUN
                            AND TSUCHI_NO       = i_NwTSUCHI_NO;
                          EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                RETURN;
                        END;
                        BEGIN
                          SELECT * INTO RwKDMKIHON FROM ZLBTKDM_KIHON_CAL
                            WHERE KOKU_SETAI_NO   = i_NSETAI
                            AND SANTEIDANTAI_CD = i_NDANTAI
                            AND CHOTEI_NENDO    = i_NNENDO
                            AND NENDO_BUN       = i_NNENDO_BUN
                            AND TSUCHI_NO       = i_NTSUCHI_NO
                            AND SYS_TANMATSU_NO = i_VTANMATSU;
                          EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                RETURN;
                        END;

                        -- 履歴番号等を変更
                        RwKDMKIHON.CHOTEI_NENDO        := RwKDMKIHON_KIHON.CHOTEI_NENDO;
                        RwKDMKIHON.TSUCHI_NO           := RwKDMKIHON_KIHON.TSUCHI_NO;
                        RwKDMKIHON.R_NO                := RwKDMKIHON_KIHON.R_NO + c_NRNO_CNT;
                        NNENZEI_KEI_KDM                := RwKDMKIHON.KANENDO + RwKDMKIHON.NENZEI;
                        RwKDMKIHON.NENZEI              := RwKDMKIHON_KIHON.NENZEI;
                        RwKDMKIHON.KANENDO             := NNENZEI_KEI_KDM - RwKDMKIHON.NENZEI;
                        RwKDMKIHON.SYS_SAKUSEIBI       := NlDATE;
                        RwKDMKIHON.SYS_KOSHINBI        := NlDATE;
                        RwKDMKIHON.SYS_JIKAN           := NlTIME;
                        RwKDMKIHON.SYS_SHOKUINKOJIN_NO := i_NSYS_SHOKUIN;
                        RwKDMKIHON.SYS_TANMATSU_NO     := i_VTANMATSU;

                        -- 計算TBLに追加
                        INSERT INTO ZLBTKDM_KIHON_CAL VALUES RwKDMKIHON;

                        NlKDMHANTEI := 1;
                    --  2025/08/11 ZCZL.HAODAPENG ADD END

                END CASE;
            ELSE
                IF i_NwTBL = c_NKIHON THEN
                    NlIRYHANTEI := 1;
                ELSIF i_NwTBL = c_NKAIKIHON THEN
                    NlKAIHANTEI := 1;
                --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
                ELSIF i_NwTBL = c_NSIENKIHON THEN
                    NlSIENHANTEI := 1;
                --  2025/08/11 ZCZL.HAODAPENG ADD END
                ELSE
                    --  2025/08/11 ZCZL.HAODAPENG ADD 1.1.200.000:子ども子育て支援金対応
                    --  NlSIENHANTEI := 1;
                    NlKDMHANTEI := 1;
                END IF;
            END IF;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subSetFusokuCal 不足分データ作成' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;
    END subSetFusokuCal;
-------------------------------------------------------------------------------
--  08 不足レコード作成処理
--      増減処理で追加したレコードで不足しているTBLの情報を追加する
-------------------------------------------------------------------------------
    PROCEDURE subMakeCal IS

        -- 増減処理で作成されたレコード一覧カーソル
        CURSOR CwTAISHO IS
            SELECT DISTINCT CHOTEI_NENDO, R_NO, TSUCHI_NO
              FROM ((SELECT CHOTEI_NENDO, R_NO, TSUCHI_NO FROM ZLBTKIHON_CAL
                      WHERE KOKU_SETAI_NO   =  i_NSETAI
                        AND SANTEIDANTAI_CD =  i_NDANTAI
                        AND CHOTEI_NENDO    <> i_NNENDO
                        AND NENDO_BUN       =  i_NNENDO_BUN
                        AND SYS_TANMATSU_NO =  i_VTANMATSU) UNION
                    (SELECT CHOTEI_NENDO, R_NO, TSUCHI_NO FROM ZLBTTAI_CAL
                      WHERE KOKU_SETAI_NO   =  i_NSETAI
                        AND SANTEIDANTAI_CD =  i_NDANTAI
                        AND CHOTEI_NENDO    <> i_NNENDO
                        AND NENDO_BUN       =  i_NNENDO_BUN
                        AND SYS_TANMATSU_NO =  i_VTANMATSU) UNION
                    (SELECT CHOTEI_NENDO, R_NO, TSUCHI_NO FROM ZLBTKAI_KIHON_CAL
                      WHERE KOKU_SETAI_NO   =  i_NSETAI
                        AND SANTEIDANTAI_CD =  i_NDANTAI
                        AND CHOTEI_NENDO    <> i_NNENDO
                        AND NENDO_BUN       =  i_NNENDO_BUN
                        AND SYS_TANMATSU_NO =  i_VTANMATSU) UNION
                    (SELECT CHOTEI_NENDO, R_NO, TSUCHI_NO FROM ZLBTKAI_TAI_CAL
                      WHERE KOKU_SETAI_NO   =  i_NSETAI
                        AND SANTEIDANTAI_CD =  i_NDANTAI
                        AND CHOTEI_NENDO    <> i_NNENDO
                        AND NENDO_BUN       =  i_NNENDO_BUN
                        AND SYS_TANMATSU_NO =  i_VTANMATSU) UNION
                    (SELECT CHOTEI_NENDO, R_NO, TSUCHI_NO FROM ZLBTSIEN_KIHON_CAL
                      WHERE KOKU_SETAI_NO   =  i_NSETAI
                        AND SANTEIDANTAI_CD =  i_NDANTAI
                        AND CHOTEI_NENDO    <> i_NNENDO
                        AND NENDO_BUN       =  i_NNENDO_BUN
                        AND SYS_TANMATSU_NO =  i_VTANMATSU) UNION
                    (SELECT CHOTEI_NENDO, R_NO, TSUCHI_NO FROM ZLBTSIEN_TAI_CAL
                      WHERE KOKU_SETAI_NO   =  i_NSETAI
                        AND SANTEIDANTAI_CD =  i_NDANTAI
                        AND CHOTEI_NENDO    <> i_NNENDO
                        AND NENDO_BUN       =  i_NNENDO_BUN
                        --  2025/08/11 ZCZL.HAODAPENG UPDATE START 1.1.200.000:子ども子育て支援金対応
                        --AND SYS_TANMATSU_NO =  i_VTANMATSU))
                        AND SYS_TANMATSU_NO =  i_VTANMATSU) UNION
                    (SELECT CHOTEI_NENDO, R_NO, TSUCHI_NO FROM ZLBTKDM_KIHON_CAL
                      WHERE KOKU_SETAI_NO   =  i_NSETAI
                        AND SANTEIDANTAI_CD =  i_NDANTAI
                        AND CHOTEI_NENDO    <> i_NNENDO
                        AND NENDO_BUN       =  i_NNENDO_BUN
                        AND SYS_TANMATSU_NO =  i_VTANMATSU)
                        )
                        --  2025/08/11 ZCZL.HAODAPENG UPDATE END
             ORDER BY CHOTEI_NENDO, TSUCHI_NO;

    BEGIN
        FOR RwTAISHO IN CwTAISHO LOOP
            NlIRYHANTEI := 0;
            NlKAIHANTEI := 0;
            NlSIENHANTEI := 0;
            --  2025/08/11 ZCZL.HAODAPENG add 1.1.200.000:子ども子育て支援金対応
            NlKDMHANTEI := 0;

            -- 計算基本存在チェックおよび追加更新
            subSetFusokuCal(c_NKIHON,
                            RwTAISHO.CHOTEI_NENDO,
                            RwTAISHO.R_NO,
                            RwTAISHO.TSUCHI_NO);        -- 09 計算TBL存在CHKおよび追加更新

            -- 計算退職存在チェックおよび追加更新
            IF NlRTN = c_NOK THEN
                subSetFusokuCal(c_NTAI,
                                RwTAISHO.CHOTEI_NENDO,
                                RwTAISHO.R_NO,
                                RwTAISHO.TSUCHI_NO);    -- 09 計算TBL存在CHKおよび追加更新
            END IF;

            IF NlIRYHANTEI = 1 THEN
                -- 計算介護基本存在チェックおよび追加更新
                IF NlRTN = c_NOK THEN
                    subSetFusokuCal(c_NKAIKIHON,
                                    RwTAISHO.CHOTEI_NENDO,
                                    RwTAISHO.R_NO,
                                    RwTAISHO.TSUCHI_NO);    -- 09 計算TBL存在CHKおよび追加更新
                END IF;

                -- 計算介護退職存在チェックおよび追加更新
                IF NlRTN = c_NOK AND NlKAIHANTEI = 1 THEN
                    subSetFusokuCal(c_NKAITAI,
                                    RwTAISHO.CHOTEI_NENDO,
                                    RwTAISHO.R_NO,
                                    RwTAISHO.TSUCHI_NO);    -- 09 計算TBL存在CHKおよび追加更新
                END IF;

                -- 計算支援基本存在チェックおよび追加更新
                IF NlRTN = c_NOK THEN
                    subSetFusokuCal(c_NSIENKIHON,
                                    RwTAISHO.CHOTEI_NENDO,
                                    RwTAISHO.R_NO,
                                    RwTAISHO.TSUCHI_NO);    -- 09 計算TBL存在CHKおよび追加更新
                END IF;

                -- 計算支援退職存在チェックおよび追加更新
                IF NlRTN = c_NOK AND NlSIENHANTEI = 1 THEN
                    subSetFusokuCal(c_NSIENTAI,
                                    RwTAISHO.CHOTEI_NENDO,
                                    RwTAISHO.R_NO,
                                    RwTAISHO.TSUCHI_NO);    -- 09 計算TBL存在CHKおよび追加更新
                END IF;
                --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
                IF NlRTN = c_NOK THEN
                    subSetFusokuCal(c_NKDMKIHON,
                                    RwTAISHO.CHOTEI_NENDO,
                                    RwTAISHO.R_NO,
                                    RwTAISHO.TSUCHI_NO);    -- 計算子ども基本存在チェックおよび追加更新
                END IF;
                --  2025/08/11 ZCZL.HAODAPENG ADD END

            END IF;
            EXIT WHEN NlRTN != c_NOK;
        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subMakeCal 不足レコード作成処理' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;
    END subMakeCal;
-------------------------------------------------------------------------------
--  07 減額処理(主課税する)
--      指定された計算TBLについて次の項目を更新する
--          ・過年度分、年税額
-------------------------------------------------------------------------------
    PROCEDURE subGengaku(i_NwTBL IN NUMBER) IS
      -- 内部変数
      VwSQL               VARCHAR2(2048);           -- SQL文
      VwCALTBL            NVARCHAR2(30);            -- 計算TBL名
      NwSAGAKU            NUMBER;                   -- 差額
      NwCALKANENDO        NUMBER;                   -- 算出過年度分
      NwCALNENZEI         NUMBER;                   -- 算出年税額
      NwNENDO             NUMBER;                   -- 調定年度(賦課取得)
      NwNENZEI            NUMBER;                   -- 年税額(賦課取得)
      NwSEKISAN           NUMBER;                   -- 積算税額(賦課取得)
      NwGENGAKU_KEI       NUMBER;                   -- 減額合計(賦課取得)
      NwCNT               NUMBER;                   -- データ取得件数
      NwSETFLG            NUMBER := 0;              -- 更新フラグ
      NwSETFLG2           NUMBER := 0;              -- 全体税額取得フラグ
      NwZEN_NENZEI        NUMBER;                   -- 全体年税額

      -- 計算結果バックアップ
      RwKIHON_BK          ZLBTKIHON_N%ROWTYPE;      -- 計算基本
      RwTAI_BK            ZLBTTAI_N%ROWTYPE;        -- 計算退職基本
      RwKKIHON_BK         ZLBTKAI_KIHON_N%ROWTYPE;  -- 計算介護基本
      RwKTAI_BK           ZLBTKAI_TAI_N%ROWTYPE;    -- 計算介護退職基本
      RwSKIHON_BK         ZLBTSIEN_KIHON_N%ROWTYPE; -- 計算支援基本
      RwSTAI_BK           ZLBTSIEN_TAI_N%ROWTYPE;   -- 計算支援退職基本

     -- 賦課TBL取得ワーク
      RwKIHON             ZLBTKIHON_N%ROWTYPE;      -- 賦課基本        (最新)
      RwTAI               ZLBTTAI_N%ROWTYPE;        -- 賦課退職基本    (最新)
      RwKKIHON            ZLBTKAI_KIHON_N%ROWTYPE;  -- 賦課介護基本    (最新)
      RwKTAI              ZLBTKAI_TAI_N%ROWTYPE;    -- 賦課介護退職基本(最新)
      RwSKIHON            ZLBTSIEN_KIHON_N%ROWTYPE; -- 賦課支援基本    (最新)
      RwSTAI              ZLBTSIEN_TAI_N%ROWTYPE;   -- 賦課支援退職基本(最新)

     -- 計算TBL出力ワーク
      RwKIHON_INS         ZLBTKIHON_N%ROWTYPE;      -- 計算基本
      RwTAI_INS           ZLBTTAI_N%ROWTYPE;        -- 計算退職基本
      RwKKIHON_INS        ZLBTKAI_KIHON_N%ROWTYPE;  -- 計算介護基本
      RwKTAI_INS          ZLBTKAI_TAI_N%ROWTYPE;    -- 計算介護退職基本
      RwSKIHON_INS        ZLBTSIEN_KIHON_N%ROWTYPE; -- 計算支援基本
      RwSTAI_INS          ZLBTSIEN_TAI_N%ROWTYPE;   -- 計算支援退職基本
      --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
      RwKDMKIHON_BK       ZLBTKDM_KIHON_N%ROWTYPE;   --計算子ども基本
      RwKDMKIHON          ZLBTKDM_KIHON_N%ROWTYPE;   --賦課子ども基本  (最新)
      RwKDMKIHON_INS      ZLBTKDM_KIHON_N%ROWTYPE;   --計算子ども基本挿入
      --  2025/08/11 ZCZL.HAODAPENG ADD END

      NwLOOPCNT           NUMBER := 0;              --ループ回数記録用

      -- 賦課基本(最新)カーソル    [過年度分のみ]
      CURSOR CwKIHON IS
          SELECT * FROM ZLBTKIHON_N
           WHERE KOKU_SETAI_NO   =  i_NSETAI
             AND SANTEIDANTAI_CD =  i_NDANTAI
             AND CHOTEI_NENDO    <> i_NNENDO
             AND NENDO_BUN       =  i_NNENDO_BUN
             AND   NUSHI_KOJIN_NO  = NlNUSHI_KOJIN_NO
           ORDER BY CHOTEI_NENDO DESC, TSUCHI_NO DESC;

      -- 賦課退職(最新)カーソル    [過年度分のみ]
      CURSOR CwTAI IS
          SELECT * FROM ZLBTTAI_N
           WHERE KOKU_SETAI_NO   =  i_NSETAI
             AND SANTEIDANTAI_CD =  i_NDANTAI
             AND CHOTEI_NENDO    <> i_NNENDO
             AND NENDO_BUN       =  i_NNENDO_BUN
             AND   TSUCHI_NO       = (SELECT MAX(TSUCHI_NO) FROM ZLBTKIHON_N
                             WHERE KOKU_SETAI_NO   = i_NSETAI
                             AND   SANTEIDANTAI_CD = i_NDANTAI
                             AND   CHOTEI_NENDO    <> i_NNENDO
                             AND   NENDO_BUN       = i_NNENDO_BUN
                             AND   NUSHI_KOJIN_NO  = NlNUSHI_KOJIN_NO)
           ORDER BY CHOTEI_NENDO DESC, TSUCHI_NO DESC;

      -- 賦課介護基本(最新)カーソル[過年度分のみ]
      CURSOR CwKAIKIHON IS
          SELECT * FROM ZLBTKAI_KIHON_N
           WHERE KOKU_SETAI_NO   =  i_NSETAI
             AND SANTEIDANTAI_CD =  i_NDANTAI
             AND CHOTEI_NENDO    <> i_NNENDO
             AND NENDO_BUN       =  i_NNENDO_BUN
             AND   NUSHI_KOJIN_NO  = NlNUSHI_KOJIN_NO
           ORDER BY CHOTEI_NENDO DESC, TSUCHI_NO DESC;

      -- 賦課介護退職(最新)カーソル[過年度分のみ]
      CURSOR CwKAITAI IS
          SELECT * FROM ZLBTKAI_TAI_N
           WHERE KOKU_SETAI_NO   =  i_NSETAI
             AND SANTEIDANTAI_CD =  i_NDANTAI
             AND CHOTEI_NENDO    <> i_NNENDO
             AND NENDO_BUN       =  i_NNENDO_BUN
             AND   TSUCHI_NO       = (SELECT MAX(TSUCHI_NO) FROM ZLBTKIHON_N
                             WHERE KOKU_SETAI_NO   = i_NSETAI
                             AND   SANTEIDANTAI_CD = i_NDANTAI
                             AND   CHOTEI_NENDO    <> i_NNENDO
                             AND   NENDO_BUN       = i_NNENDO_BUN
                             AND   NUSHI_KOJIN_NO  = NlNUSHI_KOJIN_NO)
           ORDER BY CHOTEI_NENDO DESC, TSUCHI_NO DESC;

      -- 賦課支援基本(最新)カーソル[過年度分のみ]
      CURSOR CwSIENKIHON IS
          SELECT * FROM ZLBTSIEN_KIHON_N
           WHERE KOKU_SETAI_NO   =  i_NSETAI
             AND SANTEIDANTAI_CD =  i_NDANTAI
             AND CHOTEI_NENDO    <> i_NNENDO
             AND NENDO_BUN       =  i_NNENDO_BUN
             AND   NUSHI_KOJIN_NO  = NlNUSHI_KOJIN_NO
           ORDER BY CHOTEI_NENDO DESC, TSUCHI_NO DESC;

      -- 賦課支援退職(最新)カーソル[過年度分のみ]
      CURSOR CwSIENTAI IS
          SELECT * FROM ZLBTSIEN_TAI_N
           WHERE KOKU_SETAI_NO   =  i_NSETAI
             AND SANTEIDANTAI_CD =  i_NDANTAI
             AND CHOTEI_NENDO    <> i_NNENDO
             AND NENDO_BUN       =  i_NNENDO_BUN
             AND   TSUCHI_NO       = (SELECT MAX(TSUCHI_NO) FROM ZLBTKIHON_N
                             WHERE KOKU_SETAI_NO   = i_NSETAI
                             AND   SANTEIDANTAI_CD = i_NDANTAI
                             AND   CHOTEI_NENDO    <> i_NNENDO
                             AND   NENDO_BUN       = i_NNENDO_BUN
                             AND   NUSHI_KOJIN_NO  = NlNUSHI_KOJIN_NO)
           ORDER BY CHOTEI_NENDO DESC, TSUCHI_NO DESC;

      --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
      --賦課子ども基本(最新)カーソル[過年度分のみ]
      --賦課子ども基本(最新)
      CURSOR CwKDMKIHON IS
          SELECT * FROM ZLBTKDM_KIHON_N
           WHERE KOKU_SETAI_NO   =  i_NSETAI
             AND SANTEIDANTAI_CD =  i_NDANTAI
             AND CHOTEI_NENDO    <> i_NNENDO
             AND NENDO_BUN       =  i_NNENDO_BUN
             AND NUSHI_KOJIN_NO  = NlNUSHI_KOJIN_NO
           ORDER BY CHOTEI_NENDO DESC, TSUCHI_NO DESC;
      --  2025/08/11 ZCZL.HAODAPENG ADD END
    BEGIN
        -- 11 テーブル名取得(計算TBL) --------------------------------------------1
        VwCALTBL := funcGetTblnm(i_NwTBL, 0);
        IF VwCALTBL IS NULL THEN
            NlRTN := c_NERR;
            VlMSG := 'subGengaku ' || 'テーブル名取得' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;
        END IF;

        -- 計算結果の基本内容をSave ----------------------------------------------2
        IF NlRTN = c_NOK THEN
            CASE i_NwTBL
            -- 基本
            WHEN c_NKIHON    THEN
                SELECT * INTO RwKIHON_BK FROM ZLBTKIHON_CAL
                WHERE KOKU_SETAI_NO   = i_NSETAI
                AND   SANTEIDANTAI_CD = i_NDANTAI
                AND   CHOTEI_NENDO    = i_NNENDO
                AND   NENDO_BUN       = i_NNENDO_BUN
                AND   TSUCHI_NO       = i_NTSUCHI_NO
                AND   SYS_TANMATSU_NO = i_VTANMATSU;
            -- 退職
            WHEN c_NTAI      THEN
                SELECT * INTO RwTAI_BK FROM ZLBTTAI_CAL
                WHERE KOKU_SETAI_NO   = i_NSETAI
                AND   SANTEIDANTAI_CD = i_NDANTAI
                AND   CHOTEI_NENDO    = i_NNENDO
                AND   NENDO_BUN       = i_NNENDO_BUN
                AND   TSUCHI_NO       = i_NTSUCHI_NO
                AND   SYS_TANMATSU_NO = i_VTANMATSU;
            -- 介護基本
            WHEN c_NKAIKIHON THEN
                SELECT * INTO RwKKIHON_BK FROM ZLBTKAI_KIHON_CAL
                WHERE KOKU_SETAI_NO   = i_NSETAI
                AND   SANTEIDANTAI_CD = i_NDANTAI
                AND   CHOTEI_NENDO    = i_NNENDO
                AND   NENDO_BUN       = i_NNENDO_BUN
                AND   TSUCHI_NO       = i_NTSUCHI_NO
                AND   SYS_TANMATSU_NO = i_VTANMATSU;
            -- 介護退職
            WHEN c_NKAITAI   THEN
                SELECT * INTO RwKTAI_BK FROM ZLBTKAI_TAI_CAL
                WHERE KOKU_SETAI_NO   = i_NSETAI
                AND   SANTEIDANTAI_CD = i_NDANTAI
                AND   CHOTEI_NENDO    = i_NNENDO
                AND   NENDO_BUN       = i_NNENDO_BUN
               AND   TSUCHI_NO       = i_NTSUCHI_NO
               AND   SYS_TANMATSU_NO = i_VTANMATSU;
            -- 支援基本
            WHEN c_NSIENKIHON THEN
                SELECT * INTO RwSKIHON_BK FROM ZLBTSIEN_KIHON_CAL
                WHERE KOKU_SETAI_NO   = i_NSETAI
                AND   SANTEIDANTAI_CD = i_NDANTAI
                AND   CHOTEI_NENDO    = i_NNENDO
                AND   NENDO_BUN       = i_NNENDO_BUN
                AND   TSUCHI_NO       = i_NTSUCHI_NO
                AND   SYS_TANMATSU_NO = i_VTANMATSU;
            -- 支援退職
            WHEN c_NSIENTAI   THEN
                SELECT * INTO RwSTAI_BK FROM ZLBTSIEN_TAI_CAL
                WHERE KOKU_SETAI_NO   = i_NSETAI
                AND   SANTEIDANTAI_CD = i_NDANTAI
                AND   CHOTEI_NENDO    = i_NNENDO
                AND   NENDO_BUN       = i_NNENDO_BUN
               AND   TSUCHI_NO       = i_NTSUCHI_NO
               AND   SYS_TANMATSU_NO = i_VTANMATSU;
            --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
            --子ども
            WHEN c_NKDMKIHON THEN
                SELECT * INTO RwKDMKIHON_BK FROM ZLBTKDM_KIHON_CAL
                WHERE KOKU_SETAI_NO   = i_NSETAI
                AND   SANTEIDANTAI_CD = i_NDANTAI
                AND   CHOTEI_NENDO    = i_NNENDO
                AND   NENDO_BUN       = i_NNENDO_BUN
                AND   TSUCHI_NO       = i_NTSUCHI_NO
                AND   SYS_TANMATSU_NO = i_VTANMATSU;
            ELSE
               NULL;
            --  2025/08/11 ZCZL.HAODAPENG ADD END
            END CASE;

            -- パラメータ指定の調定年度／年度分データの作成(課税計算済みの情報更新) --3
            -- 差額=年税額過計-年税額(課税計算結果)
            NwSAGAKU := NlNENZEI_KEI - NlNENZEI;
            --   過年度分=年税額過計,年税額=0
            VwSQL := 'UPDATE '                   || VwCALTBL     ||
                     ' SET KANENDO = NENZEI'     ||                   -- 過年度分
                     ' ,NENZEI = 0'              ||                   -- 年税額
                     ' WHERE KOKU_SETAI_NO = '   || i_NSETAI     ||
                     ' AND SANTEIDANTAI_CD = '   || i_NDANTAI    ||
                     ' AND CHOTEI_NENDO = '      || i_NNENDO     ||
                     ' AND NENDO_BUN = '         || i_NNENDO_BUN ||
                     ' AND TSUCHI_NO = '         || i_NTSUCHI_NO ||
                     ' AND SYS_TANMATSU_NO = ''' || i_VTANMATSU  || '''';
            EXECUTE IMMEDIATE VwSQL;

            -- 賦課(最新で且つ過年度分)を取得し差額がなくなるまで減額する ------------4
            -- カーソルオープン
            CASE i_NwTBL
            WHEN c_NKIHON    THEN       -- 賦課基本(最新)
                IF CwKIHON%ISOPEN THEN
                    CLOSE CwKIHON;
                END IF;
                OPEN CwKIHON;
            WHEN c_NTAI      THEN       -- 賦課退職(最新)
                IF CwTAI%ISOPEN THEN
                    CLOSE CwTAI;
                END IF;
                OPEN CwTAI;
            WHEN c_NKAIKIHON THEN       -- 賦課介護基本(最新)
                IF CwKAIKIHON%ISOPEN THEN
                    CLOSE CwKAIKIHON;
                END IF;
                OPEN CwKAIKIHON;
            WHEN c_NKAITAI   THEN       -- 賦課介護退職(最新)
                IF CwKAITAI%ISOPEN THEN
                    CLOSE CwKAITAI;
                END IF;
                OPEN CwKAITAI;
            WHEN c_NSIENKIHON THEN       -- 賦課支援基本(最新)
                IF CwSIENKIHON%ISOPEN THEN
                    CLOSE CwSIENKIHON;
                END IF;
                OPEN CwSIENKIHON;
            WHEN c_NSIENTAI   THEN       -- 賦課支援退職(最新)
                IF CwSIENTAI%ISOPEN THEN
                    CLOSE CwSIENTAI;
                END IF;
                OPEN CwSIENTAI;
            --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
            WHEN c_NKDMKIHON   THEN
                IF CwKDMKIHON%ISOPEN THEN
                    CLOSE CwKDMKIHON;
                END IF;
                OPEN CwKDMKIHON;
            --  2025/08/11 ZCZL.HAODAPENG ADD END
            END CASE;

            -- カーソルデータ分 OR 差額≦０までLOOP
            LOOP
                -- 差額が0以下ならば処理完了
                IF i_NwTBL IN (c_NKIHON,c_NKAIKIHON,c_NSIENKIHON) THEN
                    EXIT WHEN NwSAGAKU < 0 AND TOTAL_GEN_FLG = 0;
                ELSE
                    EXIT WHEN NwSAGAKU = 0;
                END IF;

                NwLOOPCNT := NwLOOPCNT + 1;

                -- 差額減額編集セット
                CASE i_NwTBL
                -- 賦課基本(最新)
                WHEN c_NKIHON    THEN
                    FETCH CwKIHON    INTO RwKIHON;
                    EXIT WHEN CwKIHON%NOTFOUND;
                    -- 年税額,過年度分,減免額算出準備
                    NwNENDO       := RwKIHON.CHOTEI_NENDO;
                    NwNENZEI      := RwKIHON.NENZEI;
                    NwSEKISAN     := RwKIHON.SEKISAN;
                    NwGENGAKU_KEI := RwKIHON.GENGAKU_KEI;
                -- 賦課退職(最新)
                WHEN c_NTAI      THEN
                    FETCH CwTAI      INTO RwTAI;
                    EXIT WHEN CwTAI%NOTFOUND;
                    -- 年税額,過年度分,減免額算出準備
                    NwNENDO       := RwTAI.CHOTEI_NENDO;
                    NwNENZEI      := RwTAI.NENZEI;
                    NwSEKISAN     := RwTAI.SEKISAN;
                    NwGENGAKU_KEI := RwTAI.GENGAKU_KEI;
                -- 賦課介護基本(最新)
                WHEN c_NKAIKIHON THEN
                    FETCH CwKAIKIHON INTO RwKKIHON;
                    EXIT WHEN CwKAIKIHON%NOTFOUND;
                    -- 年税額,過年度分,減免額算出準備
                    NwNENDO       := RwKKIHON.CHOTEI_NENDO;
                    NwNENZEI      := RwKKIHON.NENZEI;
                    NwSEKISAN     := RwKKIHON.SEKISAN;
                    NwGENGAKU_KEI := RwKKIHON.GENGAKU_KEI;
                -- 賦課介護退職(最新)
                WHEN c_NKAITAI   THEN
                    FETCH CwKAITAI   INTO RwKTAI;
                    EXIT WHEN CwKAITAI%NOTFOUND;
                    -- 年税額,過年度分,減免額算出準備
                    NwNENDO       := RwKTAI.CHOTEI_NENDO;
                    NwNENZEI      := RwKTAI.NENZEI;
                    NwSEKISAN     := RwKTAI.SEKISAN;
                    NwGENGAKU_KEI := RwKTAI.GENGAKU_KEI;
                -- 賦課支援基本(最新)
                WHEN c_NSIENKIHON THEN
                    FETCH CwSIENKIHON INTO RwSKIHON;
                    EXIT WHEN CwSIENKIHON%NOTFOUND;
                    -- 年税額,過年度分,減免額算出準備
                    NwNENDO       := RwSKIHON.CHOTEI_NENDO;
                    NwNENZEI      := RwSKIHON.NENZEI;
                    NwSEKISAN     := RwSKIHON.SEKISAN;
                    NwGENGAKU_KEI := RwSKIHON.GENGAKU_KEI;
                -- 賦課支援退職(最新)
                WHEN c_NSIENTAI   THEN
                    FETCH CwSIENTAI   INTO RwSTAI;
                    EXIT WHEN CwSIENTAI%NOTFOUND;
                    -- 年税額,過年度分,減免額算出準備
                    NwNENDO       := RwSTAI.CHOTEI_NENDO;
                    NwNENZEI      := RwSTAI.NENZEI;
                    NwSEKISAN     := RwSTAI.SEKISAN;
                    NwGENGAKU_KEI := RwSTAI.GENGAKU_KEI;
                --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
                -- 子ども
                WHEN c_NKDMKIHON   THEN
                    FETCH CwKDMKIHON   INTO RwKDMKIHON;
                    EXIT WHEN CwKDMKIHON%NOTFOUND;
                    -- 年税額,過年度分,減免額算出準備
                    NwNENDO       := RwKDMKIHON.CHOTEI_NENDO;
                    NwNENZEI      := RwKDMKIHON.NENZEI;
                    NwSEKISAN     := RwKDMKIHON.SEKISAN;
                    NwGENGAKU_KEI := RwKDMKIHON.GENGAKU_KEI;
                --  2025/08/11 ZCZL.HAODAPENG ADD END
                END CASE;

                -- 過年度分、年税額を算出(年税額・過年度分はそれぞれ算出)
                -- 差額と取得年税額を比較して年税額を算出
                IF NwSAGAKU >= NwNENZEI THEN
                    -- 差額の方が大きい場合
                    NwCALNENZEI  := 0;                      -- 算出年税=0
                    NwCALKANENDO := NlNENZEI;               -- 算出過年=年税(結果)
                    NwSAGAKU     := NwSAGAKU - NwNENZEI;    -- 差額=差額-取得年税
                ELSE
                    -- 差額の方が小さい場合
                    -- 医療退職、介護退職、支援退職の場合
                    IF i_NwTBL IN (c_NTAI,c_NKAITAI,c_NSIENTAI) AND NwSAGAKU < 0 THEN
                        NwZEN_NENZEI := 0;
                        NwSETFLG2 := 0;
                        -- 医療退職
                        IF i_NwTBL = c_NTAI THEN
                            -- 全体年税額を取得
                            FOR vRec IN (SELECT NENZEI
                                         FROM   ZLBTKIHON_CAL
                                         WHERE  KOKU_SETAI_NO   = RwTAI_BK.KOKU_SETAI_NO
                                           AND  SANTEIDANTAI_CD = RwTAI_BK.SANTEIDANTAI_CD
                                           AND  CHOTEI_NENDO    = RwTAI.CHOTEI_NENDO
                                           AND  NENDO_BUN       = RwTAI_BK.NENDO_BUN
                                           AND  TSUCHI_NO       = RwTAI.TSUCHI_NO
                                           AND  SYS_TANMATSU_NO = i_VTANMATSU) LOOP
                                NwZEN_NENZEI := vRec.NENZEI;
                                NwSETFLG2 := 1;
                                EXIT;
                            END LOOP;
                        -- 介護退職
                        ELSIF i_NwTBL = c_NKAITAI THEN
                            -- 全体年税額を取得
                            FOR vRec IN (SELECT NENZEI
                                         FROM   ZLBTKAI_KIHON_CAL
                                         WHERE  KOKU_SETAI_NO   = RwKTAI_BK.KOKU_SETAI_NO
                                           AND  SANTEIDANTAI_CD = RwKTAI_BK.SANTEIDANTAI_CD
                                           AND  CHOTEI_NENDO    = RwKTAI.CHOTEI_NENDO
                                           AND  NENDO_BUN       = RwKTAI_BK.NENDO_BUN
                                           AND  TSUCHI_NO       = RwKTAI.TSUCHI_NO
                                           AND  SYS_TANMATSU_NO = i_VTANMATSU) LOOP
                                NwZEN_NENZEI := vRec.NENZEI;
                                NwSETFLG2 := 1;
                                EXIT;
                            END LOOP;
                        -- 支援退職
                        ELSIF i_NwTBL = c_NSIENTAI THEN
                            -- 全体年税額を取得
                            FOR vRec IN (SELECT NENZEI
                                         FROM   ZLBTSIEN_KIHON_CAL
                                         WHERE  KOKU_SETAI_NO   = RwSTAI_BK.KOKU_SETAI_NO
                                           AND  SANTEIDANTAI_CD = RwSTAI_BK.SANTEIDANTAI_CD
                                           AND  CHOTEI_NENDO    = RwSTAI.CHOTEI_NENDO
                                           AND  NENDO_BUN       = RwSTAI_BK.NENDO_BUN
                                           AND  TSUCHI_NO       = RwSTAI.TSUCHI_NO
                                           AND  SYS_TANMATSU_NO = i_VTANMATSU) LOOP
                                NwZEN_NENZEI := vRec.NENZEI;
                                NwSETFLG2 := 1;
                                EXIT;
                            END LOOP;
                        END IF;
                        -- 全体年税額が取得取得できた場合
                        IF NwSETFLG2 = 1 THEN
                            -- 全体年税額＜＝差額適用後の退職年税額の場合
                            IF NwZEN_NENZEI <= NwNENZEI - NwSAGAKU THEN
                                -- 退職年税額は全体年税額と同額とする
                                NwCALNENZEI  := NwZEN_NENZEI;
                            ELSE
                              IF NwSAGAKU < 0 AND NwLOOPCNT > 1 THEN
                                NwCALNENZEI  := NwNENZEI;    -- 算出年税=取得年税
                              ELSE
                                NwCALNENZEI  := NwNENZEI - NwSAGAKU;    -- 算出年税=取得年税-差額
                              END IF;
                                NwSAGAKU     := NwSAGAKU - NwNENZEI;    -- 差額=差額-取得年税額
                            END IF;
                            NwCALKANENDO := NlNENZEI - NwCALNENZEI; -- 算出過年=年税(結果)-算出年税
                        ELSE
                          IF NwSAGAKU < 0 AND NwLOOPCNT > 1 THEN
                            NwCALNENZEI  := NwNENZEI;    -- 算出年税=取得年税
                          ELSE
                            NwCALNENZEI  := NwNENZEI - NwSAGAKU;    -- 算出年税=取得年税-差額
                          END IF;
                            NwCALKANENDO := NlNENZEI - NwCALNENZEI; -- 算出過年=年税(結果)-算出年税
                            NwSAGAKU     := NwSAGAKU - NwNENZEI;    -- 差額=差額-取得年税額
                        END IF;
                    ELSE
                      IF NwSAGAKU < 0 AND NwLOOPCNT > 1 THEN
                        NwCALNENZEI  := NwNENZEI;    -- 算出年税=取得年税
                      ELSE
                        NwCALNENZEI  := NwNENZEI - NwSAGAKU;    -- 算出年税=取得年税-差額
                      END IF;
                        NwCALKANENDO := NlNENZEI - NwCALNENZEI; -- 算出過年=年税(結果)-算出年税
                        NwSAGAKU     := NwSAGAKU - NwNENZEI;    -- 差額=差額-取得年税額
                    END IF;
                END IF;

                -- 計算TBL作成(追加)
                CASE i_NwTBL
                -- 賦課基本(最新)
                WHEN c_NKIHON    THEN
                    RwKIHON_INS                     := RwKIHON_BK;                -- 計算バックアップ内容を出力ワークにセット
                    RwKIHON_INS.CHOTEI_NENDO        := RwKIHON.CHOTEI_NENDO;      -- 調定年度
                    RwKIHON_INS.R_NO                := RwKIHON.R_NO + c_NRNO_CNT; -- 履歴番号
                    RwKIHON_INS.TSUCHI_NO           := RwKIHON.TSUCHI_NO;         -- 通知書番号
                    RwKIHON_INS.KANENDO             := NwCALKANENDO;              -- 過年度分
                    RwKIHON_INS.NENZEI              := NwCALNENZEI;               -- 年税額
                    RwKIHON_INS.SYS_SAKUSEIBI       := NlDATE;                    -- 作成日
                    RwKIHON_INS.SYS_KOSHINBI        := NlDATE;                    -- 更新日
                    RwKIHON_INS.SYS_JIKAN           := NlTIME;                    -- 更新時間
                    RwKIHON_INS.SYS_SHOKUINKOJIN_NO := i_NSYS_SHOKUIN;            -- 更新職員番号
                    RwKIHON_INS.SYS_TANMATSU_NO     := i_VTANMATSU;               -- 更新端末番号
                    -- 計算TBLに追加
                    INSERT INTO ZLBTKIHON_CAL VALUES RwKIHON_INS;
                    NwSETFLG := 1;
                    -- 計算個人に追加
                    subInsKojin(RwKIHON_INS.CHOTEI_NENDO,
                              RwKIHON_INS.R_NO,
                              RwKIHON_INS.TSUCHI_NO);     -- 12 計算個人の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算所得の追加
                    subInsShotoku(RwKIHON_INS.CHOTEI_NENDO,
                              RwKIHON_INS.R_NO,
                              RwKIHON_INS.TSUCHI_NO);   -- 13 計算所得の追加
                    EXIT WHEN NlRTN != c_NOK;

                    -- 計算賦課拡張の追加
                    subInsExt(RwKIHON_INS.CHOTEI_NENDO,
                              RwKIHON_INS.R_NO,
                              RwKIHON_INS.TSUCHI_NO);   -- 14 計算賦課拡張の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算特徴対象者の追加
                    subInsTokukihon(RwKIHON_INS.CHOTEI_NENDO,
                                    RwKIHON_INS.R_NO,
                                    RwKIHON_INS.TSUCHI_NO);   -- 15 計算特徴対象者の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算減免個人の追加
                    IF NlCNT > 0 THEN
                      subInsGENMENKOJIN(RwKIHON_INS.CHOTEI_NENDO,
                                        RwKIHON_INS.R_NO,
                                        RwKIHON_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                      EXIT WHEN NlRTN != c_NOK;
                    END IF;


                -- 賦課退職(最新)
                WHEN c_NTAI      THEN
                    RwTAI_INS                       := RwTAI_BK;                  -- 計算バックアップ内容を出力ワークにセット
                    RwTAI_INS.CHOTEI_NENDO          := RwTAI.CHOTEI_NENDO;        -- 調定年度
                    RwTAI_INS.R_NO                  := RwTAI.R_NO + c_NRNO_CNT;   -- 履歴番号
                    RwTAI_INS.TSUCHI_NO             := RwTAI.TSUCHI_NO;           -- 通知書番号
                    RwTAI_INS.KANENDO               := NwCALKANENDO;              -- 過年度分
                    RwTAI_INS.NENZEI                := NwCALNENZEI;               -- 年税額
                    RwTAI_INS.SYS_SAKUSEIBI         := NlDATE;                    -- 作成日
                    RwTAI_INS.SYS_KOSHINBI          := NlDATE;                    -- 更新日
                    RwTAI_INS.SYS_JIKAN             := NlTIME;                    -- 更新時間
                    RwTAI_INS.SYS_SHOKUINKOJIN_NO   := i_NSYS_SHOKUIN;            -- 更新職員番号
                    RwTAI_INS.SYS_TANMATSU_NO       := i_VTANMATSU;               -- 更新端末番号
                    -- 計算TBLに追加
                    INSERT INTO ZLBTTAI_CAL VALUES RwTAI_INS;
                    NwSETFLG := 1;
                    -- 計算個人に追加
                    subInsKojin(RwTAI_INS.CHOTEI_NENDO,
                              RwTAI_INS.R_NO,
                              RwTAI_INS.TSUCHI_NO);     -- 12 計算個人の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算所得の追加
                    subInsShotoku(RwTAI_INS.CHOTEI_NENDO,
                              RwTAI_INS.R_NO,
                              RwTAI_INS.TSUCHI_NO);   -- 13 計算所得の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算賦課拡張の追加
                    subInsExt(RwTAI_INS.CHOTEI_NENDO,
                              RwTAI_INS.R_NO,
                              RwTAI_INS.TSUCHI_NO);   -- 14 計算賦課拡張の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算特徴対象者の追加
                    subInsTokukihon(RwTAI_INS.CHOTEI_NENDO,
                                    RwTAI_INS.R_NO,
                                    RwTAI_INS.TSUCHI_NO);   -- 15 計算特徴対象者の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算減免個人の追加
                    IF NlCNT > 0 THEN
                      subInsGENMENKOJIN(RwTAI_INS.CHOTEI_NENDO,
                                        RwTAI_INS.R_NO,
                                        RwTAI_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                      EXIT WHEN NlRTN != c_NOK;
                    END IF;

                -- 賦課介護基本(最新)
                WHEN c_NKAIKIHON THEN
                    RwKKIHON_INS                    := RwKKIHON_BK;               -- 計算バックアップ内容を出力ワークにセット
                    RwKKIHON_INS.CHOTEI_NENDO       := RwKKIHON.CHOTEI_NENDO;     -- 調定年度
                    RwKKIHON_INS.R_NO               := RwKKIHON.R_NO + c_NRNO_CNT;-- 履歴番号
                    RwKKIHON_INS.TSUCHI_NO          := RwKKIHON.TSUCHI_NO;        -- 通知書番号
                    RwKKIHON_INS.KANENDO            := NwCALKANENDO;              -- 過年度分
                    RwKKIHON_INS.NENZEI             := NwCALNENZEI;               -- 年税額
                    RwKKIHON_INS.SYS_SAKUSEIBI      := NlDATE;                    -- 作成日
                    RwKKIHON_INS.SYS_KOSHINBI       := NlDATE;                    -- 更新日
                    RwKKIHON_INS.SYS_JIKAN          := NlTIME;                    -- 更新時間
                    RwKKIHON_INS.SYS_SHOKUINKOJIN_NO:= i_NSYS_SHOKUIN;            -- 更新職員番号
                    RwKKIHON_INS.SYS_TANMATSU_NO    := i_VTANMATSU;               -- 更新端末番号
                    -- 計算TBLに追加
                    INSERT INTO ZLBTKAI_KIHON_CAL VALUES RwKKIHON_INS;
                    NwSETFLG := 1;
                    -- 計算個人に追加
                    subInsKojin(RwKKIHON_INS.CHOTEI_NENDO,
                            RwKKIHON_INS.R_NO,
                            RwKKIHON_INS.TSUCHI_NO);    -- 12 計算個人の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算所得の追加
                    subInsShotoku(RwKKIHON_INS.CHOTEI_NENDO,
                            RwKKIHON_INS.R_NO,
                            RwKKIHON_INS.TSUCHI_NO);  -- 13 計算所得の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算賦課拡張の追加
                    subInsExt(RwKKIHON_INS.CHOTEI_NENDO,
                              RwKKIHON_INS.R_NO,
                              RwKKIHON_INS.TSUCHI_NO);   -- 14 計算賦課拡張の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算特徴対象者の追加
                    subInsTokukihon(RwKKIHON_INS.CHOTEI_NENDO,
                                    RwKKIHON_INS.R_NO,
                                    RwKKIHON_INS.TSUCHI_NO);   -- 15 計算特徴対象者の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算減免個人の追加
                    IF NlCNT > 0 THEN
                      subInsGENMENKOJIN(RwKKIHON_INS.CHOTEI_NENDO,
                                        RwKKIHON_INS.R_NO,
                                        RwKKIHON_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                      EXIT WHEN NlRTN != c_NOK;
                    END IF;
                -- 賦課介護退職(最新)
                WHEN c_NKAITAI   THEN
                    RwKTAI_INS                      := RwKTAI_BK;                 -- 計算バックアップ内容を出力ワークにセット
                    RwKTAI_INS.CHOTEI_NENDO         := RwKTAI.CHOTEI_NENDO;       -- 調定年度
                    RwKTAI_INS.R_NO                 := RwKTAI.R_NO + c_NRNO_CNT;  -- 履歴番号
                    RwKTAI_INS.TSUCHI_NO            := RwKTAI.TSUCHI_NO;          -- 通知書番号
                    RwKTAI_INS.KANENDO              := NwCALKANENDO;              -- 過年度分
                    RwKTAI_INS.NENZEI               := NwCALNENZEI;               -- 年税額
                    RwKTAI_INS.SYS_SAKUSEIBI        := NlDATE;                    -- 作成日
                    RwKTAI_INS.SYS_KOSHINBI         := NlDATE;                    -- 更新日
                    RwKTAI_INS.SYS_JIKAN            := NlTIME;                    -- 更新時間
                    RwKTAI_INS.SYS_SHOKUINKOJIN_NO  := i_NSYS_SHOKUIN;            -- 更新職員番号
                    RwKTAI_INS.SYS_TANMATSU_NO      := i_VTANMATSU;               -- 更新端末番号
                    -- 計算TBLに追加
                    INSERT INTO ZLBTKAI_TAI_CAL VALUES RwKTAI_INS;
                    NwSETFLG := 1;
                    -- 計算個人に追加
                    subInsKojin(RwKTAI_INS.CHOTEI_NENDO,
                                RwKTAI_INS.R_NO,
                                RwKTAI_INS.TSUCHI_NO);      -- 12 計算個人の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算所得の追加
                    subInsShotoku(RwKTAI_INS.CHOTEI_NENDO,
                                RwKTAI_INS.R_NO,
                                RwKTAI_INS.TSUCHI_NO);    -- 13 計算所得の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算賦課拡張の追加
                    subInsExt(RwKTAI_INS.CHOTEI_NENDO,
                              RwKTAI_INS.R_NO,
                              RwKTAI_INS.TSUCHI_NO);   -- 14 計算賦課拡張の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算特徴対象者の追加
                    subInsTokukihon(RwKTAI_INS.CHOTEI_NENDO,
                                    RwKTAI_INS.R_NO,
                                    RwKTAI_INS.TSUCHI_NO);   -- 15 計算特徴対象者の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算減免個人の追加
                    IF NlCNT > 0 THEN
                      subInsGENMENKOJIN(RwKTAI_INS.CHOTEI_NENDO,
                                        RwKTAI_INS.R_NO,
                                        RwKTAI_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                      EXIT WHEN NlRTN != c_NOK;
                    END IF;
                -- 賦課支援基本(最新)
                WHEN c_NSIENKIHON THEN
                    RwSKIHON_INS                    := RwSKIHON_BK;               -- 計算バックアップ内容を出力ワークにセット
                    RwSKIHON_INS.CHOTEI_NENDO       := RwSKIHON.CHOTEI_NENDO;     -- 調定年度
                    RwSKIHON_INS.R_NO               := RwSKIHON.R_NO + c_NRNO_CNT;-- 履歴番号
                    RwSKIHON_INS.TSUCHI_NO          := RwSKIHON.TSUCHI_NO;        -- 通知書番号
                    RwSKIHON_INS.KANENDO            := NwCALKANENDO;              -- 過年度分
                    RwSKIHON_INS.NENZEI             := NwCALNENZEI;               -- 年税額
                    RwSKIHON_INS.SYS_SAKUSEIBI      := NlDATE;                    -- 作成日
                    RwSKIHON_INS.SYS_KOSHINBI       := NlDATE;                    -- 更新日
                    RwSKIHON_INS.SYS_JIKAN          := NlTIME;                    -- 更新時間
                    RwSKIHON_INS.SYS_SHOKUINKOJIN_NO:= i_NSYS_SHOKUIN;            -- 更新職員番号
                    RwSKIHON_INS.SYS_TANMATSU_NO    := i_VTANMATSU;               -- 更新端末番号
                    -- 計算TBLに追加
                    INSERT INTO ZLBTSIEN_KIHON_CAL VALUES RwSKIHON_INS;
                    NwSETFLG := 1;
                    -- 計算個人に追加
                    subInsKojin(RwSKIHON_INS.CHOTEI_NENDO,
                            RwSKIHON_INS.R_NO,
                            RwSKIHON_INS.TSUCHI_NO);    -- 12 計算個人の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算所得の追加
                    subInsShotoku(RwSKIHON_INS.CHOTEI_NENDO,
                            RwSKIHON_INS.R_NO,
                            RwSKIHON_INS.TSUCHI_NO);  -- 13 計算所得の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算賦課拡張の追加
                    subInsExt(RwSKIHON_INS.CHOTEI_NENDO,
                              RwSKIHON_INS.R_NO,
                              RwSKIHON_INS.TSUCHI_NO);   -- 14 計算賦課拡張の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算特徴対象者の追加
                    subInsTokukihon(RwSKIHON_INS.CHOTEI_NENDO,
                                    RwSKIHON_INS.R_NO,
                                    RwSKIHON_INS.TSUCHI_NO);   -- 15 計算特徴対象者の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算減免個人の追加
                    IF NlCNT > 0 THEN
                      subInsGENMENKOJIN(RwSKIHON_INS.CHOTEI_NENDO,
                                        RwSKIHON_INS.R_NO,
                                        RwSKIHON_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                      EXIT WHEN NlRTN != c_NOK;
                    END IF;
                -- 賦課支援退職(最新)
                WHEN c_NSIENTAI   THEN
                    RwSTAI_INS                      := RwSTAI_BK;                 -- 計算バックアップ内容を出力ワークにセット
                    RwSTAI_INS.CHOTEI_NENDO         := RwSTAI.CHOTEI_NENDO;       -- 調定年度
                    RwSTAI_INS.R_NO                 := RwSTAI.R_NO + c_NRNO_CNT;  -- 履歴番号
                    RwSTAI_INS.TSUCHI_NO            := RwSTAI.TSUCHI_NO;          -- 通知書番号
                    RwSTAI_INS.KANENDO              := NwCALKANENDO;              -- 過年度分
                    RwSTAI_INS.NENZEI               := NwCALNENZEI;               -- 年税額
                    RwSTAI_INS.SYS_SAKUSEIBI        := NlDATE;                    -- 作成日
                    RwSTAI_INS.SYS_KOSHINBI         := NlDATE;                    -- 更新日
                    RwSTAI_INS.SYS_JIKAN            := NlTIME;                    -- 更新時間
                    RwSTAI_INS.SYS_SHOKUINKOJIN_NO  := i_NSYS_SHOKUIN;            -- 更新職員番号
                    RwSTAI_INS.SYS_TANMATSU_NO      := i_VTANMATSU;               -- 更新端末番号
                    -- 計算TBLに追加
                    INSERT INTO ZLBTSIEN_TAI_CAL VALUES RwSTAI_INS;
                    NwSETFLG := 1;
                    -- 計算個人に追加
                    subInsKojin(RwSTAI_INS.CHOTEI_NENDO,
                                RwSTAI_INS.R_NO,
                                RwSTAI_INS.TSUCHI_NO);      -- 12 計算個人の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算所得の追加
                    subInsShotoku(RwSTAI_INS.CHOTEI_NENDO,
                                RwSTAI_INS.R_NO,
                                RwSTAI_INS.TSUCHI_NO);    -- 13 計算所得の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算賦課拡張の追加
                    subInsExt(RwSTAI_INS.CHOTEI_NENDO,
                              RwSTAI_INS.R_NO,
                              RwSTAI_INS.TSUCHI_NO);   -- 14 計算賦課拡張の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算特徴対象者の追加
                    subInsTokukihon(RwSTAI_INS.CHOTEI_NENDO,
                                    RwSTAI_INS.R_NO,
                                    RwSTAI_INS.TSUCHI_NO);   -- 15 計算特徴対象者の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算減免個人の追加
                    IF NlCNT > 0 THEN
                      subInsGENMENKOJIN(RwSTAI_INS.CHOTEI_NENDO,
                                        RwSTAI_INS.R_NO,
                                        RwSTAI_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                      EXIT WHEN NlRTN != c_NOK;
                    END IF;
                --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
                -- 子ども
                WHEN c_NKDMKIHON   THEN
                    -- 年税額,過年度分,減免額算出準備
                    --子どもの出力ワーク：子どもの計算バックアップ内容をセット
                    --子どもの出力ワーク.調定年度：子どもの計算バックアップ内容.調定年度をセット
                    --子どもの出力ワーク.履歴番号：子どもの計算バックアップ内容.履歴番号+定数：10をセット
                    --子どもの出力ワーク.通知書番号：子どもの計算バックアップ内容.通知書番号をセット
                    --子どもの出力ワーク.過年度分：算出過年度分変数をセット
                    --子どもの出力ワーク.年税額：算出年税額変数をセット
                    --子どもの出力ワーク.作成日：作成日変数をセット
                    --子どもの出力ワーク.更新日：作成日分変数をセット
                    --子どもの出力ワーク.更新時間：更新時間変数をセット
                    --子どもの出力ワーク.更新職員番号：更新職員番号分変数をセット
                    --子どもの出力ワーク.更新端末番号：更新版末番号変数をセット
                    RwKDMKIHON_INS                      := RwKDMKIHON_BK;                 -- 計算バックアップ内容を出力ワークにセット
                    RwKDMKIHON_INS.CHOTEI_NENDO         := RwKDMKIHON.CHOTEI_NENDO;       -- 調定年度
                    RwKDMKIHON_INS.R_NO                 := RwKDMKIHON.R_NO + c_NRNO_CNT;  -- 履歴番号
                    RwKDMKIHON_INS.TSUCHI_NO            := RwKDMKIHON.TSUCHI_NO;          -- 通知書番号
                    RwKDMKIHON_INS.KANENDO              := NwCALKANENDO;              -- 過年度分
                    RwKDMKIHON_INS.NENZEI               := NwCALNENZEI;               -- 年税額
                    RwKDMKIHON_INS.SYS_SAKUSEIBI        := NlDATE;                    -- 作成日
                    RwKDMKIHON_INS.SYS_KOSHINBI         := NlDATE;                    -- 更新日
                    RwKDMKIHON_INS.SYS_JIKAN            := NlTIME;                    -- 更新時間
                    RwKDMKIHON_INS.SYS_SHOKUINKOJIN_NO  := i_NSYS_SHOKUIN;            -- 更新職員番号
                    RwKDMKIHON_INS.SYS_TANMATSU_NO      := i_VTANMATSU;               -- 更新端末番号
                    -- 計算TBLに追加
                    INSERT INTO ZLBTKDM_KIHON_CAL VALUES RwKDMKIHON_INS;
                    NwSETFLG := 1;
                    -- 計算個人に追加
                    subInsKojin(RwKDMKIHON_INS.CHOTEI_NENDO,
                                RwKDMKIHON_INS.R_NO,
                                RwKDMKIHON_INS.TSUCHI_NO);      -- 12 計算個人の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算所得の追加
                    subInsShotoku(RwKDMKIHON_INS.CHOTEI_NENDO,
                                RwKDMKIHON_INS.R_NO,
                                RwKDMKIHON_INS.TSUCHI_NO);    -- 13 計算所得の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算賦課拡張の追加
                    subInsExt(RwKDMKIHON_INS.CHOTEI_NENDO,
                              RwKDMKIHON_INS.R_NO,
                              RwKDMKIHON_INS.TSUCHI_NO);   -- 14 計算賦課拡張の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算特徴対象者の追加
                    subInsTokukihon(RwKDMKIHON_INS.CHOTEI_NENDO,
                                    RwKDMKIHON_INS.R_NO,
                                    RwKDMKIHON_INS.TSUCHI_NO);   -- 15 計算特徴対象者の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算減免個人の追加
                    IF NlCNT > 0 THEN
                      subInsGENMENKOJIN(RwKDMKIHON_INS.CHOTEI_NENDO,
                                        RwKDMKIHON_INS.R_NO,
                                        RwKDMKIHON_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                      EXIT WHEN NlRTN != c_NOK;
                    END IF;
                    --  2025/08/11 ZCZL.HAODAPENG ADD END

                END CASE;
            END LOOP;

            -- カーソルクローズ
            CASE i_NwTBL
            WHEN c_NKIHON    THEN CLOSE CwKIHON;        -- 賦課基本(最新)
            WHEN c_NTAI      THEN CLOSE CwTAI;          -- 賦課退職(最新)
            WHEN c_NKAIKIHON THEN CLOSE CwKAIKIHON;     -- 賦課介護基本(最新)
            WHEN c_NKAITAI   THEN CLOSE CwKAITAI;       -- 賦課介護退職(最新)
            WHEN c_NSIENKIHON THEN CLOSE CwSIENKIHON;   -- 賦課支援基本(最新)
            WHEN c_NSIENTAI   THEN CLOSE CwSIENTAI;     -- 賦課支援退職(最新)
            --  2025/08/11 ZCZL.HAODAPENG ADD 1.1.200.000:子ども子育て支援金対応
            WHEN c_NKDMKIHON   THEN CLOSE CwKDMKIHON;     -- 子ども
            END CASE;
        END IF;


        -- 賦課(最新で且つ調定年度＝年度分)を取得し計算結果の内容で追加する ------5
        IF i_NwTBL = c_NKIHON THEN
            NwIRYSAGAKU := NwSAGAKU;
        ELSIF i_NwTBL = c_NKAIKIHON THEN
            NwKAISAGAKU := NwSAGAKU;
        ELSIF i_NwTBL = c_NSIENKIHON THEN
            NwSIENSAGAKU := NwSAGAKU;
        --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
        ELSIF i_NwTBL = c_NKDMKIHON THEN
            NwKDMSAGAKU := NwSAGAKU;
        --  2025/08/11 ZCZL.HAODAPENG ADD END
        END IF;

        IF (NwSAGAKU >= 0 OR
            (i_NwTBL = c_NTAI AND NwIRYSAGAKU <= 0 AND NwSAGAKU < 0) OR
            (i_NwTBL = c_NKAITAI AND NwKAISAGAKU <= 0 AND NwSAGAKU < 0) OR
            (i_NwTBL = c_NSIENTAI AND NwSIENSAGAKU <= 0 AND NwSAGAKU < 0)) AND NwSETFLG = 0 THEN
            -- 差額の残り有り→調定年度＝年度分のデータを作成
            CASE i_NwTBL
            -- 基本
            WHEN c_NKIHON    THEN
                SELECT COUNT(*) INTO NwCNT FROM ZLBTKIHON_N
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    <> i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN
                 AND   NUSHI_KOJIN_NO  = NlNUSHI_KOJIN_NO;
            -- 退職
            WHEN c_NTAI      THEN
                SELECT COUNT(*) INTO NwCNT FROM ZLBTTAI_N
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    <> i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN
                 AND   TSUCHI_NO       = (SELECT MAX(TSUCHI_NO) FROM ZLBTKIHON_N
                               WHERE KOKU_SETAI_NO   = i_NSETAI
                               AND   SANTEIDANTAI_CD = i_NDANTAI
                               AND   CHOTEI_NENDO    <> i_NNENDO
                               AND   NENDO_BUN       = i_NNENDO_BUN
                               AND   NUSHI_KOJIN_NO  = NlNUSHI_KOJIN_NO);
            -- 介護基本
            WHEN c_NKAIKIHON THEN
                SELECT COUNT(*) INTO NwCNT FROM ZLBTKAI_KIHON_N
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    <> i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN
                 AND   NUSHI_KOJIN_NO  = NlNUSHI_KOJIN_NO;
            -- 介護退職
            WHEN c_NKAITAI   THEN
                SELECT COUNT(*) INTO NwCNT FROM ZLBTKAI_TAI_N
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    <> i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN
                 AND   TSUCHI_NO       = (SELECT MAX(TSUCHI_NO) FROM ZLBTKAI_KIHON_N
                               WHERE KOKU_SETAI_NO   = i_NSETAI
                               AND   SANTEIDANTAI_CD = i_NDANTAI
                               AND   CHOTEI_NENDO    <> i_NNENDO
                               AND   NENDO_BUN       = i_NNENDO_BUN
                               AND   NUSHI_KOJIN_NO  = NlNUSHI_KOJIN_NO);

            -- 支援基本
            WHEN c_NSIENKIHON THEN
                SELECT COUNT(*) INTO NwCNT FROM ZLBTSIEN_KIHON_N
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    <> i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN
                 AND   NUSHI_KOJIN_NO  = NlNUSHI_KOJIN_NO;
            -- 支援退職
            WHEN c_NSIENTAI   THEN
                SELECT COUNT(*) INTO NwCNT FROM ZLBTSIEN_TAI_N
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    <> i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN
                 AND   TSUCHI_NO       = (SELECT MAX(TSUCHI_NO) FROM ZLBTSIEN_KIHON_N
                               WHERE KOKU_SETAI_NO   = i_NSETAI
                               AND   SANTEIDANTAI_CD = i_NDANTAI
                               AND   CHOTEI_NENDO    <> i_NNENDO
                               AND   NENDO_BUN       = i_NNENDO_BUN
                               AND   NUSHI_KOJIN_NO  = NlNUSHI_KOJIN_NO);
            --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
            WHEN c_NKDMKIHON   THEN
                SELECT COUNT(*) INTO NwCNT FROM ZLBTKDM_KIHON_N
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    <> i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN
                 AND   NUSHI_KOJIN_NO  = NlNUSHI_KOJIN_NO
                 ;
            --  2025/08/11 ZCZL.HAODAPENG ADD END
            END CASE;

            -- 取得データが1件の時のみ処理する。
            IF NwCNT >= 1 THEN
                -- カーソルオープン
                CASE i_NwTBL
                WHEN c_NKIHON    THEN       -- 賦課基本(最新)
                    IF CwKIHON%ISOPEN THEN
                        CLOSE CwKIHON;
                    END IF;
                    OPEN CwKIHON;
                WHEN c_NTAI      THEN       -- 賦課退職(最新)
                    IF CwTAI%ISOPEN THEN
                        CLOSE CwTAI;
                     END IF;
                    OPEN CwTAI;
                WHEN c_NKAIKIHON THEN       -- 賦課介護基本(最新)
                    IF CwKAIKIHON%ISOPEN THEN
                        CLOSE CwKAIKIHON;
                    END IF;
                    OPEN CwKAIKIHON;
                WHEN c_NKAITAI   THEN       -- 賦課介護退職(最新)
                    IF CwKAITAI%ISOPEN THEN
                        CLOSE CwKAITAI;
                    END IF;
                    OPEN CwKAITAI;
                WHEN c_NSIENKIHON THEN       -- 賦課支援基本(最新)
                    IF CwSIENKIHON%ISOPEN THEN
                        CLOSE CwSIENKIHON;
                    END IF;
                    OPEN CwSIENKIHON;
                WHEN c_NSIENTAI   THEN       -- 賦課支援退職(最新)
                    IF CwSIENTAI%ISOPEN THEN
                        CLOSE CwSIENTAI;
                    END IF;
                    OPEN CwSIENTAI;
                --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
                WHEN c_NKDMKIHON   THEN
                    IF CwKDMKIHON%ISOPEN THEN
                        CLOSE CwKDMKIHON;
                    END IF;
                    OPEN CwKDMKIHON;
                --  2025/08/11 ZCZL.HAODAPENG ADD END
                END CASE;

                Loop
                    EXIT WHEN NwCNT <= 0;

                    -- 計算TBL作成(追加)
                    CASE i_NwTBL
                    -- 賦課基本(最新)
                    WHEN c_NKIHON    THEN
                        FETCH CwKIHON    INTO RwKIHON;
                        EXIT WHEN CwKIHON%NOTFOUND;
                        RwKIHON_INS                     := RwKIHON;                   -- 計算バックアップ内容を出力ワークにセット
                        RwKIHON_INS.CHOTEI_NENDO        := RwKIHON.CHOTEI_NENDO;      -- 調定年度
                        RwKIHON_INS.R_NO                := RwKIHON.R_NO + c_NRNO_CNT; -- 履歴番号
                        RwKIHON_INS.TSUCHI_NO           := RwKIHON.TSUCHI_NO;         -- 通知書番号
                        RwKIHON_INS.SYS_SAKUSEIBI       := NlDATE;                    -- 作成日
                        RwKIHON_INS.SYS_KOSHINBI        := NlDATE;                    -- 更新日
                        RwKIHON_INS.SYS_JIKAN           := NlTIME;                    -- 更新時間
                        RwKIHON_INS.SYS_SHOKUINKOJIN_NO := i_NSYS_SHOKUIN;            -- 更新職員番号
                        RwKIHON_INS.SYS_TANMATSU_NO     := i_VTANMATSU;               -- 更新端末番号
                        -- 計算TBLに追加
                        INSERT INTO ZLBTKIHON_CAL VALUES RwKIHON_INS;
                        -- 計算個人に追加
                        subInsKojin(RwKIHON_INS.CHOTEI_NENDO,
                                    RwKIHON_INS.R_NO,
                                    RwKIHON_INS.TSUCHI_NO);       -- 12 計算個人の追加
                        -- 計算所得の追加
                        IF NlRTN = c_NOK THEN
                          subInsShotoku(RwKIHON_INS.CHOTEI_NENDO,
                                        RwKIHON_INS.R_NO,
                                        RwKIHON_INS.TSUCHI_NO);   -- 13 計算所得の追加
                        END IF;
                        -- 計算賦課拡張の追加
                        IF NlRTN = c_NOK THEN
                          subInsExt(RwKIHON_INS.CHOTEI_NENDO,
                                    RwKIHON_INS.R_NO,
                                    RwKIHON_INS.TSUCHI_NO);        -- 14 計算賦課拡張の追加
                        END IF;

                        -- 計算特徴対象者の追加
                        IF NlRTN = c_NOK THEN
                          subInsTokukihon(RwKIHON_INS.CHOTEI_NENDO,
                                          RwKIHON_INS.R_NO,
                                          RwKIHON_INS.TSUCHI_NO);  -- 15 計算特徴対象者の追加
                        END IF;
                        -- 計算減免個人の追加
                        IF NlCNT > 0 THEN
                          subInsGENMENKOJIN(RwKIHON_INS.CHOTEI_NENDO,
                                            RwKIHON_INS.R_NO,
                                            RwKIHON_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                        END IF;
                    -- 賦課退職(最新)
                    WHEN c_NTAI      THEN
                        FETCH CwTAI      INTO RwTAI;
                        EXIT WHEN CwTAI%NOTFOUND;
                        RwTAI_INS                       := RwTAI;                  -- 計算バックアップ内容を出力ワークにセット
                        RwTAI_INS.CHOTEI_NENDO          := RwTAI.CHOTEI_NENDO;        -- 調定年度
                        RwTAI_INS.R_NO                  := RwTAI.R_NO + c_NRNO_CNT;   -- 履歴番号
                        RwTAI_INS.TSUCHI_NO             := RwTAI.TSUCHI_NO;           -- 通知書番号
                        RwTAI_INS.SYS_SAKUSEIBI         := NlDATE;                    -- 作成日
                        RwTAI_INS.SYS_KOSHINBI          := NlDATE;                    -- 更新日
                        RwTAI_INS.SYS_JIKAN             := NlTIME;                    -- 更新時間
                        RwTAI_INS.SYS_SHOKUINKOJIN_NO   := i_NSYS_SHOKUIN;            -- 更新職員番号
                        RwTAI_INS.SYS_TANMATSU_NO       := i_VTANMATSU;               -- 更新端末番号
                        -- 計算TBLに追加
                        INSERT INTO ZLBTTAI_CAL VALUES RwTAI_INS;
                        -- 計算個人に追加
                        subInsKojin(RwTAI_INS.CHOTEI_NENDO,
                                    RwTAI_INS.R_NO,
                                    RwTAI_INS.TSUCHI_NO);       -- 12 計算個人の追加
                        -- 計算所得の追加
                        IF NlRTN = c_NOK THEN
                          subInsShotoku(RwTAI_INS.CHOTEI_NENDO,
                                        RwTAI_INS.R_NO,
                                        RwTAI_INS.TSUCHI_NO);   -- 13 計算所得の追加
                        END IF;
                        -- 計算賦課拡張の追加
                        IF NlRTN = c_NOK THEN
                          subInsExt(RwTAI_INS.CHOTEI_NENDO,
                                    RwTAI_INS.R_NO,
                                    RwTAI_INS.TSUCHI_NO);        -- 14 計算賦課拡張の追加
                        END IF;

                        -- 計算特徴対象者の追加
                        IF NlRTN = c_NOK THEN
                          subInsTokukihon(RwTAI_INS.CHOTEI_NENDO,
                                          RwTAI_INS.R_NO,
                                          RwTAI_INS.TSUCHI_NO);  -- 15 計算特徴対象者の追加
                        END IF;
                        -- 計算減免個人の追加
                        IF NlCNT > 0 THEN
                          subInsGENMENKOJIN(RwTAI_INS.CHOTEI_NENDO,
                                            RwTAI_INS.R_NO,
                                            RwTAI_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                        END IF;
                    -- 賦課介護基本(最新)
                    WHEN c_NKAIKIHON THEN
                        FETCH CwKAIKIHON INTO RwKKIHON;
                        EXIT WHEN CwKAIKIHON%NOTFOUND;
                        RwKKIHON_INS                    := RwKKIHON;               -- 計算バックアップ内容を出力ワークにセット
                        RwKKIHON_INS.CHOTEI_NENDO       := RwKKIHON.CHOTEI_NENDO;     -- 調定年度
                        RwKKIHON_INS.R_NO               := RwKKIHON.R_NO + c_NRNO_CNT;-- 履歴番号
                        RwKKIHON_INS.TSUCHI_NO          := RwKKIHON.TSUCHI_NO;        -- 通知書番号
                        RwKKIHON_INS.SYS_SAKUSEIBI      := NlDATE;                    -- 作成日
                        RwKKIHON_INS.SYS_KOSHINBI       := NlDATE;                    -- 更新日
                        RwKKIHON_INS.SYS_JIKAN          := NlTIME;                    -- 更新時間
                        RwKKIHON_INS.SYS_SHOKUINKOJIN_NO:= i_NSYS_SHOKUIN;            -- 更新職員番号
                        RwKKIHON_INS.SYS_TANMATSU_NO    := i_VTANMATSU;               -- 更新端末番号
                        -- 計算TBLに追加
                        INSERT INTO ZLBTKAI_KIHON_CAL VALUES RwKKIHON_INS;
                        -- 計算個人に追加
                        subInsKojin(RwKKIHON_INS.CHOTEI_NENDO,
                                    RwKKIHON_INS.R_NO,
                                    RwKKIHON_INS.TSUCHI_NO);      -- 12 計算個人の追加
                        -- 計算所得の追加
                        IF NlRTN = c_NOK THEN
                          subInsShotoku(RwKKIHON_INS.CHOTEI_NENDO,
                                        RwKKIHON_INS.R_NO,
                                        RwKKIHON_INS.TSUCHI_NO);  -- 13 計算所得の追加
                        END IF;
                        -- 計算賦課拡張の追加
                        IF NlRTN = c_NOK THEN
                          subInsExt(RwKKIHON_INS.CHOTEI_NENDO,
                                    RwKKIHON_INS.R_NO,
                                    RwKKIHON_INS.TSUCHI_NO);        -- 14 計算賦課拡張の追加
                        END IF;

                        -- 計算特徴対象者の追加
                        IF NlRTN = c_NOK THEN
                          subInsTokukihon(RwKKIHON_INS.CHOTEI_NENDO,
                                          RwKKIHON_INS.R_NO,
                                          RwKKIHON_INS.TSUCHI_NO);  -- 15 計算特徴対象者の追加
                        END IF;
                        -- 計算減免個人の追加
                        IF NlCNT > 0 THEN
                          subInsGENMENKOJIN(RwKKIHON_INS.CHOTEI_NENDO,
                                            RwKKIHON_INS.R_NO,
                                            RwKKIHON_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                        END IF;
                    -- 賦課介護退職(最新)
                    WHEN c_NKAITAI   THEN
                        FETCH CwKAITAI   INTO RwKTAI;
                        EXIT WHEN CwKAITAI%NOTFOUND;
                        RwKTAI_INS                      := RwKTAI;                 -- 計算バックアップ内容を出力ワークにセット
                        RwKTAI_INS.CHOTEI_NENDO         := RwKTAI.CHOTEI_NENDO;       -- 調定年度
                        RwKTAI_INS.R_NO                 := RwKTAI.R_NO + c_NRNO_CNT;  -- 履歴番号
                        RwKTAI_INS.TSUCHI_NO            := RwKTAI.TSUCHI_NO;          -- 通知書番号
                        RwKTAI_INS.SYS_SAKUSEIBI        := NlDATE;                    -- 作成日
                        RwKTAI_INS.SYS_KOSHINBI         := NlDATE;                    -- 更新日
                        RwKTAI_INS.SYS_JIKAN            := NlTIME;                    -- 更新時間
                        RwKTAI_INS.SYS_SHOKUINKOJIN_NO  := i_NSYS_SHOKUIN;            -- 更新職員番号
                        RwKTAI_INS.SYS_TANMATSU_NO      := i_VTANMATSU;               -- 更新端末番号
                        -- 計算TBLに追加
                        INSERT INTO ZLBTKAI_TAI_CAL VALUES RwKTAI_INS;
                        -- 計算個人に追加
                        subInsKojin(RwKTAI_INS.CHOTEI_NENDO,
                                    RwKTAI_INS.R_NO,
                                    RwKTAI_INS.TSUCHI_NO);        -- 12 計算個人の追加
                        -- 計算所得の追加
                        IF NlRTN = c_NOK THEN
                          subInsShotoku(RwKTAI_INS.CHOTEI_NENDO,
                                        RwKTAI_INS.R_NO,
                                        RwKTAI_INS.TSUCHI_NO);    -- 13 計算所得の追加
                        END IF;
                        -- 計算賦課拡張の追加
                        IF NlRTN = c_NOK THEN
                          subInsExt(RwKTAI_INS.CHOTEI_NENDO,
                                    RwKTAI_INS.R_NO,
                                    RwKTAI_INS.TSUCHI_NO);        -- 14 計算賦課拡張の追加
                        END IF;

                        -- 計算特徴対象者の追加
                        IF NlRTN = c_NOK THEN
                          subInsTokukihon(RwKTAI_INS.CHOTEI_NENDO,
                                          RwKTAI_INS.R_NO,
                                          RwKTAI_INS.TSUCHI_NO);  -- 15 計算特徴対象者の追加
                        END IF;
                        -- 計算減免個人の追加
                        IF NlCNT > 0 THEN
                          subInsGENMENKOJIN(RwKTAI_INS.CHOTEI_NENDO,
                                            RwKTAI_INS.R_NO,
                                            RwKTAI_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                        END IF;

                    -- 賦課支援基本(最新)
                    WHEN c_NSIENKIHON THEN
                        FETCH CwSIENKIHON INTO RwSKIHON;
                        EXIT WHEN CwSIENKIHON%NOTFOUND;
                        RwSKIHON_INS                    := RwSKIHON;               -- 計算バックアップ内容を出力ワークにセット
                        RwSKIHON_INS.CHOTEI_NENDO       := RwSKIHON.CHOTEI_NENDO;     -- 調定年度
                        RwSKIHON_INS.R_NO               := RwSKIHON.R_NO + c_NRNO_CNT;-- 履歴番号
                        RwSKIHON_INS.TSUCHI_NO          := RwSKIHON.TSUCHI_NO;        -- 通知書番号
                        RwSKIHON_INS.SYS_SAKUSEIBI      := NlDATE;                    -- 作成日
                        RwSKIHON_INS.SYS_KOSHINBI       := NlDATE;                    -- 更新日
                        RwSKIHON_INS.SYS_JIKAN          := NlTIME;                    -- 更新時間
                        RwSKIHON_INS.SYS_SHOKUINKOJIN_NO:= i_NSYS_SHOKUIN;            -- 更新職員番号
                        RwSKIHON_INS.SYS_TANMATSU_NO    := i_VTANMATSU;               -- 更新端末番号
                        -- 計算TBLに追加
                        INSERT INTO ZLBTSIEN_KIHON_CAL VALUES RwSKIHON_INS;
                        -- 計算個人に追加
                        subInsKojin(RwSKIHON_INS.CHOTEI_NENDO,
                                    RwSKIHON_INS.R_NO,
                                    RwSKIHON_INS.TSUCHI_NO);      -- 12 計算個人の追加
                        -- 計算所得の追加
                        IF NlRTN = c_NOK THEN
                          subInsShotoku(RwSKIHON_INS.CHOTEI_NENDO,
                                        RwSKIHON_INS.R_NO,
                                        RwSKIHON_INS.TSUCHI_NO);  -- 13 計算所得の追加
                        END IF;
                        -- 計算賦課拡張の追加
                        IF NlRTN = c_NOK THEN
                          subInsExt(RwSKIHON_INS.CHOTEI_NENDO,
                                    RwSKIHON_INS.R_NO,
                                    RwSKIHON_INS.TSUCHI_NO);        -- 14 計算賦課拡張の追加
                        END IF;

                        -- 計算特徴対象者の追加
                        IF NlRTN = c_NOK THEN
                          subInsTokukihon(RwSKIHON_INS.CHOTEI_NENDO,
                                          RwSKIHON_INS.R_NO,
                                          RwSKIHON_INS.TSUCHI_NO);  -- 15 計算特徴対象者の追加
                        END IF;
                        -- 計算減免個人の追加
                        IF NlCNT > 0 THEN
                          subInsGENMENKOJIN(RwSKIHON_INS.CHOTEI_NENDO,
                                            RwSKIHON_INS.R_NO,
                                            RwSKIHON_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                        END IF;
                    -- 賦課支援退職(最新)
                    WHEN c_NSIENTAI   THEN
                        FETCH CwSIENTAI   INTO RwSTAI;
                        EXIT WHEN CwSIENTAI%NOTFOUND;
                        RwSTAI_INS                      := RwSTAI;                 -- 計算バックアップ内容を出力ワークにセット
                        RwSTAI_INS.CHOTEI_NENDO         := RwSTAI.CHOTEI_NENDO;       -- 調定年度
                        RwSTAI_INS.R_NO                 := RwSTAI.R_NO + c_NRNO_CNT;  -- 履歴番号
                        RwSTAI_INS.TSUCHI_NO            := RwSTAI.TSUCHI_NO;          -- 通知書番号
                        RwSTAI_INS.SYS_SAKUSEIBI        := NlDATE;                    -- 作成日
                        RwSTAI_INS.SYS_KOSHINBI         := NlDATE;                    -- 更新日
                        RwSTAI_INS.SYS_JIKAN            := NlTIME;                    -- 更新時間
                        RwSTAI_INS.SYS_SHOKUINKOJIN_NO  := i_NSYS_SHOKUIN;            -- 更新職員番号
                        RwSTAI_INS.SYS_TANMATSU_NO      := i_VTANMATSU;               -- 更新端末番号
                        -- 計算TBLに追加
                        INSERT INTO ZLBTSIEN_TAI_CAL VALUES RwSTAI_INS;
                        -- 計算個人に追加
                        subInsKojin(RwSTAI_INS.CHOTEI_NENDO,
                                    RwSTAI_INS.R_NO,
                                    RwSTAI_INS.TSUCHI_NO);        -- 12 計算個人の追加
                        -- 計算所得の追加
                        IF NlRTN = c_NOK THEN
                          subInsShotoku(RwSTAI_INS.CHOTEI_NENDO,
                                        RwSTAI_INS.R_NO,
                                        RwSTAI_INS.TSUCHI_NO);    -- 13 計算所得の追加
                        END IF;
                        -- 計算賦課拡張の追加
                        IF NlRTN = c_NOK THEN
                          subInsExt(RwSTAI_INS.CHOTEI_NENDO,
                                    RwSTAI_INS.R_NO,
                                    RwSTAI_INS.TSUCHI_NO);        -- 14 計算賦課拡張の追加
                        END IF;

                        -- 計算特徴対象者の追加
                        IF NlRTN = c_NOK THEN
                          subInsTokukihon(RwSTAI_INS.CHOTEI_NENDO,
                                          RwSTAI_INS.R_NO,
                                          RwSTAI_INS.TSUCHI_NO);  -- 15 計算特徴対象者の追加
                        END IF;
                        -- 計算減免個人の追加
                        IF NlCNT > 0 THEN
                          subInsGENMENKOJIN(RwSTAI_INS.CHOTEI_NENDO,
                                            RwSTAI_INS.R_NO,
                                            RwSTAI_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                        END IF;
                    --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
                    -- 子ども
                    WHEN c_NKDMKIHON   THEN
                        -- 年税額,過年度分,減免額算出準備
                        --子どもの出力ワーク：子どもの計算バックアップ内容をセット
                        --子どもの出力ワーク.調定年度：子どもの計算バックアップ内容.調定年度をセット
                        --子どもの出力ワーク.履歴番号：子どもの計算バックアップ内容.履歴番号+定数：10をセット
                        --子どもの出力ワーク.通知書番号：子どもの計算バックアップ内容.通知書番号をセット
                        --子どもの出力ワーク.過年度分：算出過年度分変数をセット
                        --子どもの出力ワーク.年税額：算出年税額変数をセット
                        --子どもの出力ワーク.作成日：作成日変数をセット
                        --子どもの出力ワーク.更新日：作成日分変数をセット
                        --子どもの出力ワーク.更新時間：更新時間変数をセット
                        --子どもの出力ワーク.更新職員番号：更新職員番号分変数をセット
                        --子どもの出力ワーク.更新端末番号：更新版末番号変数をセット
                        FETCH CwKDMKIHON INTO RwKDMKIHON;
                        EXIT WHEN CwKDMKIHON%NOTFOUND;
                        RwKDMKIHON_INS                      := RwKDMKIHON;                 -- 賦課子ども基本  (最新)　内容をセット
                        RwKDMKIHON_INS.CHOTEI_NENDO         := RwKDMKIHON.CHOTEI_NENDO;       -- 調定年度
                        RwKDMKIHON_INS.R_NO                 := RwKDMKIHON.R_NO + c_NRNO_CNT;  -- 履歴番号
                        RwKDMKIHON_INS.TSUCHI_NO            := RwKDMKIHON.TSUCHI_NO;          -- 通知書番号
                        RwKDMKIHON_INS.SYS_SAKUSEIBI        := NlDATE;                    -- 作成日
                        RwKDMKIHON_INS.SYS_KOSHINBI         := NlDATE;                    -- 更新日
                        RwKDMKIHON_INS.SYS_JIKAN            := NlTIME;                    -- 更新時間
                        RwKDMKIHON_INS.SYS_SHOKUINKOJIN_NO  := i_NSYS_SHOKUIN;            -- 更新職員番号
                        RwKDMKIHON_INS.SYS_TANMATSU_NO      := i_VTANMATSU;               -- 更新端末番号
                        -- 計算TBLに追加
                        INSERT INTO ZLBTKDM_KIHON_CAL VALUES RwKDMKIHON_INS;
                        -- 計算個人に追加
                        subInsKojin(RwKDMKIHON_INS.CHOTEI_NENDO,
                                    RwKDMKIHON_INS.R_NO,
                                    RwKDMKIHON_INS.TSUCHI_NO);        -- 12 計算個人の追加
                        -- 計算所得の追加
                        IF NlRTN = c_NOK THEN
                          subInsShotoku(RwKDMKIHON_INS.CHOTEI_NENDO,
                                        RwKDMKIHON_INS.R_NO,
                                        RwKDMKIHON_INS.TSUCHI_NO);    -- 13 計算所得の追加
                        END IF;
                        -- 計算賦課拡張の追加
                        IF NlRTN = c_NOK THEN
                          subInsExt(RwKDMKIHON_INS.CHOTEI_NENDO,
                                    RwKDMKIHON_INS.R_NO,
                                    RwKDMKIHON_INS.TSUCHI_NO);        -- 14 計算賦課拡張の追加
                        END IF;

                        -- 計算特徴対象者の追加
                        IF NlRTN = c_NOK THEN
                          subInsTokukihon(RwKDMKIHON_INS.CHOTEI_NENDO,
                                          RwKDMKIHON_INS.R_NO,
                                          RwKDMKIHON_INS.TSUCHI_NO);  -- 15 計算特徴対象者の追加
                        END IF;
                        -- 計算減免個人の追加
                        IF NlCNT > 0 THEN
                          subInsGENMENKOJIN(RwKDMKIHON_INS.CHOTEI_NENDO,
                                            RwKDMKIHON_INS.R_NO,
                                            RwKDMKIHON_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                        END IF;
                        --  2025/08/11 ZCZL.HAODAPENG ADD END

                    END CASE;

                    -- 取得データがn件時は清算処理が行われている為、自動セット不可能
                    NwCNT := NwCNT - 1;
                END LOOP;

                -- カーソルクローズ
                CASE i_NwTBL
                WHEN c_NKIHON    THEN CLOSE CwKIHON;        -- 賦課基本(最新)
                WHEN c_NTAI      THEN CLOSE CwTAI;          -- 賦課退職(最新)
                WHEN c_NKAIKIHON THEN CLOSE CwKAIKIHON;     -- 賦課介護基本(最新)
                WHEN c_NKAITAI   THEN CLOSE CwKAITAI;       -- 賦課介護退職(最新)
                WHEN c_NSIENKIHON THEN CLOSE CwSIENKIHON;   -- 賦課支援基本(最新)
                WHEN c_NSIENTAI   THEN CLOSE CwSIENTAI;     -- 賦課支援退職(最新)
                --  2025/08/11 ZCZL.HAODAPENG ADD 1.1.200.000:子ども子育て支援金対応
                WHEN c_NKDMKIHON   THEN CLOSE CwKDMKIHON;     -- 子ども
                END CASE;
            END IF;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            IF CwKIHON%ISOPEN THEN
              CLOSE CwKIHON;
            END IF;
            IF CwTAI%ISOPEN THEN
              CLOSE CwTAI;
            END IF;
            IF CwKAIKIHON%ISOPEN THEN
              CLOSE CwKAIKIHON;
            END IF;
            IF CwKAITAI%ISOPEN THEN
              CLOSE CwKAITAI;
            END IF;
            IF CwSIENKIHON%ISOPEN THEN
              CLOSE CwSIENKIHON;
            END IF;
            IF CwSIENTAI%ISOPEN THEN
              CLOSE CwSIENTAI;
            END IF;
            --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
            IF CwKDMKIHON%ISOPEN THEN
              CLOSE CwKDMKIHON;
            END IF;
            --  2025/08/11 ZCZL.HAODAPENG ADD END
            NlRTN := c_NERR;
            VlMSG := 'subGengaku 減額処理' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;

    END subGengaku;
-------------------------------------------------------------------------------
--  07 減額処理(主課税しない場合)
--      指定された計算TBLについて次の項目を更新する
--          ・過年度分、年税額
-------------------------------------------------------------------------------
    PROCEDURE subGengaku2(i_NwTBL IN NUMBER) IS
      -- 内部変数
      VwSQL               VARCHAR2(2048);           -- SQL文
      VwCALTBL            NVARCHAR2(30);            -- 計算TBL名
      NwSAGAKU            NUMBER;                   -- 差額
      NwCALKANENDO        NUMBER;                   -- 算出過年度分
      NwCALNENZEI         NUMBER;                   -- 算出年税額
      NwNENDO             NUMBER;                   -- 調定年度(賦課取得)
      NwNENZEI            NUMBER;                   -- 年税額(賦課取得)
      NwSEKISAN           NUMBER;                   -- 積算税額(賦課取得)
      NwGENGAKU_KEI       NUMBER;                   -- 減額合計(賦課取得)
      NwCNT               NUMBER;                   -- データ取得件数
      NwSETFLG            NUMBER := 0;    -- 更新フラグ
      NwSETFLG2           NUMBER := 0;              -- 全体税額取得フラグ
      NwZEN_NENZEI        NUMBER;                   -- 全体年税額

      -- 計算結果バックアップ
      RwKIHON_BK          ZLBTKIHON_N%ROWTYPE;      -- 計算基本
      RwTAI_BK            ZLBTTAI_N%ROWTYPE;        -- 計算退職基本
      RwKKIHON_BK         ZLBTKAI_KIHON_N%ROWTYPE;  -- 計算介護基本
      RwKTAI_BK           ZLBTKAI_TAI_N%ROWTYPE;    -- 計算介護退職基本
      RwSKIHON_BK         ZLBTSIEN_KIHON_N%ROWTYPE; -- 計算支援基本
      RwSTAI_BK           ZLBTSIEN_TAI_N%ROWTYPE;   -- 計算支援退職基本
     -- 賦課TBL取得ワーク
      RwKIHON             ZLBTKIHON_N%ROWTYPE;      -- 賦課基本        (最新)
      RwTAI               ZLBTTAI_N%ROWTYPE;        -- 賦課退職基本    (最新)
      RwKKIHON            ZLBTKAI_KIHON_N%ROWTYPE;  -- 賦課介護基本    (最新)
      RwKTAI              ZLBTKAI_TAI_N%ROWTYPE;    -- 賦課介護退職基本(最新)
      RwSKIHON            ZLBTSIEN_KIHON_N%ROWTYPE; -- 賦課支援基本    (最新)
      RwSTAI              ZLBTSIEN_TAI_N%ROWTYPE;   -- 賦課支援退職基本(最新)
     -- 計算TBL出力ワーク
      RwKIHON_INS         ZLBTKIHON_N%ROWTYPE;      -- 計算基本
      RwTAI_INS           ZLBTTAI_N%ROWTYPE;        -- 計算退職基本
      RwKKIHON_INS        ZLBTKAI_KIHON_N%ROWTYPE;  -- 計算介護基本
      RwKTAI_INS          ZLBTKAI_TAI_N%ROWTYPE;    -- 計算介護退職基本
      RwSKIHON_INS        ZLBTSIEN_KIHON_N%ROWTYPE; -- 計算支援基本
      RwSTAI_INS          ZLBTSIEN_TAI_N%ROWTYPE;   -- 計算支援退職基本
      --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
      RwKDMKIHON_BK       ZLBTKDM_KIHON_N%ROWTYPE;   --計算子ども基本
      RwKDMKIHON          ZLBTKDM_KIHON_N%ROWTYPE;   --賦課子ども基本  (最新)
      RwKDMKIHON_INS      ZLBTKDM_KIHON_N%ROWTYPE;   --計算子ども基本挿入
      --  2025/08/11 ZCZL.HAODAPENG ADD END

      NwLOOPCNT           NUMBER := 0;              --ループ回数記録用
      -- 賦課基本(最新)カーソル    [過年度分のみ]
      CURSOR CwKIHON IS
          SELECT * FROM ZLBTKIHON_N
           WHERE KOKU_SETAI_NO   =  i_NSETAI
             AND SANTEIDANTAI_CD =  i_NDANTAI
             AND CHOTEI_NENDO    <> i_NNENDO
             AND NENDO_BUN       =  i_NNENDO_BUN
           ORDER BY CHOTEI_NENDO DESC, TSUCHI_NO DESC;

      -- 賦課退職(最新)カーソル    [過年度分のみ]
      CURSOR CwTAI IS
          SELECT * FROM ZLBTTAI_N
           WHERE KOKU_SETAI_NO   =  i_NSETAI
             AND SANTEIDANTAI_CD =  i_NDANTAI
             AND CHOTEI_NENDO    <> i_NNENDO
             AND NENDO_BUN       =  i_NNENDO_BUN
           ORDER BY CHOTEI_NENDO DESC, TSUCHI_NO DESC;

      -- 賦課介護基本(最新)カーソル[過年度分のみ]
      CURSOR CwKAIKIHON IS
          SELECT * FROM ZLBTKAI_KIHON_N
           WHERE KOKU_SETAI_NO   =  i_NSETAI
             AND SANTEIDANTAI_CD =  i_NDANTAI
             AND CHOTEI_NENDO    <> i_NNENDO
             AND NENDO_BUN       =  i_NNENDO_BUN
           ORDER BY CHOTEI_NENDO DESC, TSUCHI_NO DESC;

      -- 賦課介護退職(最新)カーソル[過年度分のみ]
      CURSOR CwKAITAI IS
          SELECT * FROM ZLBTKAI_TAI_N
           WHERE KOKU_SETAI_NO   =  i_NSETAI
             AND SANTEIDANTAI_CD =  i_NDANTAI
             AND CHOTEI_NENDO    <> i_NNENDO
             AND NENDO_BUN       =  i_NNENDO_BUN
           ORDER BY CHOTEI_NENDO DESC, TSUCHI_NO DESC;

      -- 賦課支援基本(最新)カーソル[過年度分のみ]
      CURSOR CwSIENKIHON IS
          SELECT * FROM ZLBTSIEN_KIHON_N
           WHERE KOKU_SETAI_NO   =  i_NSETAI
             AND SANTEIDANTAI_CD =  i_NDANTAI
             AND CHOTEI_NENDO    <> i_NNENDO
             AND NENDO_BUN       =  i_NNENDO_BUN
           ORDER BY CHOTEI_NENDO DESC, TSUCHI_NO DESC;

      -- 賦課支援退職(最新)カーソル[過年度分のみ]
      CURSOR CwSIENTAI IS
          SELECT * FROM ZLBTSIEN_TAI_N
           WHERE KOKU_SETAI_NO   =  i_NSETAI
             AND SANTEIDANTAI_CD =  i_NDANTAI
             AND CHOTEI_NENDO    <> i_NNENDO
             AND NENDO_BUN       =  i_NNENDO_BUN
           ORDER BY CHOTEI_NENDO DESC, TSUCHI_NO DESC;
      --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
      --賦課子ども基本(最新)カーソル[過年度分のみ]
      --賦課子ども基本(最新)
      CURSOR CwKDMKIHON IS
          SELECT * FROM ZLBTKDM_KIHON_N
           WHERE KOKU_SETAI_NO   =  i_NSETAI
             AND SANTEIDANTAI_CD =  i_NDANTAI
             AND CHOTEI_NENDO    <> i_NNENDO
             AND NENDO_BUN       =  i_NNENDO_BUN
           ORDER BY CHOTEI_NENDO DESC, TSUCHI_NO DESC;
      --  2025/08/11 ZCZL.HAODAPENG ADD END

    BEGIN
        -- 11 テーブル名取得(計算TBL) --------------------------------------------1
        VwCALTBL := funcGetTblnm(i_NwTBL, 0);
        IF VwCALTBL IS NULL THEN
          NlRTN := c_NERR;
          VlMSG := 'subGengaku ' || 'テーブル名取得' ||
                   '(国保世帯番号=' || i_NSETAI ||
                   ')' || SQLERRM;
        END IF;
        -- 計算結果の基本内容をSave ----------------------------------------------2
        IF NlRTN = c_NOK THEN
            CASE i_NwTBL
            -- 基本
            WHEN c_NKIHON    THEN
                SELECT * INTO RwKIHON_BK FROM ZLBTKIHON_CAL
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    = i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN
                 AND   TSUCHI_NO       = i_NTSUCHI_NO
                 AND   SYS_TANMATSU_NO = i_VTANMATSU;
            -- 退職
            WHEN c_NTAI      THEN
                SELECT * INTO RwTAI_BK FROM ZLBTTAI_CAL
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    = i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN
                 AND   TSUCHI_NO       = i_NTSUCHI_NO
                 AND   SYS_TANMATSU_NO = i_VTANMATSU;
            -- 介護基本
            WHEN c_NKAIKIHON THEN
                SELECT * INTO RwKKIHON_BK FROM ZLBTKAI_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    = i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN
                 AND   TSUCHI_NO       = i_NTSUCHI_NO
                 AND   SYS_TANMATSU_NO = i_VTANMATSU;
            -- 介護退職
            WHEN c_NKAITAI   THEN
                SELECT * INTO RwKTAI_BK FROM ZLBTKAI_TAI_CAL
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    = i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN
                 AND   TSUCHI_NO       = i_NTSUCHI_NO
                 AND   SYS_TANMATSU_NO = i_VTANMATSU;
            -- 支援基本
            WHEN c_NSIENKIHON THEN
                SELECT * INTO RwSKIHON_BK FROM ZLBTSIEN_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    = i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN
                 AND   TSUCHI_NO       = i_NTSUCHI_NO
                 AND   SYS_TANMATSU_NO = i_VTANMATSU;
            -- 支援退職
            WHEN c_NSIENTAI   THEN
                SELECT * INTO RwSTAI_BK FROM ZLBTSIEN_TAI_CAL
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    = i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN
                 AND   TSUCHI_NO       = i_NTSUCHI_NO
                 AND   SYS_TANMATSU_NO = i_VTANMATSU;
            --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
            --子ども
            WHEN c_NKDMKIHON THEN
                SELECT * INTO RwKDMKIHON_BK FROM ZLBTKDM_KIHON_CAL
                WHERE KOKU_SETAI_NO   = i_NSETAI
                AND   SANTEIDANTAI_CD = i_NDANTAI
                AND   CHOTEI_NENDO    = i_NNENDO
                AND   NENDO_BUN       = i_NNENDO_BUN
                AND   TSUCHI_NO       = i_NTSUCHI_NO
                AND   SYS_TANMATSU_NO = i_VTANMATSU;
            --  2025/08/11 ZCZL.HAODAPENG ADD END
            END CASE;

            -- パラメータ指定の調定年度／年度分データの作成(課税計算済みの情報更新) --3
            -- 差額=年税額過計-年税額(課税計算結果)
            NwSAGAKU := NlNENZEI_KEI - NlNENZEI;
            --   過年度分=年税額過計,年税額=0
            VwSQL := 'UPDATE '                   || VwCALTBL     ||
                     ' SET KANENDO = NENZEI'     ||                   -- 過年度分
                     ' ,NENZEI = 0'              ||                   -- 年税額
                     ' WHERE KOKU_SETAI_NO = '   || i_NSETAI     ||
                     ' AND SANTEIDANTAI_CD = '   || i_NDANTAI    ||
                     ' AND CHOTEI_NENDO = '      || i_NNENDO     ||
                     ' AND NENDO_BUN = '         || i_NNENDO_BUN ||
                     ' AND TSUCHI_NO = '         || i_NTSUCHI_NO ||
                     ' AND SYS_TANMATSU_NO = ''' || i_VTANMATSU  || '''';
            EXECUTE IMMEDIATE VwSQL;

            -- 賦課(最新で且つ過年度分)を取得し差額がなくなるまで減額する ------------4
            -- カーソルオープン
            CASE i_NwTBL
            WHEN c_NKIHON    THEN       -- 賦課基本(最新)
                IF CwKIHON%ISOPEN THEN
                    CLOSE CwKIHON;
                END IF;
                OPEN CwKIHON;
            WHEN c_NTAI      THEN       -- 賦課退職(最新)
                IF CwTAI%ISOPEN THEN
                    CLOSE CwTAI;
                END IF;
                OPEN CwTAI;
            WHEN c_NKAIKIHON THEN       -- 賦課介護基本(最新)
                IF CwKAIKIHON%ISOPEN THEN
                    CLOSE CwKAIKIHON;
                END IF;
                OPEN CwKAIKIHON;
            WHEN c_NKAITAI   THEN       -- 賦課介護退職(最新)
                IF CwKAITAI%ISOPEN THEN
                    CLOSE CwKAITAI;
                END IF;
                OPEN CwKAITAI;
            WHEN c_NSIENKIHON THEN       -- 賦課支援基本(最新)
                IF CwSIENKIHON%ISOPEN THEN
                    CLOSE CwSIENKIHON;
                END IF;
                OPEN CwSIENKIHON;
            WHEN c_NSIENTAI   THEN       -- 賦課支援退職(最新)
                IF CwSIENTAI%ISOPEN THEN
                    CLOSE CwSIENTAI;
                END IF;
                OPEN CwSIENTAI;
            --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
            WHEN c_NKDMKIHON   THEN
                IF CwKDMKIHON%ISOPEN THEN
                    CLOSE CwKDMKIHON;
                END IF;
                OPEN CwKDMKIHON;
            --  2025/08/11 ZCZL.HAODAPENG ADD END
            END CASE;

            -- カーソルデータ分 OR 差額≦０までLOOP
            LOOP
                -- 差額が0以下ならば処理完了
                IF i_NwTBL IN (c_NKIHON,c_NKAIKIHON,c_NSIENKIHON) THEN
                    EXIT WHEN NwSAGAKU < 0 AND TOTAL_GEN_FLG = 0;
                ELSE
                    EXIT WHEN NwSAGAKU = 0;
                END IF;

                NwLOOPCNT := NwLOOPCNT + 1;

                -- 差額減額編集セット
                CASE i_NwTBL
                -- 賦課基本(最新)
                WHEN c_NKIHON    THEN
                    FETCH CwKIHON    INTO RwKIHON;
                    EXIT WHEN CwKIHON%NOTFOUND;
                    -- 年税額,過年度分,減免額算出準備
                    NwNENDO       := RwKIHON.CHOTEI_NENDO;
                    NwNENZEI      := RwKIHON.NENZEI;
                    NwSEKISAN     := RwKIHON.SEKISAN;
                    NwGENGAKU_KEI := RwKIHON.GENGAKU_KEI;
                -- 賦課退職(最新)
                WHEN c_NTAI      THEN
                    FETCH CwTAI      INTO RwTAI;
                    EXIT WHEN CwTAI%NOTFOUND;
                    -- 年税額,過年度分,減免額算出準備
                    NwNENDO       := RwTAI.CHOTEI_NENDO;
                    NwNENZEI      := RwTAI.NENZEI;
                    NwSEKISAN     := RwTAI.SEKISAN;
                    NwGENGAKU_KEI := RwTAI.GENGAKU_KEI;
                -- 賦課介護基本(最新)
                WHEN c_NKAIKIHON THEN
                    FETCH CwKAIKIHON INTO RwKKIHON;
                    EXIT WHEN CwKAIKIHON%NOTFOUND;
                    -- 年税額,過年度分,減免額算出準備
                    NwNENDO       := RwKKIHON.CHOTEI_NENDO;
                    NwNENZEI      := RwKKIHON.NENZEI;
                    NwSEKISAN     := RwKKIHON.SEKISAN;
                    NwGENGAKU_KEI := RwKKIHON.GENGAKU_KEI;
                -- 賦課介護退職(最新)
                WHEN c_NKAITAI   THEN
                    FETCH CwKAITAI   INTO RwKTAI;
                    EXIT WHEN CwKAITAI%NOTFOUND;
                    -- 年税額,過年度分,減免額算出準備
                    NwNENDO       := RwKTAI.CHOTEI_NENDO;
                    NwNENZEI      := RwKTAI.NENZEI;
                    NwSEKISAN     := RwKTAI.SEKISAN;
                    NwGENGAKU_KEI := RwKTAI.GENGAKU_KEI;
                -- 賦課支援基本(最新)
                WHEN c_NSIENKIHON THEN
                    FETCH CwSIENKIHON INTO RwSKIHON;
                    EXIT WHEN CwSIENKIHON%NOTFOUND;
                    -- 年税額,過年度分,減免額算出準備
                    NwNENDO       := RwSKIHON.CHOTEI_NENDO;
                    NwNENZEI      := RwSKIHON.NENZEI;
                    NwSEKISAN     := RwSKIHON.SEKISAN;
                    NwGENGAKU_KEI := RwSKIHON.GENGAKU_KEI;
                -- 賦課支援退職(最新)
                WHEN c_NSIENTAI   THEN
                    FETCH CwSIENTAI   INTO RwSTAI;
                    EXIT WHEN CwSIENTAI%NOTFOUND;
                    -- 年税額,過年度分,減免額算出準備
                    NwNENDO       := RwSTAI.CHOTEI_NENDO;
                    NwNENZEI      := RwSTAI.NENZEI;
                    NwSEKISAN     := RwSTAI.SEKISAN;
                    NwGENGAKU_KEI := RwSTAI.GENGAKU_KEI;
                --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
                -- 子ども
                WHEN c_NKDMKIHON   THEN
                    FETCH CwKDMKIHON   INTO RwKDMKIHON;
                    EXIT WHEN CwKDMKIHON%NOTFOUND;
                    -- 調定年度,年税額,積算税額,減額合計
                    NwNENDO       := RwKDMKIHON.CHOTEI_NENDO;
                    NwNENZEI      := RwKDMKIHON.NENZEI;
                    NwSEKISAN     := RwKDMKIHON.SEKISAN;
                    NwGENGAKU_KEI := RwKDMKIHON.GENGAKU_KEI;
                --  2025/08/11 ZCZL.HAODAPENG ADD END
                END CASE;

                -- 過年度分、年税額を算出(年税額・過年度分はそれぞれ算出)
                -- 差額と取得年税額を比較して年税額を算出
                IF NwSAGAKU >= NwNENZEI THEN
                    -- 差額の方が大きい場合
                    NwCALNENZEI  := 0;                      -- 算出年税=0
                    NwCALKANENDO := NlNENZEI;               -- 算出過年=年税(結果)
                    NwSAGAKU     := NwSAGAKU - NwNENZEI;    -- 差額=差額-取得年税
                ELSE
                    -- 差額の方が小さい場合
                    -- 医療退職、介護退職、支援退職の場合
                    IF i_NwTBL IN (c_NTAI,c_NKAITAI,c_NSIENTAI) AND NwSAGAKU < 0 THEN
                        NwZEN_NENZEI := 0;
                        NwSETFLG2 := 0;
                        -- 医療退職
                        IF i_NwTBL = c_NTAI THEN
                            -- 全体年税額を取得
                            FOR vRec IN (SELECT NENZEI
                                         FROM   ZLBTKIHON_CAL
                                         WHERE  KOKU_SETAI_NO   = RwTAI_BK.KOKU_SETAI_NO
                                           AND  SANTEIDANTAI_CD = RwTAI_BK.SANTEIDANTAI_CD
                                           AND  CHOTEI_NENDO    = RwTAI.CHOTEI_NENDO
                                           AND  NENDO_BUN       = RwTAI_BK.NENDO_BUN
                                           AND  TSUCHI_NO       = RwTAI.TSUCHI_NO
                                           AND  SYS_TANMATSU_NO = i_VTANMATSU) LOOP
                                NwZEN_NENZEI := vRec.NENZEI;
                                NwSETFLG2 := 1;
                                EXIT;
                            END LOOP;
                        -- 介護退職
                        ELSIF i_NwTBL = c_NKAITAI THEN
                            -- 全体年税額を取得
                            FOR vRec IN (SELECT NENZEI
                                         FROM   ZLBTKAI_KIHON_CAL
                                         WHERE  KOKU_SETAI_NO   = RwKTAI_BK.KOKU_SETAI_NO
                                           AND  SANTEIDANTAI_CD = RwKTAI_BK.SANTEIDANTAI_CD
                                           AND  CHOTEI_NENDO    = RwKTAI.CHOTEI_NENDO
                                           AND  NENDO_BUN       = RwKTAI_BK.NENDO_BUN
                                           AND  TSUCHI_NO       = RwKTAI.TSUCHI_NO
                                           AND  SYS_TANMATSU_NO = i_VTANMATSU) LOOP
                                NwZEN_NENZEI := vRec.NENZEI;
                                NwSETFLG2 := 1;
                                EXIT;
                            END LOOP;
                        -- 支援退職
                        ELSIF i_NwTBL = c_NSIENTAI THEN
                            -- 全体年税額を取得
                            FOR vRec IN (SELECT NENZEI
                                         FROM   ZLBTSIEN_KIHON_CAL
                                         WHERE  KOKU_SETAI_NO   = RwSTAI_BK.KOKU_SETAI_NO
                                           AND  SANTEIDANTAI_CD = RwSTAI_BK.SANTEIDANTAI_CD
                                           AND  CHOTEI_NENDO    = RwSTAI.CHOTEI_NENDO
                                           AND  NENDO_BUN       = RwSTAI_BK.NENDO_BUN
                                           AND  TSUCHI_NO       = RwSTAI.TSUCHI_NO
                                           AND  SYS_TANMATSU_NO = i_VTANMATSU) LOOP
                                NwZEN_NENZEI := vRec.NENZEI;
                                NwSETFLG2 := 1;
                                EXIT;
                            END LOOP;
                        END IF;
                        -- 全体年税額が取得取得できた場合
                        IF NwSETFLG2 = 1 THEN
                            -- 全体年税額＜＝差額適用後の退職年税額の場合
                            IF NwZEN_NENZEI <= NwNENZEI - NwSAGAKU THEN
                                -- 退職年税額は全体年税額と同額とする
                                NwCALNENZEI  := NwZEN_NENZEI;
                            ELSE
                              IF NwSAGAKU < 0 AND NwLOOPCNT > 1 THEN
                                NwCALNENZEI  := NwNENZEI;    -- 算出年税=取得年税
                              ELSE
                                NwCALNENZEI  := NwNENZEI - NwSAGAKU;    -- 算出年税=取得年税-差額
                              END IF;
                                NwSAGAKU     := NwSAGAKU - NwNENZEI;    -- 差額=差額-取得年税額
                            END IF;
                            NwCALKANENDO := NlNENZEI - NwCALNENZEI; -- 算出過年=年税(結果)-算出年税
                        ELSE
                          IF NwSAGAKU < 0 AND NwLOOPCNT > 1 THEN
                            NwCALNENZEI  := NwNENZEI;    -- 算出年税=取得年税
                          ELSE
                            NwCALNENZEI  := NwNENZEI - NwSAGAKU;    -- 算出年税=取得年税-差額
                          END IF;
                            NwCALKANENDO := NlNENZEI - NwCALNENZEI; -- 算出過年=年税(結果)-算出年税
                            NwSAGAKU     := NwSAGAKU - NwNENZEI;    -- 差額=差額-取得年税額
                        END IF;
                    ELSE
                        IF NwSAGAKU < 0 AND NwLOOPCNT > 1 THEN
                          NwCALNENZEI  := NwNENZEI;    -- 算出年税=取得年税
                        ELSE
                          NwCALNENZEI  := NwNENZEI - NwSAGAKU;    -- 算出年税=取得年税-差額
                        END IF;

                        NwCALKANENDO := NlNENZEI - NwCALNENZEI; -- 算出過年=年税(結果)-算出年税
                        NwSAGAKU     := NwSAGAKU - NwNENZEI;    -- 差額=差額-取得年税額
                    END IF;
                END IF;

                -- 計算TBL作成(追加)
                CASE i_NwTBL
                -- 賦課基本(最新)
                WHEN c_NKIHON    THEN
                    RwKIHON_INS                     := RwKIHON_BK;                -- 計算バックアップ内容を出力ワークにセット
                    RwKIHON_INS.CHOTEI_NENDO        := RwKIHON.CHOTEI_NENDO;      -- 調定年度
                    RwKIHON_INS.R_NO                := RwKIHON.R_NO + c_NRNO_CNT; -- 履歴番号
                    RwKIHON_INS.TSUCHI_NO           := RwKIHON.TSUCHI_NO;         -- 通知書番号
                    RwKIHON_INS.KANENDO             := NwCALKANENDO;              -- 過年度分
                    RwKIHON_INS.NENZEI              := NwCALNENZEI;               -- 年税額
                    RwKIHON_INS.SYS_SAKUSEIBI       := NlDATE;                    -- 作成日
                    RwKIHON_INS.SYS_KOSHINBI        := NlDATE;                    -- 更新日
                    RwKIHON_INS.SYS_JIKAN           := NlTIME;                    -- 更新時間
                    RwKIHON_INS.SYS_SHOKUINKOJIN_NO := i_NSYS_SHOKUIN;            -- 更新職員番号
                    RwKIHON_INS.SYS_TANMATSU_NO     := i_VTANMATSU;               -- 更新端末番号
                    -- 計算TBLに追加
                    INSERT INTO ZLBTKIHON_CAL VALUES RwKIHON_INS;
                    NwSETFLG := 1;
                    -- 計算個人に追加
                    subInsKojin(RwKIHON_INS.CHOTEI_NENDO,
                                RwKIHON_INS.R_NO,
                                RwKIHON_INS.TSUCHI_NO);     -- 12 計算個人の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算所得の追加
                    subInsShotoku(RwKIHON_INS.CHOTEI_NENDO,
                                  RwKIHON_INS.R_NO,
                                  RwKIHON_INS.TSUCHI_NO);   -- 13 計算所得の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算拡張の追加
                    subInsExt(RwKIHON_INS.CHOTEI_NENDO,
                              RwKIHON_INS.R_NO,
                              RwKIHON_INS.TSUCHI_NO);       -- 14 計算賦課拡張の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算特徴対象者の追加
                    subInsTokukihon(RwKIHON_INS.CHOTEI_NENDO,
                                    RwKIHON_INS.R_NO,
                                    RwKIHON_INS.TSUCHI_NO); -- 15 計算特徴対象者の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算減免個人の追加
                    IF NlCNT > 0 THEN
                      subInsGENMENKOJIN(RwKIHON_INS.CHOTEI_NENDO,
                                        RwKIHON_INS.R_NO,
                                        RwKIHON_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                      EXIT WHEN NlRTN != c_NOK;
                    END IF;
                -- 賦課退職(最新)
                WHEN c_NTAI      THEN
                    RwTAI_INS                       := RwTAI_BK;                  -- 計算バックアップ内容を出力ワークにセット
                    RwTAI_INS.CHOTEI_NENDO          := RwTAI.CHOTEI_NENDO;        -- 調定年度
                    RwTAI_INS.R_NO                  := RwTAI.R_NO + c_NRNO_CNT;   -- 履歴番号
                    RwTAI_INS.TSUCHI_NO             := RwTAI.TSUCHI_NO;           -- 通知書番号
                    RwTAI_INS.KANENDO               := NwCALKANENDO;              -- 過年度分
                    RwTAI_INS.NENZEI                := NwCALNENZEI;               -- 年税額
                    RwTAI_INS.SYS_SAKUSEIBI         := NlDATE;                    -- 作成日
                    RwTAI_INS.SYS_KOSHINBI          := NlDATE;                    -- 更新日
                    RwTAI_INS.SYS_JIKAN             := NlTIME;                    -- 更新時間
                    RwTAI_INS.SYS_SHOKUINKOJIN_NO   := i_NSYS_SHOKUIN;            -- 更新職員番号
                    RwTAI_INS.SYS_TANMATSU_NO       := i_VTANMATSU;               -- 更新端末番号
                    -- 計算TBLに追加
                    INSERT INTO ZLBTTAI_CAL VALUES RwTAI_INS;
                    NwSETFLG := 1;
                    -- 計算個人に追加
                    subInsKojin(RwTAI_INS.CHOTEI_NENDO,
                                RwTAI_INS.R_NO,
                                RwTAI_INS.TSUCHI_NO);     -- 12 計算個人の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算所得の追加
                    subInsShotoku(RwTAI_INS.CHOTEI_NENDO,
                                  RwTAI_INS.R_NO,
                                  RwTAI_INS.TSUCHI_NO);   -- 13 計算所得の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算賦課拡張の追加
                    subInsExt(RwTAI_INS.CHOTEI_NENDO,
                              RwTAI_INS.R_NO,
                              RwTAI_INS.TSUCHI_NO);   -- 14 計算賦課拡張の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算特徴対象者の追加
                    subInsTokukihon(RwTAI_INS.CHOTEI_NENDO,
                                    RwTAI_INS.R_NO,
                                    RwTAI_INS.TSUCHI_NO); -- 15 計算特徴対象者の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算減免個人の追加
                    IF NlCNT > 0 THEN
                      subInsGENMENKOJIN(RwTAI_INS.CHOTEI_NENDO,
                                        RwTAI_INS.R_NO,
                                        RwTAI_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                      EXIT WHEN NlRTN != c_NOK;
                    END IF;

                -- 賦課介護基本(最新)
                WHEN c_NKAIKIHON THEN
                    RwKKIHON_INS                    := RwKKIHON_BK;               -- 計算バックアップ内容を出力ワークにセット
                    RwKKIHON_INS.CHOTEI_NENDO       := RwKKIHON.CHOTEI_NENDO;     -- 調定年度
                    RwKKIHON_INS.R_NO               := RwKKIHON.R_NO + c_NRNO_CNT;-- 履歴番号
                    RwKKIHON_INS.TSUCHI_NO          := RwKKIHON.TSUCHI_NO;        -- 通知書番号
                    RwKKIHON_INS.KANENDO            := NwCALKANENDO;              -- 過年度分
                    RwKKIHON_INS.NENZEI             := NwCALNENZEI;               -- 年税額
                    RwKKIHON_INS.SYS_SAKUSEIBI      := NlDATE;                    -- 作成日
                    RwKKIHON_INS.SYS_KOSHINBI       := NlDATE;                    -- 更新日
                    RwKKIHON_INS.SYS_JIKAN          := NlTIME;                    -- 更新時間
                    RwKKIHON_INS.SYS_SHOKUINKOJIN_NO:= i_NSYS_SHOKUIN;            -- 更新職員番号
                    RwKKIHON_INS.SYS_TANMATSU_NO    := i_VTANMATSU;               -- 更新端末番号
                    -- 計算TBLに追加
                    INSERT INTO ZLBTKAI_KIHON_CAL VALUES RwKKIHON_INS;
                    NwSETFLG := 1;
                    -- 計算個人に追加
                    subInsKojin(RwKKIHON_INS.CHOTEI_NENDO,
                                RwKKIHON_INS.R_NO,
                                RwKKIHON_INS.TSUCHI_NO);    -- 12 計算個人の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算所得の追加
                    subInsShotoku(RwKKIHON_INS.CHOTEI_NENDO,
                                  RwKKIHON_INS.R_NO,
                                  RwKKIHON_INS.TSUCHI_NO);  -- 13 計算所得の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算賦課拡張の追加
                    subInsExt(RwKKIHON_INS.CHOTEI_NENDO,
                              RwKKIHON_INS.R_NO,
                              RwKKIHON_INS.TSUCHI_NO);   -- 14 計算賦課拡張の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算特徴対象者の追加
                    subInsTokukihon(RwKKIHON_INS.CHOTEI_NENDO,
                                    RwKKIHON_INS.R_NO,
                                    RwKKIHON_INS.TSUCHI_NO); -- 15 計算特徴対象者の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算減免個人の追加
                    IF NlCNT > 0 THEN
                      subInsGENMENKOJIN(RwKKIHON_INS.CHOTEI_NENDO,
                                        RwKKIHON_INS.R_NO,
                                        RwKKIHON_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                      EXIT WHEN NlRTN != c_NOK;
                    END IF;

                -- 賦課介護退職(最新)
                WHEN c_NKAITAI   THEN
                    RwKTAI_INS                      := RwKTAI_BK;                 -- 計算バックアップ内容を出力ワークにセット
                    RwKTAI_INS.CHOTEI_NENDO         := RwKTAI.CHOTEI_NENDO;       -- 調定年度
                    RwKTAI_INS.R_NO                 := RwKTAI.R_NO + c_NRNO_CNT;  -- 履歴番号
                    RwKTAI_INS.TSUCHI_NO            := RwKTAI.TSUCHI_NO;          -- 通知書番号
                    RwKTAI_INS.KANENDO              := NwCALKANENDO;              -- 過年度分
                    RwKTAI_INS.NENZEI               := NwCALNENZEI;               -- 年税額
                    RwKTAI_INS.SYS_SAKUSEIBI        := NlDATE;                    -- 作成日
                    RwKTAI_INS.SYS_KOSHINBI         := NlDATE;                    -- 更新日
                    RwKTAI_INS.SYS_JIKAN            := NlTIME;                    -- 更新時間
                    RwKTAI_INS.SYS_SHOKUINKOJIN_NO  := i_NSYS_SHOKUIN;            -- 更新職員番号
                    RwKTAI_INS.SYS_TANMATSU_NO      := i_VTANMATSU;               -- 更新端末番号
                    -- 計算TBLに追加
                    INSERT INTO ZLBTKAI_TAI_CAL VALUES RwKTAI_INS;
                    NwSETFLG := 1;
                    -- 計算個人に追加
                    subInsKojin(RwKTAI_INS.CHOTEI_NENDO,
                                RwKTAI_INS.R_NO,
                                RwKTAI_INS.TSUCHI_NO);      -- 12 計算個人の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算所得の追加
                    subInsShotoku(RwKTAI_INS.CHOTEI_NENDO,
                                  RwKTAI_INS.R_NO,
                                  RwKTAI_INS.TSUCHI_NO);    -- 13 計算所得の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算賦課拡張の追加
                    subInsExt(RwKTAI_INS.CHOTEI_NENDO,
                              RwKTAI_INS.R_NO,
                              RwKTAI_INS.TSUCHI_NO);   -- 14 計算賦課拡張の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算特徴対象者の追加
                    subInsTokukihon(RwKTAI_INS.CHOTEI_NENDO,
                                    RwKTAI_INS.R_NO,
                                    RwKTAI_INS.TSUCHI_NO); -- 15 計算特徴対象者の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算減免個人の追加
                    IF NlCNT > 0 THEN
                      subInsGENMENKOJIN(RwKTAI_INS.CHOTEI_NENDO,
                                        RwKTAI_INS.R_NO,
                                        RwKTAI_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                      EXIT WHEN NlRTN != c_NOK;
                    END IF;

                -- 賦課支援基本(最新)
                WHEN c_NSIENKIHON THEN
                    RwSKIHON_INS                    := RwSKIHON_BK;               -- 計算バックアップ内容を出力ワークにセット
                    RwSKIHON_INS.CHOTEI_NENDO       := RwSKIHON.CHOTEI_NENDO;     -- 調定年度
                    RwSKIHON_INS.R_NO               := RwSKIHON.R_NO + c_NRNO_CNT;-- 履歴番号
                    RwSKIHON_INS.TSUCHI_NO          := RwSKIHON.TSUCHI_NO;        -- 通知書番号
                    RwSKIHON_INS.KANENDO            := NwCALKANENDO;              -- 過年度分
                    RwSKIHON_INS.NENZEI             := NwCALNENZEI;               -- 年税額
                    RwSKIHON_INS.SYS_SAKUSEIBI      := NlDATE;                    -- 作成日
                    RwSKIHON_INS.SYS_KOSHINBI       := NlDATE;                    -- 更新日
                    RwSKIHON_INS.SYS_JIKAN          := NlTIME;                    -- 更新時間
                    RwSKIHON_INS.SYS_SHOKUINKOJIN_NO:= i_NSYS_SHOKUIN;            -- 更新職員番号
                    RwSKIHON_INS.SYS_TANMATSU_NO    := i_VTANMATSU;               -- 更新端末番号
                    -- 計算TBLに追加
                    INSERT INTO ZLBTSIEN_KIHON_CAL VALUES RwSKIHON_INS;
                    NwSETFLG := 1;
                    -- 計算個人に追加
                    subInsKojin(RwSKIHON_INS.CHOTEI_NENDO,
                                RwSKIHON_INS.R_NO,
                                RwSKIHON_INS.TSUCHI_NO);    -- 12 計算個人の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算所得の追加
                    subInsShotoku(RwSKIHON_INS.CHOTEI_NENDO,
                                  RwSKIHON_INS.R_NO,
                                  RwSKIHON_INS.TSUCHI_NO);  -- 13 計算所得の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算賦課拡張の追加
                    subInsExt(RwSKIHON_INS.CHOTEI_NENDO,
                              RwSKIHON_INS.R_NO,
                              RwSKIHON_INS.TSUCHI_NO);   -- 14 計算賦課拡張の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算特徴対象者の追加
                    subInsTokukihon(RwSKIHON_INS.CHOTEI_NENDO,
                                    RwSKIHON_INS.R_NO,
                                    RwSKIHON_INS.TSUCHI_NO); -- 15 計算特徴対象者の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算減免個人の追加
                    IF NlCNT > 0 THEN
                      subInsGENMENKOJIN(RwSKIHON_INS.CHOTEI_NENDO,
                                        RwSKIHON_INS.R_NO,
                                        RwSKIHON_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                      EXIT WHEN NlRTN != c_NOK;
                    END IF;

                -- 賦課支援退職(最新)
                WHEN c_NSIENTAI   THEN
                    RwSTAI_INS                      := RwSTAI_BK;                 -- 計算バックアップ内容を出力ワークにセット
                    RwSTAI_INS.CHOTEI_NENDO         := RwSTAI.CHOTEI_NENDO;       -- 調定年度
                    RwSTAI_INS.R_NO                 := RwSTAI.R_NO + c_NRNO_CNT;  -- 履歴番号
                    RwSTAI_INS.TSUCHI_NO            := RwSTAI.TSUCHI_NO;          -- 通知書番号
                    RwSTAI_INS.KANENDO              := NwCALKANENDO;              -- 過年度分
                    RwSTAI_INS.NENZEI               := NwCALNENZEI;               -- 年税額
                    RwSTAI_INS.SYS_SAKUSEIBI        := NlDATE;                    -- 作成日
                    RwSTAI_INS.SYS_KOSHINBI         := NlDATE;                    -- 更新日
                    RwSTAI_INS.SYS_JIKAN            := NlTIME;                    -- 更新時間
                    RwSTAI_INS.SYS_SHOKUINKOJIN_NO  := i_NSYS_SHOKUIN;            -- 更新職員番号
                    RwSTAI_INS.SYS_TANMATSU_NO      := i_VTANMATSU;               -- 更新端末番号
                    -- 計算TBLに追加
                    INSERT INTO ZLBTSIEN_TAI_CAL VALUES RwSTAI_INS;
                    NwSETFLG := 1;
                    -- 計算個人に追加
                    subInsKojin(RwSTAI_INS.CHOTEI_NENDO,
                                RwSTAI_INS.R_NO,
                                RwSTAI_INS.TSUCHI_NO);      -- 12 計算個人の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算所得の追加
                    subInsShotoku(RwSTAI_INS.CHOTEI_NENDO,
                                  RwSTAI_INS.R_NO,
                                  RwSTAI_INS.TSUCHI_NO);    -- 13 計算所得の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算賦課拡張の追加
                    subInsExt(RwSTAI_INS.CHOTEI_NENDO,
                              RwSTAI_INS.R_NO,
                              RwSTAI_INS.TSUCHI_NO);   -- 14 計算賦課拡張の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算特徴対象者の追加
                    subInsTokukihon(RwSTAI_INS.CHOTEI_NENDO,
                                    RwSTAI_INS.R_NO,
                                    RwSTAI_INS.TSUCHI_NO); -- 15 計算特徴対象者の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算減免個人の追加
                    IF NlCNT > 0 THEN
                      subInsGENMENKOJIN(RwSTAI_INS.CHOTEI_NENDO,
                                        RwSTAI_INS.R_NO,
                                        RwSTAI_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                      EXIT WHEN NlRTN != c_NOK;
                    END IF;
                --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
                -- 子ども
                WHEN c_NKDMKIHON   THEN
                    -- 年税額,過年度分,減免額算出準備
                    --子どもの出力ワーク：子どもの計算バックアップ内容をセット
                    --子どもの出力ワーク.調定年度：子どもの計算バックアップ内容.調定年度をセット
                    --子どもの出力ワーク.履歴番号：子どもの計算バックアップ内容.履歴番号+定数：10をセット
                    --子どもの出力ワーク.通知書番号：子どもの計算バックアップ内容.通知書番号をセット
                    --子どもの出力ワーク.過年度分：算出過年度分変数をセット
                    --子どもの出力ワーク.年税額：算出年税額変数をセット
                    --子どもの出力ワーク.作成日：作成日変数をセット
                    --子どもの出力ワーク.更新日：作成日分変数をセット
                    --子どもの出力ワーク.更新時間：更新時間変数をセット
                    --子どもの出力ワーク.更新職員番号：更新職員番号分変数をセット
                    --子どもの出力ワーク.更新端末番号：更新版末番号変数をセット
                    RwKDMKIHON_INS                      := RwKDMKIHON_BK;                 -- 計算バックアップ内容を出力ワークにセット
                    RwKDMKIHON_INS.CHOTEI_NENDO         := RwKDMKIHON.CHOTEI_NENDO;       -- 調定年度
                    RwKDMKIHON_INS.R_NO                 := RwKDMKIHON.R_NO + c_NRNO_CNT;  -- 履歴番号
                    RwKDMKIHON_INS.TSUCHI_NO            := RwKDMKIHON.TSUCHI_NO;          -- 通知書番号
                    RwKDMKIHON_INS.KANENDO              := NwCALKANENDO;              -- 過年度分
                    RwKDMKIHON_INS.NENZEI               := NwCALNENZEI;               -- 年税額
                    RwKDMKIHON_INS.SYS_SAKUSEIBI        := NlDATE;                    -- 作成日
                    RwKDMKIHON_INS.SYS_KOSHINBI         := NlDATE;                    -- 更新日
                    RwKDMKIHON_INS.SYS_JIKAN            := NlTIME;                    -- 更新時間
                    RwKDMKIHON_INS.SYS_SHOKUINKOJIN_NO  := i_NSYS_SHOKUIN;            -- 更新職員番号
                    RwKDMKIHON_INS.SYS_TANMATSU_NO      := i_VTANMATSU;               -- 更新端末番号
                    -- 計算TBLに追加
                    INSERT INTO ZLBTKDM_KIHON_CAL VALUES RwKDMKIHON_INS;
                    NwSETFLG := 1;
                    -- 計算個人に追加
                    subInsKojin(RwKDMKIHON_INS.CHOTEI_NENDO,
                                RwKDMKIHON_INS.R_NO,
                                RwKDMKIHON_INS.TSUCHI_NO);      -- 12 計算個人の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算所得の追加
                    subInsShotoku(RwKDMKIHON_INS.CHOTEI_NENDO,
                                RwKDMKIHON_INS.R_NO,
                                RwKDMKIHON_INS.TSUCHI_NO);    -- 13 計算所得の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算賦課拡張の追加
                    subInsExt(RwKDMKIHON_INS.CHOTEI_NENDO,
                              RwKDMKIHON_INS.R_NO,
                              RwKDMKIHON_INS.TSUCHI_NO);   -- 14 計算賦課拡張の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算特徴対象者の追加
                    subInsTokukihon(RwKDMKIHON_INS.CHOTEI_NENDO,
                                    RwKDMKIHON_INS.R_NO,
                                    RwKDMKIHON_INS.TSUCHI_NO);   -- 15 計算特徴対象者の追加
                    EXIT WHEN NlRTN != c_NOK;
                    -- 計算減免個人の追加
                    IF NlCNT > 0 THEN
                      subInsGENMENKOJIN(RwKDMKIHON_INS.CHOTEI_NENDO,
                                        RwKDMKIHON_INS.R_NO,
                                        RwKDMKIHON_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                      EXIT WHEN NlRTN != c_NOK;
                    END IF;
                    --  2025/08/11 ZCZL.HAODAPENG ADD END

                END CASE;
            END LOOP;

            -- カーソルクローズ
            CASE i_NwTBL
            WHEN c_NKIHON    THEN CLOSE CwKIHON;        -- 賦課基本(最新)
            WHEN c_NTAI      THEN CLOSE CwTAI;          -- 賦課退職(最新)
            WHEN c_NKAIKIHON THEN CLOSE CwKAIKIHON;     -- 賦課介護基本(最新)
            WHEN c_NKAITAI   THEN CLOSE CwKAITAI;       -- 賦課介護退職(最新)
            WHEN c_NSIENKIHON THEN CLOSE CwSIENKIHON;   -- 賦課支援基本(最新)
            WHEN c_NSIENTAI   THEN CLOSE CwSIENTAI;     -- 賦課支援退職(最新)
            --  2025/08/11 ZCZL.HAODAPENG ADD 1.1.200.000:子ども子育て支援金対応
            WHEN c_NKDMKIHON   THEN CLOSE CwKDMKIHON;     -- 子ども
            END CASE;
        END IF;

        -- 賦課(最新で且つ調定年度＝年度分)を取得し計算結果の内容で追加する ------5
        IF i_NwTBL = c_NKIHON THEN
            NwIRYSAGAKU := NwSAGAKU;
        ELSIF i_NwTBL = c_NKAIKIHON THEN
            NwKAISAGAKU := NwSAGAKU;
        ELSIF i_NwTBL = c_NSIENKIHON THEN
            NwSIENSAGAKU := NwSAGAKU;
        --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
        ELSIF i_NwTBL = c_NKDMKIHON THEN
            NwKDMSAGAKU := NwSAGAKU;
        --  2025/08/11 ZCZL.HAODAPENG ADD END
        END IF;

        IF (NwSAGAKU >= 0 OR
            (i_NwTBL = c_NTAI AND NwIRYSAGAKU <= 0 AND NwSAGAKU < 0) OR
            (i_NwTBL = c_NKAITAI AND NwKAISAGAKU <= 0 AND NwSAGAKU < 0) OR
            (i_NwTBL = c_NSIENTAI AND NwSIENSAGAKU <= 0 AND NwSAGAKU < 0)) AND NwSETFLG = 0 THEN

            -- 差額の残り有り→調定年度＝年度分のデータを作成
            CASE i_NwTBL
            -- 基本
            WHEN c_NKIHON    THEN
                SELECT COUNT(*) INTO NwCNT FROM ZLBTKIHON_N
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    <> i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN;
            -- 退職
            WHEN c_NTAI      THEN
                SELECT COUNT(*) INTO NwCNT FROM ZLBTTAI_N
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    <> i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN;
            -- 介護基本
            WHEN c_NKAIKIHON THEN
                SELECT COUNT(*) INTO NwCNT FROM ZLBTKAI_KIHON_N
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    <> i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN;
            -- 介護退職
            WHEN c_NKAITAI   THEN
                SELECT COUNT(*) INTO NwCNT FROM ZLBTKAI_TAI_N
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    <> i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN;
            -- 支援基本
            WHEN c_NSIENKIHON THEN
                SELECT COUNT(*) INTO NwCNT FROM ZLBTSIEN_KIHON_N
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    <> i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN;
            -- 支援退職
            WHEN c_NSIENTAI   THEN
                SELECT COUNT(*) INTO NwCNT FROM ZLBTSIEN_TAI_N
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    <> i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN;
            --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
            WHEN c_NKDMKIHON   THEN
                SELECT COUNT(*) INTO NwCNT FROM ZLBTKDM_KIHON_N
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                 AND   SANTEIDANTAI_CD = i_NDANTAI
                 AND   CHOTEI_NENDO    <> i_NNENDO
                 AND   NENDO_BUN       = i_NNENDO_BUN
                 ;
            --  2025/08/11 ZCZL.HAODAPENG ADD END
            END CASE;

            -- 取得データが1件の時のみ処理する。
            IF NwCNT >= 1 THEN
                -- カーソルオープン
                CASE i_NwTBL
                WHEN c_NKIHON    THEN       -- 賦課基本(最新)
                    IF CwKIHON%ISOPEN THEN
                        CLOSE CwKIHON;
                    END IF;
                    OPEN CwKIHON;
                WHEN c_NTAI      THEN       -- 賦課退職(最新)
                    IF CwTAI%ISOPEN THEN
                        CLOSE CwTAI;
                    END IF;
                    OPEN CwTAI;
                WHEN c_NKAIKIHON THEN       -- 賦課介護基本(最新)
                    IF CwKAIKIHON%ISOPEN THEN
                        CLOSE CwKAIKIHON;
                    END IF;
                    OPEN CwKAIKIHON;
                WHEN c_NKAITAI   THEN       -- 賦課介護退職(最新)
                    IF CwKAITAI%ISOPEN THEN
                        CLOSE CwKAITAI;
                    END IF;
                    OPEN CwKAITAI;
                WHEN c_NSIENKIHON THEN       -- 賦課支援基本(最新)
                    IF CwSIENKIHON%ISOPEN THEN
                        CLOSE CwSIENKIHON;
                    END IF;
                    OPEN CwSIENKIHON;
                WHEN c_NSIENTAI   THEN       -- 賦課支援退職(最新)
                    IF CwSIENTAI%ISOPEN THEN
                        CLOSE CwSIENTAI;
                    END IF;
                    OPEN CwSIENTAI;
                --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
                WHEN c_NKDMKIHON   THEN
                    IF CwKDMKIHON%ISOPEN THEN
                        CLOSE CwKDMKIHON;
                    END IF;
                    OPEN CwKDMKIHON;
                --  2025/08/11 ZCZL.HAODAPENG ADD END
                END CASE;

                Loop
                    EXIT WHEN NwCNT <= 0;

                    -- 計算TBL作成(追加)
                    CASE i_NwTBL
                    -- 賦課基本(最新)
                    WHEN c_NKIHON    THEN
                        FETCH CwKIHON    INTO RwKIHON;
                        EXIT WHEN CwKIHON%NOTFOUND;
                        RwKIHON_INS                     := RwKIHON;                   -- 計算バックアップ内容を出力ワークにセット
                        RwKIHON_INS.CHOTEI_NENDO        := RwKIHON.CHOTEI_NENDO;      -- 調定年度
                        RwKIHON_INS.R_NO                := RwKIHON.R_NO + c_NRNO_CNT; -- 履歴番号
                        RwKIHON_INS.TSUCHI_NO           := RwKIHON.TSUCHI_NO;         -- 通知書番号
                        RwKIHON_INS.SYS_SAKUSEIBI       := NlDATE;                    -- 作成日
                        RwKIHON_INS.SYS_KOSHINBI        := NlDATE;                    -- 更新日
                        RwKIHON_INS.SYS_JIKAN           := NlTIME;                    -- 更新時間
                        RwKIHON_INS.SYS_SHOKUINKOJIN_NO := i_NSYS_SHOKUIN;            -- 更新職員番号
                        RwKIHON_INS.SYS_TANMATSU_NO     := i_VTANMATSU;               -- 更新端末番号

                        -- 計算TBLに追加
                        INSERT INTO ZLBTKIHON_CAL VALUES RwKIHON_INS;
                        -- 計算個人に追加
                        subInsKojin(RwKIHON_INS.CHOTEI_NENDO,
                                    RwKIHON_INS.R_NO,
                                    RwKIHON_INS.TSUCHI_NO);       -- 12 計算個人の追加
                        -- 計算所得の追加
                        IF NlRTN = c_NOK THEN
                          subInsShotoku(RwKIHON_INS.CHOTEI_NENDO,
                                        RwKIHON_INS.R_NO,
                                        RwKIHON_INS.TSUCHI_NO);   -- 13 計算所得の追加
                        END IF;
                        -- 計算賦課拡張の追加
                        IF NlRTN = c_NOK THEN
                        subInsExt(RwKIHON_INS.CHOTEI_NENDO,
                                  RwKIHON_INS.R_NO,
                                  RwKIHON_INS.TSUCHI_NO);         -- 14 計算賦課拡張の追加
                        END IF;
                        -- 計算特徴対象者の追加
                        IF NlRTN = c_NOK THEN
                        subInsTokukihon(RwKIHON_INS.CHOTEI_NENDO,
                                        RwKIHON_INS.R_NO,
                                        RwKIHON_INS.TSUCHI_NO);   -- 15 計算特徴対象者の追加
                        END IF;
                        -- 計算減免個人の追加
                        IF NlCNT > 0 THEN
                           subInsGENMENKOJIN(RwKIHON_INS.CHOTEI_NENDO,
                                             RwKIHON_INS.R_NO,
                                             RwKIHON_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                        END IF;
                    -- 賦課退職(最新)
                    WHEN c_NTAI      THEN
                        FETCH CwTAI      INTO RwTAI;
                        EXIT WHEN CwTAI%NOTFOUND;
                        RwTAI_INS                       := RwTAI;                  -- 計算バックアップ内容を出力ワークにセット
                        RwTAI_INS.CHOTEI_NENDO          := RwTAI.CHOTEI_NENDO;        -- 調定年度
                        RwTAI_INS.R_NO                  := RwTAI.R_NO + c_NRNO_CNT;   -- 履歴番号
                        RwTAI_INS.TSUCHI_NO             := RwTAI.TSUCHI_NO;           -- 通知書番号
                        RwTAI_INS.SYS_SAKUSEIBI         := NlDATE;                    -- 作成日
                        RwTAI_INS.SYS_KOSHINBI          := NlDATE;                    -- 更新日
                        RwTAI_INS.SYS_JIKAN             := NlTIME;                    -- 更新時間
                        RwTAI_INS.SYS_SHOKUINKOJIN_NO   := i_NSYS_SHOKUIN;            -- 更新職員番号
                        RwTAI_INS.SYS_TANMATSU_NO       := i_VTANMATSU;               -- 更新端末番号
                        -- 計算TBLに追加
                        INSERT INTO ZLBTTAI_CAL VALUES RwTAI_INS;
                        -- 計算個人に追加
                        subInsKojin(RwTAI_INS.CHOTEI_NENDO,
                                    RwTAI_INS.R_NO,
                                    RwTAI_INS.TSUCHI_NO);       -- 12 計算個人の追加
                        -- 計算所得の追加
                        IF NlRTN = c_NOK THEN
                          subInsShotoku(RwTAI_INS.CHOTEI_NENDO,
                                        RwTAI_INS.R_NO,
                                        RwTAI_INS.TSUCHI_NO);   -- 13 計算所得の追加
                        END IF;
                        -- 計算賦課拡張の追加
                        IF NlRTN = c_NOK THEN
                        subInsExt(RwTAI_INS.CHOTEI_NENDO,
                                  RwTAI_INS.R_NO,
                                  RwTAI_INS.TSUCHI_NO);         -- 14 計算賦課拡張の追加
                        END IF;
                        -- 計算特徴対象者の追加
                        IF NlRTN = c_NOK THEN
                        subInsTokukihon(RwTAI_INS.CHOTEI_NENDO,
                                        RwTAI_INS.R_NO,
                                        RwTAI_INS.TSUCHI_NO);   -- 15 計算特徴対象者の追加
                        END IF;
                        -- 計算減免個人の追加
                        IF NlCNT > 0 THEN
                          subInsGENMENKOJIN(RwTAI_INS.CHOTEI_NENDO,
                                            RwTAI_INS.R_NO,
                                            RwTAI_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                        END IF;
                    -- 賦課介護基本(最新)
                    WHEN c_NKAIKIHON THEN
                        FETCH CwKAIKIHON INTO RwKKIHON;
                        EXIT WHEN CwKAIKIHON%NOTFOUND;
                        RwKKIHON_INS                    := RwKKIHON;               -- 計算バックアップ内容を出力ワークにセット
                        RwKKIHON_INS.CHOTEI_NENDO       := RwKKIHON.CHOTEI_NENDO;     -- 調定年度
                        RwKKIHON_INS.R_NO               := RwKKIHON.R_NO + c_NRNO_CNT;-- 履歴番号
                        RwKKIHON_INS.TSUCHI_NO          := RwKKIHON.TSUCHI_NO;        -- 通知書番号
                        RwKKIHON_INS.SYS_SAKUSEIBI      := NlDATE;                    -- 作成日
                        RwKKIHON_INS.SYS_KOSHINBI       := NlDATE;                    -- 更新日
                        RwKKIHON_INS.SYS_JIKAN          := NlTIME;                    -- 更新時間
                        RwKKIHON_INS.SYS_SHOKUINKOJIN_NO:= i_NSYS_SHOKUIN;            -- 更新職員番号
                        RwKKIHON_INS.SYS_TANMATSU_NO    := i_VTANMATSU;               -- 更新端末番号
                        -- 計算TBLに追加
                        INSERT INTO ZLBTKAI_KIHON_CAL VALUES RwKKIHON_INS;
                        -- 計算個人に追加
                        subInsKojin(RwKKIHON_INS.CHOTEI_NENDO,
                                    RwKKIHON_INS.R_NO,
                                    RwKKIHON_INS.TSUCHI_NO);      -- 12 計算個人の追加
                        -- 計算所得の追加
                        IF NlRTN = c_NOK THEN
                          subInsShotoku(RwKKIHON_INS.CHOTEI_NENDO,
                                        RwKKIHON_INS.R_NO,
                                        RwKKIHON_INS.TSUCHI_NO);  -- 13 計算所得の追加
                        END IF;
                        -- 計算賦課拡張の追加
                        IF NlRTN = c_NOK THEN
                        subInsExt(RwKKIHON_INS.CHOTEI_NENDO,
                                  RwKKIHON_INS.R_NO,
                                  RwKKIHON_INS.TSUCHI_NO);        -- 14 計算賦課拡張の追加
                        END IF;
                        -- 計算特徴対象者の追加
                        IF NlRTN = c_NOK THEN
                        subInsTokukihon(RwKKIHON_INS.CHOTEI_NENDO,
                                        RwKKIHON_INS.R_NO,
                                        RwKKIHON_INS.TSUCHI_NO);  -- 15 計算特徴対象者の追加
                        END IF;
                        -- 計算減免個人の追加
                        IF NlCNT > 0 THEN
                          subInsGENMENKOJIN(RwKKIHON_INS.CHOTEI_NENDO,
                                            RwKKIHON_INS.R_NO,
                                            RwKKIHON_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                        END IF;
                    -- 賦課介護退職(最新)
                    WHEN c_NKAITAI   THEN
                        FETCH CwKAITAI   INTO RwKTAI;
                        EXIT WHEN CwKAITAI%NOTFOUND;
                        RwKTAI_INS                      := RwKTAI;                 -- 計算バックアップ内容を出力ワークにセット
                        RwKTAI_INS.CHOTEI_NENDO         := RwKTAI.CHOTEI_NENDO;       -- 調定年度
                        RwKTAI_INS.R_NO                 := RwKTAI.R_NO + c_NRNO_CNT;  -- 履歴番号
                        RwKTAI_INS.TSUCHI_NO            := RwKTAI.TSUCHI_NO;          -- 通知書番号
                        RwKTAI_INS.SYS_SAKUSEIBI        := NlDATE;                    -- 作成日
                        RwKTAI_INS.SYS_KOSHINBI         := NlDATE;                    -- 更新日
                        RwKTAI_INS.SYS_JIKAN            := NlTIME;                    -- 更新時間
                        RwKTAI_INS.SYS_SHOKUINKOJIN_NO  := i_NSYS_SHOKUIN;            -- 更新職員番号
                        RwKTAI_INS.SYS_TANMATSU_NO      := i_VTANMATSU;               -- 更新端末番号
                        -- 計算TBLに追加
                        INSERT INTO ZLBTKAI_TAI_CAL VALUES RwKTAI_INS;
                        -- 計算個人に追加
                        subInsKojin(RwKTAI_INS.CHOTEI_NENDO,
                                    RwKTAI_INS.R_NO,
                                    RwKTAI_INS.TSUCHI_NO);        -- 12 計算個人の追加
                        -- 計算所得の追加
                        IF NlRTN = c_NOK THEN
                          subInsShotoku(RwKTAI_INS.CHOTEI_NENDO,
                                        RwKTAI_INS.R_NO,
                                        RwKTAI_INS.TSUCHI_NO);    -- 13 計算所得の追加
                        END IF;
                        -- 計算賦課拡張の追加
                        IF NlRTN = c_NOK THEN
                        subInsExt(RwKTAI_INS.CHOTEI_NENDO,
                                  RwKTAI_INS.R_NO,
                                  RwKTAI_INS.TSUCHI_NO);          -- 14 計算賦課拡張の追加
                        END IF;
                        -- 計算特徴対象者の追加
                        IF NlRTN = c_NOK THEN
                        subInsTokukihon(RwKTAI_INS.CHOTEI_NENDO,
                                        RwKTAI_INS.R_NO,
                                        RwKTAI_INS.TSUCHI_NO);    -- 15 計算特徴対象者の追加
                        END IF;
                        -- 計算減免個人の追加
                        IF NlCNT > 0 THEN
                          subInsGENMENKOJIN(RwKTAI_INS.CHOTEI_NENDO,
                                            RwKTAI_INS.R_NO,
                                            RwKTAI_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                        END IF;
                    -- 賦課支援基本(最新)
                    WHEN c_NSIENKIHON THEN
                        FETCH CwSIENKIHON INTO RwSKIHON;
                        EXIT WHEN CwSIENKIHON%NOTFOUND;
                        RwSKIHON_INS                    := RwSKIHON;               -- 計算バックアップ内容を出力ワークにセット
                        RwSKIHON_INS.CHOTEI_NENDO       := RwSKIHON.CHOTEI_NENDO;     -- 調定年度
                        RwSKIHON_INS.R_NO               := RwSKIHON.R_NO + c_NRNO_CNT;-- 履歴番号
                        RwSKIHON_INS.TSUCHI_NO          := RwSKIHON.TSUCHI_NO;        -- 通知書番号
                        RwSKIHON_INS.SYS_SAKUSEIBI      := NlDATE;                    -- 作成日
                        RwSKIHON_INS.SYS_KOSHINBI       := NlDATE;                    -- 更新日
                        RwSKIHON_INS.SYS_JIKAN          := NlTIME;                    -- 更新時間
                        RwSKIHON_INS.SYS_SHOKUINKOJIN_NO:= i_NSYS_SHOKUIN;            -- 更新職員番号
                        RwSKIHON_INS.SYS_TANMATSU_NO    := i_VTANMATSU;               -- 更新端末番号
                        -- 計算TBLに追加
                        INSERT INTO ZLBTSIEN_KIHON_CAL VALUES RwSKIHON_INS;
                        -- 計算個人に追加
                        subInsKojin(RwSKIHON_INS.CHOTEI_NENDO,
                                    RwSKIHON_INS.R_NO,
                                    RwSKIHON_INS.TSUCHI_NO);      -- 12 計算個人の追加
                        -- 計算所得の追加
                        IF NlRTN = c_NOK THEN
                          subInsShotoku(RwSKIHON_INS.CHOTEI_NENDO,
                                        RwSKIHON_INS.R_NO,
                                        RwSKIHON_INS.TSUCHI_NO);  -- 13 計算所得の追加
                        END IF;
                        -- 計算賦課拡張の追加
                        IF NlRTN = c_NOK THEN
                        subInsExt(RwSKIHON_INS.CHOTEI_NENDO,
                                  RwSKIHON_INS.R_NO,
                                  RwSKIHON_INS.TSUCHI_NO);        -- 14 計算賦課拡張の追加
                        END IF;
                        -- 計算特徴対象者の追加
                        IF NlRTN = c_NOK THEN
                        subInsTokukihon(RwSKIHON_INS.CHOTEI_NENDO,
                                        RwSKIHON_INS.R_NO,
                                        RwSKIHON_INS.TSUCHI_NO);  -- 15 計算特徴対象者の追加
                        END IF;
                        -- 計算減免個人の追加
                        IF NlCNT > 0 THEN
                           subInsGENMENKOJIN(RwSKIHON_INS.CHOTEI_NENDO,
                                             RwSKIHON_INS.R_NO,
                                             RwSKIHON_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                        END IF;
                    -- 賦課支援退職(最新)
                    WHEN c_NSIENTAI   THEN
                        FETCH CwSIENTAI   INTO RwSTAI;
                        EXIT WHEN CwSIENTAI%NOTFOUND;
                        RwSTAI_INS                      := RwSTAI;                 -- 計算バックアップ内容を出力ワークにセット
                        RwSTAI_INS.CHOTEI_NENDO         := RwSTAI.CHOTEI_NENDO;       -- 調定年度
                        RwSTAI_INS.R_NO                 := RwSTAI.R_NO + c_NRNO_CNT;  -- 履歴番号
                        RwSTAI_INS.TSUCHI_NO            := RwSTAI.TSUCHI_NO;          -- 通知書番号
                        RwSTAI_INS.SYS_SAKUSEIBI        := NlDATE;                    -- 作成日
                        RwSTAI_INS.SYS_KOSHINBI         := NlDATE;                    -- 更新日
                        RwSTAI_INS.SYS_JIKAN            := NlTIME;                    -- 更新時間
                        RwSTAI_INS.SYS_SHOKUINKOJIN_NO  := i_NSYS_SHOKUIN;            -- 更新職員番号
                        RwSTAI_INS.SYS_TANMATSU_NO      := i_VTANMATSU;               -- 更新端末番号
                        -- 計算TBLに追加
                        INSERT INTO ZLBTSIEN_TAI_CAL VALUES RwSTAI_INS;
                        -- 計算個人に追加
                        subInsKojin(RwSTAI_INS.CHOTEI_NENDO,
                                    RwSTAI_INS.R_NO,
                                    RwSTAI_INS.TSUCHI_NO);        -- 12 計算個人の追加
                        -- 計算所得の追加
                        IF NlRTN = c_NOK THEN
                          subInsShotoku(RwSTAI_INS.CHOTEI_NENDO,
                                        RwSTAI_INS.R_NO,
                                        RwSTAI_INS.TSUCHI_NO);    -- 13 計算所得の追加
                        END IF;
                        -- 計算賦課拡張の追加
                        IF NlRTN = c_NOK THEN
                        subInsExt(RwSTAI_INS.CHOTEI_NENDO,
                                  RwSTAI_INS.R_NO,
                                  RwSTAI_INS.TSUCHI_NO);          -- 14 計算賦課拡張の追加
                        END IF;
                        -- 計算特徴対象者の追加
                        IF NlRTN = c_NOK THEN
                        subInsTokukihon(RwSTAI_INS.CHOTEI_NENDO,
                                        RwSTAI_INS.R_NO,
                                        RwSTAI_INS.TSUCHI_NO);    -- 15 計算特徴対象者の追加
                        END IF;
                        -- 計算減免個人の追加
                        IF NlCNT > 0 THEN
                           subInsGENMENKOJIN(RwSTAI_INS.CHOTEI_NENDO,
                                             RwSTAI_INS.R_NO,
                                             RwSTAI_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                        END IF;
                    --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
                    -- 子ども
                    WHEN c_NKDMKIHON   THEN
                        -- 年税額,過年度分,減免額算出準備
                        --子どもの出力ワーク：子どもの計算バックアップ内容をセット
                        --子どもの出力ワーク.調定年度：子どもの計算バックアップ内容.調定年度をセット
                        --子どもの出力ワーク.履歴番号：子どもの計算バックアップ内容.履歴番号+定数：10をセット
                        --子どもの出力ワーク.通知書番号：子どもの計算バックアップ内容.通知書番号をセット
                        --子どもの出力ワーク.過年度分：算出過年度分変数をセット
                        --子どもの出力ワーク.年税額：算出年税額変数をセット
                        --子どもの出力ワーク.作成日：作成日変数をセット
                        --子どもの出力ワーク.更新日：作成日分変数をセット
                        --子どもの出力ワーク.更新時間：更新時間変数をセット
                        --子どもの出力ワーク.更新職員番号：更新職員番号分変数をセット
                        --子どもの出力ワーク.更新端末番号：更新版末番号変数をセット
                        FETCH CwKDMKIHON INTO RwKDMKIHON;
                        EXIT WHEN CwKDMKIHON%NOTFOUND;
                        RwKDMKIHON_INS                      := RwKDMKIHON;                    -- 賦課子ども基本  (最新)　内容をセット
                        RwKDMKIHON_INS.CHOTEI_NENDO         := RwKDMKIHON.CHOTEI_NENDO;       -- 調定年度
                        RwKDMKIHON_INS.R_NO                 := RwKDMKIHON.R_NO + c_NRNO_CNT;  -- 履歴番号
                        RwKDMKIHON_INS.TSUCHI_NO            := RwKDMKIHON.TSUCHI_NO;          -- 通知書番号
                        RwKDMKIHON_INS.SYS_SAKUSEIBI        := NlDATE;                    -- 作成日
                        RwKDMKIHON_INS.SYS_KOSHINBI         := NlDATE;                    -- 更新日
                        RwKDMKIHON_INS.SYS_JIKAN            := NlTIME;                    -- 更新時間
                        RwKDMKIHON_INS.SYS_SHOKUINKOJIN_NO  := i_NSYS_SHOKUIN;            -- 更新職員番号
                        RwKDMKIHON_INS.SYS_TANMATSU_NO      := i_VTANMATSU;               -- 更新端末番号
                        -- 計算TBLに追加
                        INSERT INTO ZLBTKDM_KIHON_CAL VALUES RwKDMKIHON_INS;
                        -- 計算個人に追加
                        subInsKojin(RwKDMKIHON_INS.CHOTEI_NENDO,
                                    RwKDMKIHON_INS.R_NO,
                                    RwKDMKIHON_INS.TSUCHI_NO);        -- 12 計算個人の追加
                        -- 計算所得の追加
                        IF NlRTN = c_NOK THEN
                          subInsShotoku(RwKDMKIHON_INS.CHOTEI_NENDO,
                                        RwKDMKIHON_INS.R_NO,
                                        RwKDMKIHON_INS.TSUCHI_NO);    -- 13 計算所得の追加
                        END IF;
                        -- 計算賦課拡張の追加
                        IF NlRTN = c_NOK THEN
                          subInsExt(RwKDMKIHON_INS.CHOTEI_NENDO,
                                    RwKDMKIHON_INS.R_NO,
                                    RwKDMKIHON_INS.TSUCHI_NO);        -- 14 計算賦課拡張の追加
                        END IF;

                        -- 計算特徴対象者の追加
                        IF NlRTN = c_NOK THEN
                          subInsTokukihon(RwKDMKIHON_INS.CHOTEI_NENDO,
                                          RwKDMKIHON_INS.R_NO,
                                          RwKDMKIHON_INS.TSUCHI_NO);  -- 15 計算特徴対象者の追加
                        END IF;
                        -- 計算減免個人の追加
                        IF NlCNT > 0 THEN
                          subInsGENMENKOJIN(RwKDMKIHON_INS.CHOTEI_NENDO,
                                            RwKDMKIHON_INS.R_NO,
                                            RwKDMKIHON_INS.TSUCHI_NO);   -- 15-2 計算減免個人の追加
                        END IF;
                        --  2025/08/11 ZCZL.HAODAPENG ADD END
                    END CASE;
                    -- 取得データがn件時は清算処理が行われている為、自動セット不可能

                    NwCNT := NwCNT - 1;
                END LOOP;

                -- カーソルクローズ
                CASE i_NwTBL
                WHEN c_NKIHON    THEN CLOSE CwKIHON;        -- 賦課基本(最新)
                WHEN c_NTAI      THEN CLOSE CwTAI;          -- 賦課退職(最新)
                WHEN c_NKAIKIHON THEN CLOSE CwKAIKIHON;     -- 賦課介護基本(最新)
                WHEN c_NKAITAI   THEN CLOSE CwKAITAI;       -- 賦課介護退職(最新)
                WHEN c_NSIENKIHON THEN CLOSE CwSIENKIHON;   -- 賦課支援基本(最新)
                WHEN c_NSIENTAI   THEN CLOSE CwSIENTAI;     -- 賦課支援退職(最新)
                --  2025/08/11 ZCZL.HAODAPENG ADD 1.1.200.000:子ども子育て支援金対応
                WHEN c_NKDMKIHON   THEN CLOSE CwKDMKIHON;     -- 子ども
                END CASE;
            END IF;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
          IF CwKIHON%ISOPEN THEN
              CLOSE CwKIHON;
            END IF;
            IF CwTAI%ISOPEN THEN
              CLOSE CwTAI;
            END IF;
            IF CwKAIKIHON%ISOPEN THEN
              CLOSE CwKAIKIHON;
            END IF;
            IF CwKAITAI%ISOPEN THEN
              CLOSE CwKAITAI;
            END IF;
            IF CwSIENKIHON%ISOPEN THEN
              CLOSE CwSIENKIHON;
            END IF;
            IF CwSIENTAI%ISOPEN THEN
              CLOSE CwSIENTAI;
            END IF;
            --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
            IF CwKDMKIHON%ISOPEN THEN
              CLOSE CwKDMKIHON;
            END IF;
            --  2025/08/11 ZCZL.HAODAPENG ADD END
            NlRTN := c_NERR;
            VlMSG := 'subGengaku 減額処理' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;

    END subGengaku2;
-------------------------------------------------------------------------------
--  06 増額処理
--      指定された計算TBLについて次の項目を更新する
--          ・過年度分 = NlNENZEI_KEI(過計)
--          ・年税額 = NlNENZEI(年税額) - NlNENZEI_KEI(過計)
-------------------------------------------------------------------------------
    PROCEDURE subZogaku(i_NwTBL IN NUMBER) IS
        VwTBL           NVARCHAR2(30);
        VwSQL           VARCHAR2(2048);

        NwNENZEI        NUMBER;
        NwTSUKIWARI_GEN NUMBER;                 -- 月割減額
        NwGENGAKU_KEI   NUMBER;                 -- 減額合計
    BEGIN
        VwTBL := funcGetTblnm(i_NwTBL, 0);      -- 11 テーブル名取得(計算TBL)

        IF VwTBL IS NULL THEN
            NlRTN := c_NERR;
            VlMSG := 'subZogaku ' || 'テーブル名取得' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;
        ELSE
            -- 年税額算出(計算年税額-年税額過計)
            NwNENZEI := NlNENZEI - NlNENZEI_KEI;
            IF NwNENZEI < 0 THEN        -- 全体増で退職減のときありえる
                NwTSUKIWARI_GEN := NwNENZEI;
                NwGENGAKU_KEI   := NwNENZEI;
                NwNENZEI := 0;
            ELSE
                NwTSUKIWARI_GEN := 0;
                NwGENGAKU_KEI   := 0;
            END IF;

            VwSQL := 'UPDATE '                   || VwTBL        ||
                     ' SET KANENDO = '           || NlNENZEI_KEI ||      -- 過年度分
                     ' ,NENZEI = '               || NwNENZEI     ||      -- 年税額
                     ' ,TSUKIWARI_GEN = TSUKIWARI_GEN + ' || NwTSUKIWARI_GEN ||
                     ' ,GENGAKU_KEI   = GENGAKU_KEI   + ' || NwGENGAKU_KEI   ||
                     ' WHERE KOKU_SETAI_NO = '   || i_NSETAI     ||
                     ' AND SANTEIDANTAI_CD = '   || i_NDANTAI    ||
                     ' AND CHOTEI_NENDO = '      || i_NNENDO     ||
                     ' AND NENDO_BUN = '         || i_NNENDO_BUN ||
                     ' AND TSUCHI_NO = '         || i_NTSUCHI_NO ||
                     ' AND SYS_TANMATSU_NO = ''' || i_VTANMATSU  || '''';
            EXECUTE IMMEDIATE VwSQL;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subZogaku 増額処理' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;
    END subZogaku;
-------------------------------------------------------------------------------
--  05 年税額(賦課TBL)
--      指定された賦課TBLの税額過計/総計と端数過計/総計を取得
-------------------------------------------------------------------------------
    PROCEDURE subGetNenzeiN(i_NwTBL IN NUMBER) IS
        VwTBL           NVARCHAR2(30);
        VwSQL           VARCHAR2(2048);
        VwSQL2          VARCHAR2(2048);
    BEGIN
        VwTBL := funcGetTblnm(i_NwTBL, 1);      -- 11 テーブル名取得(賦課(最新)TBL)
        IF VwTBL IS NULL THEN
            NlRTN := c_NERR;
            VlMSG := 'subGetNenzeiN ' || 'テーブル名取得' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;
        ELSE
            -- 総計算出 --------------------------------------------------------------
            VwSQL := 'SELECT NVL(SUM(NENZEI), 0), NVL(SUM(HASU), 0) FROM ' || VwTBL ||
                     ' WHERE KOKU_SETAI_NO = '   || i_NSETAI     ||
                     ' AND SANTEIDANTAI_CD = '   || i_NDANTAI    ||
                     ' AND NENDO_BUN = '         || i_NNENDO_BUN;

            VwSQL2 := '';
            -- 主課税の場合は下記条件を追加
            IF NlNUSHI_KAZEI <> 0 THEN
                --  2025/08/11 ZCZL.HAODAPENG UPDATE START 1.1.200.000:子ども子育て支援金対応
                --IF i_NwTBL in (c_NKIHON,c_NKAIKIHON,c_NSIENKIHON) THEN
                IF i_NwTBL in (c_NKIHON,c_NKAIKIHON,c_NSIENKIHON,c_NKDMKIHON) THEN
                --  2025/08/11 ZCZL.HAODAPENG UPDATE END
                    -- 一般の場合
                    VwSQL := VwSQL || ' AND NUSHI_KOJIN_NO = ' || NlNUSHI_KOJIN_NO;
                ELSE
                    -- 退職の場合
                    IF i_NwTBL = c_NTAI THEN
                        -- 医療の場合
                        VwSQL := VwSQL || ' AND TSUCHI_NO in (SELECT TSUCHI_NO FROM ZLBTKIHON_N ';
--                        -- 介護の場合
                    ELSIF i_NwTBL = c_NKAITAI THEN
                        -- 介護の場合
                        VwSQL := VwSQL || ' AND TSUCHI_NO in (SELECT TSUCHI_NO FROM ZLBTKAI_KIHON_N ';
                    ELSE
                        -- 支援の場合
                        VwSQL := VwSQL || ' AND TSUCHI_NO in (SELECT TSUCHI_NO FROM ZLBTSIEN_KIHON_N ';

                    END IF;
                    VwSQL2 := ' WHERE KOKU_SETAI_NO = '   || i_NSETAI     ||
                              ' AND SANTEIDANTAI_CD = '   || i_NDANTAI    ||
                              ' AND CHOTEI_NENDO <> '      || i_NNENDO     ||
                              ' AND NENDO_BUN = '         || i_NNENDO_BUN ||
                              ' AND NUSHI_KOJIN_NO = '         || NlNUSHI_KOJIN_NO || ')';
                END IF;
            END IF;
            EXECUTE IMMEDIATE VwSQL || VwSQL2 INTO NlNENZEI_SO, NlHASU_SO;

            -- 過計算出 --------------------------------------------------------------
            VwSQL := 'SELECT NVL(SUM(NENZEI), 0), NVL(SUM(HASU), 0) FROM ' || VwTBL ||
                     ' WHERE KOKU_SETAI_NO = '   || i_NSETAI     ||
                     ' AND SANTEIDANTAI_CD = '   || i_NDANTAI    ||
                     ' AND CHOTEI_NENDO <> '     || i_NNENDO     ||
                     ' AND NENDO_BUN = '         || i_NNENDO_BUN;

            VwSQL2 := '';

            IF NlNUSHI_KAZEI <> 0 THEN
                --  2025/08/11 ZCZL.HAODAPENG UPDATE START 1.1.200.000:子ども子育て支援金対応
                -- i_NwTBL in (c_NKIHON,c_NKAIKIHON,c_NSIENKIHON) THEN
                IF i_NwTBL in (c_NKIHON,c_NKAIKIHON,c_NSIENKIHON,c_NKDMKIHON) THEN
                --  2025/08/11 ZCZL.HAODAPENG UPDATE END

                    -- 一般の場合
                    VwSQL := VwSQL || ' AND NUSHI_KOJIN_NO = ' || NlNUSHI_KOJIN_NO;
                ELSE
                    -- 退職の場合
                    IF i_NwTBL = c_NTAI THEN
                        -- 医療の場合
                        VwSQL := VwSQL || ' AND TSUCHI_NO in (SELECT TSUCHI_NO FROM ZLBTKIHON_N ';
--                        -- 介護の場合
                    ELSIF i_NwTBL = c_NKAITAI THEN
                        -- 介護の場合
                        VwSQL := VwSQL || ' AND TSUCHI_NO in (SELECT TSUCHI_NO FROM ZLBTKAI_KIHON_N ';
                    ELSE
                        -- 支援の場合
                        VwSQL := VwSQL || ' AND TSUCHI_NO in (SELECT TSUCHI_NO FROM ZLBTSIEN_KIHON_N ';
                    END IF;
                    VwSQL2 := ' WHERE KOKU_SETAI_NO = '   || i_NSETAI     ||
                              ' AND SANTEIDANTAI_CD = '   || i_NDANTAI    ||
                              ' AND CHOTEI_NENDO <> '      || i_NNENDO     ||
                              ' AND NENDO_BUN = '         || i_NNENDO_BUN ||
                              ' AND NUSHI_KOJIN_NO = '         || NlNUSHI_KOJIN_NO || ')';
                END IF;
            END IF;
             EXECUTE IMMEDIATE VwSQL || VwSQL2 INTO NlNENZEI_KEI, NlHASU_KEI;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subGetNenzeiN 年税額過計取得' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;
    END subGetNenzeiN;
-------------------------------------------------------------------------------
--  04 年税額(計算TBL)
--      指定された計算TBLの税額と端数を取得
-------------------------------------------------------------------------------
    PROCEDURE subGetNenzeiCal(i_NwTBL IN NUMBER) IS
        VwTBL           NVARCHAR2(30);
        VwSQL           VARCHAR2(2048);
    BEGIN

        VwTBL := funcGetTblnm(i_NwTBL, 0);      -- 11 テーブル名取得(計算TBL)

        IF VwTBL IS NULL THEN
            NlRTN := c_NERR;
            VlMSG := 'subGetNenzeiCal ' || 'テーブル名取得' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;
        ELSE
            VwSQL := 'SELECT NENZEI, HASU FROM ' || VwTBL        ||
                     ' WHERE KOKU_SETAI_NO = '   || i_NSETAI     ||
                     ' AND SANTEIDANTAI_CD = '   || i_NDANTAI    ||
                     ' AND CHOTEI_NENDO = '      || i_NNENDO     ||
                     ' AND NENDO_BUN = '         || i_NNENDO_BUN ||
                     ' AND TSUCHI_NO = '         || i_NTSUCHI_NO ||
                     ' AND SYS_TANMATSU_NO = ''' || i_VTANMATSU  || '''';

            EXECUTE IMMEDIATE VwSQL INTO NlNENZEI, NlHASU;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subGetNenzeiCal 年税額取得' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;
    END subGetNenzeiCal;

-------------------------------------------------------------------------------
--  03 計算TBLの増減判定チェック
--      指定された計算TBLの税額と賦課TBLの税額を比較する。
-------------------------------------------------------------------------------
    PROCEDURE subChkZogen(i_NwTBL IN NUMBER) IS
        NwNENZEI            NUMBER;     -- 今回計算した結果の年税額　--（判定用）
        NwNENZEI_KEI        NUMBER;     -- 賦課を集計した年税額(過計)　--（判定用）
    BEGIN
        IF NOT i_NwTBL in (c_NTAI, c_NKAITAI, c_NSIENTAI) THEN
            NlNENZEI     := 0;          -- 年税額(課税計算結果)
            NlHASU       := 0;          -- 端数金額(課税計算結果)
            NlNENZEI_KEI := 0;          -- 年税額過計
            NlHASU_KEI   := 0;          -- 端数過計
        END IF;

        NwNENZEI_KEI := 0;          -- 年税額過計

        -- 判定用の年税額を取得する。(基本分のみ）
        IF NOT i_NwTBL in (c_NTAI, c_NKAITAI, c_NSIENTAI) THEN

            subGetNenzeical(i_NwTBL);   -- 各テーブル
        END IF;
        -- 基本分を退避
        NwNENZEI := NlNENZEI;         -- 年税額(課税計算結果)

        IF NlRTN = c_NOK  THEN
            -- 過年度計の年税額を取得する。(基本分のみ）
            IF NOT i_NwTBL in (c_NTAI, c_NKAITAI, c_NSIENTAI) THEN

                subGetNenzeiN(i_NwTBL);     -- 各テーブル
            END IF;
            NwNENZEI_KEI := NlNENZEI_KEI;   -- 年税額(課税計算結果)
        END IF;

        -- 各テーブルのデータを取得しなおす。

        -- 計算TBL取得(年税額,端数)
        subGetNenzeiCal(i_NwTBL);       -- 04 年税額(計算TBL)

        -- 賦課(最新)TBL取得(年税額,端数の過計)
        IF NlRTN = c_NOK THEN
            subGetNenzeiN(i_NwTBL);     -- 05 年税額(賦課TBL)
        END IF;

        IF NlRTN = c_NOK THEN

            IF i_NwTBL IN (c_NTAI, c_NKAITAI, c_NSIENTAI) THEN
                -- 退職時のみ
                IF NwNENZEI <> NlNENZEI THEN
                    NwNENZEI := NwNENZEI - NlNENZEI;               -- 年税額一般(全体-退職)
                    NwNENZEI_KEI := NwNENZEI_KEI - NlNENZEI_KEI;   -- 年税額一般(全体-退職)
                END IF;
            END IF;

            -- 増減判定（端数調整前税額から端数調整後税額に変更）
            IF NwNENZEI > NwNENZEI_KEI THEN
                -- 年税額が増の場合
                IF i_NwTBL IN (c_NKIHON, c_NTAI) THEN
                    NlIRY_ZOGEN := c_NZO; -- 医療
                ELSIF i_NwTBL IN (c_NKAIKIHON, c_NKAITAI) THEN
                    NlKAI_ZOGEN := c_NZO; -- 介護
                --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
                ELSIF i_NwTBL IN (c_NSIENKIHON, c_NSIENTAI) THEN
                    NlSIEN_ZOGEN := c_NZO;-- 支援
                ELSE
                    NlKDM_ZOGEN := c_NZO; -- 子ども
                END IF;
                --  2025/08/11 ZCZL.HAODAPENG ADD END
            ELSIF NwNENZEI < NwNENZEI_KEI THEN
                -- 年税額が減の場合
                IF i_NwTBL IN (c_NKIHON, c_NTAI) THEN
                    NlIRY_ZOGEN := c_NGEN; -- 医療
                ELSIF i_NwTBL IN (c_NKAIKIHON, c_NKAITAI) THEN
                    NlKAI_ZOGEN := c_NGEN; -- 介護
                --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
                ELSIF i_NwTBL IN (c_NSIENKIHON, c_NSIENTAI) THEN
                    NlSIEN_ZOGEN := c_NGEN;-- 支援
                ELSE
                    NlKDM_ZOGEN := c_NGEN; -- 子ども
                END IF;
                --  2025/08/11 ZCZL.HAODAPENG ADD END
            END IF;
        END IF;
-- 全体総額が減額になるか判定
        IF i_NwTBL IN (c_NKIHON, c_NTAI) THEN
            IR_NENZEI     := NwNENZEI;
            IR_NENZEI_KEI := NwNENZEI_KEI;
        ELSIF i_NwTBL IN (c_NKAIKIHON, c_NKAITAI) THEN
            KAI_NENZEI     := NwNENZEI;
            KAI_NENZEI_KEI := NwNENZEI_KEI;
        --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
        ELSIF i_NwTBL IN (c_NSIENKIHON, c_NSIENTAI) THEN
            SIEN_NENZEI     := NwNENZEI;
            SIEN_NENZEI_KEI := NwNENZEI_KEI;
        ELSE
            KDM_NENZEI     := NwNENZEI;
            KDM_NENZEI_KEI := NwNENZEI_KEI;
        --  2025/08/11 ZCZL.HAODAPENG ADD END
          -- 内訳単位で増更正が発生しているもの、または年税額０で増減が発生していないものはないか判定
          --  2025/08/11 ZCZL.HAODAPENG UPDATE START 1.1.200.000:子ども子育て支援金対応
          --IF (IR_NENZEI >= IR_NENZEI_KEI) OR (KAI_NENZEI >= KAI_NENZEI_KEI) OR (SIEN_NENZEI >= SIEN_NENZEI_KEI) THEN
            -- 全体総額が減額になる、または年税額０のまま変動がないか判定
          --  IF (IR_NENZEI + KAI_NENZEI + SIEN_NENZEI) <= (IR_NENZEI_KEI + KAI_NENZEI_KEI + SIEN_NENZEI_KEI) THEN
          IF (IR_NENZEI >= IR_NENZEI_KEI) OR (KAI_NENZEI >= KAI_NENZEI_KEI) OR (SIEN_NENZEI >= SIEN_NENZEI_KEI) OR (KDM_NENZEI >= KDM_NENZEI_KEI) THEN
            -- 全体総額が減額になる、または年税額０のまま変動がないか判定
            IF (IR_NENZEI + KAI_NENZEI + SIEN_NENZEI + KDM_NENZEI) <= (IR_NENZEI_KEI + KAI_NENZEI_KEI + SIEN_NENZEI_KEI + KDM_NENZEI_KEI) THEN
                NlKDM_ZOGEN  := c_NGEN;
          --  2025/08/11 ZCZL.HAODAPENG UPDATE END
                NlIRY_ZOGEN  := c_NGEN;
                NlKAI_ZOGEN  := c_NGEN;
                NlSIEN_ZOGEN := c_NGEN;
                TOTAL_GEN_FLG := 1;
            END IF;
          END IF;
        END IF;
    END subChkZogen;
-------------------------------------------------------------------------------
--  03 計算TBLのデータ生成
--      指定された計算TBLの税額と賦課TBLの税額を比較しデータを生成する
-------------------------------------------------------------------------------
    PROCEDURE subCreateCal(i_NwTBL IN NUMBER) IS

       NwJOKEN_HASU        NUMBER;     -- システム条件で取得した端数金額
       NwGENDOGAKU         NUMBER;     -- 賦課限度額
       NwZOGEN             NUMBER;     -- 増減判定

       NwNENZEI            NUMBER;     -- 今回計算した結果の年税額　--（判定用）
       NwNENZEI_KEI        NUMBER;     -- 賦課を集計した年税額(過計)　--（判定用）
       NwNENZEI2           NUMBER;     -- 今回計算した結果の全体年税額　　--（判定用退避）
       NwNENZEI_KEI2       NUMBER;     -- 賦課を集計した全体年税額(過計)　--（判定用退避）

    BEGIN
      IF i_NwTBL in (c_NKIHON, c_NTAI) THEN
          -- 医療時
          NwGENDOGAKU := NlGENDOGAKU_IRY; -- 医療限度額
          NwZOGEN     := NlIRY_ZOGEN;     -- 医療の増減状況

      ELSIF i_NwTBL in (c_NKAIKIHON, c_NKAITAI) THEN
          -- 介護時
          NwGENDOGAKU := NlGENDOGAKU_KAI; -- 介護限度額
          NwZOGEN     := NlKAI_ZOGEN;     -- 介護の増減状況
      --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
      ELSIF i_NwTBL IN (c_NSIENKIHON, c_NSIENTAI) THEN
          -- 支援時
          NwGENDOGAKU := NlGENDOGAKU_SIEN; -- 支援限度額
          NwZOGEN     := NlSIEN_ZOGEN;     -- 支援の増減状況
      ELSE
          --子ども時
          NwGENDOGAKU     := NlGENDOGAKU_KDM;
          NwZOGEN         := NlKDM_ZOGEN;
      --  2025/08/11 ZCZL.HAODAPENG ADD END

      END IF;

      IF NOT i_NwTBL in (c_NTAI, c_NKAITAI, c_NSIENTAI) THEN
          NlNENZEI     := 0;          -- 年税額(課税計算結果)
          NlHASU       := 0;          -- 端数金額(課税計算結果)
          NlNENZEI_KEI := 0;          -- 年税額過計
          NlHASU_KEI   := 0;          -- 端数過計
      END IF;

      -- クリア
      NwNENZEI_KEI := 0;          -- 年税額過計
      NwNENZEI_KEI2 := 0;         -- 全体年税額過計

      -- 判定用の年税額を取得する。(常に全体分）
      IF NOT i_NwTBL in (c_NTAI, c_NKAITAI ,c_NSIENTAI) THEN

          subGetNenzeical(i_NwTBL);   -- 各テーブル
      END IF;
      -- 基本分を退避
      NwNENZEI := NlNENZEI;         -- 年税額(課税計算結果)
      NwNENZEI2 := NlNENZEI;        -- 全体年税額(課税計算結果)

      -- 過年度計の年税額を取得する。(常に全体分)
      IF NlRTN = c_NOK  THEN
          IF NOT i_NwTBL in (c_NTAI, c_NKAITAI , c_NSIENTAI) THEN
              subGetNenzeiN(i_NwTBL);     -- 各テーブル
          END IF;
          NwNENZEI_KEI := NlNENZEI_KEI;   -- 年税額(課税計算結果)
          NwNENZEI_KEI2 := NlNENZEI_KEI;  -- 全体年税額(課税計算結果)
      END IF;

      -- 各テーブルのデータを取得しなおす。
      -- 計算TBL取得(年税額,端数)
      subGetNenzeiCal(i_NwTBL);       -- 04 年税額(計算TBL)

      -- 賦課(最新)TBL取得(年税額,端数の過計)
      IF NlRTN = c_NOK THEN
          subGetNenzeiN(i_NwTBL);     -- 05 年税額(賦課TBL)
      END IF;

      IF NlRTN = c_NOK THEN
          IF i_NwTBL IN (c_NKIHON, c_NTAI) THEN
              NwJOKEN_HASU := NlHASU_IRY;      -- 医療端数金額
          ELSIF i_NwTBL IN (c_NKAIKIHON, c_NKAITAI) THEN
              NwJOKEN_HASU := NlHASU_KAI;      -- 介護端数金額
          ELSIF i_NwTBL IN (c_NSIENKIHON, c_NSIENTAI) THEN
              NwJOKEN_HASU := NlHASU_SIEN;     -- 支援端数金額
          --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
          ELSIF i_NwTBL IN (c_NKDMKIHON) THEN
              --子ども時
              NwJOKEN_HASU     := NlHASU_KDM;
          --  2025/08/11 ZCZL.HAODAPENG ADD END
          END IF;

          IF i_NwTBL IN (c_NTAI, c_NKAITAI, c_NSIENTAI) THEN
             -- 退職時のみ
              IF NwNENZEI <> NlNENZEI THEN
                  -- 退職税額に変化がないなら
                  IF NlNENZEI = (NwNENZEI - NwNENZEI_KEI) THEN
                      NwNENZEI     := NlNENZEI;                     -- 年税額退職
                      NwNENZEI_KEI := NlNENZEI_KEI;                 -- 年税額退職
                  ELSE
                      NwNENZEI     := NwNENZEI - NlNENZEI;          -- 年税額一般(全体-退職)
                      NwNENZEI_KEI := NwNENZEI_KEI - NlNENZEI_KEI;  -- 年税額一般(全体-退職)
                  END IF;
              END IF;
          END IF;

          -- 増減判定（端数調整前税額から端数調整後税額に変更）

          IF NwNENZEI > NwNENZEI_KEI AND NwZOGEN = c_NZO THEN
              -- 退職のみ
              -- 全体増＜退職増
              -- 退職増＞＝端数調整額の場合、現年度データを作成後に過年度データを作成する
              -- 年税額調整はsubUpdTaiにて行う
              IF i_NwTBL in (c_NTAI, c_NKAITAI , c_NSIENTAI) AND
                 NwNENZEI2 - NwNENZEI_KEI2 < NlNENZEI - NlNENZEI_KEI AND
                 NlNENZEI - NlNENZEI_KEI >= NwJOKEN_HASU THEN
                  IF NlNUSHI_KAZEI = 0 THEN
                      subGengaku2(i_NwTBL);   -- 07 減額処理(主課税しない）
                  ELSE
                      subGengaku(i_NwTBL);    -- 07 減額処理(主課税する）
                  END IF;
              END IF;
              -- 年税額が増の場合
              subZogaku(i_NwTBL);         -- 06 増額処理
          ELSE
              -- 医療の年税額が限度超過で介護が増となる場合 or
              -- 介護の年税額が限度超過で医療が増となる場合
              IF (NwNENZEI >= NwGENDOGAKU AND NwNENZEI_KEI >= NwGENDOGAKU) AND NwZOGEN = c_NZO THEN
                  -- 年税額が増の場合
                  subZogaku(i_NwTBL);         -- 06 増額処理
              ELSE
                  -- 退職のみ
                  -- 一般年税額が減の場合（＝退職年税額が増の場合）
                  -- 全体増＜退職増のケース
                  IF i_NwTBL in (c_NTAI, c_NKAITAI , c_NSIENTAI) AND
                     NwNENZEI <= NwNENZEI_KEI AND
                     NwZOGEN = c_NZO THEN
                      -- 退職増が端数金額内でおさまる場合
                      IF NwNENZEI_KEI - NwNENZEI < NwJOKEN_HASU THEN
                          subZogaku(i_NwTBL);         -- 06 増額処理
                      ELSE
                          -- 現年度データを作成後に過年度データを作成する
                          -- 年税額調整はsubUpdTaiにて行う
                          IF NlNUSHI_KAZEI = 0 THEN
                              subGengaku2(i_NwTBL);   -- 07 減額処理(主課税しない）
                          ELSE
                              subGengaku(i_NwTBL);    -- 07 減額処理(主課税する）
                          END IF;
                          subZogaku(i_NwTBL);         -- 06 増額処理
                      END IF;
                  ELSE

if NwNENZEI > 0 or NwNENZEI_KEI > 0 or NwZOGEN = c_NGEN then
                      -- 年税額が減の場合
                      IF NlNUSHI_KAZEI = 0 THEN
                          subGengaku2(i_NwTBL);   -- 07 減額処理(主課税しない）
                      ELSE
                          subGengaku(i_NwTBL);    -- 07 減額処理(主課税する）
                      END IF;
end if;
                  END IF;
              END IF;
          END IF;
      END IF;

    END subCreateCal;
-------------------------------------------------------------------------------
--  xx 主課税条件を判定する
--      主課税対応か必要かどうかを判定する。
-------------------------------------------------------------------------------
    PROCEDURE subChkNUSHIKAZEI IS
        NwNUSHI_4    NUMBER;
        NwNUSHI_5    NUMBER;
        NwNUSHI_6    NUMBER;
        NwNUSHI_7    NUMBER;
        NwNUSHI_8    NUMBER;
        NwNUSHI_9    NUMBER;
        NwNUSHI_10   NUMBER;
        NwNUSHI_11   NUMBER;
        NwNUSHI_12   NUMBER;
        NwNUSHI_1    NUMBER;
        NwNUSHI_2    NUMBER;
        NwNUSHI_3    NUMBER;
        NwKOJINNO    NUMBER;
        NwCOUNT      NUMBER;
        NwDATE_END     NUMBER(8);    -- 期末日(3/31)
    BEGIN
        IF NlRTN = c_NOK THEN
            -- 主課税判定用の世帯主個人番号を取得
            BEGIN
                SELECT NUSHI_4,NUSHI_5,NUSHI_6,NUSHI_7,NUSHI_8,NUSHI_9,NUSHI_10,NUSHI_11,NUSHI_12,NUSHI_1,NUSHI_2,NUSHI_3
                INTO NwNUSHI_4,NwNUSHI_5,NwNUSHI_6,NwNUSHI_7,NwNUSHI_8,NwNUSHI_9,NwNUSHI_10,NwNUSHI_11,NwNUSHI_12,NwNUSHI_1,NwNUSHI_2,NwNUSHI_3
                FROM ZLBTSEISAN_CAL
                WHERE KOKU_SETAI_NO = i_NSETAI
                AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                  WHEN OTHERS THEN
                      NlRTN := c_NERR;
                      VlMSG := 'subChkNUSHIKAZEI 清算フラグ取得' || '(国保世帯番号=' || i_NSETAI ||')' || SQLERRM;
            END;

            --初期化
            NlNUSHI_KAZEI := 0;
            NwKOJINNO := NwNUSHI_4;
            --主が変更されていれば主課税とする。
            IF NwNUSHI_5 <> NwKOJINNO THEN
                NlNUSHI_KAZEI := 1;
            END IF;
            IF NwNUSHI_6 <> NwKOJINNO THEN
                NlNUSHI_KAZEI := 1;
            END IF;
            IF NwNUSHI_7 <> NwKOJINNO THEN
                NlNUSHI_KAZEI := 1;
            END IF;
            IF NwNUSHI_8 <> NwKOJINNO THEN
                NlNUSHI_KAZEI := 1;
            END IF;
            IF NwNUSHI_9 <> NwKOJINNO THEN
                NlNUSHI_KAZEI := 1;
            END IF;
            IF NwNUSHI_10 <> NwKOJINNO THEN
                NlNUSHI_KAZEI := 1;
            END IF;
            IF NwNUSHI_11 <> NwKOJINNO THEN
                NlNUSHI_KAZEI := 1;
            END IF;
            IF NwNUSHI_12 <> NwKOJINNO THEN
                NlNUSHI_KAZEI := 1;
            END IF;
            IF NwNUSHI_1 <> NwKOJINNO THEN
                NlNUSHI_KAZEI := 1;
            END IF;
            IF NwNUSHI_2 <> NwKOJINNO THEN
                NlNUSHI_KAZEI := 1;
            END IF;
            IF NwNUSHI_3 <> NwKOJINNO THEN
                NlNUSHI_KAZEI := 1;
            END IF;
        END IF;

        IF NlNUSHI_KAZEI = 0 THEN
          NwCOUNT := 0;

          BEGIN
              NwDATE_END := TO_NUMBER(TO_CHAR(i_NNENDO_BUN + 1) || '0331'); -- 翌年+0331

              -- 清算区分取得
              SELECT COUNT(*) INTO NwCOUNT FROM ZLBTNUSHI_TMP
              WHERE KOKU_SETAI_NO = i_NSETAI
              AND NUSHI_KOJIN_NO = NlNUSHI_KOJIN_NO
              AND NUSHI_TEKI_SBI = (
              SELECT MAX(NUSHI_TEKI_SBI) FROM ZLBTNUSHI_TMP
              WHERE KOKU_SETAI_NO = i_NSETAI
              AND NUSHI_KOJIN_NO = NlNUSHI_KOJIN_NO
              AND NUSHI_TEKI_SBI   <= NwDATE_END
              AND SYS_TANMATSU_NO = i_VTANMATSU)
              AND SEISAN_FLAG = 1
              AND SYS_TANMATSU_NO = i_VTANMATSU;
          EXCEPTION
              WHEN NO_DATA_FOUND THEN
                  NULL;
              WHEN OTHERS THEN
                  NlRTN := c_NERR;
                  VlMSG := 'subChkNUSHIKAZEI 清算対象取得' || '(世帯主宛名番号=' || NlNUSHI_KOJIN_NO || ')' || SQLERRM;
          END;

          IF NwCOUNT > 0 THEN
              -- 賦課基本と4月分の世帯主は異なっているか？(過年度分 or 現年度分)
              BEGIN
                  SELECT COUNT(*) INTO NwCOUNT FROM ZLBTKIHON_N
                  WHERE KOKU_SETAI_NO   = i_NSETAI
                  AND SANTEIDANTAI_CD = i_NDANTAI
                  AND CHOTEI_NENDO    = i_NNENDO
                  AND NENDO_BUN       = i_NNENDO_BUN
                  AND NUSHI_KOJIN_NO  <> NlNUSHI_KOJIN_NO;
              EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                      NULL;
                  WHEN OTHERS THEN
                      NlRTN := c_NERR;
                      VlMSG := 'subChkNUSHIKAZEI 世帯主チェック' || '(世帯主宛名番号=' || NlNUSHI_KOJIN_NO || ')' || SQLERRM;
              END;

              IF NwCOUNT <= 0 THEN
                   -- 賦課基本と4月の世帯主は異なっているか？(現年度分)
                  BEGIN
                      SELECT COUNT(*) INTO NwCOUNT FROM ZLBTKIHON_N
                      WHERE KOKU_SETAI_NO   = i_NSETAI
                      AND SANTEIDANTAI_CD = i_NDANTAI
                      AND CHOTEI_NENDO    = i_NNENDO_BUN
                      AND NENDO_BUN       = i_NNENDO_BUN
                      AND NUSHI_KOJIN_NO  <> NlNUSHI_KOJIN_NO;
                  EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                          NULL;
                      WHEN OTHERS THEN
                          NlRTN := c_NERR;
                          VlMSG := 'subChkNUSHIKAZEI 世帯主チェック' || '(世帯主宛名番号=' || NlNUSHI_KOJIN_NO || ')' || SQLERRM;
                  END;
              END IF;

              IF NwCOUNT > 0 THEN
                  NlNUSHI_KAZEI := 1;
              END IF;
          END IF;
        END IF;
    END subChkNUSHIKAZEI;
-------------------------------------------------------------------------------
--  02 メイン処理
--      税額を判断し計算基本･退職･介護基本･介護退職を生成する
-------------------------------------------------------------------------------
    PROCEDURE subMain IS
    BEGIN

        -- 世帯主個人番号の取得
        NlNUSHI_KOJIN_NO := 0;
        NwIRYSAGAKU := 0;   -- 差額
        NwKAISAGAKU := 0;   -- 差額
        BEGIN
            SELECT NUSHI_KOJIN_NO INTO NlNUSHI_KOJIN_NO FROM ZLBTKIHON_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
             AND   SANTEIDANTAI_CD = i_NDANTAI
             AND   CHOTEI_NENDO    = i_NNENDO
             AND   NENDO_BUN       = i_NNENDO_BUN
             AND   TSUCHI_NO       = i_NTSUCHI_NO
             AND   SYS_TANMATSU_NO = i_VTANMATSU;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subMain 世帯主宛名番号取得' || '(国保世帯番号=' || i_NSETAI ||')' || SQLERRM;
        END;

        -- 主課税判定
        IF NlRTN = c_NOK THEN
            subChkNUSHIKAZEI;
        END IF;

        -- 計算TBLの増減判定(基本)
        IF NlRTN = c_NOK THEN
            subChkZogen(c_NKIHON);
        END IF;
        -- 計算TBLの増減判定(介護基本)
        IF NlRTN = c_NOK THEN
            subChkZogen(c_NKAIKIHON);
        END IF;
        -- 計算TBLの増減判定(支援基本)
        IF NlRTN = c_NOK THEN
            subChkZogen(c_NSIENKIHON);
        END IF;
        --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
        -- 計算TBLの増減判定(子ども)
        IF NlRTN = c_NOK THEN
            subChkZogen(c_NKDMKIHON);
        END IF;
        --  2025/08/11 ZCZL.HAODAPENG ADD END
        -- 計算基本生成
        IF NlRTN = c_NOK THEN
            subCreateCal(c_NKIHON);
        END IF;
        -- 計算退職生成
        IF NlRTN = c_NOK THEN
            subCreateCal(c_NTAI);
        END IF;
        -- 計算介護基本生成
        IF NlRTN = c_NOK THEN
            subCreateCal(c_NKAIKIHON);
        END IF;
        -- 計算介護退職生成
        IF NlRTN = c_NOK THEN
            subCreateCal(c_NKAITAI);
        END IF;
        -- 計算支援基本生成
        IF NlRTN = c_NOK THEN
            subCreateCal(c_NSIENKIHON);
        END IF;
        -- 計算支援退職生成
        IF NlRTN = c_NOK THEN
            subCreateCal(c_NSIENTAI);
        END IF;
        --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
        -- 子ども
        IF NlRTN = c_NOK THEN
            subCreateCal(c_NKDMKIHON);
        END IF;
        --  2025/08/11 ZCZL.HAODAPENG ADD END

        -- 不足情報生成
        IF NlRTN = c_NOK THEN
            subMakeCal;
        END IF;

        -- 全体税額＜退職税額対応
        IF NlRTN = c_NOK THEN
            subUpdTai;
        END IF;
        -- 不要情報削除
        IF NlRTN = c_NOK THEN
            subDeleteCal;
        END IF;

    END subMain;
-------------------------------------------------------------------------------
--  01 システム条件取得
--      システム条件より医療･介護賦課額端数を取得→端数金額に変換する
-------------------------------------------------------------------------------
    PROCEDURE subJokenSel IS

        NwHASU_IRY          NUMBER;     -- 医療賦課額端数
        NwHASU_KAI          NUMBER;     -- 介護賦課額端数
        NwHASU_SIEN         NUMBER;     --支援賦課額端数
        NwFUKI_KAZEI        NUMBER;     -- 不均一課税
        --  2025/08/11 ZCZL.HAODAPENG ADD 1.1.200.000:子ども子育て支援金対応
        NwHASU_KDM          NUMBER;     --子ども端数区分用変数定義

    BEGIN
        -- システム条件より不均一課税を取得(合併後算定団体)
        SELECT HASU_IRY,        -- 医療賦課額端数
               HASU_KAI,        -- 介護賦課額端数
               GENDOGAKU_IRY,   -- 医療賦課限度額
               GENDOGAKU_KAI,   -- 介護賦課限度額
               HASU_SIEN,       -- 支援賦課額端数
               GENDOGAKU_SIEN,  -- 支援賦課限度額
               --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
               HASU_KDM,        -- 子ども賦課額端数
               GENDOGAKU_KDM,   -- 子ども賦課限度額
               --  2025/08/11 ZCZL.HAODAPENG ADD END
               FUKI_KAZEI       -- 不均一課税
          INTO NwHASU_IRY,
               NwHASU_KAI,
               NlGENDOGAKU_IRY,
               NlGENDOGAKU_KAI,
               NwHASU_SIEN,
               NlGENDOGAKU_SIEN,
               --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
               NwHASU_KDM,
               NlGENDOGAKU_KDM,
               --  2025/08/11 ZCZL.HAODAPENG ADD END
               NwFUKI_KAZEI
          FROM ZLBTJOKEN
         WHERE NENDO           = i_NNENDO_BUN
           AND SANTEIDANTAI_CD = c_NDANTAI;

        -- 不均一課税の場合、指定された算定団体コードで端数を取得しなおす
        IF NwFUKI_KAZEI = c_NFKAZEI THEN        -- 不均一課税を行なう
            SELECT HASU_IRY,        -- 医療賦課額端数
                   HASU_KAI,        -- 介護賦課額端数
                   GENDOGAKU_IRY,   -- 医療賦課限度額
                   GENDOGAKU_KAI,   -- 介護賦課限度額
                   HASU_SIEN,       -- 支援賦課額端数
                   GENDOGAKU_SIEN   -- 支援賦課限度額
                   --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
                   ,HASU_KDM        -- 子ども賦課額端数
                   ,GENDOGAKU_KDM   -- 子ども賦課限度額
                   --  2025/08/11 ZCZL.HAODAPENG ADD END
              INTO NwHASU_IRY,
                   NwHASU_KAI,
                   NlGENDOGAKU_IRY,
                   NlGENDOGAKU_KAI,
                   NwHASU_SIEN,
                   NlGENDOGAKU_SIEN
                   --  2025/08/11 ZCZL.HAODAPENG ADD START 1.1.200.000:子ども子育て支援金対応
                   ,NwHASU_KDM
                   ,NlGENDOGAKU_KDM
                   --  2025/08/11 ZCZL.HAODAPENG ADD END
              FROM ZLBTJOKEN
             WHERE NENDO           = i_NNENDO_BUN
               AND SANTEIDANTAI_CD = i_NDANTAI;
        END IF;

        -- 区分より金額に変換
        NlHASU_IRY := funcGetHasu(NwHASU_IRY);      -- 10 端数金額取得処理(医療)
        NlHASU_KAI := funcGetHasu(NwHASU_KAI);      -- 10 端数金額取得処理(介護)
        NlHASU_SIEN := funcGetHasu(NwHASU_SIEN);    -- 10 端数金額取得処理(支援)
        --  2025/08/11 ZCZL.HAODAPENG ADD 1.1.200.000:子ども子育て支援金対応
        NlHASU_KDM := funcGetHasu(NwHASU_KDM);      --子ども端数金額の取得

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subJokenSel システム条件取得' ||
                     '(国保世帯番号=' || i_NSETAI ||
                     ')' || SQLERRM;
    END subJokenSel;
-------------------------------------------------------------------------------
--  00 メイン
-------------------------------------------------------------------------------
BEGIN


----- 初期処理 -----
    NlRTN := c_NOK;
    VlMSG := NULL;

----------------------------------------------------------------------
-- ZLBTGENMEN_KOJIN テーブルの存在チェック
----------------------------------------------------------------------
    NlCNT  := 0;
    NlCNT := 1;
    NlDATE := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));
    NlTIME := TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MIDD'));

    -- システム条件を取得し医療/介護賦課端数金額を算出
    subJokenSel;

----- 主処理 -----
    -- 税額を判断し計算基本･退職･介護基本･介護退職を生成する
    IF NlRTN = c_NOK THEN
        subMain;
    END IF;

----- 終了処理 -----
    IF NlRTN = c_NOK THEN
        BEGIN
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'COMMIT発行(国保世帯番号=' || i_NSETAI || ')' || SQLERRM;
        END;
    END IF;

    IF NlRTN != c_NOK THEN
        BEGIN
            ROLLBACK;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
    END IF;

-- エラーログ
    IF NlRTN != c_NOK AND VlMSG IS NOT NULL THEN
        IF i_NJIKKOU_KBN = c_NBATCH THEN

            -- バッチ起動時(ﾛｸﾞTBL出力)
            BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSKCALMAINP', 1, '', '','ZLBSKCALMAINP ' || VlMSG, i_NSYS_SHOKUIN, i_VTANMATSU);
        ELSIF i_NTRENBAN = -1 THEN

            -- オンライン起動時(テストの時のみ)
            DBMS_OUTPUT.PUT_LINE('ZLBSKCALMAINP ' || VlMSG);

        END IF;

    END IF;

    o_NRESULT := NlRTN;

END ZLBSKCALMAINP;
/