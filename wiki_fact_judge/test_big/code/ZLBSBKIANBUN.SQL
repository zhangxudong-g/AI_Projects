CREATE OR REPLACE PROCEDURE ZLBSBKIANBUN(I_NSYORI_KBN          IN  NUMBER,
--1.1.200.000
                                        I_NKIJUNBI            IN  NUMBER,
                                        I_NTSUCHI_NO          IN  NUMBER,
                                        I_NDANTAI             IN  NUMBER,
                                        I_NSETAI              IN  NUMBER,
                                        I_NJIKKOU_KBN         IN  NUMBER,
                                        I_VTANMATSU           IN  NVARCHAR2,
                                        I_NTRENBAN            IN  NUMBER,
                                        O_NRESULT             OUT NUMBER,
                                        I_NCHOTEI_NENDO       IN  NUMBER := 0,
                                        I_NNENDO_BUN          IN  NUMBER := 0)
-------------------------------------------------------------------------------
-- 業務名   ZLB（国民健康保険税）
-- ＰＧ名   ZLBSBKIANBUN
-- 名称     計算期別内訳作成
-- 処理概要 各期別の内訳(医療全体税額,医療退職税額,介護全体税額,介護退職税額)
--          を算出して計算期別を更新する。
--          税額試算の場合退職税額を除く。
-- 引き数   I_NSYORI_KBN            処理区分(0:全期按分,1:差額按分)
--          I_NKIJUNBI              基準日
--          I_NTSUCHI_NO            通知書番号
--          I_NDANTAI               算定団体コード
--          I_NSETAI                国保世帯番号（ログ出力用）
--          I_NJIKKOU_KBN           実行区分(0:バッチから起動 本算定/月例/仮算定/過年度
--                                           1:オンライン起動 即時課税計算/期割
--                                           2:オンライン起動 税額試算)
--          I_VTANMATSU             端末番号
--          I_NTRENBAN              登録連番
--          O_NRESULT               処理結果
--  作成者       ZCZL.LIUCHENYU
--  作成日       2023/08/03
--  Version      0.2.000.000
-------------------------------------------------------------------------------------
--変更履歴
--2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
--2025/05/20 jcbc.zei UPDATE ZLB_1.0.304.000：QA14706の対応 
--2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
------------------------------------------------------------------------------
IS
    TYPE MTZEIGAKUR2  IS RECORD (               -- 税額レコード2
                ZENZEI      NUMBER(10) DEFAULT 0,   -- 全体税額
                TAIZEI      NUMBER(10) DEFAULT 0,   -- 退職税額
                IRY_ZENZEI  NUMBER(10) DEFAULT 0,   -- 医療全体税額
                IRY_TAIZEI  NUMBER(10) DEFAULT 0,   -- 医療退職税額
                KAI_ZENZEI  NUMBER(10) DEFAULT 0,   -- 介護全体税額
                KAI_TAIZEI  NUMBER(10) DEFAULT 0,   -- 介護退職税額
                SIEN_ZENZEI NUMBER(10) DEFAULT 0,   -- 支援全体税額 
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
                KDM_ZENZEI  NUMBER(10) DEFAULT 0,   -- 子ども全体税額
--  2025/08/11 ZCZL.WANGMINGYANG END
                SIEN_TAIZEI NUMBER(10) DEFAULT 0);  -- 支援退職税額

    TYPE MTKIBETSUR   IS RECORD (               -- 期別レコード
                BKIBETSU    NUMBER(2)  DEFAULT 0,   -- 物理期別
                RKIBETSU    NUMBER(2)  DEFAULT 0);  -- 論理期別
    TYPE MTKIBETSU    IS TABLE OF MTKIBETSUR  INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY4  IS TABLE OF NUMBER(4)   INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY10 IS TABLE OF NUMBER(10)  INDEX BY BINARY_INTEGER;
-------------------------------------------------------------------------------
-- 定数の定義
-------------------------------------------------------------------------------
    C_NOK               CONSTANT NUMBER(1) := 0;   -- 処理正常
    C_NERR              CONSTANT NUMBER(1) := 1;   -- 処理異常
    -- 処理区分
    C_NSYORI_ZENKI      CONSTANT NUMBER(1) := 0;    -- 全期按分
    C_NSYORI_SABUN      CONSTANT NUMBER(1) := 1;    -- 差額按分
    -- 主処理区分
    C_NSHU_ZEN          CONSTANT NUMBER(1) := 0;    -- 全体処理
    C_NSHU_TAI          CONSTANT NUMBER(1) := 1;    -- 退職処理
    -- 科目コード
    C_NKAMOKU_BASE      CONSTANT NUMBER(3) := 15;   -- 科目コード(作成元)
    C_NKAMOKU_NEW       CONSTANT NUMBER(3) := 0;    -- 科目コード(新規分)
    -- 科目詳細コード
    C_NKAMOKUS_FUTU     CONSTANT NUMBER(2)  := 1;   -- 科目詳細コード：普通
    C_NKAMOKUS_TOKU     CONSTANT NUMBER(2)  := 2;   -- 科目詳細コード：特徴
    -- 実行区分
    C_NBATCH            CONSTANT NUMBER(1) := 0;    -- バッチ(本算定/月例/仮算定/過年度)
    C_NONLINE           CONSTANT NUMBER(1) := 1;    -- オンライン(即時/期割)
    C_NTEST             CONSTANT NUMBER(1) := 2;    -- オンライン(税額試算)
    -- 端数
    c_NHASU_1           CONSTANT NUMBER := -3;
    c_NHASU_2           CONSTANT NUMBER := -2;
    c_NHASU_3           CONSTANT NUMBER := 0;
    c_NHASU_10          CONSTANT NUMBER := -1;
    c_NHASU_KBN_1       CONSTANT NUMBER := 0;       -- c_NHASU_1に対応
    c_NHASU_KBN_2       CONSTANT NUMBER := 1;       -- c_NHASU_2に対応
    c_NHASU_KBN_3       CONSTANT NUMBER := 2;       -- c_NHASU_3に対応
    c_NHASU_KBN_10      CONSTANT NUMBER := 3;       -- c_NHASU_10に対応
-------------------------------------------------------------------------------
-- 変数の定義
-------------------------------------------------------------------------------
    NLRTN               NUMBER;
    BLRTN               BOOLEAN;
    VLMSG               NVARCHAR2(100);
    NLIRY_ABTAI_ZEI     NUMBER(10);     -- 按分対象 医療対象税額
    NLKAI_ABTAI_ZEI     NUMBER(10);     --          介護対象税額
    NLIRY_ABGAI_ZEI     NUMBER(10);     -- 按分対象外 医療対象外税額
    NLKAI_ABGAI_ZEI     NUMBER(10);     --            介護対象外税額
    NLFUKA_IRY_ZEI      NUMBER(10);     -- 賦課期別 医療税額
    NLFUKA_KAI_ZEI      NUMBER(10);     --          介護税額
    NLFUKA_ZEN_ZEI      NUMBER(10);     --          全体税額
    NLFUKA_TAI_ZEI      NUMBER(10);     --          退職税額
    NLIRY_ZEN_NENZEI    NUMBER(10);     -- 計算基本     医療全体年税額
    NLIRY_TAI_NENZEI    NUMBER(10);     -- 計算退職     医療退職年税額
    NLKAI_ZEN_NENZEI    NUMBER(10);     -- 計算介護基本 介護全体年税額
    NLKAI_TAI_NENZEI    NUMBER(10);     -- 計算介護退職 介護退職年税額
    MLZENZEI            MTNUMARRAY10;   -- 計算期別     全体税額
    NLFUKA_IRY_ZENZEI   NUMBER(10);     -- 賦課基本     医療全体年税額
    NLFUKA_IRY_TAIZEI   NUMBER(10);     -- 賦課退職     医療退職年税額
    NLFUKA_KAI_ZENZEI   NUMBER(10);     -- 賦課介護基本 介護全体年税額
    NLFUKA_KAI_TAIZEI   NUMBER(10);     -- 賦課介護退職 介護退職年税額
    MLRONRIKIBETSU      MTNUMARRAY4;    -- 按分 論理期別
    MLKAMOKUSHOSAI      MTNUMARRAY4;    --科目詳細
    MLZEIGAKU           MTNUMARRAY10;   --      税額
    MLIRY_ZEIGAKU       MTNUMARRAY10;   --      医療税額
    MLKAI_ZEIGAKU       MTNUMARRAY10;   --      介護税額
    NLSYORI_KBN         NUMBER(1);      -- 処理区分
    NLCHOTEI_NENDO      NUMBER;         --調定年度
    NLNENDO_BUN         NUMBER;         --年度分
    IZAN_MODE           PLS_INTEGER;    -- 0:通常 1:仮算定中
    NZEN_ZEIGAKU_TOKU   NUMBER(12) := 0;  -- 特徴期割税額合計
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
    NLKDM_ABTAI_ZEI      NUMBER(10);    -- 按分対象 子ども対象
    NLKDM_ABGAI_ZEI      NUMBER(10);    -- 按分対象外 子ども対象
    NLKDM_ZEN_NENZEI     NUMBER(10);    -- 計算子ども基本 子ども
    NLFUKA_KDM_ZENZEI    NUMBER(10);    -- 賦課子ども基本 子ども
    MLKDM_ZEIGAKU        MTNUMARRAY10;  -- 按分     子ども税額
    NLFUKA_KDM_ZEI       NUMBER(10);    -- 計算期別子ども全体税額
--  2025/08/11 ZCZL.WANGMINGYANG ADD END 
    NLSIEN_ABTAI_ZEI     NUMBER(10);    -- 按分対象 支援対象税額
    NLSIEN_ABGAI_ZEI     NUMBER(10);    -- 按分対象外 支援対象外税額
    NLSIEN_ZEN_NENZEI    NUMBER(10);    -- 計算支援基本 支援全体年税額
    NLSIEN_TAI_NENZEI    NUMBER(10);    -- 計算支援退職 支援退職年税額
    NLFUKA_SIEN_ZENZEI   NUMBER(10);    -- 賦課支援基本 支援全体年税額
    NLFUKA_SIEN_TAIZEI   NUMBER(10);    -- 賦課支援退職 支援退職年税額
    MLSIEN_ZEIGAKU       MTNUMARRAY10;  -- 按分     支援税額
    NLFUKA_SIEN_ZEI      NUMBER(10);    --          介護税額
    MLSIENZENZEI         MTNUMARRAY10;  -- 計算期別 支援税額
    NlMAINASU_CNT        NUMBER;        --マイナス期別カウント用

    IZANTEIKIWAI_JCONS      PLS_INTEGER := 0;
    IZANTEIKIWARI_FLG       PLS_INTEGER := 0;
    IHON_GENZON_CNT         PLS_INTEGER := 0;
-------------------------------------------------------------------------------
-- カーソルの定義
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- 09 再期割処理
--  手順① 過ぎた期別の税額を算出、全体税額より差し引く
--      ② 介護の退職分の期別税額を算出
--      ③ 医療の退職分の期別税額を算出
--      ④ 介護の全体分の期別税額を算出
--      ⑤ 医療の全体分の期別税額を算出
-------------------------------------------------------------------------------
    PROCEDURE SUBSAIKIWARISUB(I_MWNENZEI        IN  MTZEIGAKUR2,
                              I_NWSTRRKIBETSU   IN  NUMBER,
                              I_NWENDRKIBETSU   IN  NUMBER,
                              I_IDXRKIBETSU     IN  NUMBER := 0) IS  
        NWZEIGAKU       NUMBER(10) := 0;
        NWZEIGAKU2      NUMBER(10) := 0;
        NWYUKO_KIBETSU  NUMBER(2)  := 0;
        MWWNENZEI       MTZEIGAKUR2;
        NWZEIGAKU_KAI       NUMBER(10) := 0;   
        NWYUKO_KIBETSU_KAI  NUMBER(2)  := 0;   
        NWANBUNKIHONFLG     NUMBER(1)  := 0;   
        NWANBUNTAIFLG       NUMBER(1)  := 0;   
    BEGIN
----- 手順① 過ぎた期別の税額を算出、全体税額より差し引く
        BEGIN
            SELECT NVL(SUM(ZEN_ZEIGAKU),     0), NVL(SUM(TAI_ZEIGAKU),     0),
                   NVL(SUM(IR_ZEN_ZEIGAKU),  0), NVL(SUM(IR_TAI_ZEIGAKU),  0),
                   NVL(SUM(KAI_ZEN_ZEIGAKU), 0), NVL(SUM(KAI_TAI_ZEIGAKU), 0)
                   ,
                   NVL(SUM(SIEN_ZEN_ZEIGAKU), 0), NVL(SUM(SIEN_TAI_ZEIGAKU), 0)
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                   ,NVL(SUM(KDM_ZEN_ZEIGAKU),     0)
              INTO MWWNENZEI.ZENZEI,    MWWNENZEI.TAIZEI,
                   MWWNENZEI.IRY_ZENZEI,MWWNENZEI.IRY_TAIZEI,
                   MWWNENZEI.KAI_ZENZEI,MWWNENZEI.KAI_TAIZEI
                   ,
                   MWWNENZEI.SIEN_ZENZEI,MWWNENZEI.SIEN_TAIZEI
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                   ,MWWNENZEI.KDM_ZENZEI
              FROM ZLBTKIBETSU_CAL
              WHERE ((KAMOKU_CD     = C_NKAMOKU_NEW
                    AND KAMOKUS_CD  = C_NKAMOKUS_FUTU)
                  OR (KAMOKU_CD     = C_NKAMOKU_BASE
                    AND KAMOKUS_CD  = C_NKAMOKUS_TOKU))
               AND KOKU_SETAI_NO   = I_NSETAI       --国保世帯番号
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND CHOTEINENDO     = NLCHOTEI_NENDO 
               AND NENDOBUN        = NLNENDO_BUN    
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND RONRIKIBETSU    < I_NWSTRRKIBETSU
               AND SYS_TANMATSU_NO = I_VTANMATSU;
            MWWNENZEI.ZENZEI     := I_MWNENZEI.ZENZEI     - MWWNENZEI.ZENZEI;
            MWWNENZEI.TAIZEI     := I_MWNENZEI.TAIZEI     - MWWNENZEI.TAIZEI;
            MWWNENZEI.IRY_ZENZEI := I_MWNENZEI.IRY_ZENZEI - MWWNENZEI.IRY_ZENZEI;
            MWWNENZEI.IRY_TAIZEI := I_MWNENZEI.IRY_TAIZEI - MWWNENZEI.IRY_TAIZEI;
            MWWNENZEI.KAI_ZENZEI := I_MWNENZEI.KAI_ZENZEI - MWWNENZEI.KAI_ZENZEI;
            MWWNENZEI.KAI_TAIZEI := I_MWNENZEI.KAI_TAIZEI - MWWNENZEI.KAI_TAIZEI;
            MWWNENZEI.SIEN_ZENZEI := I_MWNENZEI.SIEN_ZENZEI - MWWNENZEI.SIEN_ZENZEI;
            MWWNENZEI.SIEN_TAIZEI := I_MWNENZEI.SIEN_TAIZEI - MWWNENZEI.SIEN_TAIZEI;
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
            MWWNENZEI.KDM_ZENZEI := I_MWNENZEI.KDM_ZENZEI - MWWNENZEI.KDM_ZENZEI;
        EXCEPTION
            WHEN OTHERS THEN
                NLRTN := C_NERR;
                VLMSG := 'SUBSAIKIWARISUB 過ぎた期別の税額取得(国保世帯番号='||
                         I_NSETAI||')'||SQLERRM;
                RETURN;
        END;
----- 手順② 介護の退職分の期別税額を算出
        IF MWWNENZEI.TAIZEI = 0 THEN
            BEGIN
                UPDATE ZLBTKIBETSU_CAL
                   SET IR_TAI_ZEIGAKU = 0, KAI_TAI_ZEIGAKU = 0
                       , SIEN_TAI_ZEIGAKU = 0             
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO    
                   AND NENDOBUN        = NLNENDO_BUN       
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 過ぎた期別の税額更新(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
        ELSE
            NWZEIGAKU  := 0;
            NWZEIGAKU2 := 0;
            BEGIN
                SELECT SUM(KAI_TAI_ZEIGAKU) INTO NWZEIGAKU
                  FROM ZLBTKIBETSU_CAL
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO    
                   AND NENDOBUN        = NLNENDO_BUN       
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU    = I_NWSTRRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 開始期別の介護退職税額取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            BEGIN
                SELECT SUM(KAI_TAI_ZEIGAKU) INTO NWZEIGAKU2
                  FROM ZLBTKIBETSU_CAL
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO    
                   AND NENDOBUN        = NLNENDO_BUN       
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU > I_NWSTRRKIBETSU AND RONRIKIBETSU <= I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 期別範囲の介護退職税額取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            IF NWZEIGAKU = MWWNENZEI.KAI_TAIZEI AND NWZEIGAKU2 = 0 THEN
                BEGIN
                    UPDATE ZLBTKIBETSU_CAL
                       SET KAI_TAI_ZEIGAKU = 0
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO    
                       AND NENDOBUN        = NLNENDO_BUN       
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARISUB 介護退職税額(0)更新(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
            ELSE
                -- 介護退職期別税額=退職税額に占める介護退職税額の割合*退職税額
                BEGIN
                    UPDATE ZLBTKIBETSU_CAL
                       SET KAI_TAI_ZEIGAKU = ROUND(
                                             (MWWNENZEI.KAI_TAIZEI / MWWNENZEI.TAIZEI) *
                                             TAI_ZEIGAKU)
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO    
                       AND NENDOBUN        = NLNENDO_BUN       
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARISUB 介護退職税額更新(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
                -- 支援退職期別税額を介護同様、退職税額に占める割合で算出させる
                NWANBUNTAIFLG := 1;   -- 退職按分フラグを立てる
            END IF;
            NWZEIGAKU  := 0;
            BEGIN
                -- 介護退職期別税額の合計と介護退職年税額を比較
                SELECT SUM(KAI_TAI_ZEIGAKU) INTO NWZEIGAKU FROM ZLBTKIBETSU_CAL
                  WHERE ((KAMOKU_CD     = C_NKAMOKU_NEW
                        AND KAMOKUS_CD  = C_NKAMOKUS_FUTU)
                      OR (KAMOKU_CD     = C_NKAMOKU_BASE
                        AND KAMOKUS_CD  = C_NKAMOKUS_TOKU))
                   AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO    
                   AND NENDOBUN        = NLNENDO_BUN       
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
                NWZEIGAKU := I_MWNENZEI.KAI_TAIZEI - NWZEIGAKU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 介護退職期別税額合計の取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            IF NWZEIGAKU != 0 THEN
                -- 比較後の不一致税額をセットする論理期別を求める
                BEGIN
                    SELECT MIN(RONRIKIBETSU) INTO NWYUKO_KIBETSU
                      FROM ZLBTKIBETSU_CAL
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO    
                       AND NENDOBUN        = NLNENDO_BUN       
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU   >= I_NWSTRRKIBETSU
                       AND TAI_ZEIGAKU     > 0
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARISUB 不一致分加算(介護退職)開始論理期別取得(国保世帯番号='||I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
                -- 比較後の不一致税額を開始論理期別へ加算する
                BEGIN
                    UPDATE ZLBTKIBETSU_CAL
                       SET KAI_TAI_ZEIGAKU = KAI_TAI_ZEIGAKU + NWZEIGAKU
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO    
                       AND NENDOBUN        = NLNENDO_BUN       
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU    = NWYUKO_KIBETSU
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARISUB 不一致分加算(介護退職)の更新(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
            END IF;
----- 手順②-1 支援の退職分の期別税額を算出
            NWZEIGAKU  := 0;
            NWZEIGAKU2 := 0;
            BEGIN
                SELECT SUM(SIEN_TAI_ZEIGAKU) INTO NWZEIGAKU
                  FROM ZLBTKIBETSU_CAL
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO
                   AND NENDOBUN        = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU    = I_NWSTRRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 開始期別の支援退職税額取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            BEGIN
                SELECT SUM(SIEN_TAI_ZEIGAKU) INTO NWZEIGAKU2
                  FROM ZLBTKIBETSU_CAL
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO
                   AND NENDOBUN        = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU > I_NWSTRRKIBETSU AND RONRIKIBETSU <= I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 期別範囲の支援退職税額取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;

-- 介護按分処理を行った後は支援も按分処理を行う
            IF NWANBUNTAIFLG = 0 AND
               (NWZEIGAKU = MWWNENZEI.SIEN_TAIZEI AND NWZEIGAKU2 = 0) THEN
                BEGIN
                    UPDATE ZLBTKIBETSU_CAL
                       SET SIEN_TAI_ZEIGAKU = 0
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO
                       AND NENDOBUN        = NLNENDO_BUN
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARISUB 支援退職税額(0)更新(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
            ELSE

                -- 支援退職期別税額=退職税額に占める支援退職税額の割合*退職税額
                BEGIN
                    UPDATE ZLBTKIBETSU_CAL
                       SET SIEN_TAI_ZEIGAKU = ROUND(
                                             (MWWNENZEI.SIEN_TAIZEI / MWWNENZEI.TAIZEI) *
                                             TAI_ZEIGAKU)
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO
                       AND NENDOBUN        = NLNENDO_BUN
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARISUB 支援退職税額更新(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
            END IF;
            NWZEIGAKU  := 0;
            BEGIN
                -- 支援退職期別税額の合計と支援退職年税額を比較
                SELECT SUM(SIEN_TAI_ZEIGAKU) INTO NWZEIGAKU FROM ZLBTKIBETSU_CAL
                  WHERE ((KAMOKU_CD     = C_NKAMOKU_NEW
                        AND KAMOKUS_CD  = C_NKAMOKUS_FUTU)
                      OR (KAMOKU_CD     = C_NKAMOKU_BASE
                        AND KAMOKUS_CD  = C_NKAMOKUS_TOKU))
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO
                   AND NENDOBUN        = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
                NWZEIGAKU := I_MWNENZEI.SIEN_TAIZEI - NWZEIGAKU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 支援退職期別税額合計の取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            IF NWZEIGAKU != 0 THEN
                -- 比較後の不一致税額をセットする論理期別を求める
                BEGIN
                    SELECT MIN(RONRIKIBETSU) INTO NWYUKO_KIBETSU
                      FROM ZLBTKIBETSU_CAL
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO
                       AND NENDOBUN        = NLNENDO_BUN
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU   >= I_NWSTRRKIBETSU
                       AND TAI_ZEIGAKU     > 0
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARISUB 不一致分加算(支援退職)開始論理期別取得(国保世帯番号='||I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;

                -- 比較後の不一致税額を開始論理期別へ加算する
                BEGIN
                    UPDATE ZLBTKIBETSU_CAL
                       SET SIEN_TAI_ZEIGAKU = SIEN_TAI_ZEIGAKU + NWZEIGAKU
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO
                       AND NENDOBUN        = NLNENDO_BUN
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU    = NWYUKO_KIBETSU
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARISUB 不一致分加算(支援退職)の更新(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
            END IF;
        END IF;
----- 手順③ 医療の退職分の期別税額を算出
        BEGIN
            UPDATE ZLBTKIBETSU_CAL
               SET IR_TAI_ZEIGAKU = TAI_ZEIGAKU - KAI_TAI_ZEIGAKU - SIEN_TAI_ZEIGAKU
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND CHOTEINENDO     = NLCHOTEI_NENDO    
               AND NENDOBUN        = NLNENDO_BUN       
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        EXCEPTION
            WHEN OTHERS THEN
                NLRTN := C_NERR;
                VLMSG := 'SUBSAIKIWARISUB 医療退職税額の更新(国保世帯番号='||
                         I_NSETAI||')'||SQLERRM;
                RETURN;
        END;
----- 手順④ 介護の全体分の期別税額を算出
        IF MWWNENZEI.KAI_ZENZEI = 0 THEN
            BEGIN
                UPDATE ZLBTKIBETSU_CAL
                   SET KAI_ZEN_ZEIGAKU = 0
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO = NLCHOTEI_NENDO 
                   AND NENDOBUN = NLNENDO_BUN       
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 介護全体税額(0)の更新(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
        ELSIF MWWNENZEI.KAI_ZENZEI = MWWNENZEI.KAI_TAIZEI THEN
            -- 介護全体額と介護退職額が同じならば介護退職額にあわせる
            -- (同じ額でも按分すると期別で金額が異なることを防ぐ)
            BEGIN
              IF I_NWSTRRKIBETSU = I_IDXRKIBETSU THEN
                -- 論理期別が1期になったときだけ介護全体税額に合わせる。
                UPDATE ZLBTKIBETSU_CAL
                   SET KAI_TAI_ZEIGAKU = KAI_ZEN_ZEIGAKU
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO    
                   AND NENDOBUN        = NLNENDO_BUN       
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
              ELSE
                UPDATE ZLBTKIBETSU_CAL
                   SET KAI_ZEN_ZEIGAKU = KAI_TAI_ZEIGAKU
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO    
                   AND NENDOBUN        = NLNENDO_BUN       
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
              END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 介護全体税額(介護退職額)の更新(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
        ELSE
            -- 医療と介護で還付が発生する場合、どちらかだけ期別をさかのぼりすぎて
            -- さかのぼってあまった期から、年度末期別まで按分するのでさかのぼった
            -- 方が少ない金額で按分されるのを防ぐ・・・説明不足で意味が分からないと思いますが。。。
            NWZEIGAKU  := 0;
            NWZEIGAKU2 := 0;
            BEGIN
                SELECT SUM(KAI_ZEN_ZEIGAKU) INTO NWZEIGAKU
                  FROM ZLBTKIBETSU_CAL
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO    
                   AND NENDOBUN        = NLNENDO_BUN       
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU    = I_NWSTRRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 開始期別の介護税額取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            BEGIN
                SELECT SUM(KAI_ZEN_ZEIGAKU) INTO NWZEIGAKU2
                  FROM ZLBTKIBETSU_CAL
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO    
                   AND NENDOBUN        = NLNENDO_BUN       
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU > I_NWSTRRKIBETSU AND RONRIKIBETSU <= I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 期別範囲の介護税額取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            IF MWWNENZEI.ZENZEI = 0 OR
               (NWZEIGAKU = MWWNENZEI.KAI_ZENZEI AND NWZEIGAKU2 = 0) THEN
                BEGIN
                    UPDATE ZLBTKIBETSU_CAL
                       SET KAI_ZEN_ZEIGAKU = 0
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO    
                       AND NENDOBUN        = NLNENDO_BUN       
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARISUB 介護税額(0)更新(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
            ELSE
                -- 介護全体期別税額=全体税額に占める介護全体期別の割合*全体税額
                BEGIN
                    UPDATE ZLBTKIBETSU_CAL
                       SET KAI_ZEN_ZEIGAKU = ROUND(
                                             (MWWNENZEI.KAI_ZENZEI / MWWNENZEI.ZENZEI) *
                                             ZEN_ZEIGAKU)
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO    
                       AND NENDOBUN        = NLNENDO_BUN       
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARISUB 介護税額更新(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
                -- 支援全体期別税額を介護同様、全体税額に占める割合で算出させる
                NWANBUNKIHONFLG := 1;   -- 基本按分フラグを立てる
            END IF;
            NWZEIGAKU := 0;
            -- 介護全体期別税額の合計と介護全体年税額を比較
            BEGIN
                SELECT SUM(KAI_ZEN_ZEIGAKU) INTO NWZEIGAKU
                  FROM ZLBTKIBETSU_CAL
                  WHERE ((KAMOKU_CD     = C_NKAMOKU_NEW
                        AND KAMOKUS_CD  = C_NKAMOKUS_FUTU)
                      OR (KAMOKU_CD     = C_NKAMOKU_BASE
                        AND KAMOKUS_CD  = C_NKAMOKUS_TOKU))
                   AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO    
                   AND NENDOBUN        = NLNENDO_BUN       
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
                NWZEIGAKU := I_MWNENZEI.KAI_ZENZEI - NWZEIGAKU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 介護税額取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            IF NWZEIGAKU != 0 THEN
                -- 比較後の不一致税額を開始論理期別へ加算する
                BEGIN
                    SELECT MIN(RONRIKIBETSU) INTO NWYUKO_KIBETSU
                      FROM ZLBTKIBETSU_CAL
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO    
                       AND NENDOBUN        = NLNENDO_BUN       
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU   >= I_NWSTRRKIBETSU
                       AND ZEN_ZEIGAKU     > 0
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARISUB 開始論理期別取得(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
                IF NWYUKO_KIBETSU IS NULL THEN
                  BEGIN
                    SELECT MAX(RONRIKIBETSU) INTO NWYUKO_KIBETSU
                        FROM ZLBTKIBETSU_CAL
                       WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                         AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                         AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                         AND SANTEIDANTAI_CD = I_NDANTAI
                         AND CHOTEINENDO     = NLCHOTEI_NENDO    
                         AND NENDOBUN        = NLNENDO_BUN       
                         AND TSUCHI_NO       = I_NTSUCHI_NO
                         AND RONRIKIBETSU   <= I_NWSTRRKIBETSU
                       AND ZEN_ZEIGAKU     > 0
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                  EXCEPTION
                      WHEN OTHERS THEN
                          NLRTN := C_NERR;
                          VLMSG := 'SUBSAIKIWARISUB 開始論理期別取得(国保世帯番号='||
                                   I_NSETAI||')'||SQLERRM;
                          RETURN;
                  END;
                END IF;
                BEGIN
                    UPDATE ZLBTKIBETSU_CAL
                       SET KAI_ZEN_ZEIGAKU = KAI_ZEN_ZEIGAKU + NWZEIGAKU
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO    
                       AND NENDOBUN        = NLNENDO_BUN       
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU    = NWYUKO_KIBETSU
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARISUB 不一致分加算(介護全体)の更新(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
                -- 期と差額を退避
                NWZEIGAKU_KAI := NWZEIGAKU;
                NWYUKO_KIBETSU_KAI := NWYUKO_KIBETSU;
            END IF;
        END IF;
----- 手順④-1 支援の全体分の期別税額を算出
        IF MWWNENZEI.SIEN_ZENZEI = 0 THEN
            BEGIN
                UPDATE ZLBTKIBETSU_CAL
                   SET SIEN_ZEN_ZEIGAKU = 0
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO = NLCHOTEI_NENDO
                   AND NENDOBUN = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 支援全体税額(0)の更新(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
        ELSIF MWWNENZEI.SIEN_ZENZEI = MWWNENZEI.SIEN_TAIZEI THEN
            -- 支援全体額と支援退職額が同じならば支援退職額にあわせる
            -- (同じ額でも按分すると期別で金額が異なることを防ぐ)
            BEGIN
              IF I_NWSTRRKIBETSU = I_IDXRKIBETSU THEN

                -- 論理期別が1期になったときだけ介護全体税額に合わせる。
                UPDATE ZLBTKIBETSU_CAL
                   SET SIEN_TAI_ZEIGAKU = SIEN_ZEN_ZEIGAKU
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO
                   AND NENDOBUN        = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
              ELSE

                UPDATE ZLBTKIBETSU_CAL
                   SET SIEN_ZEN_ZEIGAKU = SIEN_TAI_ZEIGAKU
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO
                   AND NENDOBUN        = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
              END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 支援全体税額(支援退職額)の更新(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
        ELSE
            -- 医療と支援で還付が発生する場合、どちらかだけ期別をさかのぼりすぎて
            -- さかのぼってあまった期から、年度末期別まで按分するのでさかのぼった
            -- 方が少ない金額で按分されるのを防ぐ・・・説明不足で意味が分からないと思いますが。。。
            NWZEIGAKU  := 0;
            NWZEIGAKU2 := 0;
            BEGIN
                SELECT SUM(SIEN_ZEN_ZEIGAKU) INTO NWZEIGAKU
                  FROM ZLBTKIBETSU_CAL
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO
                   AND NENDOBUN        = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU    = I_NWSTRRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 開始期別の支援税額取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            BEGIN
                SELECT SUM(SIEN_ZEN_ZEIGAKU) INTO NWZEIGAKU2
                  FROM ZLBTKIBETSU_CAL
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO
                   AND NENDOBUN        = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU > I_NWSTRRKIBETSU AND RONRIKIBETSU <= I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 期別範囲の支援税額取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
-- 介護按分処理を行った後は支援も按分処理を行う
            IF NWANBUNKIHONFLG = 0 AND
               (MWWNENZEI.ZENZEI = 0 OR
               (NWZEIGAKU = MWWNENZEI.SIEN_ZENZEI AND NWZEIGAKU2 = 0)) THEN

                BEGIN
                    UPDATE ZLBTKIBETSU_CAL
                       SET SIEN_ZEN_ZEIGAKU = 0
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO
                       AND NENDOBUN        = NLNENDO_BUN
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARISUB 支援税額(0)更新(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
            ELSE

                -- 支援全体期別税額=全体税額に占める支援全体期別の割合*全体税額
                BEGIN
                    UPDATE ZLBTKIBETSU_CAL
                       SET SIEN_ZEN_ZEIGAKU = ROUND(
                                             (MWWNENZEI.SIEN_ZENZEI / MWWNENZEI.ZENZEI) *
                                             ZEN_ZEIGAKU)
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO
                       AND NENDOBUN        = NLNENDO_BUN
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARISUB 支援税額更新(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
            END IF;
            NWZEIGAKU := 0;
            -- 支援全体期別税額の合計と支援全体年税額を比較
            BEGIN
                SELECT SUM(SIEN_ZEN_ZEIGAKU) INTO NWZEIGAKU
                  FROM ZLBTKIBETSU_CAL
                  WHERE ((KAMOKU_CD     = C_NKAMOKU_NEW
                        AND KAMOKUS_CD  = C_NKAMOKUS_FUTU)
                      OR (KAMOKU_CD     = C_NKAMOKU_BASE
                        AND KAMOKUS_CD  = C_NKAMOKUS_TOKU))
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO
                   AND NENDOBUN        = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
                NWZEIGAKU := I_MWNENZEI.SIEN_ZENZEI - NWZEIGAKU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 支援税額取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            IF NWZEIGAKU != 0 THEN
                -- 比較後の不一致税額を開始論理期別へ加算する
                BEGIN
                    SELECT MIN(RONRIKIBETSU) INTO NWYUKO_KIBETSU
                      FROM ZLBTKIBETSU_CAL
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO
                       AND NENDOBUN        = NLNENDO_BUN
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU   >= I_NWSTRRKIBETSU
                       AND ZEN_ZEIGAKU     > 0
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARISUB 開始論理期別取得(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
                IF NWYUKO_KIBETSU IS NULL THEN
                  BEGIN
                    SELECT MAX(RONRIKIBETSU) INTO NWYUKO_KIBETSU
                        FROM ZLBTKIBETSU_CAL
                       WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                         AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                         AND KOKU_SETAI_NO   = I_NSETAI
                         AND SANTEIDANTAI_CD = I_NDANTAI
                         AND CHOTEINENDO     = NLCHOTEI_NENDO
                         AND NENDOBUN        = NLNENDO_BUN
                         AND TSUCHI_NO       = I_NTSUCHI_NO
                         AND RONRIKIBETSU   <= I_NWSTRRKIBETSU
                       AND ZEN_ZEIGAKU     > 0
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                  EXCEPTION
                      WHEN OTHERS THEN
                          NLRTN := C_NERR;
                          VLMSG := 'SUBSAIKIWARISUB 開始論理期別取得(国保世帯番号='||
                                   I_NSETAI||')'||SQLERRM;
                          RETURN;
                  END;
                END IF;
                BEGIN

                    UPDATE ZLBTKIBETSU_CAL
                       SET SIEN_ZEN_ZEIGAKU = SIEN_ZEN_ZEIGAKU + NWZEIGAKU
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO
                       AND NENDOBUN        = NLNENDO_BUN
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU    = NWYUKO_KIBETSU
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARISUB 不一致分加算(支援全体)の更新(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
            END IF;
        END IF; 
        
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
----- 手順④-2 子どもの全体分の期別税額を算出        
        IF MWWNENZEI.KDM_ZENZEI = 0 THEN 
          -- 計算期別の更新
          BEGIN
                UPDATE ZLBTKIBETSU_CAL
                   SET KDM_ZEN_ZEIGAKU = 0
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO = NLCHOTEI_NENDO
                   AND NENDOBUN = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 子ども全体税額(0)の更新(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
        ELSE 
            --変数の初期値設定
            NWZEIGAKU  := 0;
            NWZEIGAKU2 := 0;
            -- 計算期別より開始期別の子ども全体税額を集計①
            BEGIN
                SELECT SUM(KDM_ZEN_ZEIGAKU) INTO NWZEIGAKU
                   FROM ZLBTKIBETSU_CAL
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO = NLCHOTEI_NENDO
                   AND NENDOBUN = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU    = I_NWSTRRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 開始期別の子ども税額取得(国保世帯番号='||
                              I_NSETAI||')'||SQLERRM;
                    RETURN;
            END; 
            -- 計算期別より期別範囲の子ども全体税額を集計②
            BEGIN
                SELECT SUM(KDM_ZEN_ZEIGAKU) INTO NWZEIGAKU2
                   FROM ZLBTKIBETSU_CAL
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO = NLCHOTEI_NENDO
                   AND NENDOBUN = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU > I_NWSTRRKIBETSU AND RONRIKIBETSU <= I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 期別範囲の子ども税額取得(国保世帯番号='||
                              I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            -- 介護按分処理を行った後は子どもも按分処理を行う
            IF NWANBUNKIHONFLG = 0 AND (MWWNENZEI.ZENZEI = 0 OR (NWZEIGAKU = MWWNENZEI.KDM_ZENZEI AND NWZEIGAKU2 = 0)) THEN
              -- 計算期別の更新
              BEGIN
                UPDATE ZLBTKIBETSU_CAL
                   SET KDM_ZEN_ZEIGAKU = 0
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO = NLCHOTEI_NENDO
                   AND NENDOBUN = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
               EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 子ども税額(0)更新(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
               END;
            ELSE
             -- 計算期別の更新(子ども全体期別税額=全体税額に占める子ども全体期別の割合*全体税額)
              BEGIN
                UPDATE ZLBTKIBETSU_CAL
                   SET KDM_ZEN_ZEIGAKU =  ROUND((MWWNENZEI.KDM_ZENZEI / MWWNENZEI.ZENZEI) * ZEN_ZEIGAKU)
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO = NLCHOTEI_NENDO
                   AND NENDOBUN = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
               EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 子ども税額更新(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
               END;
            END IF;
            -- 子 ども全体期別税額の合計と子ども全体年税額を比較
            BEGIN
                SELECT SUM(KDM_ZEN_ZEIGAKU) INTO NWZEIGAKU
                   FROM ZLBTKIBETSU_CAL
                 WHERE ((KAMOKU_CD     = C_NKAMOKU_NEW
                   AND KAMOKUS_CD  = C_NKAMOKUS_FUTU)
                   OR (KAMOKU_CD     = C_NKAMOKU_BASE
                   AND KAMOKUS_CD  = C_NKAMOKUS_TOKU))
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO
                   AND NENDOBUN        = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 子ども税額取得(国保世帯番号='||
                              I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            NWZEIGAKU := I_MWNENZEI.KDM_ZENZEI - NWZEIGAKU;
        
            IF NWZEIGAKU != 0 THEN
             -- 最小期別の取得
            BEGIN
                SELECT  MIN(RONRIKIBETSU) INTO NWYUKO_KIBETSU
                   FROM ZLBTKIBETSU_CAL
                 WHERE KAMOKU_CD     = C_NKAMOKU_NEW
                   AND KAMOKUS_CD  = C_NKAMOKUS_FUTU
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO
                   AND NENDOBUN        = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU   >= I_NWSTRRKIBETSU
                   AND ZEN_ZEIGAKU     > 0
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
                 IF NWYUKO_KIBETSU IS NULL THEN
                   BEGIN
                      SELECT  MAX(RONRIKIBETSU) INTO NWYUKO_KIBETSU
                         FROM ZLBTKIBETSU_CAL
                       WHERE KAMOKU_CD     = C_NKAMOKU_NEW
                         AND KAMOKUS_CD  = C_NKAMOKUS_FUTU
                         AND KOKU_SETAI_NO   = I_NSETAI
                         AND SANTEIDANTAI_CD = I_NDANTAI
                         AND CHOTEINENDO     = NLCHOTEI_NENDO
                         AND NENDOBUN        = NLNENDO_BUN
                         AND TSUCHI_NO       = I_NTSUCHI_NO
                         AND RONRIKIBETSU   <= I_NWSTRRKIBETSU
                         AND ZEN_ZEIGAKU     > 0
                         AND SYS_TANMATSU_NO = I_VTANMATSU;
                      EXCEPTION
                          WHEN OTHERS THEN
                              NLRTN := C_NERR;
                              VLMSG := 'SUBSAIKIWARISUB 開始論理期別取得(国保世帯番号='||
                                        I_NSETAI||')'||SQLERRM;
                              RETURN;
                      END;
                 END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 開始論理期別取得(国保世帯番号='||
                              I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            -- 計算期別の更新
            BEGIN
                UPDATE ZLBTKIBETSU_CAL
                   SET KDM_ZEN_ZEIGAKU = KDM_ZEN_ZEIGAKU + NWZEIGAKU
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO
                   AND NENDOBUN        = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU    = NWYUKO_KIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 不一致分加算(子ども全体)の更新(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            
            END IF;
        
        END IF;
--  2025/08/11 ZCZL.WANGMINGYANG ADD END

----- 手順⑤ 医療の全体分の期別税額を算出
        BEGIN
            UPDATE ZLBTKIBETSU_CAL
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--               SET IR_ZEN_ZEIGAKU = ZEN_ZEIGAKU - KAI_ZEN_ZEIGAKU - SIEN_ZEN_ZEIGAKU 
               SET IR_ZEN_ZEIGAKU = ZEN_ZEIGAKU - KAI_ZEN_ZEIGAKU - SIEN_ZEN_ZEIGAKU - KDM_ZEN_ZEIGAKU
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND CHOTEINENDO     = NLCHOTEI_NENDO    
               AND NENDOBUN        = NLNENDO_BUN       
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND RONRIKIBETSU BETWEEN 1 AND I_NWENDRKIBETSU
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        EXCEPTION
            WHEN OTHERS THEN
                NLRTN := C_NERR;
                VLMSG := 'SUBSAIKIWARISUB 医療全体税額の更新(国保世帯番号='||
                         I_NSETAI||')'||SQLERRM;
                RETURN;
        END;
        IF NWZEIGAKU != 0 THEN
            BEGIN
                UPDATE ZLBTKIBETSU_CAL
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--                   SET IR_ZEN_ZEIGAKU = ZEN_ZEIGAKU - KAI_ZEN_ZEIGAKU - SIEN_ZEN_ZEIGAKU 
                   SET IR_ZEN_ZEIGAKU = ZEN_ZEIGAKU - KAI_ZEN_ZEIGAKU - SIEN_ZEN_ZEIGAKU - KDM_ZEN_ZEIGAKU
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO 
                   AND NENDOBUN        = NLNENDO_BUN       
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU    = NWYUKO_KIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 医療全体税額の更新(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
        END IF;
        IF NWZEIGAKU_KAI != 0 THEN
            BEGIN
                UPDATE ZLBTKIBETSU_CAL
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--                   SET IR_ZEN_ZEIGAKU = ZEN_ZEIGAKU - KAI_ZEN_ZEIGAKU - SIEN_ZEN_ZEIGAKU
                    SET IR_ZEN_ZEIGAKU = ZEN_ZEIGAKU - KAI_ZEN_ZEIGAKU - SIEN_ZEN_ZEIGAKU - KDM_ZEN_ZEIGAKU
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU
                   AND KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO
                   AND NENDOBUN        = NLNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU    = NWYUKO_KIBETSU_KAI
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARISUB 介護全体税額の更新(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
        END IF;
    END SUBSAIKIWARISUB;
-------------------------------------------------------------------------------
-- 指定論理期別の１つ前の論理期別を求める 
-------------------------------------------------------------------------------
    FUNCTION FUNCRKIBETSU_MAE(I_MKIBETSU IN MTKIBETSU, I_KI_NO IN PLS_INTEGER) RETURN PLS_INTEGER IS
        IKIBETSU  PLS_INTEGER := 0;  --１つ前の論理期別がなければ０でＯＫ
    BEGIN
      BEGIN
        FOR IDX IN I_MKIBETSU.FIRST..I_MKIBETSU.LAST LOOP
          IF I_MKIBETSU(IDX).RKIBETSU = I_KI_NO THEN
            --指定期別を発見
            IF I_MKIBETSU.EXISTS(IDX - 1) THEN          --有効チェック
              IKIBETSU := I_MKIBETSU(IDX - 1).RKIBETSU; --１つ前の論理期別をセット
            END IF;
            EXIT;  --抜ける
          END IF;
        END LOOP;
      EXCEPTION
        WHEN OTHERS THEN
          NLRTN := C_NERR;
          VLMSG := 'FUNCRKIBETSU_MAE '||SQLERRM;
      END;
      RETURN (IKIBETSU);
    END FUNCRKIBETSU_MAE;
-------------------------------------------------------------------------------
-- 08 マイナス調整
-------------------------------------------------------------------------------
    PROCEDURE SUBCHOSEI(I_MWNENZEI      IN  MTZEIGAKUR2,
                        I_NWSTRRKIBETSU IN  NUMBER,
                        I_NWENDRKIBETSU IN  NUMBER,
                        I_MKIBETSU      IN  MTKIBETSU) IS  
        NWCNT               NUMBER := 0;
        NWKIBETSU           NUMBER := 0;
        MWWNENZEI           MTZEIGAKUR2;
        IWKIBETSU           PLS_INTEGER;  
        CURSOR CWKIBETSUD IS
            SELECT * FROM ZLBTKIBETSU_CAL
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND CHOTEINENDO     = NLCHOTEI_NENDO    
               AND NENDOBUN        = NLNENDO_BUN       
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND SYS_TANMATSU_NO = I_VTANMATSU
             ORDER BY RONRIKIBETSU DESC;
    BEGIN
        -- マイナス期割の存在チェック
        BEGIN
            SELECT COUNT(*) INTO NWCNT
              FROM ZLBTKIBETSU_CAL
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND CHOTEINENDO     = NLCHOTEI_NENDO    
               AND NENDOBUN        = NLNENDO_BUN       
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND (IR_ZEN_ZEIGAKU  < 0 OR IR_TAI_ZEIGAKU  < 0
                 OR KAI_ZEN_ZEIGAKU < 0 OR KAI_TAI_ZEIGAKU < 0
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--                 OR SIEN_ZEN_ZEIGAKU < 0 OR SIEN_TAI_ZEIGAKU < 0) 
                 OR SIEN_ZEN_ZEIGAKU < 0 OR SIEN_TAI_ZEIGAKU < 0
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                 OR KDM_ZEN_ZEIGAKU < 0)
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        EXCEPTION
            WHEN OTHERS THEN
                NLRTN := C_NERR;
                VLMSG := 'SUBCHOSEI マイナス期割の存在チェック(国保世帯番号='||
                         I_NSETAI||')'||SQLERRM;
                RETURN;
        END;
        IF NWCNT > 0 THEN
            -- マイナス期割額を集計
            BEGIN
                SELECT SUM(DECODE(SIGN(IR_ZEN_ZEIGAKU),  -1, IR_ZEN_ZEIGAKU,  0)),
                       SUM(DECODE(SIGN(IR_TAI_ZEIGAKU),  -1, IR_TAI_ZEIGAKU,  0)),
                       SUM(DECODE(SIGN(SIEN_ZEN_ZEIGAKU),-1, SIEN_ZEN_ZEIGAKU,0)),
                       SUM(DECODE(SIGN(SIEN_TAI_ZEIGAKU),-1, SIEN_TAI_ZEIGAKU,0)),
                       SUM(DECODE(SIGN(KAI_ZEN_ZEIGAKU), -1, KAI_ZEN_ZEIGAKU, 0)),
                       SUM(DECODE(SIGN(KAI_TAI_ZEIGAKU), -1, KAI_TAI_ZEIGAKU, 0))
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                      ,SUM(DECODE(SIGN(KDM_ZEN_ZEIGAKU),-1, KDM_ZEN_ZEIGAKU,0))
                  INTO MWWNENZEI.IRY_ZENZEI, MWWNENZEI.IRY_TAIZEI,
                       MWWNENZEI.SIEN_ZENZEI, MWWNENZEI.SIEN_TAIZEI,
                       MWWNENZEI.KAI_ZENZEI, MWWNENZEI.KAI_TAIZEI
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                       ,MWWNENZEI.KDM_ZENZEI
                  FROM ZLBTKIBETSU_CAL
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO    
                   AND NENDOBUN        = NLNENDO_BUN       
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBCHOSEI マイナス期割集計(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            -- マイナス期割額を０へ更新
            BEGIN
                UPDATE ZLBTKIBETSU_CAL
                   SET IR_ZEN_ZEIGAKU  = DECODE(SIGN(IR_ZEN_ZEIGAKU),  -1, 0, IR_ZEN_ZEIGAKU),
                       IR_TAI_ZEIGAKU  = DECODE(SIGN(IR_TAI_ZEIGAKU),  -1, 0, IR_TAI_ZEIGAKU),
                       SIEN_ZEN_ZEIGAKU= DECODE(SIGN(SIEN_ZEN_ZEIGAKU),-1, 0, SIEN_ZEN_ZEIGAKU),
                       SIEN_TAI_ZEIGAKU= DECODE(SIGN(SIEN_TAI_ZEIGAKU),-1, 0, SIEN_TAI_ZEIGAKU),
                       KAI_ZEN_ZEIGAKU = DECODE(SIGN(KAI_ZEN_ZEIGAKU), -1, 0, KAI_ZEN_ZEIGAKU),
                       KAI_TAI_ZEIGAKU = DECODE(SIGN(KAI_TAI_ZEIGAKU), -1, 0, KAI_TAI_ZEIGAKU)
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                      ,KDM_ZEN_ZEIGAKU = DECODE(SIGN(KDM_ZEN_ZEIGAKU),-1, 0, KDM_ZEN_ZEIGAKU)
                 WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                   AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                   AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEINENDO     = NLCHOTEI_NENDO    
                   AND NENDOBUN        = NLNENDO_BUN       
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND RONRIKIBETSU BETWEEN I_NWSTRRKIBETSU AND I_NWENDRKIBETSU
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBCHOSEI マイナス期割0更新(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            BEGIN
                FOR RWKIBETSUD IN CWKIBETSUD LOOP
                    -- 医療全体税額
                    IF MWWNENZEI.IRY_ZENZEI < 0 AND RWKIBETSUD.IR_ZEN_ZEIGAKU > 0 THEN
                        IF ABS(MWWNENZEI.IRY_ZENZEI) <= RWKIBETSUD.IR_ZEN_ZEIGAKU THEN
                            RWKIBETSUD.IR_ZEN_ZEIGAKU := RWKIBETSUD.IR_ZEN_ZEIGAKU +
                                                         MWWNENZEI.IRY_ZENZEI;
                            MWWNENZEI.IRY_ZENZEI      := 0;
                        ELSE
                            MWWNENZEI.IRY_ZENZEI      := MWWNENZEI.IRY_ZENZEI +
                                                         RWKIBETSUD.IR_ZEN_ZEIGAKU;
                            RWKIBETSUD.IR_ZEN_ZEIGAKU := 0;
                        END IF;
                        BEGIN
                            UPDATE ZLBTKIBETSU_CAL
                               SET IR_ZEN_ZEIGAKU = RWKIBETSUD.IR_ZEN_ZEIGAKU
                             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                               AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                               AND SANTEIDANTAI_CD = I_NDANTAI
                               AND CHOTEINENDO     = NLCHOTEI_NENDO    
                               AND NENDOBUN        = NLNENDO_BUN       
                               AND TSUCHI_NO       = I_NTSUCHI_NO
                               AND RONRIKIBETSU = RWKIBETSUD.RONRIKIBETSU
                               AND SYS_TANMATSU_NO = I_VTANMATSU;
                        EXCEPTION
                            WHEN OTHERS THEN
                                NLRTN := C_NERR;
                                VLMSG := 'SUBCHOSEI 計算期別更新(医療全体)(国保世帯番号='||
                                         I_NSETAI||')'||SQLERRM;
                                RETURN;
                        END;
                        NWKIBETSU := RWKIBETSUD.RONRIKIBETSU;
                    END IF;
                    -- 医療退職税額
                    IF MWWNENZEI.IRY_TAIZEI < 0 AND RWKIBETSUD.IR_TAI_ZEIGAKU > 0 THEN
                        IF ABS(MWWNENZEI.IRY_TAIZEI) <= RWKIBETSUD.IR_TAI_ZEIGAKU THEN
                            RWKIBETSUD.IR_TAI_ZEIGAKU := RWKIBETSUD.IR_TAI_ZEIGAKU +
                                                         MWWNENZEI.IRY_TAIZEI;
                            MWWNENZEI.IRY_TAIZEI      := 0;
                        ELSE
                            MWWNENZEI.IRY_TAIZEI      := MWWNENZEI.IRY_TAIZEI +
                                                         RWKIBETSUD.IR_TAI_ZEIGAKU;
                            RWKIBETSUD.IR_TAI_ZEIGAKU := 0;
                        END IF;
                        BEGIN
                            UPDATE ZLBTKIBETSU_CAL
                               SET IR_TAI_ZEIGAKU = RWKIBETSUD.IR_TAI_ZEIGAKU
                             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                               AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                               AND SANTEIDANTAI_CD = I_NDANTAI
                               AND CHOTEINENDO     = NLCHOTEI_NENDO    
                               AND NENDOBUN        = NLNENDO_BUN       
                               AND TSUCHI_NO       = I_NTSUCHI_NO
                               AND RONRIKIBETSU = RWKIBETSUD.RONRIKIBETSU
                               AND SYS_TANMATSU_NO = I_VTANMATSU;
                        EXCEPTION
                            WHEN OTHERS THEN
                                NLRTN := C_NERR;
                                VLMSG := 'SUBCHOSEI 計算期別更新(医療退職)(国保世帯番号='||
                                         I_NSETAI||')'||SQLERRM;
                                RETURN;
                        END;
                        NWKIBETSU := RWKIBETSUD.RONRIKIBETSU;
                    END IF;
                    -- 介護全体税額
                    IF MWWNENZEI.KAI_ZENZEI < 0 AND RWKIBETSUD.KAI_ZEN_ZEIGAKU > 0 THEN
                        IF ABS(MWWNENZEI.KAI_ZENZEI) <= RWKIBETSUD.KAI_ZEN_ZEIGAKU THEN
                            RWKIBETSUD.KAI_ZEN_ZEIGAKU := RWKIBETSUD.KAI_ZEN_ZEIGAKU +
                                                          MWWNENZEI.KAI_ZENZEI;
                            MWWNENZEI.KAI_ZENZEI       := 0;
                        ELSE
                            MWWNENZEI.KAI_ZENZEI       := MWWNENZEI.KAI_ZENZEI +
                                                          RWKIBETSUD.KAI_ZEN_ZEIGAKU;
                            RWKIBETSUD.KAI_ZEN_ZEIGAKU := 0;
                        END IF;
                        BEGIN
                            UPDATE ZLBTKIBETSU_CAL
                               SET KAI_ZEN_ZEIGAKU = RWKIBETSUD.KAI_ZEN_ZEIGAKU
                             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                               AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                               AND SANTEIDANTAI_CD = I_NDANTAI
                               AND CHOTEINENDO     = NLCHOTEI_NENDO    
                               AND NENDOBUN        = NLNENDO_BUN       
                               AND TSUCHI_NO       = I_NTSUCHI_NO
                               AND RONRIKIBETSU = RWKIBETSUD.RONRIKIBETSU
                               AND SYS_TANMATSU_NO = I_VTANMATSU;
                        EXCEPTION
                            WHEN OTHERS THEN
                                NLRTN := C_NERR;
                                VLMSG := 'SUBCHOSEI 計算期別更新(介護全体)(国保世帯番号='||
                                         I_NSETAI||')'||SQLERRM;
                                RETURN;
                        END;
                        NWKIBETSU := RWKIBETSUD.RONRIKIBETSU;
                    END IF;
                    -- 介護退職税額
                    IF MWWNENZEI.KAI_TAIZEI < 0 AND RWKIBETSUD.KAI_TAI_ZEIGAKU > 0 THEN
                        IF ABS(MWWNENZEI.KAI_TAIZEI) <= RWKIBETSUD.KAI_TAI_ZEIGAKU THEN
                            RWKIBETSUD.KAI_TAI_ZEIGAKU := RWKIBETSUD.KAI_TAI_ZEIGAKU +
                                                          MWWNENZEI.KAI_TAIZEI;
                            MWWNENZEI.KAI_TAIZEI       := 0;
                        ELSE
                            MWWNENZEI.KAI_TAIZEI       := MWWNENZEI.KAI_TAIZEI +
                                                          RWKIBETSUD.KAI_TAI_ZEIGAKU;
                            RWKIBETSUD.KAI_TAI_ZEIGAKU := 0;
                        END IF;
                        BEGIN
                            UPDATE ZLBTKIBETSU_CAL
                               SET KAI_TAI_ZEIGAKU = RWKIBETSUD.KAI_TAI_ZEIGAKU
                             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                               AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
                               AND SANTEIDANTAI_CD = I_NDANTAI
                               AND CHOTEINENDO     = NLCHOTEI_NENDO    
                               AND NENDOBUN        = NLNENDO_BUN       
                               AND TSUCHI_NO       = I_NTSUCHI_NO
                               AND RONRIKIBETSU = RWKIBETSUD.RONRIKIBETSU
                               AND SYS_TANMATSU_NO = I_VTANMATSU;
                        EXCEPTION
                            WHEN OTHERS THEN
                                NLRTN := C_NERR;
                                VLMSG := 'SUBCHOSEI 計算期別更新(介護退職)(国保世帯番号='||
                                         I_NSETAI||')'||SQLERRM;
                                RETURN;
                        END;
                        NWKIBETSU := RWKIBETSUD.RONRIKIBETSU;
                    END IF;
                    -- 支援全体税額
                    IF MWWNENZEI.SIEN_ZENZEI < 0 AND RWKIBETSUD.SIEN_ZEN_ZEIGAKU > 0 THEN
                        IF ABS(MWWNENZEI.SIEN_ZENZEI) <= RWKIBETSUD.SIEN_ZEN_ZEIGAKU THEN
                            RWKIBETSUD.SIEN_ZEN_ZEIGAKU := RWKIBETSUD.SIEN_ZEN_ZEIGAKU +
                                                          MWWNENZEI.SIEN_ZENZEI;
                            MWWNENZEI.SIEN_ZENZEI       := 0;
                        ELSE
                            MWWNENZEI.SIEN_ZENZEI       := MWWNENZEI.SIEN_ZENZEI +
                                                          RWKIBETSUD.SIEN_ZEN_ZEIGAKU;
                            RWKIBETSUD.SIEN_ZEN_ZEIGAKU := 0;
                        END IF;
                        BEGIN
                            UPDATE ZLBTKIBETSU_CAL
                               SET SIEN_ZEN_ZEIGAKU = RWKIBETSUD.SIEN_ZEN_ZEIGAKU
                             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                               AND KOKU_SETAI_NO   = I_NSETAI
                               AND SANTEIDANTAI_CD = I_NDANTAI
                               AND CHOTEINENDO     = NLCHOTEI_NENDO
                               AND NENDOBUN        = NLNENDO_BUN
                               AND TSUCHI_NO       = I_NTSUCHI_NO
                               AND RONRIKIBETSU = RWKIBETSUD.RONRIKIBETSU
                               AND SYS_TANMATSU_NO = I_VTANMATSU;
                        EXCEPTION
                            WHEN OTHERS THEN
                                NLRTN := C_NERR;
                                VLMSG := 'SUBCHOSEI 計算期別更新(支援全体)(国保世帯番号='||
                                         I_NSETAI||')'||SQLERRM;
                                RETURN;
                        END;
                        NWKIBETSU := RWKIBETSUD.RONRIKIBETSU;
                    END IF;
                    -- 支援退職税額
                    IF MWWNENZEI.SIEN_TAIZEI < 0 AND RWKIBETSUD.SIEN_TAI_ZEIGAKU > 0 THEN
                        IF ABS(MWWNENZEI.SIEN_TAIZEI) <= RWKIBETSUD.SIEN_TAI_ZEIGAKU THEN
                            RWKIBETSUD.SIEN_TAI_ZEIGAKU := RWKIBETSUD.SIEN_TAI_ZEIGAKU +
                                                          MWWNENZEI.SIEN_TAIZEI;
                            MWWNENZEI.SIEN_TAIZEI       := 0;
                        ELSE
                            MWWNENZEI.SIEN_TAIZEI       := MWWNENZEI.SIEN_TAIZEI +
                                                          RWKIBETSUD.SIEN_TAI_ZEIGAKU;
                            RWKIBETSUD.SIEN_TAI_ZEIGAKU := 0;
                        END IF;
                        BEGIN
                            UPDATE ZLBTKIBETSU_CAL
                               SET SIEN_TAI_ZEIGAKU = RWKIBETSUD.SIEN_TAI_ZEIGAKU
                             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                               AND KOKU_SETAI_NO   = I_NSETAI
                               AND SANTEIDANTAI_CD = I_NDANTAI
                               AND CHOTEINENDO     = NLCHOTEI_NENDO
                               AND NENDOBUN        = NLNENDO_BUN
                               AND TSUCHI_NO       = I_NTSUCHI_NO
                               AND RONRIKIBETSU = RWKIBETSUD.RONRIKIBETSU
                               AND SYS_TANMATSU_NO = I_VTANMATSU;
                        EXCEPTION
                            WHEN OTHERS THEN
                                NLRTN := C_NERR;
                                VLMSG := 'SUBCHOSEI 計算期別更新(支援退職)(国保世帯番号='||
                                         I_NSETAI||')'||SQLERRM;
                                RETURN;
                        END;
                        NWKIBETSU := RWKIBETSUD.RONRIKIBETSU;
                    END IF;
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
                    -- 子ども全体税額
                    IF MWWNENZEI.KDM_ZENZEI < 0 AND RWKIBETSUD.KDM_ZEN_ZEIGAKU > 0 THEN 
                       IF ABS(MWWNENZEI.KDM_ZENZEI) <= RWKIBETSUD.KDM_ZEN_ZEIGAKU THEN
                           RWKIBETSUD.KDM_ZEN_ZEIGAKU := RWKIBETSUD.KDM_ZEN_ZEIGAKU +
                                                         MWWNENZEI.KDM_ZENZEI;
                           MWWNENZEI.KDM_ZENZEI       := 0;
                       ELSE
                           MWWNENZEI.KDM_ZENZEI       := MWWNENZEI.KDM_ZENZEI +
                                                         RWKIBETSUD.KDM_ZEN_ZEIGAKU;
                           RWKIBETSUD.KDM_ZEN_ZEIGAKU := 0;
                       END IF;

                       BEGIN
                            UPDATE ZLBTKIBETSU_CAL
                               SET KDM_ZEN_ZEIGAKU = RWKIBETSUD.KDM_ZEN_ZEIGAKU
                             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                               AND KOKU_SETAI_NO   = I_NSETAI
                               AND SANTEIDANTAI_CD = I_NDANTAI
                               AND CHOTEINENDO     = NLCHOTEI_NENDO
                               AND NENDOBUN        = NLNENDO_BUN
                               AND TSUCHI_NO       = I_NTSUCHI_NO
                               AND RONRIKIBETSU = RWKIBETSUD.RONRIKIBETSU
                               AND SYS_TANMATSU_NO = I_VTANMATSU;
                        EXCEPTION
                            WHEN OTHERS THEN
                                NLRTN := C_NERR;
                                VLMSG := 'SUBCHOSEI 計算期別更新(子ども全体)(国保世帯番号='||
                                         I_NSETAI||')'||SQLERRM;
                                RETURN;
                        END;
                        NWKIBETSU := RWKIBETSUD.RONRIKIBETSU;
                    END IF;
--  2025/08/11 ZCZL.WANGMINGYANG ADD END
                END LOOP;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBCHOSEI 計算期別取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            IF NWKIBETSU > 0 AND NWKIBETSU < I_NWSTRRKIBETSU THEN
                -- 按分処理３回目
                -- 論理期別で(-1)は不適切だが(間が抜けているかもしれない)
                -- I_NWSTRRKIBETSUを含めずに処理したい為に-1を指定
--上記のコメントどおり（-1）して論理期別がない場合に期割がおかしい為、修正
--               ＣＳ版は多久市のみで論期期別が抜けていないので問題なかった
                IWKIBETSU := FUNCRKIBETSU_MAE(I_MKIBETSU, I_NWSTRRKIBETSU);
                SUBSAIKIWARISUB(I_MWNENZEI,
                                NWKIBETSU,
                                IWKIBETSU);
                IF NLRTN != C_NOK THEN
                    RETURN;
                END IF;
            END IF;
            -- 按分処理４回目
            SUBSAIKIWARISUB(I_MWNENZEI,
                            I_NWSTRRKIBETSU,
                            I_NWENDRKIBETSU);               -- 09 再期割処理
        END IF;
    END SUBCHOSEI;
-------------------------------------------------------------------------------
-- 07 計算期別0更新
-------------------------------------------------------------------------------
    PROCEDURE SUB0UPDATE(I_MWNENZEI IN MTZEIGAKUR2) IS
    BEGIN
        IF I_MWNENZEI.ZENZEI = 0 THEN           -- 全体税額が0
            UPDATE ZLBTKIBETSU_CAL
               SET ZEN_ZEIGAKU     = 0, TAI_ZEIGAKU     = 0,
                   IR_ZEN_ZEIGAKU  = 0, IR_TAI_ZEIGAKU  = 0,
                   KAI_ZEN_ZEIGAKU = 0, KAI_TAI_ZEIGAKU = 0
                   , SIEN_ZEN_ZEIGAKU = 0, SIEN_TAI_ZEIGAKU = 0
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                   ,KDM_ZEN_ZEIGAKU = 0
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND CHOTEINENDO     = NLCHOTEI_NENDO    
               AND NENDOBUN        = NLNENDO_BUN       
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        ELSIF I_MWNENZEI.TAIZEI = 0 THEN        -- 退職税額が0
            UPDATE ZLBTKIBETSU_CAL
               SET TAI_ZEIGAKU     = 0,
                   IR_TAI_ZEIGAKU  = 0,
                   KAI_TAI_ZEIGAKU = 0
                   , SIEN_TAI_ZEIGAKU = 0  
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND CHOTEINENDO     = NLCHOTEI_NENDO    
               AND NENDOBUN        = NLNENDO_BUN       
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        END IF;
        IF I_MWNENZEI.IRY_ZENZEI = 0 THEN       -- 医療全体税額が0
            UPDATE ZLBTKIBETSU_CAL
               SET IR_ZEN_ZEIGAKU = 0, IR_TAI_ZEIGAKU = 0
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND CHOTEINENDO     = NLCHOTEI_NENDO    
               AND NENDOBUN        = NLNENDO_BUN       
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        ELSIF I_MWNENZEI.IRY_TAIZEI = 0 THEN    -- 医療退職税額が0
            UPDATE ZLBTKIBETSU_CAL
               SET IR_TAI_ZEIGAKU = 0
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND CHOTEINENDO     = NLCHOTEI_NENDO    
               AND NENDOBUN        = NLNENDO_BUN       
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        END IF;
        IF I_MWNENZEI.KAI_ZENZEI = 0 THEN       -- 介護全体税額が0
            UPDATE ZLBTKIBETSU_CAL
               SET KAI_ZEN_ZEIGAKU = 0, KAI_TAI_ZEIGAKU = 0
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND CHOTEINENDO     = NLCHOTEI_NENDO    
               AND NENDOBUN        = NLNENDO_BUN       
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        ELSIF I_MWNENZEI.KAI_TAIZEI = 0 THEN    -- 介護退職税額が0
            UPDATE ZLBTKIBETSU_CAL
               SET KAI_TAI_ZEIGAKU = 0
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
               AND CHOTEINENDO     = NLCHOTEI_NENDO    
               AND NENDOBUN        = NLNENDO_BUN       
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        END IF;
        IF I_MWNENZEI.SIEN_ZENZEI = 0 THEN       -- 支援全体税額が0
            UPDATE ZLBTKIBETSU_CAL
               SET SIEN_ZEN_ZEIGAKU = 0, SIEN_TAI_ZEIGAKU = 0
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND KOKU_SETAI_NO   = I_NSETAI
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND CHOTEINENDO     = NLCHOTEI_NENDO
               AND NENDOBUN        = NLNENDO_BUN
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        ELSIF I_MWNENZEI.SIEN_TAIZEI = 0 THEN    -- 支援退職税額が0
            UPDATE ZLBTKIBETSU_CAL
               SET SIEN_TAI_ZEIGAKU = 0
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND KOKU_SETAI_NO   = I_NSETAI
               AND CHOTEINENDO     = NLCHOTEI_NENDO
               AND NENDOBUN        = NLNENDO_BUN
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        END IF;
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
        IF I_MWNENZEI.KDM_ZENZEI = 0 THEN       -- 子ども全体税額
            UPDATE ZLBTKIBETSU_CAL
               SET KDM_ZEN_ZEIGAKU = 0
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND KOKU_SETAI_NO   = I_NSETAI
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND CHOTEINENDO     = NLCHOTEI_NENDO
               AND NENDOBUN        = NLNENDO_BUN
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        END IF;
--  2025/08/11 ZCZL.WANGMINGYANG ADD END
    EXCEPTION
        WHEN OTHERS THEN
            NLRTN := C_NERR;
            VLMSG := 'SUB0UPDATE 計算期割0更新(国保世帯番号='||
                     I_NSETAI||')'||SQLERRM;
    END SUB0UPDATE;
-------------------------------------------------------------------------------
-- 06 マイナス期数算出
-------------------------------------------------------------------------------
    PROCEDURE SUBMINUSKISU(I_NKAMOKU_CD IN  NUMBER,
                           O_NCNT       OUT NUMBER) IS
    BEGIN
        -- マイナス期割の存在チェック
        SELECT COUNT(*) INTO O_NCNT
          FROM ZLBTKIBETSU_CAL
         WHERE KAMOKU_CD       = I_NKAMOKU_CD
           AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
           AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
           AND SANTEIDANTAI_CD = I_NDANTAI
           AND CHOTEINENDO     = NLCHOTEI_NENDO    
           AND NENDOBUN        = NLNENDO_BUN       
           AND TSUCHI_NO       = I_NTSUCHI_NO
           AND (ZEN_ZEIGAKU     < TAI_ZEIGAKU     OR TAI_ZEIGAKU     < 0
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--             OR ZEN_ZEIGAKU     <> (IR_ZEN_ZEIGAKU + KAI_ZEN_ZEIGAKU + SIEN_ZEN_ZEIGAKU)
             OR ZEN_ZEIGAKU     <> (IR_ZEN_ZEIGAKU + KAI_ZEN_ZEIGAKU + SIEN_ZEN_ZEIGAKU + KDM_ZEN_ZEIGAKU)
             OR TAI_ZEIGAKU     <> (IR_TAI_ZEIGAKU + KAI_TAI_ZEIGAKU + SIEN_TAI_ZEIGAKU)
             OR IR_ZEN_ZEIGAKU  < IR_TAI_ZEIGAKU  OR IR_TAI_ZEIGAKU  < 0
             OR KAI_ZEN_ZEIGAKU < KAI_TAI_ZEIGAKU OR KAI_TAI_ZEIGAKU < 0
             OR SIEN_ZEN_ZEIGAKU < SIEN_TAI_ZEIGAKU OR SIEN_TAI_ZEIGAKU < 0)
           AND SYS_TANMATSU_NO = I_VTANMATSU;
    EXCEPTION
        WHEN OTHERS THEN
            NLRTN := C_NERR;
            VLMSG := 'SUBMINUSKISU マイナス期割存在チェック(国保世帯番号='||
                     I_NSETAI||')'||SQLERRM;
    END SUBMINUSKISU;
-------------------------------------------------------------------------------
-- 退職税額の按分確認
-------------------------------------------------------------------------------
    FUNCTION FUNC_IS_TAISHOKUZEI_DIVIDED RETURN NUMBER IS
      --退職税額の按分有無判定結果
      NRESULT NUMBER;
      --退職税額の按分有無確認カーソル
      CURSOR C_CTD IS
        SELECT RONRIKIBETSU, ZEN_ZEIGAKU, TAI_ZEIGAKU
          FROM ZLBTKIBETSU_CAL
         WHERE KAMOKU_CD = C_NKAMOKU_BASE
           AND KAMOKUS_CD = C_NKAMOKUS_FUTU
           AND KOKU_SETAI_NO = I_NSETAI
           AND SANTEIDANTAI_CD = I_NDANTAI
           AND CHOTEINENDO = NLCHOTEI_NENDO
           AND NENDOBUN = NLNENDO_BUN
           AND TSUCHI_NO = I_NTSUCHI_NO
           AND SYS_TANMATSU_NO = I_VTANMATSU
           AND ZEN_ZEIGAKU > 0
         ORDER BY RONRIKIBETSU;
    BEGIN
      --初期化
      NRESULT := 0;
      --計算期別で全体税額>0の普徴月レコードを取得する
      FOR REC IN C_CTD LOOP
        IF C_CTD%ROWCOUNT = 1 THEN
          --全体税額の期割開始月
          IF REC.TAI_ZEIGAKU > 0 THEN
            --退職税額>0
            NRESULT := 1;
          ELSE
            --全体税額期割開始月の退職税額=0の場合はループを抜ける
            EXIT;
          END IF;
        ELSE
          --全体税額の期割開始月の翌月以降
          IF REC.TAI_ZEIGAKU > 0 THEN
            --退職税額>0（按分されている）
            NRESULT := 0;
          ELSE
            --按分されていない
            NRESULT := 1;
          END IF;
        END IF;
      END LOOP;
      RETURN NRESULT;
    END FUNC_IS_TAISHOKUZEI_DIVIDED;
-------------------------------------------------------------------------------
-- 05 再期割(マイナス調整)
--  手順① 期別データのコピー(科目コード=0)を作成
--      ② 過ぎている期別を再読込み
--      ③ 期別税額を各年税額に合わせるように調整
--      ④ 再期割
--      ⑤ それでもマイナス期割がある場合、1つ前の期別も含めて再期割
--      ⑥ 算出した税額で計算期別を更新
-------------------------------------------------------------------------------
    PROCEDURE SUBSAIKIWARI IS
        NWCNT               NUMBER      := 0;
        NWIX                NUMBER(2)   := 0;
        NWIX2               NUMBER(2)   := 0;
        NWMAXIX             NUMBER(2)   := 0;
        NWSTRIX             NUMBER(2)   := 0;
        NWENDIX             NUMBER(2)   := 0;
        NWSRKIBETSU         NUMBER(2)   := 0;   -- 処理論理期別
        NWSNOUKIKBN         NUMBER      := 0;   -- 処理納期区分
        NWSTRRKIBETSU       NUMBER(2)   := 0;   -- 開始論理期別
        NWENDRKIBETSU       NUMBER(2)   := 0;   -- 終了論理期別
        NWSTRKIBETSU        NUMBER(2)   := 0;   -- 開始期別
        NWENDKIBETSU        NUMBER(2)   := 0;   -- 終了期別
        NWSHIME_NENGETSU    NUMBER(6)   := 0;   -- 〆年月
        NWZENZEITMP         NUMBER(10)  := 0;   -- 全体税額TMP
        NWTAIZEITMP         NUMBER(10)  := 0;   -- 退職税額TMP
        NWZEIGAKUTMP        NUMBER(10)  := 0;   -- 税額TMP
        NWKIJUNBI_NENDO     NUMBER(4)   := 0;   -- 基準日の属する年度
        -- 更新用主キー格納
        NWKAMOKU_CD         NUMBER(3)   := 0;   -- 科目コード
        NWKAMOKUS_CD        NUMBER(2)   := 0;   -- 科目詳細コード
        --2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
        --NWKOKU_SETAI_NO     NUMBER(12)  := 0;   --国保世帯番号
        NWKOKU_SETAI_NO     NUMBER  := 0;   --国保世帯番号
        NWSANTEIDANTAI_CD   NUMBER(2)   := 0;   -- 算定団体コード
        NWCHOTEINENDO       NUMBER(4)   := 0;   -- 調定年度
        NWNENDOBUN          NUMBER(4)   := 0;   -- 年度分
        NWTSUCHI_NO         NUMBER(12)  := 0;   -- 通知書番号
        MWNENZEI        MTZEIGAKUR2;    -- 年税額
        MWWNENZEI       MTZEIGAKUR2;    -- 年税額WORK
        MWKIBETSU       MTKIBETSU;      -- 期別
        RWJOKEN         ZLBTJOKEN%ROWTYPE;
        NlCUT_COL               NUMBER;
        -- カーソル
        -- 計算期別(科目コード=0)カーソル
        CURSOR CWKIBETSU_NEW IS
            SELECT * FROM ZLBTKIBETSU_CAL
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW      -- 科目コード(新規分)
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU    
               AND KOKU_SETAI_NO   = I_NSETAI           --国保世帯番号
               AND SANTEIDANTAI_CD = I_NDANTAI          -- 算定団体コード
               AND CHOTEINENDO     = NLCHOTEI_NENDO     
               AND NENDOBUN        = NLNENDO_BUN        
               AND TSUCHI_NO       = I_NTSUCHI_NO       -- 通知書番号
               AND SYS_TANMATSU_NO = I_VTANMATSU
             ORDER BY RONRIKIBETSU;                     -- 論理期別(昇順)
        -- 計算期別降順(科目コード=0)カーソル
        CURSOR CWKIBETSUD_NEW IS
            SELECT * FROM ZLBTKIBETSU_CAL
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW      -- 科目コード(新規分)
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND KOKU_SETAI_NO   = I_NSETAI           --国保世帯番号
               AND SANTEIDANTAI_CD = I_NDANTAI          -- 算定団体コード
               AND CHOTEINENDO     = NLCHOTEI_NENDO     
               AND NENDOBUN        = NLNENDO_BUN        
               AND TSUCHI_NO       = I_NTSUCHI_NO       -- 通知書番号
               AND SYS_TANMATSU_NO = I_VTANMATSU
             ORDER BY RONRIKIBETSU DESC;                -- 論理期別(降順)
        -- 計算期別(科目コード=15)カーソル
        CURSOR CWKIBETSU_BASE IS
            SELECT * FROM ZLBTKIBETSU_CAL
             WHERE KAMOKU_CD       = C_NKAMOKU_BASE     -- 科目コード(作成元)
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND KOKU_SETAI_NO   = I_NSETAI           --国保世帯番号
               AND SANTEIDANTAI_CD = I_NDANTAI          -- 算定団体コード
               AND CHOTEINENDO     = NLCHOTEI_NENDO     
               AND NENDOBUN        = NLNENDO_BUN        
               AND TSUCHI_NO       = I_NTSUCHI_NO       -- 通知書番号
               AND SYS_TANMATSU_NO = I_VTANMATSU
             ORDER BY RONRIKIBETSU;                     -- 論理期別(昇順)
    BEGIN
        -- マイナス期割の存在チェック
        SUBMINUSKISU(C_NKAMOKU_BASE, NWCNT);        -- 06 マイナス期数算出
        IF NLRTN != C_NOK THEN
            RETURN;
        END IF;
        IF NLRTN = C_NOK AND NWCNT = 0 THEN
            -- マイナス期割がない場合、税額が正しいかチェック
            BEGIN
                SELECT DECODE(SUM(IR_ZEN_ZEIGAKU),  NLIRY_ZEN_NENZEI, 0, 1)
                     + DECODE(SUM(IR_TAI_ZEIGAKU),  NLIRY_TAI_NENZEI, 0, 1)
                     + DECODE(SUM(KAI_ZEN_ZEIGAKU), NLKAI_ZEN_NENZEI, 0, 1)
                     + DECODE(SUM(KAI_TAI_ZEIGAKU), NLKAI_TAI_NENZEI, 0, 1)
                     + DECODE(SUM(SIEN_ZEN_ZEIGAKU), NLSIEN_ZEN_NENZEI, 0, 1)
                     + DECODE(SUM(SIEN_TAI_ZEIGAKU), NLSIEN_TAI_NENZEI, 0, 1) 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                     + DECODE(SUM(KDM_ZEN_ZEIGAKU), NLKDM_ZEN_NENZEI, 0, 1)
                  INTO NWCNT FROM ZLBTKIBETSU_CAL
                 WHERE SANTEIDANTAI_CD = I_NDANTAI              -- 算定団体コード
                   AND KOKU_SETAI_NO   = I_NSETAI               --国保世帯番号
                   AND CHOTEINENDO     = NLCHOTEI_NENDO         
                   AND NENDOBUN        = NLNENDO_BUN            
                   AND TSUCHI_NO       = I_NTSUCHI_NO           -- 通知書番号
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARI 計算期別税額チェック(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
            IF NLRTN = C_NOK AND NWCNT = 0 THEN
              NWCNT := FUNC_IS_TAISHOKUZEI_DIVIDED;
            END IF;
            -- 税額が正しい場合、処理を抜ける
            IF NLRTN = C_NOK AND NWCNT = 0 THEN
                RETURN;
            END IF;
        END IF;
        -- 年税額の保持
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--        MWNENZEI.ZENZEI     := NLIRY_ZEN_NENZEI + NLKAI_ZEN_NENZEI + NLSIEN_ZEN_NENZEI;
        MWNENZEI.ZENZEI     := NLIRY_ZEN_NENZEI + NLKAI_ZEN_NENZEI + NLSIEN_ZEN_NENZEI + NLKDM_ZEN_NENZEI;
        MWNENZEI.TAIZEI     := NLIRY_TAI_NENZEI + NLKAI_TAI_NENZEI + NLSIEN_TAI_NENZEI;
        IF IZAN_MODE = 1 THEN
          -- システム条件より端数、納期区分を取得(年度分)
          SELECT * INTO RwJOKEN FROM ZLBTJOKEN
            WHERE NENDO           = NLNENDO_BUN
              AND SANTEIDANTAI_CD = I_NDANTAI;

          -- 月次端数処理の保存
          -- 年税額端数処理の保存
          CASE RwJOKEN.HASU_IRY
              WHEN c_NHASU_KBN_1  THEN NlCUT_COL := c_NHASU_2;       -- 100単位
              WHEN c_NHASU_KBN_2  THEN NlCUT_COL := c_NHASU_1;       -- 1000単位
              WHEN c_NHASU_KBN_3  THEN NlCUT_COL := c_NHASU_3;       -- 行なわない
              WHEN c_NHASU_KBN_10 THEN NlCUT_COL := c_NHASU_10;      -- 10単位
              ELSE NlCUT_COL := c_NHASU_2;       -- 100単位
          END CASE;

          MWNENZEI.ZENZEI     := TRUNC(MWNENZEI.ZENZEI ,NlCUT_COL);
          MWNENZEI.TAIZEI     := TRUNC(MWNENZEI.TAIZEI ,NlCUT_COL);
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--          NLIRY_ZEN_NENZEI := MWNENZEI.ZENZEI - (NLKAI_ZEN_NENZEI + NLSIEN_ZEN_NENZEI);
          NLIRY_ZEN_NENZEI := MWNENZEI.ZENZEI - (NLKAI_ZEN_NENZEI + NLSIEN_ZEN_NENZEI + NLKDM_ZEN_NENZEI);
          NLIRY_TAI_NENZEI := MWNENZEI.TAIZEI - (NLKAI_TAI_NENZEI + NLSIEN_TAI_NENZEI);
        END IF;
        MWNENZEI.IRY_ZENZEI := NLIRY_ZEN_NENZEI;
        MWNENZEI.IRY_TAIZEI := NLIRY_TAI_NENZEI;
        MWNENZEI.KAI_ZENZEI := NLKAI_ZEN_NENZEI;
        MWNENZEI.KAI_TAIZEI := NLKAI_TAI_NENZEI;
        MWNENZEI.SIEN_ZENZEI := NLSIEN_ZEN_NENZEI;
        MWNENZEI.SIEN_TAIZEI := NLSIEN_TAI_NENZEI; 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
        MWNENZEI.KDM_ZENZEI := NLKDM_ZEN_NENZEI;
        -- 不要な計算期別を削除
        BEGIN
            DELETE FROM ZLBTKIBETSU_CAL
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW  -- 科目コード(新規分)
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND KOKU_SETAI_NO   = I_NSETAI          --国保世帯番号
               AND SANTEIDANTAI_CD = I_NDANTAI      -- 算定団体コード
               AND CHOTEINENDO     = NLCHOTEI_NENDO    
               AND NENDOBUN        = NLNENDO_BUN       
               AND TSUCHI_NO       = I_NTSUCHI_NO   -- 通知書番号
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
----- 計算期別データコピー(手順①)
        BEGIN
            FOR RWKIBETSU IN CWKIBETSU_BASE LOOP
                IF NWKAMOKU_CD = 0 THEN       -- 読込み１回目
                    -- キー保持
                    NWKAMOKU_CD         := RWKIBETSU.KAMOKU_CD;         -- 科目コード
                    NWKAMOKUS_CD        := RWKIBETSU.KAMOKUS_CD;        -- 科目詳細コード
                    NWKOKU_SETAI_NO     := RWKIBETSU.KOKU_SETAI_NO;     --国保世帯番号
                    NWSANTEIDANTAI_CD   := RWKIBETSU.SANTEIDANTAI_CD;   -- 算定団体コード
                    NWCHOTEINENDO       := RWKIBETSU.CHOTEINENDO;       -- 調定年度
                    NWNENDOBUN          := RWKIBETSU.NENDOBUN;          -- 年度分
                    NWTSUCHI_NO         := RWKIBETSU.TSUCHI_NO;         -- 通知書番号
                    NWSTRKIBETSU        := RWKIBETSU.RONRIKIBETSU;      -- 開始期別
                END IF;
                NWIX := NWIX + 1;
                MWKIBETSU(NWIX).BKIBETSU := NWIX;                       -- 物理期別
                MWKIBETSU(NWIX).RKIBETSU := RWKIBETSU.RONRIKIBETSU;     -- 論理期別
                NWENDKIBETSU             := RWKIBETSU.RONRIKIBETSU;     -- 終了期別
                IF RWKIBETSU.ZEN_ZEIGAKU > 0 THEN
                    IF NWSTRRKIBETSU = 0 THEN
                        -- 全体税額のある最初の期を取得
                        NWSTRRKIBETSU := RWKIBETSU.RONRIKIBETSU;    -- 開始論理期別
                    END IF;
                    NWENDRKIBETSU := RWKIBETSU.RONRIKIBETSU;        -- 終了論理期別
                END IF;
                BEGIN
                    -- 読込んだレコードのコピーを作成
                    RWKIBETSU.KAMOKU_CD := C_NKAMOKU_NEW;       -- 科目コード(=0)
                    INSERT INTO ZLBTKIBETSU_CAL VALUES RWKIBETSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARI 計算期別コピー(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
            END LOOP;
            NWMAXIX := NWIX;
            -- 計算期別データで年税額0の場合、各期別も0とする
            SUB0UPDATE(MWNENZEI);           -- 07 計算期別0更新
            IF NLRTN != C_NOK THEN
                RETURN;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                NLRTN := C_NERR;
                VLMSG := 'SUBSAIKIWARI 計算期別コピー(国保世帯番号='||
                         I_NSETAI||')'||SQLERRM;
                RETURN;
        END;
----- 按分対象期の判定と賦課期別より過ぎた期別の取得(手順②)
        IF NLSYORI_KBN != C_NSYORI_ZENKI THEN      -- 差額按分
-- 基準日の年度と計算期別の年度分が異なる場合は、按分開始期別を13期とする
            -- 基準日より年度を算出
--2025/05/20 jcbc.zei UPDATE Start ZLB_1.0.304.000：QA14706の対応
            --NWKIJUNBI_NENDO := KKAPK0020.FNENDO(I_NKIJUNBI,0);
            NWKIJUNBI_NENDO := KKAPK0020.FDAYNENDO(I_NKIJUNBI,0);
--2025/05/20 jcbc.zei UPDATE End
            -- 基準日年度と計算期別の年度分を比較
            IF NWKIJUNBI_NENDO = NWNENDOBUN THEN
            -- 基準日年度と計算期別の年度分が同一
              -- 基準日より論理期別を算出
              NWSRKIBETSU := TRUNC(I_NKIJUNBI - TRUNC(I_NKIJUNBI, -4), -2) / 100;
              IF NWSRKIBETSU < 4 THEN     -- ４月以前(1,2,3月→10,11,12)
                  NWSRKIBETSU := NWSRKIBETSU + 9;
              ELSE                        -- ４月以降(4,･･･,12月→1,･･･,9)
                  NWSRKIBETSU := NWSRKIBETSU - 3;
              END IF;
              -- 現在の期別を按分開始期別とする
              NWSTRRKIBETSU := NWSRKIBETSU;
            ELSE
            -- 基準日年度と計算期別の年度分が異なる
              -- 13期を按分開始期別とする
              NWSRKIBETSU := 13;
              NWSTRRKIBETSU := 13;
            END IF;
            BEGIN
                FOR RWKIBETSU IN CWKIBETSU_NEW LOOP     -- 計算期別(科目コード=0)カーソル
                    IF RWKIBETSU.RONRIKIBETSU < NWSRKIBETSU THEN
                        BEGIN
                            IF I_NJIKKOU_KBN != C_NTEST THEN    -- 実行区分が「賦課試算」以外
                                -- 賦課期別から税額を取得(税額を変更しない)
                                SELECT ZEN_ZEIGAKU,     TAI_ZEIGAKU,
                                       IR_ZEN_ZEIGAKU,  IR_TAI_ZEIGAKU,
                                       KAI_ZEN_ZEIGAKU, KAI_TAI_ZEIGAKU
                                       , SIEN_ZEN_ZEIGAKU, SIEN_TAI_ZEIGAKU
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                                       ,KDM_ZEN_ZEIGAKU

                                  INTO RWKIBETSU.ZEN_ZEIGAKU,     RWKIBETSU.TAI_ZEIGAKU,
                                       RWKIBETSU.IR_ZEN_ZEIGAKU,  RWKIBETSU.IR_TAI_ZEIGAKU,
                                       RWKIBETSU.KAI_ZEN_ZEIGAKU, RWKIBETSU.KAI_TAI_ZEIGAKU
                                       , RWKIBETSU.SIEN_ZEN_ZEIGAKU, RWKIBETSU.SIEN_TAI_ZEIGAKU
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                                       ,RWKIBETSU.KDM_ZEN_ZEIGAKU
                                  FROM ZLBTKIBETSU_N
                                 WHERE KAMOKU_CD       = NWKAMOKU_CD
                                   AND KAMOKUS_CD      = NWKAMOKUS_CD
                                   AND KOKU_SETAI_NO   = NWKOKU_SETAI_NO   
                                   AND SANTEIDANTAI_CD = I_NDANTAI
                                   AND CHOTEINENDO     = NWCHOTEINENDO
                                   AND NENDOBUN        = NWNENDOBUN
                                   AND TSUCHI_NO       = NWTSUCHI_NO
                                   AND CHOTEINENDO     = NLCHOTEI_NENDO    
                                   AND NENDOBUN        = NLNENDO_BUN       
                                   AND RONRIKIBETSU    = RWKIBETSU.RONRIKIBETSU;
                            ELSE                                -- 「賦課試算」の場合
                                -- 更正前期別から税額を取得(税額を変更しない)
                                SELECT ZEN_ZEIGAKU,     TAI_ZEIGAKU,
                                       IR_ZEN_ZEIGAKU,  IR_TAI_ZEIGAKU,
                                       KAI_ZEN_ZEIGAKU, KAI_TAI_ZEIGAKU
                                       , SIEN_ZEN_ZEIGAKU, SIEN_TAI_ZEIGAKU
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                                       ,KDM_ZEN_ZEIGAKU
                                  INTO RWKIBETSU.ZEN_ZEIGAKU,     RWKIBETSU.TAI_ZEIGAKU,
                                       RWKIBETSU.IR_ZEN_ZEIGAKU,  RWKIBETSU.IR_TAI_ZEIGAKU,
                                       RWKIBETSU.KAI_ZEN_ZEIGAKU, RWKIBETSU.KAI_TAI_ZEIGAKU
                                       , RWKIBETSU.SIEN_ZEN_ZEIGAKU, RWKIBETSU.SIEN_TAI_ZEIGAKU
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                                       ,RWKIBETSU.KDM_ZEN_ZEIGAKU
                                  FROM ZLBTKIBETSU_TS
                                 WHERE KAMOKU_CD       = NWKAMOKU_CD
                                   AND KAMOKUS_CD      = NWKAMOKUS_CD
                                   AND KOKU_SETAI_NO   = NWKOKU_SETAI_NO   
                                   AND SANTEIDANTAI_CD = I_NDANTAI
                                   AND CHOTEINENDO     = NWCHOTEINENDO
                                   AND NENDOBUN        = NWNENDOBUN
                                   AND TSUCHI_NO       = NWTSUCHI_NO
                                   AND RONRIKIBETSU    = RWKIBETSU.RONRIKIBETSU
                                   AND CHOTEINENDO     = NLCHOTEI_NENDO    
                                   AND NENDOBUN        = NLNENDO_BUN       
                                   AND SYS_TANMATSU_NO = I_VTANMATSU;
                            END IF;
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                NULL;
                            WHEN OTHERS THEN
                                NLRTN := C_NERR;
                                VLMSG := 'SUBSAIKIWARI 税額取得(国保世帯番号='||
                                         I_NSETAI||')'||SQLERRM;
                                RETURN;
                        END;
                        BEGIN
                            UPDATE ZLBTKIBETSU_CAL
                               SET ZEN_ZEIGAKU     = RWKIBETSU.ZEN_ZEIGAKU,
                                   TAI_ZEIGAKU     = RWKIBETSU.TAI_ZEIGAKU,
                                   IR_ZEN_ZEIGAKU  = RWKIBETSU.IR_ZEN_ZEIGAKU,
                                   IR_TAI_ZEIGAKU  = RWKIBETSU.IR_TAI_ZEIGAKU,
                                   KAI_ZEN_ZEIGAKU = RWKIBETSU.KAI_ZEN_ZEIGAKU,
                                   KAI_TAI_ZEIGAKU = RWKIBETSU.KAI_TAI_ZEIGAKU
                                   ,
                                   SIEN_ZEN_ZEIGAKU = RWKIBETSU.SIEN_ZEN_ZEIGAKU,
                                   SIEN_TAI_ZEIGAKU = RWKIBETSU.SIEN_TAI_ZEIGAKU 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                                   ,KDM_ZEN_ZEIGAKU = RWKIBETSU.KDM_ZEN_ZEIGAKU
                             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                               AND KOKU_SETAI_NO   = I_NSETAI          
                               AND SANTEIDANTAI_CD = I_NDANTAI
                               AND CHOTEINENDO     = NLCHOTEI_NENDO    
                               AND NENDOBUN        = NLNENDO_BUN       
                               AND TSUCHI_NO       = I_NTSUCHI_NO
                               AND RONRIKIBETSU    = RWKIBETSU.RONRIKIBETSU
                               AND SYS_TANMATSU_NO = I_VTANMATSU;
                        EXCEPTION
                            WHEN OTHERS THEN
                                NLRTN := C_NERR;
                                VLMSG := 'SUBSAIKIWARI 税額更新(国保世帯番号='||
                                         I_NSETAI||')'||SQLERRM;
                                RETURN;
                        END;
                        IF NWENDRKIBETSU < RWKIBETSU.RONRIKIBETSU AND
                           RWKIBETSU.ZEN_ZEIGAKU > 0 THEN
                            NWENDRKIBETSU := RWKIBETSU.RONRIKIBETSU;
                        END IF;
                    END IF;
                END LOOP;
                -- 計算期別データで年税額0の場合、各期別も0とする
                SUB0UPDATE(MWNENZEI);       -- 07 計算期別0更新
                IF NLRTN != C_NOK THEN
                    RETURN;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBSAIKIWARI 税額再読込み(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
                    RETURN;
            END;
        END IF;
----- 税額チェック(手順③)
        BEGIN
            -- 計算期別より各税額の合計額を取得
            SELECT SUM(ZEN_ZEIGAKU),     SUM(TAI_ZEIGAKU),
                   SUM(IR_ZEN_ZEIGAKU),  SUM(IR_TAI_ZEIGAKU),
                   SUM(KAI_ZEN_ZEIGAKU), SUM(KAI_TAI_ZEIGAKU)
                   , SUM(SIEN_ZEN_ZEIGAKU), SUM(SIEN_TAI_ZEIGAKU)
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                   ,SUM(KDM_ZEN_ZEIGAKU)
              INTO MWWNENZEI.ZENZEI,     MWWNENZEI.TAIZEI,
                   MWWNENZEI.IRY_ZENZEI, MWWNENZEI.IRY_TAIZEI,
                   MWWNENZEI.KAI_ZENZEI, MWWNENZEI.KAI_TAIZEI
                   , MWWNENZEI.SIEN_ZENZEI, MWWNENZEI.SIEN_TAIZEI
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                   ,MWWNENZEI.KDM_ZENZEI
              FROM ZLBTKIBETSU_CAL
             WHERE ((KAMOKU_CD       = C_NKAMOKU_NEW      -- 科目コード=0
                     AND KAMOKUS_CD  = C_NKAMOKUS_FUTU)   -- 科目詳細コード:普通
                    OR (KAMOKU_CD    = C_NKAMOKU_BASE     -- 科目コード=15
                     AND KAMOKUS_CD  = C_NKAMOKUS_TOKU))  -- 科目詳細コード:特別
               AND KOKU_SETAI_NO   = I_NSETAI           
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND CHOTEINENDO     = NLCHOTEI_NENDO     
               AND NENDOBUN        = NLNENDO_BUN        
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        EXCEPTION
            WHEN OTHERS THEN
                NLRTN := C_NERR;
                VLMSG := 'SUBSAIKIWARI 税額合計取得(国保世帯番号='||
                         I_NSETAI||')'||SQLERRM;
                RETURN;
        END;
        MWWNENZEI.ZENZEI     := MWNENZEI.ZENZEI     - MWWNENZEI.ZENZEI;
        MWWNENZEI.TAIZEI     := MWNENZEI.TAIZEI     - MWWNENZEI.TAIZEI;
        MWWNENZEI.IRY_ZENZEI := MWNENZEI.IRY_ZENZEI - MWWNENZEI.IRY_ZENZEI;
        MWWNENZEI.IRY_TAIZEI := MWNENZEI.IRY_TAIZEI - MWWNENZEI.IRY_TAIZEI;
        MWWNENZEI.KAI_ZENZEI := MWNENZEI.KAI_ZENZEI - MWWNENZEI.KAI_ZENZEI;
        MWWNENZEI.KAI_TAIZEI := MWNENZEI.KAI_TAIZEI - MWWNENZEI.KAI_TAIZEI;
        MWWNENZEI.SIEN_ZENZEI := MWNENZEI.SIEN_ZENZEI - MWWNENZEI.SIEN_ZENZEI;
        MWWNENZEI.SIEN_TAIZEI := MWNENZEI.SIEN_TAIZEI - MWWNENZEI.SIEN_TAIZEI; 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
        MWWNENZEI.KDM_ZENZEI := MWNENZEI.KDM_ZENZEI - MWWNENZEI.KDM_ZENZEI;
        IF MWWNENZEI.ZENZEI     = 0 AND MWWNENZEI.TAIZEI     = 0 AND
           MWWNENZEI.IRY_ZENZEI = 0 AND MWWNENZEI.IRY_TAIZEI = 0 AND
           MWWNENZEI.KAI_ZENZEI = 0 AND MWWNENZEI.KAI_TAIZEI = 0 AND
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--           MWWNENZEI.SIEN_ZENZEI = 0 AND MWWNENZEI.SIEN_TAIZEI = 0 THEN
           MWWNENZEI.SIEN_ZENZEI = 0 AND MWWNENZEI.SIEN_TAIZEI = 0 AND
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
           MWWNENZEI.KDM_ZENZEI = 0 THEN
            NULL;       -- 差額なし
        ELSE
            -- 税額に違いが有り調整の必要有り
            IF NWSTRRKIBETSU <= NWENDRKIBETSU THEN
                IF NWSTRKIBETSU < NWSTRRKIBETSU THEN
                  IF MWWNENZEI.ZENZEI = 0 AND MWWNENZEI.TAIZEI = 0 THEN
                    NULL;  --税額に差がなく内訳の差分のみなので今の開始論理期別から調整できるはず
                  ELSE
--１つ前の論理期別を求める
                    NWSTRRKIBETSU := FUNCRKIBETSU_MAE(MWKIBETSU, NWSTRRKIBETSU);
                  END IF;  
                END IF;
                BEGIN
                    UPDATE ZLBTKIBETSU_CAL
                       SET ZEN_ZEIGAKU     = ZEN_ZEIGAKU     + MWWNENZEI.ZENZEI,
                           TAI_ZEIGAKU     = TAI_ZEIGAKU     + MWWNENZEI.TAIZEI,
                           IR_ZEN_ZEIGAKU  = IR_ZEN_ZEIGAKU  + MWWNENZEI.IRY_ZENZEI,
                           IR_TAI_ZEIGAKU  = IR_TAI_ZEIGAKU  + MWWNENZEI.IRY_TAIZEI,
                           KAI_ZEN_ZEIGAKU = KAI_ZEN_ZEIGAKU + MWWNENZEI.KAI_ZENZEI,
                           KAI_TAI_ZEIGAKU = KAI_TAI_ZEIGAKU + MWWNENZEI.KAI_TAIZEI
                           ,
                           SIEN_ZEN_ZEIGAKU = SIEN_ZEN_ZEIGAKU + MWWNENZEI.SIEN_ZENZEI,
                           SIEN_TAI_ZEIGAKU = SIEN_TAI_ZEIGAKU + MWWNENZEI.SIEN_TAIZEI 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                           ,KDM_ZEN_ZEIGAKU = KDM_ZEN_ZEIGAKU + MWWNENZEI.KDM_ZENZEI
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI          
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO    
                       AND NENDOBUN        = NLNENDO_BUN       
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU    = NWSTRRKIBETSU
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                  IF MWWNENZEI.TAIZEI = 0
                    AND (MWWNENZEI.IRY_TAIZEI + MWWNENZEI.SIEN_TAIZEI + MWWNENZEI.KAI_TAIZEI) > 0 THEN
                    --退職調整額が全体退職税額は変わらないが、医療介護の退職内訳が変わる場合は更にチェック

                    IF NLFUKA_KAI_TAIZEI > 0
                      AND NLKAI_TAI_NENZEI = 0
                      AND NLIRY_TAI_NENZEI > 0
                      AND NLSIEN_TAI_NENZEI > 0 THEN
                        --更正前の賦課介護退職税額はあるが、今回の計算（計算介護退職税額）が０円となる場合
                        --計算期別の全体退職税額と医療退職税額が不一致となる事への対応

                        -- 計算期別より各税額の合計額を再取得
                        SELECT SUM(ZEN_ZEIGAKU),     SUM(TAI_ZEIGAKU),
                               SUM(IR_ZEN_ZEIGAKU),  SUM(IR_TAI_ZEIGAKU),
                               SUM(KAI_ZEN_ZEIGAKU), SUM(KAI_TAI_ZEIGAKU)
                               ,
                               SUM(SIEN_ZEN_ZEIGAKU), SUM(SIEN_TAI_ZEIGAKU)
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                               ,SUM(KDM_ZEN_ZEIGAKU)
                               INTO MWWNENZEI.ZENZEI,     MWWNENZEI.TAIZEI,
                               MWWNENZEI.IRY_ZENZEI, MWWNENZEI.IRY_TAIZEI,
                               MWWNENZEI.KAI_ZENZEI, MWWNENZEI.KAI_TAIZEI
                               ,
                               MWWNENZEI.SIEN_ZENZEI, MWWNENZEI.SIEN_TAIZEI
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                                , MWWNENZEI.KDM_ZENZEI
                          FROM ZLBTKIBETSU_CAL
                          WHERE ((KAMOKU_CD       = C_NKAMOKU_NEW      -- 科目コード=0
                                  AND KAMOKUS_CD  = C_NKAMOKUS_FUTU)   -- 科目詳細コード:普通
                                 OR (KAMOKU_CD    = C_NKAMOKU_BASE     -- 科目コード=15
                                  AND KAMOKUS_CD  = C_NKAMOKUS_TOKU))  -- 科目詳細コード:特別
                            AND KOKU_SETAI_NO   = I_NSETAI
                            AND SANTEIDANTAI_CD = I_NDANTAI
                            AND TSUCHI_NO       = I_NTSUCHI_NO
                            AND CHOTEINENDO     = NLCHOTEI_NENDO
                            AND NENDOBUN        = NLNENDO_BUN
                            AND SYS_TANMATSU_NO = I_VTANMATSU;

                        --全体退職税額合計と医療+支援退職税額合計が同じ金額であることを確認
                        IF MWWNENZEI.TAIZEI = MWWNENZEI.IRY_TAIZEI + MWWNENZEI.SIEN_TAIZEI
                                          AND MWWNENZEI.TAIZEI = NLIRY_TAI_NENZEI  + NLSIEN_TAI_NENZEI THEN
                            --１つ前の更新で全体退職税額は更新されず、医療+支援退職税額を調整しているはずで
                            --医療+支援退職税額で全体退職税額を更新してあげる
                            UPDATE ZLBTKIBETSU_CAL
                              SET TAI_ZEIGAKU = IR_TAI_ZEIGAKU + SIEN_TAI_ZEIGAKU
                              WHERE KAMOKU_CD       = C_NKAMOKU_NEW      -- 科目コード=0
                                AND KAMOKUS_CD      = C_NKAMOKUS_FUTU    
                                AND KOKU_SETAI_NO   = I_NSETAI
                                AND SANTEIDANTAI_CD = I_NDANTAI
                                AND TSUCHI_NO       = I_NTSUCHI_NO
                                AND CHOTEINENDO     = NLCHOTEI_NENDO
                                AND NENDOBUN        = NLNENDO_BUN
                                AND SYS_TANMATSU_NO = I_VTANMATSU;
                        END IF;
                    END IF;
                  END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARI 税額更新(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
            ELSE
                IF MWWNENZEI.ZENZEI >= 0 THEN
                    BEGIN
                        UPDATE ZLBTKIBETSU_CAL
                           SET ZEN_ZEIGAKU     = ZEN_ZEIGAKU     + MWWNENZEI.ZENZEI,
                               TAI_ZEIGAKU     = TAI_ZEIGAKU     + MWWNENZEI.TAIZEI,
                               IR_ZEN_ZEIGAKU  = IR_ZEN_ZEIGAKU  + MWWNENZEI.IRY_ZENZEI,
                               IR_TAI_ZEIGAKU  = IR_TAI_ZEIGAKU  + MWWNENZEI.IRY_TAIZEI,
                               KAI_ZEN_ZEIGAKU = KAI_ZEN_ZEIGAKU + MWWNENZEI.KAI_ZENZEI,
                               KAI_TAI_ZEIGAKU = KAI_TAI_ZEIGAKU + MWWNENZEI.KAI_TAIZEI
                               ,
                               SIEN_ZEN_ZEIGAKU = SIEN_ZEN_ZEIGAKU + MWWNENZEI.SIEN_ZENZEI,
                               SIEN_TAI_ZEIGAKU = SIEN_TAI_ZEIGAKU + MWWNENZEI.SIEN_TAIZEI
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                               ,KDM_ZEN_ZEIGAKU =  KDM_ZEN_ZEIGAKU + MWWNENZEI.KDM_ZENZEI
                         WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                           AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                           AND KOKU_SETAI_NO   = I_NSETAI          
                           AND SANTEIDANTAI_CD = I_NDANTAI
                           AND CHOTEINENDO     = NLCHOTEI_NENDO    
                           AND NENDOBUN        = NLNENDO_BUN       
                           AND TSUCHI_NO       = I_NTSUCHI_NO
                           AND RONRIKIBETSU    = NWENDRKIBETSU
                           AND SYS_TANMATSU_NO = I_VTANMATSU;
                    EXCEPTION
                        WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARI 税額更新(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                    END;
                ELSE
                    BEGIN
                        -- 計算期別降順(科目コード=0)カーソル
                        FOR RWKIBETSU IN CWKIBETSUD_NEW LOOP
                            -- 期別の大きい順に読込み税額の差分を割振る
                            IF RWKIBETSU.RONRIKIBETSU <= NWENDRKIBETSU THEN
                                -- 全体税額
                                IF RWKIBETSU.ZEN_ZEIGAKU >= (MWWNENZEI.ZENZEI * -1) THEN
                                    RWKIBETSU.ZEN_ZEIGAKU := RWKIBETSU.ZEN_ZEIGAKU + MWWNENZEI.ZENZEI;
                                    MWWNENZEI.ZENZEI := 0;
                                ELSE
                                    MWWNENZEI.ZENZEI := MWWNENZEI.ZENZEI + RWKIBETSU.ZEN_ZEIGAKU;
                                    RWKIBETSU.ZEN_ZEIGAKU := 0;
                                END IF;
                                -- 退職税額
                                IF RWKIBETSU.TAI_ZEIGAKU >= (MWWNENZEI.TAIZEI * -1) THEN
                                    RWKIBETSU.TAI_ZEIGAKU := RWKIBETSU.TAI_ZEIGAKU + MWWNENZEI.TAIZEI;
                                    MWWNENZEI.TAIZEI := 0;
                                ELSE
                                    MWWNENZEI.TAIZEI := MWWNENZEI.TAIZEI + RWKIBETSU.TAI_ZEIGAKU;
                                    RWKIBETSU.TAI_ZEIGAKU := 0;
                                END IF;
                                -- 医療全体税額
                                IF RWKIBETSU.IR_ZEN_ZEIGAKU >= (MWWNENZEI.IRY_ZENZEI * -1) THEN
                                    RWKIBETSU.IR_ZEN_ZEIGAKU := RWKIBETSU.IR_ZEN_ZEIGAKU + MWWNENZEI.IRY_ZENZEI;
                                    MWWNENZEI.IRY_ZENZEI := 0;
                                ELSE
                                    MWWNENZEI.IRY_ZENZEI := MWWNENZEI.IRY_ZENZEI + RWKIBETSU.IR_ZEN_ZEIGAKU;
                                    RWKIBETSU.IR_ZEN_ZEIGAKU := 0;
                                END IF;
                                -- 医療退職税額
                                IF RWKIBETSU.IR_TAI_ZEIGAKU >= (MWWNENZEI.IRY_TAIZEI * -1) THEN
                                    RWKIBETSU.IR_TAI_ZEIGAKU := RWKIBETSU.IR_TAI_ZEIGAKU + MWWNENZEI.IRY_TAIZEI;
                                    MWWNENZEI.IRY_TAIZEI := 0;
                                ELSE
                                    MWWNENZEI.IRY_TAIZEI := MWWNENZEI.IRY_TAIZEI + RWKIBETSU.IR_TAI_ZEIGAKU;
                                    RWKIBETSU.IR_TAI_ZEIGAKU := 0;
                                END IF;
                                -- 介護全体税額
                                IF RWKIBETSU.KAI_ZEN_ZEIGAKU >= (MWWNENZEI.KAI_ZENZEI * -1) THEN
                                    RWKIBETSU.KAI_ZEN_ZEIGAKU := RWKIBETSU.KAI_ZEN_ZEIGAKU + MWWNENZEI.KAI_ZENZEI;
                                    MWWNENZEI.KAI_ZENZEI := 0;
                                ELSE
                                    MWWNENZEI.KAI_ZENZEI := MWWNENZEI.KAI_ZENZEI + RWKIBETSU.KAI_ZEN_ZEIGAKU;
                                    RWKIBETSU.KAI_ZEN_ZEIGAKU := 0;
                                END IF;
                                -- 介護退職税額
                                IF RWKIBETSU.KAI_TAI_ZEIGAKU >= (MWWNENZEI.KAI_TAIZEI * -1) THEN
                                    RWKIBETSU.KAI_TAI_ZEIGAKU := RWKIBETSU.KAI_TAI_ZEIGAKU + MWWNENZEI.KAI_TAIZEI;
                                    MWWNENZEI.KAI_TAIZEI := 0;
                                ELSE
                                    MWWNENZEI.KAI_TAIZEI := MWWNENZEI.KAI_TAIZEI + RWKIBETSU.KAI_TAI_ZEIGAKU;
                                    RWKIBETSU.KAI_TAI_ZEIGAKU := 0;
                                END IF;
                                -- 支援全体税額
                                IF (RWKIBETSU.SIEN_ZEN_ZEIGAKU >= (MWWNENZEI.SIEN_ZENZEI * -1)) THEN
                                    RWKIBETSU.SIEN_ZEN_ZEIGAKU := RWKIBETSU.SIEN_ZEN_ZEIGAKU + MWWNENZEI.SIEN_ZENZEI;
                                    MWWNENZEI.SIEN_ZENZEI := 0;
                                ELSE
                                    MWWNENZEI.SIEN_ZENZEI := MWWNENZEI.SIEN_ZENZEI + RWKIBETSU.SIEN_ZEN_ZEIGAKU;
                                    RWKIBETSU.SIEN_ZEN_ZEIGAKU := 0;
                                END IF;
                                -- 支援退職税額
                                IF (RWKIBETSU.SIEN_TAI_ZEIGAKU >= (MWWNENZEI.SIEN_TAIZEI * -1)) THEN
                                    RWKIBETSU.SIEN_TAI_ZEIGAKU := RWKIBETSU.SIEN_TAI_ZEIGAKU + MWWNENZEI.SIEN_TAIZEI;
                                    MWWNENZEI.SIEN_TAIZEI := 0;
                                ELSE
                                    MWWNENZEI.SIEN_TAIZEI := MWWNENZEI.SIEN_TAIZEI + RWKIBETSU.SIEN_TAI_ZEIGAKU;
                                    RWKIBETSU.SIEN_TAI_ZEIGAKU := 0;
                                END IF; 
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
                                --  子ども全体税額
                                IF (RWKIBETSU.KDM_ZEN_ZEIGAKU >= (MWWNENZEI.KDM_ZENZEI * -1)) THEN
                                    RWKIBETSU.KDM_ZEN_ZEIGAKU := RWKIBETSU.KDM_ZEN_ZEIGAKU + MWWNENZEI.KDM_ZENZEI;
                                    MWWNENZEI.KDM_ZENZEI := 0;
                                ELSE
                                    MWWNENZEI.KDM_ZENZEI := MWWNENZEI.KDM_ZENZEI + RWKIBETSU.KDM_ZEN_ZEIGAKU;
                                    RWKIBETSU.KDM_ZEN_ZEIGAKU := 0;
                                END IF;
--  2025/08/11 ZCZL.WANGMINGYANG ADD END
                                IF RWKIBETSU.ZEN_ZEIGAKU = 0 THEN
                                    -- 医療全体税額
                                    IF RWKIBETSU.IR_ZEN_ZEIGAKU != 0 THEN
                                        MWWNENZEI.IRY_ZENZEI := MWWNENZEI.IRY_ZENZEI + RWKIBETSU.IR_ZEN_ZEIGAKU;
                                        RWKIBETSU.IR_ZEN_ZEIGAKU := 0;
                                    END IF;
                                    -- 介護全体税額
                                    IF RWKIBETSU.KAI_ZEN_ZEIGAKU != 0 THEN
                                        MWWNENZEI.KAI_ZENZEI := MWWNENZEI.KAI_ZENZEI + RWKIBETSU.KAI_ZEN_ZEIGAKU;
                                        RWKIBETSU.KAI_ZEN_ZEIGAKU := 0;
                                    END IF;
                                    -- 支援全体税額
                                    IF RWKIBETSU.SIEN_ZEN_ZEIGAKU != 0 THEN
                                        MWWNENZEI.SIEN_ZENZEI := MWWNENZEI.SIEN_ZENZEI + RWKIBETSU.SIEN_ZEN_ZEIGAKU;
                                        RWKIBETSU.SIEN_ZEN_ZEIGAKU := 0;
                                    END IF;
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
                                    --  子ども全体税額
                                    IF RWKIBETSU.KDM_ZEN_ZEIGAKU != 0 THEN
                                        MWWNENZEI.KDM_ZENZEI := MWWNENZEI.KDM_ZENZEI + RWKIBETSU.KDM_ZEN_ZEIGAKU;
                                        RWKIBETSU.KDM_ZEN_ZEIGAKU := 0;
                                    END IF;
--  2025/08/11 ZCZL.WANGMINGYANG ADD END
                                END IF;
                                IF RWKIBETSU.ZEN_ZEIGAKU = 0 OR RWKIBETSU.TAI_ZEIGAKU = 0 THEN
                                    -- 医療退職税額
                                    IF RWKIBETSU.IR_TAI_ZEIGAKU != 0 THEN
                                        MWWNENZEI.IRY_TAIZEI := MWWNENZEI.IRY_TAIZEI + RWKIBETSU.IR_TAI_ZEIGAKU;
                                        RWKIBETSU.IR_TAI_ZEIGAKU := 0;
                                    END IF;
                                    -- 介護退職税額
                                    IF RWKIBETSU.KAI_TAI_ZEIGAKU != 0 THEN
                                        MWWNENZEI.KAI_TAIZEI := MWWNENZEI.KAI_TAIZEI + RWKIBETSU.KAI_TAI_ZEIGAKU;
                                        RWKIBETSU.KAI_TAI_ZEIGAKU := 0;
                                    END IF;
                                    -- 支援退職税額
                                    IF RWKIBETSU.SIEN_TAI_ZEIGAKU != 0 THEN
                                        MWWNENZEI.SIEN_TAIZEI := MWWNENZEI.SIEN_TAIZEI + RWKIBETSU.SIEN_TAI_ZEIGAKU;
                                        RWKIBETSU.SIEN_TAI_ZEIGAKU := 0;
                                    END IF;
                                END IF;
                                BEGIN
                                    -- 計算期別更新
                                    UPDATE ZLBTKIBETSU_CAL
                                       SET ZEN_ZEIGAKU     = RWKIBETSU.ZEN_ZEIGAKU,
                                           TAI_ZEIGAKU     = RWKIBETSU.TAI_ZEIGAKU,
                                           IR_ZEN_ZEIGAKU  = RWKIBETSU.IR_ZEN_ZEIGAKU,
                                           IR_TAI_ZEIGAKU  = RWKIBETSU.IR_TAI_ZEIGAKU,
                                           KAI_ZEN_ZEIGAKU = RWKIBETSU.KAI_ZEN_ZEIGAKU,
                                           KAI_TAI_ZEIGAKU = RWKIBETSU.KAI_TAI_ZEIGAKU
                                           ,
                                           SIEN_ZEN_ZEIGAKU = RWKIBETSU.SIEN_ZEN_ZEIGAKU,
                                           SIEN_TAI_ZEIGAKU = RWKIBETSU.SIEN_TAI_ZEIGAKU
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                                           ,KDM_ZEN_ZEIGAKU = RWKIBETSU.KDM_ZEN_ZEIGAKU
                                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW     -- 科目コード=0
                                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                                       AND KOKU_SETAI_NO   = I_NSETAI          
                                       AND SANTEIDANTAI_CD = I_NDANTAI
                                       AND CHOTEINENDO     = NLCHOTEI_NENDO    
                                       AND NENDOBUN        = NLNENDO_BUN       
                                       AND TSUCHI_NO       = I_NTSUCHI_NO
                                       AND RONRIKIBETSU    = RWKIBETSU.RONRIKIBETSU
                                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        NLRTN := C_NERR;
                                        VLMSG := 'SUBSAIKIWARI 計算期別更新(国保世帯番号='||
                                                 I_NSETAI||')'||SQLERRM;
                                        RETURN;
                                END;
                            END IF;
                            EXIT WHEN MWWNENZEI.ZENZEI = 0 AND MWWNENZEI.TAIZEI = 0;
                        END LOOP;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NLRTN := C_NERR;
                            VLMSG := 'SUBSAIKIWARI 計算期別降順取得(国保世帯番号='||
                                     I_NSETAI||')'||SQLERRM;
                            RETURN;
                    END;
                END IF;
            END IF;
        END IF;
        FOR NWIX2 IN 1..NWMAXIX LOOP
          --開始論理期別が納期月外で対象の期別ＣＡＬが存在しない場合は、それ以降の期別をセット
            IF MWKIBETSU(NWIX2).RKIBETSU >= NWSTRRKIBETSU THEN
                NWENDIX := NWIX2;
                EXIT;  
            END IF;
        END LOOP;
----- 再期割(手順④,⑤)
        FOR NWIX2 IN REVERSE 1..NWENDIX LOOP
            IF MWKIBETSU(NWIX2).RKIBETSU < NWSTRRKIBETSU THEN
                NWSTRRKIBETSU := MWKIBETSU(NWIX2).RKIBETSU;
            END IF;
            -- 按分処理１回目
            SUBSAIKIWARISUB(MWNENZEI,
                            NWSTRRKIBETSU,
                            NWENDRKIBETSU,
                            MWKIBETSU(1).RKIBETSU);     --再期割処理
            IF NLRTN != C_NOK THEN
                RETURN;
            END IF;
            -- マイナス期割の存在チェック
            SUBMINUSKISU(C_NKAMOKU_NEW, NWCNT);         -- 06 マイナス期数算出
            IF NLRTN != C_NOK THEN
                RETURN;
            END IF;
            IF NLRTN = C_NOK AND NWCNT = 0 THEN
              NWCNT := FUNC_IS_TAISHOKUZEI_DIVIDED;
            END IF;
            IF NWCNT > 0 THEN
                NWZEIGAKUTMP := 0;
                NWTAIZEITMP  := 0;
                -- まだマイナス期割が存在する
                BEGIN
                    SELECT COUNT(*), SUM(ZEN_ZEIGAKU), SUM(TAI_ZEIGAKU)
                      INTO NWCNT,    NWZENZEITMP,      NWTAIZEITMP
                      FROM ZLBTKIBETSU_CAL
                     WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                       AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                       AND KOKU_SETAI_NO   = I_NSETAI          
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND CHOTEINENDO     = NLCHOTEI_NENDO    
                       AND NENDOBUN        = NLNENDO_BUN       
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND RONRIKIBETSU BETWEEN NWSTRRKIBETSU AND NWENDRKIBETSU
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBSAIKIWARI 計算期別取得(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                        RETURN;
                END;
                IF NWCNT > 0 THEN
                    BEGIN
                        -- 退職税額の存在する期別で退職税額を振り直し
                        UPDATE ZLBTKIBETSU_CAL
                           SET TAI_ZEIGAKU = DECODE(NWZENZEITMP, 0, 0,
                                             TRUNC((ZEN_ZEIGAKU / NWZENZEITMP) * NWTAIZEITMP))
                         WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                           AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                           AND KOKU_SETAI_NO   = I_NSETAI          
                           AND SANTEIDANTAI_CD = I_NDANTAI
                           AND CHOTEINENDO     = NLCHOTEI_NENDO    
                           AND NENDOBUN        = NLNENDO_BUN       
                           AND TSUCHI_NO       = I_NTSUCHI_NO
                           AND RONRIKIBETSU BETWEEN NWSTRRKIBETSU AND NWENDRKIBETSU
                           AND SYS_TANMATSU_NO = I_VTANMATSU;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NLRTN := C_NERR;
                            VLMSG := 'SUBSAIKIWARI 計算期別更新(国保世帯番号='||
                                     I_NSETAI||')'||SQLERRM;
                            RETURN;
                    END;
                    BEGIN
                        SELECT SUM(TAI_ZEIGAKU) INTO NWZENZEITMP
                          FROM ZLBTKIBETSU_CAL
                         WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                           AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                           AND KOKU_SETAI_NO   = I_NSETAI          
                           AND SANTEIDANTAI_CD = I_NDANTAI
                           AND CHOTEINENDO     = NLCHOTEI_NENDO    
                           AND NENDOBUN        = NLNENDO_BUN       
                           AND TSUCHI_NO       = I_NTSUCHI_NO
                           AND RONRIKIBETSU BETWEEN NWSTRRKIBETSU AND NWENDRKIBETSU
                           AND SYS_TANMATSU_NO = I_VTANMATSU;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NLRTN := C_NERR;
                            VLMSG := 'SUBSAIKIWARI 計算期別取得(国保世帯番号='||
                                     I_NSETAI||')'||SQLERRM;
                            RETURN;
                    END;
                    BEGIN
                        -- 退職税額の存在する期別で退職税額を振り直し
                        UPDATE ZLBTKIBETSU_CAL
                           SET TAI_ZEIGAKU = TAI_ZEIGAKU + (NWTAIZEITMP - NWZENZEITMP)
                         WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                           AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                           AND KOKU_SETAI_NO   = I_NSETAI          
                           AND SANTEIDANTAI_CD = I_NDANTAI
                           AND CHOTEINENDO     = NLCHOTEI_NENDO    
                           AND NENDOBUN        = NLNENDO_BUN       
                           AND TSUCHI_NO       = I_NTSUCHI_NO
                           AND RONRIKIBETSU    = NWSTRRKIBETSU
                           AND SYS_TANMATSU_NO = I_VTANMATSU;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NLRTN := C_NERR;
                            VLMSG := 'SUBSAIKIWARI 計算期別更新(国保世帯番号='||
                                     I_NSETAI||')'||SQLERRM;
                            RETURN;
                    END;
                    -- 按分処理２回目
                    SUBSAIKIWARISUB(MWNENZEI,
                                    NWSTRRKIBETSU,
                                    NWENDRKIBETSU);     -- 09 再期割処理
                    IF NLRTN != C_NOK THEN
                        RETURN;
                    END IF;
                END IF;
            END IF;
            SUBCHOSEI(MWNENZEI,
                      NWSTRRKIBETSU,
                      NWENDRKIBETSU,                    -- 08 マイナス調整
                      MWKIBETSU);  
            IF NLRTN != C_NOK THEN
                RETURN;
            END IF;
            SUBMINUSKISU(C_NKAMOKU_NEW, NWCNT);         -- 06 マイナス期数算出
            IF NLRTN != C_NOK THEN
                RETURN;
            END IF;
            EXIT WHEN NWCNT = 0;
        END LOOP;
      /******** 計算期別の税額チェック ********/
        --マイナスの期別を加算せずに税額をチェック
        SELECT DECODE(SUM(CASE WHEN IR_ZEN_ZEIGAKU  > 0 THEN IR_ZEN_ZEIGAKU  ELSE 0 END), NLIRY_ZEN_NENZEI, 0, 1)
             + DECODE(SUM(CASE WHEN IR_TAI_ZEIGAKU  > 0 THEN IR_TAI_ZEIGAKU  ELSE 0 END), NLIRY_TAI_NENZEI, 0, 1)
             + DECODE(SUM(CASE WHEN KAI_ZEN_ZEIGAKU > 0 THEN KAI_ZEN_ZEIGAKU ELSE 0 END), NLKAI_ZEN_NENZEI, 0, 1)
             + DECODE(SUM(CASE WHEN KAI_TAI_ZEIGAKU > 0 THEN KAI_TAI_ZEIGAKU ELSE 0 END), NLKAI_TAI_NENZEI, 0, 1)
             + DECODE(SUM(CASE WHEN SIEN_ZEN_ZEIGAKU > 0 THEN SIEN_ZEN_ZEIGAKU ELSE 0 END), NLSIEN_ZEN_NENZEI, 0, 1)
             + DECODE(SUM(CASE WHEN SIEN_TAI_ZEIGAKU > 0 THEN SIEN_TAI_ZEIGAKU ELSE 0 END), NLSIEN_TAI_NENZEI, 0, 1)
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
             + DECODE(SUM(CASE WHEN KDM_ZEN_ZEIGAKU > 0 THEN KDM_ZEN_ZEIGAKU ELSE 0 END), NLKDM_ZEN_NENZEI, 0, 1)
          INTO NWCNT
          FROM ZLBTKIBETSU_CAL
          WHERE ((KAMOKU_CD     = C_NKAMOKU_NEW      -- 科目コード=0
                AND KAMOKUS_CD  = C_NKAMOKUS_FUTU)   -- 科目詳細コード:普通
              OR (KAMOKU_CD     = C_NKAMOKU_BASE     -- 科目コード=15
                AND KAMOKUS_CD  = C_NKAMOKUS_TOKU))  -- 科目詳細コード:特別
            AND SYS_TANMATSU_NO = I_VTANMATSU;
        IF NWCNT > 0 THEN
          SELECT MIN(RONRIKIBETSU), MAX(RONRIKIBETSU)
            INTO NWSTRRKIBETSU, NWENDRKIBETSU
            FROM ZLBTKIBETSU_CAL
            WHERE KAMOKU_CD   = C_NKAMOKU_NEW
              AND KAMOKUS_CD  = C_NKAMOKUS_FUTU   
              AND SYS_TANMATSU_NO = I_VTANMATSU
              AND ZEN_ZEIGAKU > 0;
          SUBCHOSEI(MWNENZEI, NWSTRRKIBETSU, NWENDRKIBETSU
                   ,MWKIBETSU);  
        END IF;
----- 計算期別の更新(手順⑥)
        BEGIN
            UPDATE ZLBTKIBETSU_CAL A
               SET ZEN_ZEIGAKU     = (SELECT ZEN_ZEIGAKU FROM ZLBTKIBETSU_CAL
                                       WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                                         AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                                         AND KOKU_SETAI_NO   = I_NSETAI          
                                         AND SANTEIDANTAI_CD = I_NDANTAI
                                         AND CHOTEINENDO     = NLCHOTEI_NENDO    
                                         AND NENDOBUN        = NLNENDO_BUN       
                                         AND TSUCHI_NO       = I_NTSUCHI_NO
                                         AND RONRIKIBETSU    = A.RONRIKIBETSU
                                         AND SYS_TANMATSU_NO = I_VTANMATSU),
                   TAI_ZEIGAKU     = (SELECT TAI_ZEIGAKU FROM ZLBTKIBETSU_CAL
                                       WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                                         AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                                         AND KOKU_SETAI_NO   = I_NSETAI          
                                         AND SANTEIDANTAI_CD = I_NDANTAI
                                         AND CHOTEINENDO     = NLCHOTEI_NENDO    
                                         AND NENDOBUN        = NLNENDO_BUN       
                                         AND TSUCHI_NO       = I_NTSUCHI_NO
                                         AND RONRIKIBETSU    = A.RONRIKIBETSU
                                         AND SYS_TANMATSU_NO = I_VTANMATSU),
                   IR_ZEN_ZEIGAKU  = (SELECT IR_ZEN_ZEIGAKU FROM ZLBTKIBETSU_CAL
                                       WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                                         AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                                         AND KOKU_SETAI_NO   = I_NSETAI          
                                         AND SANTEIDANTAI_CD = I_NDANTAI
                                         AND CHOTEINENDO     = NLCHOTEI_NENDO    
                                         AND NENDOBUN        = NLNENDO_BUN       
                                         AND TSUCHI_NO       = I_NTSUCHI_NO
                                         AND RONRIKIBETSU    = A.RONRIKIBETSU
                                         AND SYS_TANMATSU_NO = I_VTANMATSU),
                   IR_TAI_ZEIGAKU  = (SELECT IR_TAI_ZEIGAKU FROM ZLBTKIBETSU_CAL
                                       WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                                         AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                                         AND KOKU_SETAI_NO   = I_NSETAI          
                                         AND SANTEIDANTAI_CD = I_NDANTAI
                                         AND CHOTEINENDO     = NLCHOTEI_NENDO    
                                         AND NENDOBUN        = NLNENDO_BUN       
                                         AND TSUCHI_NO       = I_NTSUCHI_NO
                                         AND RONRIKIBETSU    = A.RONRIKIBETSU
                                         AND SYS_TANMATSU_NO = I_VTANMATSU),
                   KAI_ZEN_ZEIGAKU = (SELECT KAI_ZEN_ZEIGAKU FROM ZLBTKIBETSU_CAL
                                       WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                                         AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                                         AND KOKU_SETAI_NO   = I_NSETAI          
                                         AND SANTEIDANTAI_CD = I_NDANTAI
                                         AND CHOTEINENDO     = NLCHOTEI_NENDO    
                                         AND NENDOBUN        = NLNENDO_BUN       
                                         AND TSUCHI_NO       = I_NTSUCHI_NO
                                         AND RONRIKIBETSU    = A.RONRIKIBETSU
                                         AND SYS_TANMATSU_NO = I_VTANMATSU),
                   KAI_TAI_ZEIGAKU = (SELECT KAI_TAI_ZEIGAKU FROM ZLBTKIBETSU_CAL
                                       WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                                         AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                                         AND KOKU_SETAI_NO   = I_NSETAI          
                                         AND SANTEIDANTAI_CD = I_NDANTAI
                                         AND CHOTEINENDO     = NLCHOTEI_NENDO    
                                         AND NENDOBUN        = NLNENDO_BUN       
                                         AND TSUCHI_NO       = I_NTSUCHI_NO
                                         AND RONRIKIBETSU    = A.RONRIKIBETSU
                                         AND SYS_TANMATSU_NO = I_VTANMATSU)
                                     ,
                   SIEN_ZEN_ZEIGAKU = (SELECT SIEN_ZEN_ZEIGAKU FROM ZLBTKIBETSU_CAL
                                       WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                                         AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                                         AND KOKU_SETAI_NO   = I_NSETAI
                                         AND SANTEIDANTAI_CD = I_NDANTAI
                                         AND CHOTEINENDO     = NLCHOTEI_NENDO
                                         AND NENDOBUN        = NLNENDO_BUN
                                         AND TSUCHI_NO       = I_NTSUCHI_NO
                                         AND RONRIKIBETSU    = A.RONRIKIBETSU
                                         AND SYS_TANMATSU_NO = I_VTANMATSU),
                   SIEN_TAI_ZEIGAKU = (SELECT SIEN_TAI_ZEIGAKU FROM ZLBTKIBETSU_CAL
                                       WHERE KAMOKU_CD       = C_NKAMOKU_NEW
                                         AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                                         AND KOKU_SETAI_NO   = I_NSETAI
                                         AND SANTEIDANTAI_CD = I_NDANTAI
                                         AND CHOTEINENDO     = NLCHOTEI_NENDO
                                         AND NENDOBUN        = NLNENDO_BUN
                                         AND TSUCHI_NO       = I_NTSUCHI_NO
                                         AND RONRIKIBETSU    = A.RONRIKIBETSU
                                         AND SYS_TANMATSU_NO = I_VTANMATSU)
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
                  ,KDM_ZEN_ZEIGAKU  =  (SELECT KDM_ZEN_ZEIGAKU FROM ZLBTKIBETSU_CAL
                                        WHERE KAMOKU_CD      = C_NKAMOKU_NEW
                                         AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
                                         AND KOKU_SETAI_NO   = I_NSETAI
                                         AND SANTEIDANTAI_CD = I_NDANTAI
                                         AND CHOTEINENDO     = NLCHOTEI_NENDO
                                         AND NENDOBUN        = NLNENDO_BUN
                                         AND TSUCHI_NO       = I_NTSUCHI_NO
                                         AND RONRIKIBETSU    = A.RONRIKIBETSU
                                         AND SYS_TANMATSU_NO = I_VTANMATSU)
--  2025/08/11 ZCZL.WANGMINGYANG ADD END
             WHERE KAMOKU_CD       = C_NKAMOKU_BASE
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU    
               AND KOKU_SETAI_NO   = I_NSETAI           
               AND SANTEIDANTAI_CD = I_NDANTAI          -- 算定団体コード
               AND CHOTEINENDO     = NLCHOTEI_NENDO     
               AND NENDOBUN        = NLNENDO_BUN        
               AND TSUCHI_NO       = I_NTSUCHI_NO       -- 通知書番号
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        EXCEPTION
            WHEN OTHERS THEN
                NLRTN := C_NERR;
                VLMSG := 'SUBSAIKIWARI 計算期別更新(国保世帯番号='||
                         I_NSETAI||')'||SQLERRM;
                RETURN;
        END;
        -- 不要な計算期別を削除
        BEGIN
            DELETE FROM ZLBTKIBETSU_CAL
             WHERE KAMOKU_CD       = C_NKAMOKU_NEW
               AND KAMOKUS_CD      = C_NKAMOKUS_FUTU   
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
    END SUBSAIKIWARI;
-------------------------------------------------------------------------------
-- 04 計算期別更新
-------------------------------------------------------------------------------
    PROCEDURE SUBUPDATE(I_NSHU_KBN  IN  NUMBER,
                        I_NIX       IN  NUMBER) IS
    BEGIN
        IF I_NSHU_KBN = C_NSHU_ZEN THEN         -- 全体処理
            UPDATE ZLBTKIBETSU_CAL
               SET IR_ZEN_ZEIGAKU  = MLIRY_ZEIGAKU(I_NIX),
                   KAI_ZEN_ZEIGAKU = MLKAI_ZEIGAKU(I_NIX)
                   , SIEN_ZEN_ZEIGAKU = MLSIEN_ZEIGAKU(I_NIX)
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                    ,KDM_ZEN_ZEIGAKU = MLKDM_ZEIGAKU(I_NIX)
             WHERE KOKU_SETAI_NO   = I_NSETAI          
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND CHOTEINENDO     = NLCHOTEI_NENDO    
               AND NENDOBUN        = NLNENDO_BUN       
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND RONRIKIBETSU    = MLRONRIKIBETSU(I_NIX)
               AND KAMOKUS_CD      = MLKAMOKUSHOSAI(I_NIX)  
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        ELSE                                    -- 退職処理
            UPDATE ZLBTKIBETSU_CAL
               SET IR_TAI_ZEIGAKU  = MLIRY_ZEIGAKU(I_NIX),
                   KAI_TAI_ZEIGAKU = MLKAI_ZEIGAKU(I_NIX)
                   , SIEN_TAI_ZEIGAKU = MLSIEN_ZEIGAKU(I_NIX) 
             WHERE KOKU_SETAI_NO   = I_NSETAI          
               AND SANTEIDANTAI_CD = I_NDANTAI
               AND CHOTEINENDO     = NLCHOTEI_NENDO    
               AND NENDOBUN        = NLNENDO_BUN       
               AND TSUCHI_NO       = I_NTSUCHI_NO
               AND RONRIKIBETSU    = MLRONRIKIBETSU(I_NIX)
               AND KAMOKUS_CD      = MLKAMOKUSHOSAI(I_NIX)  
               AND SYS_TANMATSU_NO = I_VTANMATSU;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            NLRTN := C_NERR;
            VLMSG := 'SUBUPDATE 計算期別更新(国保世帯番号='||
                     I_NSETAI||')'||SQLERRM;
    END SUBUPDATE;
-------------------------------------------------------------------------------
-- 03-2 賦課試算用 更正前期別取得
--      処理区分＝退職は無視、更正前期別より取得
-------------------------------------------------------------------------------
    PROCEDURE SUBGETKIBETSUTS(I_NSHU_KBN  IN NUMBER,
                              I_RWKIBETSU IN ZLBTKIBETSU_CAL%ROWTYPE) IS
    BEGIN
        IF I_NSHU_KBN = C_NSHU_ZEN THEN         -- 全体処理
            BEGIN
                SELECT IR_ZEN_ZEIGAKU, KAI_ZEN_ZEIGAKU, SIEN_ZEN_ZEIGAKU, ZEN_ZEIGAKU 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                  ,KDM_ZEN_ZEIGAKU
                  INTO NLFUKA_IRY_ZEI, NLFUKA_KAI_ZEI, NLFUKA_SIEN_ZEI,  NLFUKA_ZEN_ZEI
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                  ,NLFUKA_KDM_ZEI
                  FROM ZLBTKIBETSU_TS
                 WHERE KAMOKU_CD       = I_RWKIBETSU.KAMOKU_CD
                   AND KAMOKUS_CD      = I_RWKIBETSU.KAMOKUS_CD
                   AND KOKU_SETAI_NO   = I_RWKIBETSU.KOKU_SETAI_NO   
                   AND SANTEIDANTAI_CD = I_RWKIBETSU.SANTEIDANTAI_CD
                   AND CHOTEINENDO     = I_RWKIBETSU.CHOTEINENDO
                   AND NENDOBUN        = I_RWKIBETSU.NENDOBUN
                   AND TSUCHI_NO       = I_RWKIBETSU.TSUCHI_NO
                   AND RONRIKIBETSU    = I_RWKIBETSU.RONRIKIBETSU
                   AND SYS_TANMATSU_NO = I_RWKIBETSU.SYS_TANMATSU_NO;
                   NLFUKA_TAI_ZEI := 0;        -- 退職税額は0固定
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NLFUKA_IRY_ZEI := 0;
                    NLFUKA_KAI_ZEI := 0;
                    NLFUKA_ZEN_ZEI := 0;
                    NLFUKA_TAI_ZEI := 0;
                    NLFUKA_SIEN_ZEI := 0;
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                    NLFUKA_KDM_ZEI := 0;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIBETSUTS 更正前期別全体税額取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        ELSE                                    -- 退職処理では全て0固定
            NLFUKA_IRY_ZEI := 0;
            NLFUKA_KAI_ZEI := 0;
            NLFUKA_ZEN_ZEI := 0;
            NLFUKA_TAI_ZEI := 0;
            NLFUKA_SIEN_ZEI := 0;
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
            NLFUKA_KDM_ZEI := 0;
        END IF;
    END SUBGETKIBETSUTS;
-------------------------------------------------------------------------------
-- 03-1 賦課期別取得
-------------------------------------------------------------------------------
    PROCEDURE SUBGETKIBETSU(I_NSHU_KBN  IN NUMBER,
                            I_RWKIBETSU IN ZLBTKIBETSU_CAL%ROWTYPE) IS
    BEGIN
        IF I_NSHU_KBN = C_NSHU_ZEN THEN         -- 全体処理
            BEGIN
                SELECT IR_ZEN_ZEIGAKU, KAI_ZEN_ZEIGAKU, SIEN_ZEN_ZEIGAKU, ZEN_ZEIGAKU,    TAI_ZEIGAKU 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                  ,KDM_ZEN_ZEIGAKU
                  INTO NLFUKA_IRY_ZEI, NLFUKA_KAI_ZEI,  NLFUKA_SIEN_ZEI, NLFUKA_ZEN_ZEI, NLFUKA_TAI_ZEI 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                  ,NLFUKA_KDM_ZEI
                  FROM ZLBTKIBETSU_N
                 WHERE KAMOKU_CD       = I_RWKIBETSU.KAMOKU_CD
                   AND KAMOKUS_CD      = I_RWKIBETSU.KAMOKUS_CD
                   AND KOKU_SETAI_NO   = I_RWKIBETSU.KOKU_SETAI_NO   
                   AND SANTEIDANTAI_CD = I_RWKIBETSU.SANTEIDANTAI_CD
                   AND CHOTEINENDO     = I_RWKIBETSU.CHOTEINENDO
                   AND NENDOBUN        = I_RWKIBETSU.NENDOBUN
                   AND TSUCHI_NO       = I_RWKIBETSU.TSUCHI_NO
                   AND RONRIKIBETSU    = I_RWKIBETSU.RONRIKIBETSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NLFUKA_IRY_ZEI := 0;
                    NLFUKA_KAI_ZEI := 0;
                    NLFUKA_ZEN_ZEI := 0;
                    NLFUKA_TAI_ZEI := 0;
                    NLFUKA_SIEN_ZEI := 0;
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                    NLFUKA_KDM_ZEI := 0;
                WHEN OTHERS THEN 
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIBETSU 賦課期別全体税額取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        ELSE                                    -- 退職処理
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
            NLFUKA_KDM_ZEI := 0;
            BEGIN
                SELECT IR_TAI_ZEIGAKU, KAI_TAI_ZEIGAKU, SIEN_TAI_ZEIGAKU, ZEN_ZEIGAKU, TAI_ZEIGAKU
                  INTO NLFUKA_IRY_ZEI, NLFUKA_KAI_ZEI,  NLFUKA_SIEN_ZEI, NLFUKA_ZEN_ZEI, NLFUKA_TAI_ZEI
                  FROM ZLBTKIBETSU_N
                 WHERE KAMOKU_CD       = I_RWKIBETSU.KAMOKU_CD
                   AND KAMOKUS_CD      = I_RWKIBETSU.KAMOKUS_CD
                   AND KOKU_SETAI_NO   = I_RWKIBETSU.KOKU_SETAI_NO   
                   AND SANTEIDANTAI_CD = I_RWKIBETSU.SANTEIDANTAI_CD
                   AND CHOTEINENDO     = I_RWKIBETSU.CHOTEINENDO
                   AND NENDOBUN        = I_RWKIBETSU.NENDOBUN
                   AND TSUCHI_NO       = I_RWKIBETSU.TSUCHI_NO
                   AND RONRIKIBETSU    = I_RWKIBETSU.RONRIKIBETSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NLFUKA_IRY_ZEI := 0;
                    NLFUKA_KAI_ZEI := 0;
                    NLFUKA_ZEN_ZEI := 0;
                    NLFUKA_TAI_ZEI := 0;
                    NLFUKA_SIEN_ZEI := 0;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIBETSU 賦課期別退職税額取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        END IF;
    END SUBGETKIBETSU;
-------------------------------------------------------------------------------
-- 02 主処理
-------------------------------------------------------------------------------
    PROCEDURE SUBMAIN(I_NSHU_KBN IN NUMBER) IS
        NWIX            NUMBER(2);
        NWMAX_INDEX     NUMBER(2);      -- INDEX最大値
        -- 計算期別カーソル
        CURSOR CWKIBETSU IS
            SELECT * FROM ZLBTKIBETSU_CAL
             WHERE KOKU_SETAI_NO   = I_NSETAI       
               AND SANTEIDANTAI_CD = I_NDANTAI      -- 算定団体コード
               AND CHOTEINENDO     = NLCHOTEI_NENDO 
               AND NENDOBUN        = NLNENDO_BUN    
               AND TSUCHI_NO       = I_NTSUCHI_NO   -- 通知書番号
               AND SYS_TANMATSU_NO = I_VTANMATSU    -- 端末番号
             ORDER BY KAMOKUS_CD, RONRIKIBETSU;     -- 科目詳細, 論理期別(昇順)
    BEGIN
        NWIX            := 0;
        NLIRY_ABGAI_ZEI := 0;       -- 医療対象外税額
        NLKAI_ABGAI_ZEI := 0;       -- 介護対象外税額
        NLSIEN_ABGAI_ZEI := 0;      --支援対象外税額 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
        NLKDM_ABGAI_ZEI := 0;        --子ども対象外税額
        -- 按分対象/対象外税額を算出
        BEGIN
            FOR RWKIBETSU IN CWKIBETSU LOOP
                IF I_NJIKKOU_KBN != C_NTEST THEN    -- 実行区分が「賦課試算」以外
                    -- 賦課期別より対象税額を取得
                    SUBGETKIBETSU(I_NSHU_KBN, RWKIBETSU);   -- 03-1 賦課期別取得
                ELSE                                -- 「賦課試算」の場合
                    -- 更正前期別より対象税額を取得
                    SUBGETKIBETSUTS(I_NSHU_KBN, RWKIBETSU); -- 03-2 更正前期別取得
                END IF;
                EXIT WHEN NLRTN != C_NOK;
                -- 按分対象期の判定(全期按分OR全体税額OR退職税額に差額有り?)
                --条件:【賦課最新の各年税額あり】かつ【計算の対応する年税額なし】
                -- の場合、全期按分と同様の処理
                IF NLSYORI_KBN          =  C_NSYORI_ZENKI OR       -- 処理区分が全期按分
                   RWKIBETSU.ZEN_ZEIGAKU != NLFUKA_ZEN_ZEI OR
                   RWKIBETSU.TAI_ZEIGAKU != NLFUKA_TAI_ZEI OR
                   (NLSYORI_KBN = C_NSYORI_SABUN AND                --条件
                    ((NLFUKA_IRY_ZENZEI > 0 AND NLIRY_ZEN_NENZEI = 0) OR
                     (NLFUKA_IRY_TAIZEI > 0 AND NLIRY_TAI_NENZEI = 0) OR
                     (NLFUKA_KAI_ZENZEI > 0 AND NLKAI_ZEN_NENZEI = 0) OR
                     (NLFUKA_KAI_TAIZEI > 0 AND NLKAI_TAI_NENZEI = 0) OR
                     (NLFUKA_SIEN_ZENZEI > 0 AND NLSIEN_ZEN_NENZEI = 0) OR 
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応                     
--                     (NLFUKA_SIEN_TAIZEI > 0 AND NLSIEN_TAI_NENZEI = 0))) THEN
                     (NLFUKA_SIEN_TAIZEI > 0 AND NLSIEN_TAI_NENZEI = 0) OR
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                     (NLFUKA_KDM_ZENZEI > 0 AND NLKDM_ZEN_NENZEI = 0))) THEN
                    -- 按分対象期の計算期別を保持
                    NWIX := NWIX + 1;
                    MLRONRIKIBETSU(NWIX) := RWKIBETSU.RONRIKIBETSU; -- 論理期別
                    MLKAMOKUSHOSAI(NWIX) := RWKIBETSU.KAMOKUS_CD;   -- 科目詳細
                    IF I_NSHU_KBN = C_NSHU_ZEN THEN     -- 全体処理
                        MLZEIGAKU(NWIX) := RWKIBETSU.ZEN_ZEIGAKU;   -- 全体税額
                    ELSE                                -- 退職処理
                        MLZEIGAKU(NWIX) := RWKIBETSU.TAI_ZEIGAKU;   -- 退職税額
                        MLZENZEI(NWIX)  := RWKIBETSU.KAI_ZEN_ZEIGAKU;   -- 介護全体税額
                        MLSIENZENZEI(NWIX)  := RWKIBETSU.SIEN_ZEN_ZEIGAKU;  --支援全体税額
                    END IF;
                ELSE
                    -- 按分対象外期の税額合計算出
                    NLIRY_ABGAI_ZEI := NLIRY_ABGAI_ZEI + NLFUKA_IRY_ZEI;
                    NLKAI_ABGAI_ZEI := NLKAI_ABGAI_ZEI + NLFUKA_KAI_ZEI;
                    NLSIEN_ABGAI_ZEI := NLSIEN_ABGAI_ZEI + NLFUKA_SIEN_ZEI; 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                    NLKDM_ABGAI_ZEI := NLKDM_ABGAI_ZEI + NLFUKA_KDM_ZEI;
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                NLRTN := C_NERR;
                VLMSG := 'SUBMAIN 計算期別取得(国保世帯番号='||
                         I_NSETAI||')'||SQLERRM;
        END;
        -- 按分比率対象税額の算出
        IF NLRTN = C_NOK AND NWIX != 0 THEN     -- 按分対象が１期もなければ按分処理を行なわない
            -- 按分対象税額=年税額-按分対象外税額
            IF I_NSHU_KBN = C_NSHU_ZEN THEN     -- 全体処理
                NLIRY_ABTAI_ZEI := NLIRY_ZEN_NENZEI - NLIRY_ABGAI_ZEI;
                NLKAI_ABTAI_ZEI := NLKAI_ZEN_NENZEI - NLKAI_ABGAI_ZEI;
                NLSIEN_ABTAI_ZEI := NLSIEN_ZEN_NENZEI - NLSIEN_ABGAI_ZEI;
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                NLKDM_ABTAI_ZEI := NLKDM_ZEN_NENZEI - NLKDM_ABGAI_ZEI;
            ELSE
                NLIRY_ABTAI_ZEI := NLIRY_TAI_NENZEI - NLIRY_ABGAI_ZEI;
                NLKAI_ABTAI_ZEI := NLKAI_TAI_NENZEI - NLKAI_ABGAI_ZEI;
                NLSIEN_ABTAI_ZEI := NLSIEN_TAI_NENZEI - NLSIEN_ABGAI_ZEI;
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                NLKDM_ABTAI_ZEI := 0;
            END IF;
            -- 期別内訳算出(調整期以外)
            NWMAX_INDEX     := NWIX;
            NLIRY_ABGAI_ZEI := 0;
            NLKAI_ABGAI_ZEI := 0;
            NLSIEN_ABGAI_ZEI := 0;
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
            NLKDM_ABGAI_ZEI := 0;
            IF NWMAX_INDEX > 1 THEN
                FOR NWIX IN 2..NWMAX_INDEX LOOP
                    -- 介護算出 ****************************************************************
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--                    IF (NLIRY_ABTAI_ZEI = 0 AND NLSIEN_ABTAI_ZEI = 0) OR (NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI + NLKAI_ABTAI_ZEI) = 0 THEN 
                      IF (NLIRY_ABTAI_ZEI = 0 AND NLSIEN_ABTAI_ZEI = 0 AND NLKDM_ABTAI_ZEI = 0) OR (NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI + NLKAI_ABTAI_ZEI + NLKDM_ABTAI_ZEI) = 0 THEN
                        MLIRY_ZEIGAKU(NWIX) := 0;
                        MLSIEN_ZEIGAKU(NWIX) := 0;
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                        MLKDM_ZEIGAKU(NWIX) := 0;
                    ELSE
                        IF NLKAI_ABTAI_ZEI <= 0 THEN
                            -- 介護の按分対象税額がマイナスの場合按分しない
                            MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX);
                        ELSE
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE START 1.1.200.000: 子ども子育て支援金対応
--                            MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) * ((NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI) /
--                                                   (NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI + NLKAI_ABTAI_ZEI));      
                            MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) * ((NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI + NLKDM_ABTAI_ZEI) /
                                                   (NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI + NLKAI_ABTAI_ZEI + NLKDM_ABTAI_ZEI));   
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE END
                        END IF;
                    END IF;
--該当期別の退職税額\0の場合は介護全体内訳=介護退職内訳にさせない
                    IF I_NSHU_KBN != C_NSHU_ZEN AND NLKAI_ZEN_NENZEI = NLKAI_TAI_NENZEI AND MLZEIGAKU(NWIX) <> 0 THEN
                        MLKAI_ZEIGAKU(NWIX) := MLZENZEI(NWIX);
                        MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) - MLKAI_ZEIGAKU(NWIX);
                    ELSE
                        MLKAI_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) - MLIRY_ZEIGAKU(NWIX);
                    END IF;
                    -- 按分結果積上加算
                    NLKAI_ABGAI_ZEI := NLKAI_ABGAI_ZEI + MLKAI_ZEIGAKU(NWIX);
                    -- 税額より介護分マイナス(医療と支援の税額)
                    MLZEIGAKU(NWIX) := MLZEIGAKU(NWIX) - MLKAI_ZEIGAKU(NWIX);
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE START 1.1.200.000: 子ども子育て支援金対応
--                   -- 医療・支援算出 ******************************************************* 
                     -- 支援算出 *******************************************************
--                    IF NLIRY_ABTAI_ZEI = 0 OR (NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI) = 0 THEN
                    IF (NLIRY_ABTAI_ZEI = 0 AND NLKDM_ABTAI_ZEI = 0) OR (NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI + NLKDM_ABTAI_ZEI) = 0 THEN 
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE END
                        MLIRY_ZEIGAKU(NWIX) := 0; 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                        MLKDM_ZEIGAKU(NWIX) := 0;
                    ELSE
                        IF NLSIEN_ABTAI_ZEI <= 0 THEN
                            -- 支援の按分対象税額がマイナスの場合按分しない
                            MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX);
                        ELSE
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE START 1.1.200.000: 子ども子育て支援金対応
--                            MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) * (NLIRY_ABTAI_ZEI /
--                                                   (NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI));
                            MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) * ((NLIRY_ABTAI_ZEI + NLKDM_ABTAI_ZEI) / 
                                                   (NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI + NLKDM_ABTAI_ZEI));
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE END
                        END IF;
                    END IF;
--該当期別の退職税額\0の場合は支援全体内訳=支援退職内訳にさせない
                    IF I_NSHU_KBN != C_NSHU_ZEN AND NLSIEN_ZEN_NENZEI = NLSIEN_TAI_NENZEI AND MLZEIGAKU(NWIX) <> 0 THEN
                        MLSIEN_ZEIGAKU(NWIX) := MLSIENZENZEI(NWIX);
                        MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) - MLSIEN_ZEIGAKU(NWIX);
                    ELSE
                        MLSIEN_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) - MLIRY_ZEIGAKU(NWIX);
                    END IF;
                    -- 按分結果積上加算
--  2025/08/11 ZCZL.WANGMINGYANG DELETE 1.1.200.000: 子ども子育て支援金対応
--                    NLIRY_ABGAI_ZEI := NLIRY_ABGAI_ZEI + MLIRY_ZEIGAKU(NWIX);
                    NLSIEN_ABGAI_ZEI := NLSIEN_ABGAI_ZEI + MLSIEN_ZEIGAKU(NWIX);
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
                    -- 税額より支援分マイナス(医療と子どもの税額)
                    MLZEIGAKU(NWIX) := MLZEIGAKU(NWIX) - MLSIEN_ZEIGAKU(NWIX); 
                    -- 医療・子ども算出
                    IF NLIRY_ABTAI_ZEI = 0  OR (NLIRY_ABTAI_ZEI + NLKDM_ABTAI_ZEI) = 0 THEN
                       MLIRY_ZEIGAKU(NWIX) := 0;
                    ELSE
                      IF NLKDM_ABTAI_ZEI <= 0 THEN
                         -- 子どもの按分対象税額がマイナスの場合按分しない
                         MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX);
                      ELSE
                         MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) * (NLIRY_ABTAI_ZEI /
                                                (NLIRY_ABTAI_ZEI + NLKDM_ABTAI_ZEI));
                      END IF;
                    END IF;
                    -- 該当期別の退職税額\0の場合は子ども全体内訳=子ども退職内訳にさせない
                    IF I_NSHU_KBN != C_NSHU_ZEN THEN
                       MLKDM_ZEIGAKU(NWIX) := 0;
                       MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX);
                    ELSE
                       MLKDM_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) - MLIRY_ZEIGAKU(NWIX);
                    END IF;
                       -- 按分結果積上加算
                       NLIRY_ABGAI_ZEI := NLIRY_ABGAI_ZEI + MLIRY_ZEIGAKU(NWIX);
                       NLKDM_ABGAI_ZEI := NLKDM_ABGAI_ZEI + MLKDM_ZEIGAKU(NWIX);
--  2025/08/11 ZCZL.WANGMINGYANG ADD END                    
                    -- 計算期別更新
                    SUBUPDATE(I_NSHU_KBN, NWIX);        -- 04 計算期別更新
                    EXIT WHEN NLRTN != C_NOK;
                END LOOP;
            END IF;
            -- 期別内訳算出(調整期)
            MLIRY_ZEIGAKU(1) := 0;  -- 医療税額
            MLKAI_ZEIGAKU(1) := 0;  -- 介護税額
            MLSIEN_ZEIGAKU(1) := 0; --支援税額
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
            MLKDM_ZEIGAKU(1) := 0;  --子ども税額
            IF NLRTN = C_NOK AND NWMAX_INDEX != 0 THEN
                FOR NWIX IN 1..NWMAX_INDEX LOOP
                    IF MLZEIGAKU(NWIX) != 0 THEN
                        MLIRY_ZEIGAKU(NWIX) := MLIRY_ZEIGAKU(NWIX) +
                                               (NLIRY_ABTAI_ZEI - NLIRY_ABGAI_ZEI);
                        MLKAI_ZEIGAKU(NWIX) := MLKAI_ZEIGAKU(NWIX) +
                                               (NLKAI_ABTAI_ZEI - NLKAI_ABGAI_ZEI);
                        MLSIEN_ZEIGAKU(NWIX) := MLSIEN_ZEIGAKU(NWIX) +
                                               (NLSIEN_ABTAI_ZEI - NLSIEN_ABGAI_ZEI);
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
                        MLKDM_ZEIGAKU(NWIX) := MLKDM_ZEIGAKU(NWIX) +
                                               (NLKDM_ABTAI_ZEI - NLKDM_ABGAI_ZEI); 
--  2025/08/11 ZCZL.WANGMINGYANG ADD END
                        -- 計算期別更新
                        SUBUPDATE(I_NSHU_KBN, NWIX);        -- 04 計算期別更新
                        EXIT;
                    END IF;
                END LOOP;
                IF NLRTN = C_NOK AND MLZEIGAKU(1) = 0 THEN
                    -- 計算期別更新(調整期)
                    SUBUPDATE(I_NSHU_KBN, 1);               -- 04 計算期別更新
                END IF;
            END IF;
        END IF;
    END SUBMAIN;
-------------------------------------------------------------------------------
-- 01-2 賦課試算用 年税額取得
--      退職年税額の取得は行なわない
-------------------------------------------------------------------------------
    PROCEDURE SUBGETKIHONTS IS
        NWCHOTEI_NENDO          NUMBER;
        NWNENDO_BUN             NUMBER;
    BEGIN
        -- 個人取得
        BEGIN
            SELECT COUNT(*)  INTO IHON_GENZON_CNT FROM ZLBTKOJIN_CAL
               WHERE KOKU_SETAI_NO   = I_NSETAI
                 AND SANTEIDANTAI_CD = I_NDANTAI
                 AND TSUCHI_NO       = I_NTSUCHI_NO
                 AND SYS_TANMATSU_NO = I_VTANMATSU
                 AND SHIK_7          IN (1, 3, 11, 13);
        EXCEPTION
            WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHON 個人取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
        END;
        -- 計算基本より全体年税額を取得
        BEGIN
            IF I_NCHOTEI_NENDO = 0 THEN
              -- 引数に値がない場合
              SELECT CHOTEI_NENDO, NENDO_BUN, NENZEI
                INTO NWCHOTEI_NENDO, NWNENDO_BUN, NLIRY_ZEN_NENZEI
                FROM ZLBTKIHON_CAL
               WHERE KOKU_SETAI_NO   = I_NSETAI     
                 AND SANTEIDANTAI_CD = I_NDANTAI
                 AND TSUCHI_NO       = I_NTSUCHI_NO
                 AND SYS_TANMATSU_NO = I_VTANMATSU;
            ELSE
              SELECT CHOTEI_NENDO, NENDO_BUN, NENZEI
                INTO NWCHOTEI_NENDO, NWNENDO_BUN, NLIRY_ZEN_NENZEI
                FROM ZLBTKIHON_CAL
               WHERE KOKU_SETAI_NO   = I_NSETAI           
                 AND SANTEIDANTAI_CD = I_NDANTAI
                 AND TSUCHI_NO       = I_NTSUCHI_NO
                 AND CHOTEI_NENDO    = I_NCHOTEI_NENDO    
                 AND NENDO_BUN       = I_NNENDO_BUN       
                 AND SYS_TANMATSU_NO = I_VTANMATSU;
            END IF;
            NLCHOTEI_NENDO := NWCHOTEI_NENDO;
            NLNENDO_BUN := NWNENDO_BUN;
            -- 退職年税額は0固定
            NLIRY_TAI_NENZEI := 0;
        EXCEPTION
            WHEN OTHERS THEN
                NLRTN := C_NERR;
                VLMSG := 'SUBGETKIHONTS 計算基本取得(国保世帯番号='||
                         I_NSETAI||')'||SQLERRM;
        END;
        -- 計算介護基本より介護全体年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLKAI_ZEN_NENZEI FROM ZLBTKAI_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = I_NSETAI    
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND CHOTEI_NENDO = NLCHOTEI_NENDO 
                   AND NENDO_BUN = NLNENDO_BUN       
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
                -- 介護退職年税額は0固定
                NLKAI_TAI_NENZEI := 0;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    -- 存在しない場合はエラーとしない
                    NLKAI_ZEN_NENZEI := 0;
                    NLKAI_TAI_NENZEI := 0;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHONTS 計算介護基本取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 計算支援基本より支援全体年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLSIEN_ZEN_NENZEI FROM ZLBTSIEN_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND CHOTEI_NENDO = NLCHOTEI_NENDO
                   AND NENDO_BUN = NLNENDO_BUN
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
                -- 支援退職年税額は0固定
                NLSIEN_TAI_NENZEI := 0;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    -- 存在しない場合はエラーとしない
                    NLSIEN_ZEN_NENZEI := 0;
                    NLSIEN_TAI_NENZEI := 0;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHONTS 計算支援基本取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        END IF; 
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
        --計算子ども基本より子ども全体年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLKDM_ZEN_NENZEI FROM ZLBTKDM_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND CHOTEI_NENDO = NLCHOTEI_NENDO
                   AND NENDO_BUN = NLNENDO_BUN
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
             EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    -- データがない場合
                    NLKDM_ZEN_NENZEI := 0;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHONTS 計算子ども基本取得(国保世帯番号='||
                                                  I_NSETAI||')'||SQLERRM;
            END;
        END IF;
--  2025/08/11 ZCZL.WANGMINGYANG ADD END
        NLFUKA_IRY_ZENZEI := 0;
        NLFUKA_IRY_TAIZEI := 0;
        NLFUKA_KAI_ZENZEI := 0;
        NLFUKA_KAI_TAIZEI := 0;
        NLFUKA_SIEN_ZENZEI := 0;
        NLFUKA_SIEN_TAIZEI := 0;
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
        NLFUKA_KDM_ZENZEI := 0;
        -- 賦課基本より全体年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLFUKA_IRY_ZENZEI FROM ZLBTKIHON_N
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEI_NENDO    = NWCHOTEI_NENDO
                   AND NENDO_BUN       = NWNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHONTS 賦課基本取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 賦課介護基本より介護全体年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLFUKA_KAI_ZENZEI FROM ZLBTKAI_KIHON_N
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEI_NENDO    = NWCHOTEI_NENDO
                   AND NENDO_BUN       = NWNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHONTS 賦課介護基本取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 賦課支援基本より支援全体年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLFUKA_SIEN_ZENZEI FROM ZLBTSIEN_KIHON_N
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEI_NENDO    = NWCHOTEI_NENDO
                   AND NENDO_BUN       = NWNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHONTS 賦課支援基本取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        END IF;
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
        -- 賦課子ども基本より子ども全体年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLFUKA_KDM_ZENZEI FROM ZLBTKDM_KIHON_N
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEI_NENDO    = NWCHOTEI_NENDO
                   AND NENDO_BUN       = NWNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHONTS 賦課子ども基本取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        END IF;
--  2025/08/11 ZCZL.WANGMINGYANG ADD END
    END SUBGETKIHONTS;
-------------------------------------------------------------------------------
-- 01-1 年税額取得
-------------------------------------------------------------------------------
    PROCEDURE SUBGETKIHON IS
        NWCHOTEI_NENDO          NUMBER;
        NWNENDO_BUN             NUMBER;
    BEGIN

        -- 個人取得
        BEGIN
            SELECT COUNT(*)  INTO IHON_GENZON_CNT FROM ZLBTKOJIN_CAL
               WHERE KOKU_SETAI_NO   = I_NSETAI
                 AND SANTEIDANTAI_CD = I_NDANTAI
                 AND TSUCHI_NO       = I_NTSUCHI_NO
                 AND SYS_TANMATSU_NO = I_VTANMATSU
                 AND SHIK_7          IN (1, 3, 11, 13);
        EXCEPTION
            WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHON 個人取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
        END;
        -- 計算基本より全体年税額を取得
        BEGIN
            IF I_NCHOTEI_NENDO = 0 THEN
              -- 引数に値がない場合
              SELECT CHOTEI_NENDO, NENDO_BUN, NENZEI
                INTO NWCHOTEI_NENDO, NWNENDO_BUN, NLIRY_ZEN_NENZEI
                FROM ZLBTKIHON_CAL
               WHERE KOKU_SETAI_NO   = I_NSETAI
                 AND SANTEIDANTAI_CD = I_NDANTAI
                 AND TSUCHI_NO       = I_NTSUCHI_NO
                 AND SYS_TANMATSU_NO = I_VTANMATSU;
            ELSE
              -- 引数に値がある場合
              SELECT CHOTEI_NENDO, NENDO_BUN, NENZEI
                INTO NWCHOTEI_NENDO, NWNENDO_BUN, NLIRY_ZEN_NENZEI
                FROM ZLBTKIHON_CAL
               WHERE KOKU_SETAI_NO   = I_NSETAI
                 AND SANTEIDANTAI_CD = I_NDANTAI
                 AND TSUCHI_NO       = I_NTSUCHI_NO
                 AND CHOTEI_NENDO = I_NCHOTEI_NENDO
                 AND NENDO_BUN = I_NNENDO_BUN
                 AND SYS_TANMATSU_NO = I_VTANMATSU;
            END IF;
            NLCHOTEI_NENDO := NWCHOTEI_NENDO;
            NLNENDO_BUN := NWNENDO_BUN;
            -- 計算退職より退職年税額を取得
            BEGIN
                SELECT NENZEI INTO NLIRY_TAI_NENZEI FROM ZLBTTAI_CAL
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND CHOTEI_NENDO = NLCHOTEI_NENDO 
                   AND NENDO_BUN = NLNENDO_BUN       
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHON 計算退職取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        EXCEPTION
            WHEN OTHERS THEN
                NLRTN := C_NERR;
                VLMSG := 'SUBGETKIHON 計算基本取得(国保世帯番号='||
                         I_NSETAI||')'||SQLERRM;
        END;
        -- 計算介護基本より介護全体年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLKAI_ZEN_NENZEI FROM ZLBTKAI_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND CHOTEI_NENDO = NLCHOTEI_NENDO 
                   AND NENDO_BUN = NLNENDO_BUN       
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
                -- 計算介護退職より介護退職年税額を取得
                BEGIN
                    SELECT NENZEI INTO NLKAI_TAI_NENZEI FROM ZLBTKAI_TAI_CAL
                     WHERE KOKU_SETAI_NO   = I_NSETAI
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND CHOTEI_NENDO = NLCHOTEI_NENDO 
                       AND NENDO_BUN = NLNENDO_BUN       
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBGETKIHON 計算介護退職取得(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                END;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    -- 存在しない場合はエラーとしない
                    NLKAI_ZEN_NENZEI := 0;
                    NLKAI_TAI_NENZEI := 0;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHON 計算介護基本取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 計算支援基本より支援全体年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLSIEN_ZEN_NENZEI FROM ZLBTSIEN_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND CHOTEI_NENDO = NLCHOTEI_NENDO
                   AND NENDO_BUN = NLNENDO_BUN
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
                -- 計算支援退職より支援退職年税額を取得
                BEGIN
                    SELECT NENZEI INTO NLSIEN_TAI_NENZEI FROM ZLBTSIEN_TAI_CAL
                     WHERE KOKU_SETAI_NO   = I_NSETAI
                       AND SANTEIDANTAI_CD = I_NDANTAI
                       AND TSUCHI_NO       = I_NTSUCHI_NO
                       AND CHOTEI_NENDO = NLCHOTEI_NENDO
                       AND NENDO_BUN = NLNENDO_BUN
                       AND SYS_TANMATSU_NO = I_VTANMATSU;
                EXCEPTION
                    WHEN OTHERS THEN
                        NLRTN := C_NERR;
                        VLMSG := 'SUBGETKIHON 計算支援退職取得(国保世帯番号='||
                                 I_NSETAI||')'||SQLERRM;
                END;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    -- 存在しない場合はエラーとしない
                    NLSIEN_ZEN_NENZEI := 0;
                    NLSIEN_TAI_NENZEI := 0;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHON 計算支援基本取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        END IF; 
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
        --計算子ども基本より子ども全体年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLKDM_ZEN_NENZEI FROM ZLBTKDM_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND TSUCHI_NO       = I_NTSUCHI_NO
                   AND CHOTEI_NENDO = NLCHOTEI_NENDO
                   AND NENDO_BUN = NLNENDO_BUN
                   AND SYS_TANMATSU_NO = I_VTANMATSU;
             EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    -- データがない場合
                    NLKDM_ZEN_NENZEI := 0;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHON 計算子ども基本取得(国保世帯番号='||
                                                  I_NSETAI||')'||SQLERRM;
            END;
        END IF;
--  2025/08/11 ZCZL.WANGMINGYANG ADD END
        NLFUKA_IRY_ZENZEI := 0;
        NLFUKA_IRY_TAIZEI := 0;
        NLFUKA_KAI_ZENZEI := 0;
        NLFUKA_KAI_TAIZEI := 0;
        NLFUKA_SIEN_ZENZEI := 0;
        NLFUKA_SIEN_TAIZEI := 0;
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
        NLFUKA_KDM_ZENZEI := 0;
        -- 賦課基本より全体年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLFUKA_IRY_ZENZEI FROM ZLBTKIHON_N
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEI_NENDO    = NWCHOTEI_NENDO
                   AND NENDO_BUN       = NWNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHON 賦課基本取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 賦課退職より退職年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLFUKA_IRY_TAIZEI FROM ZLBTTAI_N
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEI_NENDO    = NWCHOTEI_NENDO
                   AND NENDO_BUN       = NWNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHON 賦課退職取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 賦課介護基本より介護全体年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLFUKA_KAI_ZENZEI FROM ZLBTKAI_KIHON_N
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEI_NENDO    = NWCHOTEI_NENDO
                   AND NENDO_BUN       = NWNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHON 賦課介護基本取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 賦課介護退職より介護退職年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLFUKA_KAI_TAIZEI FROM ZLBTKAI_TAI_N
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEI_NENDO    = NWCHOTEI_NENDO
                   AND NENDO_BUN       = NWNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHON 賦課介護退職取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 賦課支援基本より支援全体年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLFUKA_SIEN_ZENZEI FROM ZLBTSIEN_KIHON_N
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEI_NENDO    = NWCHOTEI_NENDO
                   AND NENDO_BUN       = NWNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHON 賦課支援基本取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        END IF;
        -- 賦課支援退職より支援退職年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLFUKA_SIEN_TAIZEI FROM ZLBTSIEN_TAI_N
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEI_NENDO    = NWCHOTEI_NENDO
                   AND NENDO_BUN       = NWNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHON 賦課支援退職取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        END IF;
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
        -- 賦課子ども基本より子ども全体年税額を取得
        IF NLRTN = C_NOK THEN
            BEGIN
                SELECT NENZEI INTO NLFUKA_KDM_ZENZEI FROM ZLBTKDM_KIHON_N
                 WHERE KOKU_SETAI_NO   = I_NSETAI
                   AND SANTEIDANTAI_CD = I_NDANTAI
                   AND CHOTEI_NENDO    = NWCHOTEI_NENDO
                   AND NENDO_BUN       = NWNENDO_BUN
                   AND TSUCHI_NO       = I_NTSUCHI_NO;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NLRTN := C_NERR;
                    VLMSG := 'SUBGETKIHON 賦課子ども基本取得(国保世帯番号='||
                             I_NSETAI||')'||SQLERRM;
            END;
        END IF;
--  2025/08/11 ZCZL.WANGMINGYANG ADD END
    END SUBGETKIHON;
-------------------------------------------------------------------------------
-- 00-1 主処理2(マイナス期割内訳調整)
-------------------------------------------------------------------------------
    PROCEDURE SUBMAIN2(I_NSHU_KBN IN NUMBER) IS
        NWIX                NUMBER(2);
        NWMAX_INDEX         NUMBER(2);
        NLIRY_ABTAI_ZEI     NUMBER(10);     -- 按分対象 医療対象税額
        NLKAI_ABTAI_ZEI     NUMBER(10);     --          介護対象税額
        NLSIEN_ABTAI_ZEI    NUMBER(10);     --          支援対象税額 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
        NLKDM_ABTAI_ZEI    NUMBER(10);      --          子ども対象税額
        -- 計算期別カーソル
        CURSOR CWKIBETSU IS
            SELECT * FROM ZLBTKIBETSU_CAL
             WHERE KOKU_SETAI_NO   = I_NSETAI       -- 国保世帯番号
               AND SANTEIDANTAI_CD = I_NDANTAI      -- 算定団体コード
               AND CHOTEINENDO     = NLCHOTEI_NENDO -- 調定年度
               AND NENDOBUN        = NLNENDO_BUN    -- 年度分
               AND TSUCHI_NO       = I_NTSUCHI_NO   -- 通知書番号
               AND SYS_TANMATSU_NO = I_VTANMATSU    -- 端末番号
             ORDER BY KAMOKUS_CD, RONRIKIBETSU;     -- 科目詳細, 論理期別(昇順)

    BEGIN
        NWIX := 0;

        IF I_NSHU_KBN = C_NSHU_ZEN THEN     -- 全体処理
            NLIRY_ABTAI_ZEI := NLIRY_ZEN_NENZEI;
            NLKAI_ABTAI_ZEI := NLKAI_ZEN_NENZEI;
            NLSIEN_ABTAI_ZEI:= NLSIEN_ZEN_NENZEI;
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
            NLKDM_ABTAI_ZEI:= NLKDM_ZEN_NENZEI;
        ELSE
            NLIRY_ABTAI_ZEI := NLIRY_TAI_NENZEI;
            NLKAI_ABTAI_ZEI := NLKAI_TAI_NENZEI;
            NLSIEN_ABTAI_ZEI:= NLSIEN_TAI_NENZEI;
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
            NLKDM_ABTAI_ZEI := 0;
        END IF;

        FOR RWKIBETSU IN CWKIBETSU LOOP
            -- 按分対象期の計算期別を保持
            NWIX := NWIX + 1;
            MLRONRIKIBETSU(NWIX) := RWKIBETSU.RONRIKIBETSU;       -- 論理期別
            MLKAMOKUSHOSAI(NWIX) := RWKIBETSU.KAMOKUS_CD;         -- 科目詳細
            IF I_NSHU_KBN = C_NSHU_ZEN THEN     -- 全体処理
                MLZEIGAKU(NWIX)    := RWKIBETSU.ZEN_ZEIGAKU;      -- 全体税額
            ELSE                                -- 退職処理
                MLZEIGAKU(NWIX)    := RWKIBETSU.TAI_ZEIGAKU;      -- 退職税額
                MLZENZEI(NWIX)     := RWKIBETSU.KAI_ZEN_ZEIGAKU;  -- 介護全体税額
                MLSIENZENZEI(NWIX) := RWKIBETSU.SIEN_ZEN_ZEIGAKU; -- 支援全体税額
            END IF;
        END LOOP;

        -- 期別内訳算出(調整期以外)
        NWMAX_INDEX      := NWIX;
        NLIRY_ABGAI_ZEI  := 0;
        NLKAI_ABGAI_ZEI  := 0;
        NLSIEN_ABGAI_ZEI := 0;
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
        NLKDM_ABGAI_ZEI := 0;

        IF NWMAX_INDEX > 1 THEN
            FOR NWIX IN 2..NWMAX_INDEX LOOP
                -- 介護算出 ****************************************************************
                -- 按分実行(医療+支援分算出)
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--                IF (NLIRY_ABTAI_ZEI = 0 AND NLSIEN_ABTAI_ZEI = 0) OR (NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI + NLKAI_ABTAI_ZEI) = 0 THEN 
                IF (NLIRY_ABTAI_ZEI = 0 AND NLSIEN_ABTAI_ZEI = 0 AND NLKDM_ABTAI_ZEI = 0) OR  (NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI + NLKAI_ABTAI_ZEI + NLKDM_ABTAI_ZEI) = 0 THEN
                    --医療と支援の税額なし
                    MLIRY_ZEIGAKU(NWIX) := 0;
                    MLSIEN_ZEIGAKU(NWIX) := 0; 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                    MLKDM_ZEIGAKU(NWIX) := 0;
                ELSE
                    --医療と支援の税額有り
                    IF NLKAI_ABTAI_ZEI <= 0 THEN
                        -- 介護の按分対象税額がマイナスの場合按分しない
                        MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX);
                    ELSE 
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--                        MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) * ((NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI) / (NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI + NLKAI_ABTAI_ZEI));
                        MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) * ((NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI + NLKDM_ABTAI_ZEI) / (NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI + NLKAI_ABTAI_ZEI + NLKDM_ABTAI_ZEI));
                    END IF;
                END IF;
                -- 該当期の介護の内訳をセット
--該当期別の退職税額\0の場合は介護全体内訳=介護退職内訳にさせない
                IF I_NSHU_KBN != C_NSHU_ZEN AND NLKAI_ZEN_NENZEI = NLKAI_TAI_NENZEI AND MLZEIGAKU(NWIX) <> 0 THEN
                    -- 退職モードで介護の全体年税=退職年税であれば介護の該当期の全体額を退職額にセット
                    MLKAI_ZEIGAKU(NWIX) := MLZENZEI(NWIX);
                    MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) - MLKAI_ZEIGAKU(NWIX);
                ELSE
                    MLKAI_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) - MLIRY_ZEIGAKU(NWIX);
                END IF;
                -- 按分結果積上加算
                NLKAI_ABGAI_ZEI  := NLKAI_ABGAI_ZEI  + MLKAI_ZEIGAKU(NWIX);
                -- 該当期の税額より介護分をマイナス(医療と支援の税額)
                MLZEIGAKU(NWIX) := MLZEIGAKU(NWIX) - MLKAI_ZEIGAKU(NWIX);
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--                -- 医療・支援算出 *******************************************************
                -- 支援算出 *******************************************************
                -- 按分実行(医療分算出)
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--                IF NLIRY_ABTAI_ZEI = 0 OR (NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI) = 0 THEN 
                IF (NLIRY_ABTAI_ZEI = 0  AND NLKDM_ABTAI_ZEI = 0) OR (NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI + NLKDM_ABTAI_ZEI) = 0 THEN
                    --医療の税額なし
                    MLIRY_ZEIGAKU(NWIX) := 0; 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                    MLKDM_ZEIGAKU(NWIX) := 0;
                ELSE
                    --医療の税額有り
                    IF NLSIEN_ABTAI_ZEI <= 0 THEN
                        -- 支援の按分対象税額がマイナスの場合按分しない
                        MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX);
                    ELSE
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--                        MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) * (NLIRY_ABTAI_ZEI / (NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI));
                        MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) * ((NLIRY_ABTAI_ZEI  + NLKDM_ABTAI_ZEI)/ (NLIRY_ABTAI_ZEI + NLSIEN_ABTAI_ZEI + NLKDM_ABTAI_ZEI));
                    END IF;
                END IF;
                -- 該当期の支援の内訳をセット
--該当期別の退職税額\0の場合は支援全体内訳=支援退職内訳にさせない
                IF I_NSHU_KBN != C_NSHU_ZEN AND NLSIEN_ZEN_NENZEI = NLSIEN_TAI_NENZEI AND MLZEIGAKU(NWIX) <> 0 THEN
                    -- 退職モードで支援の全体年税=退職年税であれば支援の該当期の全体額を退職額にセット
                    MLSIEN_ZEIGAKU(NWIX) := MLSIENZENZEI(NWIX);
                    MLIRY_ZEIGAKU(NWIX)  := MLZEIGAKU(NWIX) - MLSIEN_ZEIGAKU(NWIX);
                ELSE
                    MLSIEN_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) - MLIRY_ZEIGAKU(NWIX);
                END IF;

                -- 按分結果積上加算
--  2025/08/11 ZCZL.WANGMINGYANG DELETE 1.1.200.000: 子ども子育て支援金対応
--                NLIRY_ABGAI_ZEI  := NLIRY_ABGAI_ZEI  + MLIRY_ZEIGAKU(NWIX);
                NLSIEN_ABGAI_ZEI := NLSIEN_ABGAI_ZEI + MLSIEN_ZEIGAKU(NWIX); 
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
                -- 税額より支援分マイナス(医療と子どもの税額)
                MLZEIGAKU(NWIX) := MLZEIGAKU(NWIX) - MLSIEN_ZEIGAKU(NWIX); 
                -- 医療・子ども算出
                IF NLIRY_ABTAI_ZEI = 0  OR (NLIRY_ABTAI_ZEI + NLKDM_ABTAI_ZEI) = 0 THEN
                   MLIRY_ZEIGAKU(NWIX) := 0;
                ELSE
                  IF NLKDM_ABTAI_ZEI <= 0 THEN
                     -- 子どもの按分対象税額がマイナスの場合按分しない
                     MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX);
                  ELSE
                     MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) * (NLIRY_ABTAI_ZEI / (NLIRY_ABTAI_ZEI + NLKDM_ABTAI_ZEI));
                  END IF;
                END IF;
                -- 該当期別の退職税額\0の場合は子ども全体内訳=子ども退職内訳にさせない
                IF I_NSHU_KBN != C_NSHU_ZEN THEN
                   MLKDM_ZEIGAKU(NWIX) := 0;
                   MLIRY_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX);
                ELSE
                   MLKDM_ZEIGAKU(NWIX) := MLZEIGAKU(NWIX) - MLIRY_ZEIGAKU(NWIX);
                END IF;
                   -- 按分結果積上加算
                   NLIRY_ABGAI_ZEI := NLIRY_ABGAI_ZEI + MLIRY_ZEIGAKU(NWIX);
                   NLKDM_ABGAI_ZEI := NLKDM_ABGAI_ZEI + MLKDM_ZEIGAKU(NWIX);
--  2025/08/11 ZCZL.WANGMINGYANG ADD END 
                -- 計算期別更新
                SUBUPDATE(I_NSHU_KBN, NWIX);        -- 04 計算期別更新
                EXIT WHEN NLRTN != C_NOK;
            END LOOP;
        END IF;

        -- 期別内訳算出(調整期)
        IF NLRTN = C_NOK AND NWMAX_INDEX != 0 THEN
            MLIRY_ZEIGAKU(1) := 0;  -- 医療税額
            MLKAI_ZEIGAKU(1) := 0;  -- 介護税額
            MLSIEN_ZEIGAKU(1) := 0; -- 支援税額
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
            MLKDM_ZEIGAKU(1) := 0; --子ども税額
--            -- 計算期別更新
            FOR NWIX IN 1..NWMAX_INDEX LOOP
                IF MLZEIGAKU(NWIX) != 0 THEN
                    MLIRY_ZEIGAKU(NWIX) := MLIRY_ZEIGAKU(NWIX) +
                                          (NLIRY_ABTAI_ZEI - NLIRY_ABGAI_ZEI);
                    MLKAI_ZEIGAKU(NWIX) := MLKAI_ZEIGAKU(NWIX) +
                                          (NLKAI_ABTAI_ZEI - NLKAI_ABGAI_ZEI);
                    MLSIEN_ZEIGAKU(NWIX) := MLSIEN_ZEIGAKU(NWIX) +
                                          (NLSIEN_ABTAI_ZEI - NLSIEN_ABGAI_ZEI); 
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
                    MLKDM_ZEIGAKU(NWIX) := MLKDM_ZEIGAKU(NWIX) + 
                                          (NLKDM_ABTAI_ZEI - NLKDM_ABGAI_ZEI);
--  2025/08/11 ZCZL.WANGMINGYANG ADD END
                    -- 計算期別更新
                    SUBUPDATE(I_NSHU_KBN, NWIX);        -- 04 計算期別更新
                    EXIT;
                END IF;
            END LOOP;
            IF NLRTN = C_NOK AND MLZEIGAKU(1) = 0 THEN
                -- 計算期別更新(調整期)
                SUBUPDATE(I_NSHU_KBN, 1);               -- 04 計算期別更新
            END IF;
        END IF;
    END SUBMAIN2;

-------------------------------------------------------------------------------
-- 01-1-2 仮算定期割（箕面市）対応
-------------------------------------------------------------------------------
    PROCEDURE PROCGET_KARI IS
      NZEN_ZEIGAKU            NUMBER(12);
      NTAI_ZEIGAKU            NUMBER(12);
      NWCHOTEI_NENDO          NUMBER(4);
      NWNENDO_BUN             NUMBER(4);
      IKAISHI_KIBETSU         PLS_INTEGER;
      IKAISHI_TSUKI           PLS_INTEGER;
      IX                      PLS_INTEGER;
      TYPE MTNUMARRAY8  IS TABLE OF NUMBER(8)  INDEX BY BINARY_INTEGER;
      MIRY_ZEI      MTNUMARRAY8;
      MIRY_TAI_ZEI  MTNUMARRAY8;
      MKAI_ZEI      MTNUMARRAY8;
      MKAI_TAI_ZEI  MTNUMARRAY8;
      MSIEN_ZEI      MTNUMARRAY8;
      MSIEN_TAI_ZEI  MTNUMARRAY8;
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
      MKDM_ZEI      MTNUMARRAY8;
      RwJCONS        KKATCT%ROWTYPE; 
           
      CURSOR CKIBETSU IS
        SELECT RONRIKIBETSU, IR_ZEN_ZEIGAKU, IR_TAI_ZEIGAKU, KAI_ZEN_ZEIGAKU, KAI_TAI_ZEIGAKU
              ,SIEN_ZEN_ZEIGAKU, SIEN_TAI_ZEIGAKU
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
              ,KDM_ZEN_ZEIGAKU
          FROM ZLBTKIBETSU_N
         WHERE KOKU_SETAI_NO   = I_NSETAI
           AND KAMOKUS_CD      = C_NKAMOKUS_FUTU  
           AND SANTEIDANTAI_CD = I_NDANTAI
           AND TSUCHI_NO       = I_NTSUCHI_NO
           AND CHOTEINENDO = NLCHOTEI_NENDO
           AND NENDOBUN = NLNENDO_BUN;
    BEGIN
      IF NLRTN = C_NOK THEN


        BEGIN
            -- コンスタント設定
             SELECT * INTO RwJCONS FROM KKATCT
             WHERE GYOUMUCODE    = 'ZLB'
               AND CTLPRMCODE  = '00ZANTEIKIWARI'
               AND GROUPCODE = '0000'
               AND CTLPRMSEQ = NLNENDO_BUN;
            
            IZANTEIKIWAI_JCONS := TO_NUMBER(SUBSTR(RwJCONS.CTLPRM, 1, 1));
        EXCEPTION
            WHEN OTHERS THEN
            -- データが取得出来ない場合は、そのままでOKとする。
            IZANTEIKIWAI_JCONS := 0 ;
        END;

        -- 本算定までに全部喪失チェック
        -- 全部喪失の場合は、年税額を仮算定税額とするかの判断
        IF  IZANTEIKIWAI_JCONS = 1 THEN
            IF  IHON_GENZON_CNT = 0 THEN
                IZANTEIKIWARI_FLG := 10 ;
            ELSE
                IZANTEIKIWARI_FLG := 0  ;
            END IF;
        ELSE
            IZANTEIKIWARI_FLG := 0  ;
        END IF;
        -- 基準日より論理期別を算出
        IKAISHI_TSUKI := TRUNC(I_NKIJUNBI - TRUNC(I_NKIJUNBI, -4), -2) / 100;
        IF IKAISHI_TSUKI < 4 THEN   -- ４月以前(1,2,3月→10,11,12)
          IKAISHI_KIBETSU := IKAISHI_TSUKI + 9;
        ELSE                        -- ４月以降(4,･･･,12月→1,･･･,9)
          IKAISHI_KIBETSU := IKAISHI_TSUKI - 3;
        END IF;
        FOR IX IN 1..12 LOOP
          MIRY_ZEI(IX)     := 0;
          MIRY_TAI_ZEI(IX) := 0;
          MKAI_ZEI(IX)     := 0;
          MKAI_TAI_ZEI(IX) := 0;
          MSIEN_ZEI(IX)     := 0;
          MSIEN_TAI_ZEI(IX) := 0;
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
          MKDM_ZEI(IX)      := 0;
        END LOOP;
        FOR CRKIBETSU IN CKIBETSU LOOP
          MIRY_ZEI(CRKIBETSU.RONRIKIBETSU)     := CRKIBETSU.IR_ZEN_ZEIGAKU;
          MIRY_TAI_ZEI(CRKIBETSU.RONRIKIBETSU) := CRKIBETSU.IR_TAI_ZEIGAKU;
          MKAI_ZEI(CRKIBETSU.RONRIKIBETSU)     := CRKIBETSU.KAI_ZEN_ZEIGAKU;
          MKAI_TAI_ZEI(CRKIBETSU.RONRIKIBETSU) := CRKIBETSU.KAI_TAI_ZEIGAKU;
          MSIEN_ZEI(CRKIBETSU.RONRIKIBETSU)     := CRKIBETSU.SIEN_ZEN_ZEIGAKU;
          MSIEN_TAI_ZEI(CRKIBETSU.RONRIKIBETSU) := CRKIBETSU.SIEN_TAI_ZEIGAKU; 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
          MKDM_ZEI(CRKIBETSU.RONRIKIBETSU)     := CRKIBETSU.KDM_ZEN_ZEIGAKU;
        END LOOP;
        --医療全体
        ZLBPK00010.PRCAL_ZANKINENZEI(0 + IZANTEIKIWARI_FLG, NLNENDO_BUN, IKAISHI_KIBETSU,       
                                    NLIRY_ZEN_NENZEI,
                                    MIRY_ZEI(1), MIRY_ZEI(2), MIRY_ZEI(3), MIRY_ZEI(4),
                                    NLIRY_ZEN_NENZEI);
        --医療退職
        ZLBPK00010.PRCAL_ZANKINENZEI(1 + IZANTEIKIWARI_FLG, NLNENDO_BUN, IKAISHI_KIBETSU,       
                                    NLIRY_TAI_NENZEI,
                                    MIRY_TAI_ZEI(1), MIRY_TAI_ZEI(2), MIRY_TAI_ZEI(3), MIRY_TAI_ZEI(4),
                                    NLIRY_TAI_NENZEI);
        --介護全体
        ZLBPK00010.PRCAL_ZANKINENZEI(0 + IZANTEIKIWARI_FLG, NLNENDO_BUN, IKAISHI_KIBETSU,       
                                    NLKAI_ZEN_NENZEI,
                                    MKAI_ZEI(1), MKAI_ZEI(2), MKAI_ZEI(3), MKAI_ZEI(4),
                                    NLKAI_ZEN_NENZEI);
        --介護退職
        ZLBPK00010.PRCAL_ZANKINENZEI(1 + IZANTEIKIWARI_FLG, NLNENDO_BUN, IKAISHI_KIBETSU,       
                                    NLKAI_TAI_NENZEI,
                                    MKAI_TAI_ZEI(1), MKAI_TAI_ZEI(2), MKAI_TAI_ZEI(3), MKAI_TAI_ZEI(4),
                                    NLKAI_TAI_NENZEI);
        --支援全体
        ZLBPK00010.PRCAL_ZANKINENZEI(0 + IZANTEIKIWARI_FLG, NLNENDO_BUN, IKAISHI_KIBETSU,       
                                    NLSIEN_ZEN_NENZEI,
                                    MSIEN_ZEI(1), MSIEN_ZEI(2), MSIEN_ZEI(3), MSIEN_ZEI(4),
                                    NLSIEN_ZEN_NENZEI);
        --支援退職
        ZLBPK00010.PRCAL_ZANKINENZEI(1 + IZANTEIKIWARI_FLG, NLNENDO_BUN, IKAISHI_KIBETSU,       
                                    NLSIEN_TAI_NENZEI,
                                    MSIEN_TAI_ZEI(1), MSIEN_TAI_ZEI(2), MSIEN_TAI_ZEI(3), MSIEN_TAI_ZEI(4),
                                    NLSIEN_TAI_NENZEI);
--  2025/08/11 ZCZL.WANGMINGYANG ADD START 1.1.200.000: 子ども子育て支援金対応
        --子ども全体分                            
        ZLBPK00010.PRCAL_ZANKINENZEI(0 + IZANTEIKIWARI_FLG, NLNENDO_BUN, IKAISHI_KIBETSU,
                                    NLKDM_ZEN_NENZEI, 
                                    MKDM_ZEI(1),MKDM_ZEI(2),MKDM_ZEI(3),MKDM_ZEI(4),
                                    NLKDM_ZEN_NENZEI); 
--  2025/08/11 ZCZL.WANGMINGYANG ADD END
       MIRY_ZEI.DELETE;
       MIRY_TAI_ZEI.DELETE;
       MKAI_ZEI.DELETE;
       MKAI_TAI_ZEI.DELETE;
       MSIEN_ZEI.DELETE;
       MSIEN_TAI_ZEI.DELETE; 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
       MKDM_ZEI.DELETE;
      END IF;
      IF NLRTN = C_NOK THEN
        NLFUKA_IRY_ZENZEI := 0;
        NLFUKA_IRY_TAIZEI := 0;
        NLFUKA_KAI_ZENZEI := 0;
        NLFUKA_KAI_TAIZEI := 0;
        NLFUKA_SIEN_ZENZEI := 0;
        NLFUKA_SIEN_TAIZEI := 0;
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
        NLFUKA_KDM_ZENZEI := 0;
        BEGIN
          SELECT SUM(IR_ZEN_ZEIGAKU), SUM(IR_TAI_ZEIGAKU), SUM(KAI_ZEN_ZEIGAKU), SUM(KAI_TAI_ZEIGAKU)
               , SUM(SIEN_ZEN_ZEIGAKU), SUM(SIEN_TAI_ZEIGAKU)
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                ,SUM(KDM_ZEN_ZEIGAKU)
            INTO NLFUKA_IRY_ZENZEI, NLFUKA_IRY_TAIZEI, NLFUKA_KAI_ZENZEI, NLFUKA_KAI_TAIZEI
               , NLFUKA_SIEN_ZENZEI, NLFUKA_SIEN_TAIZEI 
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
               ,NLFUKA_KDM_ZENZEI
            FROM ZLBTKIBETSU_N
           WHERE KOKU_SETAI_NO   = I_NSETAI
             AND SANTEIDANTAI_CD = I_NDANTAI
             AND TSUCHI_NO       = I_NTSUCHI_NO
             AND CHOTEINENDO = NLCHOTEI_NENDO
             AND NENDOBUN = NLNENDO_BUN;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NULL;
          WHEN OTHERS THEN
            NLRTN := C_NERR;
            VLMSG := 'PROCGET_KARI 賦課期別最新取得(国保世帯番号='||I_NSETAI||')'||SQLERRM;
        END;
      END IF;
    END PROCGET_KARI;
-------------------------------------------------------------------------------
-- 00 メイン
-------------------------------------------------------------------------------
BEGIN
----- 初期処理 -----
    NLRTN := C_NOK;
    VLMSG := NULL;
    NLSYORI_KBN := I_NSYORI_KBN;
----- 主処理 -----
    IF I_NJIKKOU_KBN != C_NTEST THEN    -- 実行区分が「賦課試算」以外
        -- 計算基本,計算退職,計算介護基本,計算介護退職より年税額を取得する
        SUBGETKIHON;                -- 01-1 年税額取得
        -- 仮算定中か判定
        IF i_NJIKKOU_KBN IN (C_NONLINE,C_NTEST) THEN
          IF ZLBPK00010.FCFFJKN2(411) = 1 THEN
            IZAN_MODE := ZLBPK00010.FCZANMODE_ONL(NLCHOTEI_NENDO, NLNENDO_BUN, I_NKIJUNBI);
          ELSE
            IZAN_MODE := 0;
          END IF;
        ELSE
          IZAN_MODE := ZLBPK00010.FCZANMODE(NLCHOTEI_NENDO, NLNENDO_BUN);
        END IF;
        --仮算定期割（箕面市）対応
        IF IZAN_MODE = 1 THEN
          PROCGET_KARI;
        END IF;
    ELSE                                -- 「賦課試算」の場合
        -- 計算基本,計算介護基本より年税額を取得する(退職年税額は0固定))
        SUBGETKIHONTS;              -- 01-2 賦課試算用 年税額取得
        -- 仮算定中か判定 
        IF i_NJIKKOU_KBN IN (C_NONLINE,C_NTEST) AND ZLBPK00010.FCFFJKN2(411) = 1 THEN
          IZAN_MODE := ZLBPK00010.FCZANMODE_ONL(NLCHOTEI_NENDO, NLNENDO_BUN, I_NKIJUNBI);
        ELSE
          IZAN_MODE := ZLBPK00010.FCZANMODE(NLCHOTEI_NENDO, NLNENDO_BUN);
        END IF;
        --仮算定期割（箕面市）対応
        IF IZAN_MODE = 1 THEN
          PROCGET_KARI;
        END IF;
    END IF;
    IF i_NJIKKOU_KBN IN (C_NONLINE,C_NTEST) AND IZAN_MODE = 1 THEN
      -- 特徴期割合計の取得
      BEGIN
        SELECT SUM(ZEN_ZEIGAKU)
          INTO NZEN_ZEIGAKU_TOKU
          FROM ZLBTKIBETSU_CAL
         WHERE KAMOKU_CD       = C_NKAMOKU_BASE
           AND KAMOKUS_CD      = C_NKAMOKUS_TOKU
           AND KOKU_SETAI_NO   = I_NSETAI
           AND SANTEIDANTAI_CD = I_NDANTAI
           AND CHOTEINENDO     = NLCHOTEI_NENDO
           AND NENDOBUN        = NLNENDO_BUN
           AND TSUCHI_NO       = I_NTSUCHI_NO
           AND SYS_TANMATSU_NO = I_VTANMATSU;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          NLRTN := C_NERR;
          VLMSG := '賦課期別全体額取得(国保世帯番号='||I_NSETAI||')'||SQLERRM;
      END;
      -- 特徴期割合計>仮算定税額の場合、計算期別内訳作成は行わない
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--      IF NZEN_ZEIGAKU_TOKU > NLIRY_ZEN_NENZEI + NLKAI_ZEN_NENZEI + NLSIEN_ZEN_NENZEI THEN
        IF NZEN_ZEIGAKU_TOKU > NLIRY_ZEN_NENZEI + NLKAI_ZEN_NENZEI + NLSIEN_ZEN_NENZEI + NLKDM_ZEN_NENZEI THEN
        GOTO EXIT;
      END IF;
    END IF;
    -- 全体税額の期別内訳算出処理
    IF NLRTN = C_NOK THEN
        SUBMAIN(C_NSHU_ZEN);        -- 02 主処理(全体分)
    END IF;
    -- 退職税額の期別内訳算出処理(賦課試算時は退職なし)
    IF NLRTN = C_NOK AND I_NJIKKOU_KBN != C_NTEST THEN
        SUBMAIN(C_NSHU_TAI);        -- 02 主処理(退職分)
    END IF;
    -- 再期割(マイナス調整)
    IF NLRTN = C_NOK THEN
        SUBSAIKIWARI;               -- 05 再期割
    END IF;
    /******************************/
    /* 全体税額の期別内訳算出処理 */
    /******************************/
    IF NLRTN = C_NOK THEN
        -- 期別の内訳にマイナスの金額があるか？(全体)
        BEGIN
          SELECT COUNT(*) INTO NlMAINASU_CNT FROM ZLBTKIBETSU_CAL
            WHERE KAMOKU_CD       = C_NKAMOKU_BASE
              AND KOKU_SETAI_NO   = I_NSETAI
              AND SANTEIDANTAI_CD = I_NDANTAI
              AND CHOTEINENDO     = NLCHOTEI_NENDO
              AND NENDOBUN        = NLNENDO_BUN
              AND TSUCHI_NO       = I_NTSUCHI_NO
              AND (IR_ZEN_ZEIGAKU < 0
              OR   KAI_ZEN_ZEIGAKU < 0
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--              OR   SIEN_ZEN_ZEIGAKU < 0)
              OR   SIEN_ZEN_ZEIGAKU < 0
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
              OR   KDM_ZEN_ZEIGAKU < 0)
              AND SYS_TANMATSU_NO = I_VTANMATSU;

        EXCEPTION
            WHEN OTHERS THEN
                NLRTN := C_NERR;
                VLMSG := '内訳マイナス期割カウント全体(国保世帯番号='||I_NSETAI||')'||SQLERRM;
        END;

        IF NLRTN = C_NOK AND (NlMAINASU_CNT = 0) THEN
              -- 期別の内訳の縦計が一致しているか？(全体)
          BEGIN
            SELECT CASE WHEN IR_ZEN_ZEIGAKU   <> NLIRY_ZEN_NENZEI  THEN 1
                        WHEN KAI_ZEN_ZEIGAKU  <> NLKAI_ZEN_NENZEI  THEN 1
                        WHEN SIEN_ZEN_ZEIGAKU <> NLSIEN_ZEN_NENZEI THEN 1
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                        WHEN KDM_ZEN_ZEIGAKU  <> NLKDM_ZEN_NENZEI  THEN 1
                        ELSE 0 END
                   INTO NlMAINASU_CNT
            FROM (SELECT SUM(IR_ZEN_ZEIGAKU)   AS IR_ZEN_ZEIGAKU,
                         SUM(KAI_ZEN_ZEIGAKU)  AS KAI_ZEN_ZEIGAKU,
                         SUM(SIEN_ZEN_ZEIGAKU) AS SIEN_ZEN_ZEIGAKU
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
                          ,SUM(KDM_ZEN_ZEIGAKU) AS KDM_ZEN_ZEIGAKU
                    FROM ZLBTKIBETSU_CAL
                   WHERE KAMOKU_CD       = C_NKAMOKU_BASE
                     AND KOKU_SETAI_NO   = I_NSETAI
                     AND SANTEIDANTAI_CD = I_NDANTAI
                     AND CHOTEINENDO     = NLCHOTEI_NENDO
                     AND NENDOBUN        = NLNENDO_BUN
                     AND TSUCHI_NO       = I_NTSUCHI_NO
                     AND SYS_TANMATSU_NO = I_VTANMATSU);
          EXCEPTION
              WHEN OTHERS THEN
                  NLRTN := C_NERR;
                  VLMSG := '内訳縦計一致全体(国保世帯番号='||I_NSETAI||')'||SQLERRM;
          END;
        END IF;

        IF NLRTN = C_NOK THEN
            -- マイナス期割内訳あり(全体)
            IF (NlMAINASU_CNT > 0) THEN
                SUBMAIN2(C_NSHU_ZEN);        -- 02 主処理(全体分)
            END IF;
        END IF;
    END IF;
    /******************************/
    /* 退職税額の期別内訳算出処理 */
    /******************************/
    IF NLRTN = C_NOK AND I_NJIKKOU_KBN != C_NTEST THEN
        -- 期別の内訳にマイナスの金額があるか？(退職)
        BEGIN
          SELECT COUNT(*) INTO NlMAINASU_CNT FROM ZLBTKIBETSU_CAL
            WHERE KAMOKU_CD       = C_NKAMOKU_BASE
              AND KOKU_SETAI_NO   = I_NSETAI
              AND SANTEIDANTAI_CD = I_NDANTAI
              AND CHOTEINENDO     = NLCHOTEI_NENDO
              AND NENDOBUN        = NLNENDO_BUN
              AND TSUCHI_NO       = I_NTSUCHI_NO
              AND (IR_TAI_ZEIGAKU < 0
              OR   KAI_TAI_ZEIGAKU < 0
--  2025/08/11 ZCZL.WANGMINGYANG UPDATE 1.1.200.000: 子ども子育て支援金対応
--              OR   SIEN_ZEN_ZEIGAKU < 0)
              OR   SIEN_ZEN_ZEIGAKU < 0
--  2025/08/11 ZCZL.WANGMINGYANG ADD 1.1.200.000: 子ども子育て支援金対応
              OR   KDM_ZEN_ZEIGAKU < 0)
              AND SYS_TANMATSU_NO = I_VTANMATSU;

        EXCEPTION
            WHEN OTHERS THEN
                NLRTN := C_NERR;
                VLMSG := '内訳マイナス期割カウント退職(国保世帯番号='||I_NSETAI||')'||SQLERRM;
        END;

        IF NLRTN = C_NOK AND (NlMAINASU_CNT = 0) THEN
              -- 期別の内訳の縦計が一致しているか？(退職)
          BEGIN
            SELECT CASE WHEN IR_TAI_ZEIGAKU   <> NLIRY_TAI_NENZEI  THEN 1
                        WHEN KAI_TAI_ZEIGAKU  <> NLKAI_TAI_NENZEI  THEN 1
                        WHEN SIEN_TAI_ZEIGAKU <> NLSIEN_TAI_NENZEI THEN 1
                        ELSE 0 END
                   INTO NlMAINASU_CNT
            FROM (SELECT SUM(IR_TAI_ZEIGAKU)   AS IR_TAI_ZEIGAKU,
                         SUM(KAI_TAI_ZEIGAKU)  AS KAI_TAI_ZEIGAKU,
                         SUM(SIEN_TAI_ZEIGAKU) AS SIEN_TAI_ZEIGAKU
                    FROM ZLBTKIBETSU_CAL
                   WHERE KAMOKU_CD       = C_NKAMOKU_BASE
                     AND KOKU_SETAI_NO   = I_NSETAI
                     AND SANTEIDANTAI_CD = I_NDANTAI
                     AND CHOTEINENDO     = NLCHOTEI_NENDO
                     AND NENDOBUN        = NLNENDO_BUN
                     AND TSUCHI_NO       = I_NTSUCHI_NO
                     AND SYS_TANMATSU_NO = I_VTANMATSU);
          EXCEPTION
              WHEN OTHERS THEN
                  NLRTN := C_NERR;
                  VLMSG := '内訳縦計一致退職(国保世帯番号='||I_NSETAI||')'||SQLERRM;
          END;
        END IF;

        IF NLRTN = C_NOK THEN
            -- マイナス期割内訳あり(全体)
            IF (NlMAINASU_CNT > 0) THEN
                SUBMAIN2(C_NSHU_TAI);        -- 02 主処理(退職分)
            END IF;
        END IF;
    END IF;
    <<EXIT>>
----- 終了処理 -----
    IF NLRTN = C_NOK THEN
        BEGIN
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                NLRTN := C_NERR;
                VLMSG := 'COMMIT発行(国保世帯番号='||I_NSETAI||')'||SQLERRM;
        END;
    END IF;
    IF NLRTN != C_NOK THEN
        BEGIN
            ROLLBACK;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
    END IF;
    IF NLRTN = C_NERR AND VLMSG IS NOT NULL THEN
        VLMSG := 'ZLBSBKIANBUN '||VLMSG;
        IF I_NJIKKOU_KBN = C_NBATCH THEN    -- バッチ処理時はログを出力
            BLRTN := KKBPK5551.FSETBLOG (I_NTRENBAN,'ZLBSBKIANBUN', 1, '', '',VLMSG, '', I_VTANMATSU);
        END IF;
    END IF;
    O_NRESULT := NLRTN;
END ZLBSBKIANBUN;
/
