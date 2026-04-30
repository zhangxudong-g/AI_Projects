CREATE OR REPLACE PROCEDURE ZLBSBUPCHK(i_NGENNEN_KANEN IN  NUMBER,
--1.1.200.000
                                        i_NSETAI        IN  NUMBER,
                                        i_NNENDO        IN  NUMBER,
                                        i_NNENDO_BUN    IN  NUMBER,
                                        i_NSHOKUINKOJIN IN  CHAR,
                                        i_NJIKKOU_KBN   IN  NUMBER,
                                        i_VTANMATSU     IN  NVARCHAR2,
                                        i_NTRENBAN      IN  NUMBER,
                                        o_NRESULT       OUT NUMBER,
                                        i_NKIJUNBI      IN  NUMBER := 0)
-------------------------------------------------------------------------------
-- 業務名   ZLB（国民健康保険税）
-- ＰＧ名   ZLBSBUPCHK
-- 名称     課税計算結果チェック
-- 処理概要 課税計算完了後の計算TBLと賦課TBLを比較して変更の有無を返却する
-- 引き数   i_NGENNEN_KANEN         現年過年区分(0:現年 1:過年)
--          i_NSETAI                国保世帯番号
--          i_NNENDO                調定年度
--          i_NNENDO_BUN            年度分
--          i_NSHOKUINKOJIN         更新職員番号
--          i_NJIKKOU_KBN           実行区分(0:バッチから起動 本算定/月例...
--                                           1:オンライン起動 即時)
--          i_VTANMATSU             端末番号
--          i_NTRENBAN              登録連番
--          o_NRESULT               処理結果(0:変更あり 1:Error 9:変更なし)
--  作成者      ZCZL.WANGWEIZHE
--  作成日      2023/08/01
--  Version     0.2.000.000
-------------------------------------------------------------------------------------
--  変更履歴
--  2025/08/11 ZCZL.HEJIAQI UPDATE 1.1.200.000: 子ども子育て支援金対応
-------------------------------------------------------------------------------------
-----------------------------------------------------------------------------
IS
-------------------------------------------------------------------------------
-- コンストの定義
-------------------------------------------------------------------------------
    -- 戻り値  定数
    c_NOK            CONSTANT NUMBER(1) := 0;        -- 変更あり(OK)
    c_NERR           CONSTANT NUMBER(1) := 1;        -- 異常(NG)
    c_NNOTHING       CONSTANT NUMBER(1) := 9;        -- 変更なし(OK)

    -- 実行区分
    c_NBATCH        CONSTANT NUMBER(1) := 0;        -- バッチから起動
    c_NONLNIN       CONSTANT NUMBER(1) := 1;        -- オンライン起動

    -- ステップログ用NO
    c_NSTEPNO       CONSTANT NUMBER := 99;

    -- 現年・過年
    c_NGENNEN       CONSTANT NUMBER := 0;           -- 現年
    c_NKANEN        CONSTANT NUMBER := 1;           -- 過年

    -- 合併後算定団体
    c_NDANTAI       CONSTANT NUMBER(2) := 1;        -- 合併後算定団体

    c_NKAMOKU_CD        CONSTANT NUMBER(3)  := 15;  -- 科目コード
    c_NKAMOKUS_CD       CONSTANT NUMBER(2)  := 1;   -- 科目詳細コード
    bRTN                BOOLEAN;
-------------------------------------------------------------------------------
-- ワークエリアの定義
-------------------------------------------------------------------------------
    NlRTN                   NUMBER;             -- 戻り値
    VlMSG                   NVARCHAR2(256);     -- ログ用メッセージ
    BlRTN                   BOOLEAN;            -- ログ出力用戻り値
    NlCHK_R                 NUMBER;

    NlNENDO_ZO              NUMBER;         -- 過年度計算対象年（増額）
    NlNENDO_GEN             NUMBER;         -- 過年度計算対象年（減額）
    IZAN_MODE               PLS_INTEGER := 0; -- 0:通常 1:仮算定中
-------------------------------------------------------------------------------
--  05 対象外データ削除
-------------------------------------------------------------------------------
    PROCEDURE subDelData(i_RwKIHON IN ZLBTKIHON_CAL%ROWTYPE) IS

        -- 計算基本カーソル
        CURSOR CwTAISHO IS
            SELECT * FROM ZLBTKIHON_CAL
             WHERE KOKU_SETAI_NO   = i_RwKIHON.KOKU_SETAI_NO
               AND SANTEIDANTAI_CD = i_RwKIHON.SANTEIDANTAI_CD
-- 引数で渡されたデータのみ削除される様に修正
               AND CHOTEI_NENDO       = i_RwKIHON.CHOTEI_NENDO
               AND NENDO_BUN       = i_RwKIHON.NENDO_BUN
               AND SYS_TANMATSU_NO = i_VTANMATSU
         AND TSUCHI_NO       = i_RwKIHON.TSUCHI_NO;

    BEGIN

        FOR RwTAISHO IN CwTAISHO LOOP

            -- 基本削除
            DELETE FROM ZLBTKIHON_CAL
             WHERE KOKU_SETAI_NO   = RwTAISHO.KOKU_SETAI_NO
               AND SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
               AND CHOTEI_NENDO    = RwTAISHO.CHOTEI_NENDO
               AND NENDO_BUN       = RwTAISHO.NENDO_BUN
               AND TSUCHI_NO       = RwTAISHO.TSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;

            -- 退職削除
            DELETE FROM ZLBTTAI_CAL
             WHERE KOKU_SETAI_NO   = RwTAISHO.KOKU_SETAI_NO
               AND SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
               AND CHOTEI_NENDO    = RwTAISHO.CHOTEI_NENDO
               AND NENDO_BUN       = RwTAISHO.NENDO_BUN
               AND TSUCHI_NO       = RwTAISHO.TSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;

            -- 介護基本削除
            DELETE FROM ZLBTKAI_KIHON_CAL
             WHERE KOKU_SETAI_NO   = RwTAISHO.KOKU_SETAI_NO
               AND SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
               AND CHOTEI_NENDO    = RwTAISHO.CHOTEI_NENDO
               AND NENDO_BUN       = RwTAISHO.NENDO_BUN
               AND TSUCHI_NO       = RwTAISHO.TSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;

            -- 介護退職削除
            DELETE FROM ZLBTKAI_TAI_CAL
             WHERE KOKU_SETAI_NO   = RwTAISHO.KOKU_SETAI_NO
               AND SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
               AND CHOTEI_NENDO    = RwTAISHO.CHOTEI_NENDO
               AND NENDO_BUN       = RwTAISHO.NENDO_BUN
               AND TSUCHI_NO       = RwTAISHO.TSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;
            -- 支援基本削除
            DELETE FROM ZLBTSIEN_KIHON_CAL
             WHERE KOKU_SETAI_NO   = RwTAISHO.KOKU_SETAI_NO
               AND SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
               AND CHOTEI_NENDO    = RwTAISHO.CHOTEI_NENDO
               AND NENDO_BUN       = RwTAISHO.NENDO_BUN
               AND TSUCHI_NO       = RwTAISHO.TSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;

            -- 支援退職削除
            DELETE FROM ZLBTSIEN_TAI_CAL
             WHERE KOKU_SETAI_NO   = RwTAISHO.KOKU_SETAI_NO
               AND SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
               AND CHOTEI_NENDO    = RwTAISHO.CHOTEI_NENDO
               AND NENDO_BUN       = RwTAISHO.NENDO_BUN
               AND TSUCHI_NO       = RwTAISHO.TSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;
--  2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
            DELETE FROM ZLBTKDM_KIHON_CAL
             WHERE KOKU_SETAI_NO   = RwTAISHO.KOKU_SETAI_NO
               AND SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
               AND CHOTEI_NENDO    = RwTAISHO.CHOTEI_NENDO
               AND NENDO_BUN       = RwTAISHO.NENDO_BUN
               AND TSUCHI_NO       = RwTAISHO.TSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;
--  2025/08/11 ZCZL.HEJIAQI ADD END
            -- 期別削除
            DELETE FROM ZLBTKIBETSU_CAL
             WHERE KAMOKU_CD       = c_NKAMOKU_CD
               AND KOKU_SETAI_NO   = RwTAISHO.KOKU_SETAI_NO
               AND SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
               AND CHOTEINENDO     = RwTAISHO.CHOTEI_NENDO
               AND NENDOBUN        = RwTAISHO.NENDO_BUN
               AND TSUCHI_NO       = RwTAISHO.TSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;

            -- 個人削除
            DELETE FROM ZLBTKOJIN_CAL
             WHERE KOKU_SETAI_NO   = RwTAISHO.KOKU_SETAI_NO
               AND SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
               AND CHOTEI_NENDO    = RwTAISHO.CHOTEI_NENDO
               AND NENDO_BUN       = RwTAISHO.NENDO_BUN
               AND TSUCHI_NO       = RwTAISHO.TSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;

            -- 所得削除
            DELETE FROM ZLBTSHOTOKU_CAL
             WHERE KOKU_SETAI_NO   = RwTAISHO.KOKU_SETAI_NO
               AND SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
               AND CHOTEI_NENDO    = RwTAISHO.CHOTEI_NENDO
               AND NENDO_BUN       = RwTAISHO.NENDO_BUN
               AND TSUCHI_NO       = RwTAISHO.TSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;
            -- 計算拡張削除
            DELETE FROM ZLBTEXT_CAL
             WHERE KOKU_SETAI_NO   = RwTAISHO.KOKU_SETAI_NO
               AND SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
               AND CHOTEI_NENDO    = RwTAISHO.CHOTEI_NENDO
               AND NENDO_BUN       = RwTAISHO.NENDO_BUN
               AND TSUCHI_NO       = RwTAISHO.TSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;

            -- 計算特徴対象者TBL削除
            DELETE FROM ZLBTTOKU_KIHON_CAL
             WHERE KOKU_SETAI_NO   = RwTAISHO.KOKU_SETAI_NO
               AND SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
               AND CHOTEI_NENDO    = RwTAISHO.CHOTEI_NENDO
               AND NENDO_BUN       = RwTAISHO.NENDO_BUN
               AND TSUCHI_NO       = RwTAISHO.TSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;
        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subDelData 対象外データ削除 ' || SQLERRM;
    END subDelData;
-------------------------------------------------------------------------------
--  04 システム条件取得
-------------------------------------------------------------------------------
    PROCEDURE subJokenSel IS

        NwKANENDO_TAISHO_ZO     NUMBER;         -- 増額対象年数
        NwKANENDO_TAISHO_GEN    NUMBER;         -- 減額対象年数

    BEGIN
        -- システム条件を調定年度,最小算定団体コードで読込み
        SELECT KANENDO_TAISHO_ZO,
               KANENDO_TAISHO_GEN
          INTO NwKANENDO_TAISHO_ZO,
               NwKANENDO_TAISHO_GEN
          FROM ZLBTJOKEN
         WHERE NENDO           = i_NNENDO
           AND SANTEIDANTAI_CD = c_NDANTAI;

        -- 増額対象年度,減額対象年度,対象年度を算出
        NlNENDO_ZO  := i_NNENDO - NwKANENDO_TAISHO_ZO;     -- 増額対象年度
        NlNENDO_GEN := i_NNENDO - NwKANENDO_TAISHO_GEN;    -- 減額対象年度

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subGetNendo 対象年度取得 ' || SQLERRM;
    END subJokenSel;
-------------------------------------------------------------------------------
--  03 仮算定用チェック
-------------------------------------------------------------------------------
    PROCEDURE subChkKarisan IS

        -- 賦課期割データ
        NwNZEN_ZEIGAKU_FU           NUMBER;     -- 普徴期割・全体
        NwNTAI_ZEIGAKU_FU           NUMBER;     -- 普徴期割・退職
        NwNZEN_ZEIGAKU_TO           NUMBER;     -- 特徴期割・全体
        NwNTAI_ZEIGAKU_TO           NUMBER;     -- 特徴期割・退職
        -- 計算期割データ
        NwCZEN_ZEIGAKU_FU           NUMBER;     -- 普徴期割・全体
        NwCTAI_ZEIGAKU_FU           NUMBER;     -- 普徴期割・退職
        NwCZEN_ZEIGAKU_TO           NUMBER;     -- 特徴期割・全体
        NwCTAI_ZEIGAKU_TO           NUMBER;     -- 特徴期割・退職
        NwN_NUSHI_KOJIN_NO          NUMBER;     -- 世帯主個人番号
        -- 計算基本カーソル
        CURSOR CwKIHONC IS
            SELECT * FROM ZLBTKIHON_CAL
             WHERE CHOTEI_NENDO    = i_NNENDO
             AND   NENDO_BUN       = i_NNENDO_BUN
             AND   SYS_TANMATSU_NO = i_VTANMATSU;
    BEGIN
        -- 計算基本取得
        FOR RwKIHONC IN CwKIHONC LOOP
            NlCHK_R := c_NNOTHING;         -- 変化なし
            NwNZEN_ZEIGAKU_FU :=0;
            NwNTAI_ZEIGAKU_FU :=0;
            NwNZEN_ZEIGAKU_TO :=0;
            NwNTAI_ZEIGAKU_TO :=0;
            NwCZEN_ZEIGAKU_FU :=0;
            NwCTAI_ZEIGAKU_FU :=0;
            NwCZEN_ZEIGAKU_TO :=0;
            NwCTAI_ZEIGAKU_TO :=0;
            NwN_NUSHI_KOJIN_NO := 0;
            -- 賦課普徴期割データ
            BEGIN
                SELECT NVL(SUM(ZEN_ZEIGAKU),0),
                       NVL(SUM(TAI_ZEIGAKU),0)
                INTO   NwNZEN_ZEIGAKU_FU,
                       NwNTAI_ZEIGAKU_FU
                FROM   ZLBTKIBETSU_N
                WHERE  KAMOKUS_CD      = 1
                  AND  KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                  AND  SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                  AND  CHOTEINENDO     = RwKIHONC.CHOTEI_NENDO
                  AND  NENDOBUN        = RwKIHONC.NENDO_BUN
                  AND  TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subChkKarisan 出力判定' || SQLERRM;
                    EXIT;
            END;
            -- 賦課特徴期割データ
            BEGIN
                SELECT NVL(SUM(ZEN_ZEIGAKU),0),
                       NVL(SUM(TAI_ZEIGAKU),0)
                INTO   NwNZEN_ZEIGAKU_TO,
                       NwNTAI_ZEIGAKU_TO
                FROM   ZLBTKIBETSU_N
                WHERE  KAMOKUS_CD      = 2
                  AND  KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                  AND  SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                  AND  CHOTEINENDO     = RwKIHONC.CHOTEI_NENDO
                  AND  NENDOBUN        = RwKIHONC.NENDO_BUN
                  AND  TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subChkKarisan 出力判定' || SQLERRM;
                    EXIT;
            END;
            -- 計算普徴期割データ
            BEGIN
                SELECT NVL(SUM(ZEN_ZEIGAKU),0),
                       NVL(SUM(TAI_ZEIGAKU),0)
                INTO   NwCZEN_ZEIGAKU_FU,
                       NwCTAI_ZEIGAKU_FU
                FROM   ZLBTKIBETSU_CAL
                WHERE  KAMOKUS_CD      = 1
                  AND  KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                  AND  SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                  AND  CHOTEINENDO     = RwKIHONC.CHOTEI_NENDO
                  AND  NENDOBUN        = RwKIHONC.NENDO_BUN
                  AND  TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                  AND  SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subChkKarisan 出力判定' || SQLERRM;
                    EXIT;
            END;
            -- 計算特徴期割データ
            BEGIN
                SELECT NVL(SUM(ZEN_ZEIGAKU),0),
                       NVL(SUM(TAI_ZEIGAKU),0)
                INTO   NwCZEN_ZEIGAKU_TO,
                       NwCTAI_ZEIGAKU_TO
                FROM   ZLBTKIBETSU_CAL
                WHERE  KAMOKUS_CD      = 2
                  AND  KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                  AND  SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                  AND  CHOTEINENDO     = RwKIHONC.CHOTEI_NENDO
                  AND  NENDOBUN        = RwKIHONC.NENDO_BUN
                  AND  TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                  AND  SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subChkKarisan 出力判定' || SQLERRM;
                    EXIT;
            END;
            BEGIN
                -- 賦課基本取得
                SELECT NVL(NUSHI_KOJIN_NO, 0)
                  INTO NwN_NUSHI_KOJIN_NO
                  FROM ZLBTKIHON_N
                 WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                   AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                   AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                   AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NwN_NUSHI_KOJIN_NO := 0;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                    EXIT;
            END;
            -- 変更チェック
            IF NwNZEN_ZEIGAKU_FU       != NwCZEN_ZEIGAKU_FU    OR      -- 普徴期割・全体
               NwNTAI_ZEIGAKU_FU       != NwCTAI_ZEIGAKU_FU    OR      -- 普徴期割・退職
               NwNZEN_ZEIGAKU_TO       != NwCZEN_ZEIGAKU_TO    OR      -- 特徴期割・全体
               NwNTAI_ZEIGAKU_TO       != NwCTAI_ZEIGAKU_TO    OR      -- 特徴期割・退職
               RwKIHONC.NUSHI_KOJIN_NO != NwN_NUSHI_KOJIN_NO THEN      -- 世帯主個人番号
                  NlCHK_R := c_NOK;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subChkKarisan 出力判定' || SQLERRM;
    END subChkKarisan;
-------------------------------------------------------------------------------
--  02 現年用チェック
-------------------------------------------------------------------------------
    PROCEDURE subChkGennen IS

        NwOK_CNT                    NUMBER;
        NwIRY_FLG                   NUMBER(1);
        NwKAI_FLG                   NUMBER(1);
        NwSIEN_FLG                  NUMBER(1);
--  2025/08/11 ZCZL.HEJIAQI ADD 1.1.200.000: 子ども子育て支援金対応
        NwKDM_FLG                   NUMBER(1);
        NCNT_N                      NUMBER;
        NCNT_CAL                    NUMBER;
        NYOKU_TSUCHI_NO_N           NUMBER;
        NYOKU_TSUCHI_NO_CAL         NUMBER;
        NIDO_JIYU_N                 NUMBER;
        NIDO_JIYU_CAL               NUMBER;

        -- 計算退職取得データ
        NwTAIC_SEKISAN              NUMBER;     -- 積算税額
        NwTAIC_GENDO_CHOKA          NUMBER;     -- 限度超過額
        NwTAIC_GENGAKU_KEI          NUMBER;     -- 減額合計
        NwTAIC_NENZEI               NUMBER;     -- 年税額
        NwTAIC_KINTO_CNT            NUMBER;     -- 均等人員
        NwTAIC_GENZAI_CNT           NUMBER;     -- 現在人員
        NwTAIC_SHOTOKU              NUMBER;     --所得額
        -- 賦課基本取得データ
        NwKIHONN_SEKISAN            NUMBER;     -- 積算税額
        NwKIHONN_GENDO_CHOKA        NUMBER;     -- 限度超過額
        NwKIHONN_GENGAKU_KEI        NUMBER;     -- 減額合計
        NwKIHONN_NENZEI             NUMBER;     -- 年税額
        NwKIHONN_NUSHI_KOJIN_NO     NUMBER;     -- 主個人番号
        NwKIHONN_KINTO_CNT          NUMBER;     -- 均等人員
        NwKIHONN_GENZAI_CNT         NUMBER;     -- 現在人員
        NwKIHONN_SHINKOKU_KBN       NUMBER;     --申告区分
        NwKIHONN_SHOTOKU            NUMBER;     --所得額
        NwKIHONN_YOKU_TSUCHI_NO     NUMBER;     --翌年度通知書番号
        -- 賦課退職取得データ
        NwTAIN_SEKISAN              NUMBER;     -- 積算税額
        NwTAIN_GENDO_CHOKA          NUMBER;     -- 限度超過額
        NwTAIN_GENGAKU_KEI          NUMBER;     -- 減額合計
        NwTAIN_NENZEI               NUMBER;     -- 年税額
        NwTAIN_KINTO_CNT            NUMBER;     -- 均等人員
        NwTAIN_GENZAI_CNT           NUMBER;     -- 現在人員
        NwTAIN_SHOTOKU              NUMBER;     --所得額
        -- 計算介護基本取得データ
        NwKKIHONC_SEKISAN           NUMBER;     -- 積算税額
        NwKKIHONC_GENDO_CHOKA       NUMBER;     -- 限度超過額
        NwKKIHONC_GENGAKU_KEI       NUMBER;     -- 減額合計
        NwKKIHONC_NENZEI            NUMBER;     -- 年税額
        NwKKIHONC_NUSHI_KOJIN_NO    NUMBER;     -- 主個人番号
        NwKKIHONC_KINTO_CNT         NUMBER;     -- 均等人員
        NwKKIHONC_GENZAI_CNT        NUMBER;     -- 現在人員
        NwKKIHONC_SHINKOKU_KBN      NUMBER;     --申告区分
        NwKKIHONC_SHOTOKU           NUMBER;     --所得額
        -- 計算介護退職取得データ
        NwKTAIC_SEKISAN             NUMBER;     -- 積算税額
        NwKTAIC_GENDO_CHOKA         NUMBER;     -- 限度超過額
        NwKTAIC_GENGAKU_KEI         NUMBER;     -- 減額合計
        NwKTAIC_NENZEI              NUMBER;     -- 年税額
        NwKTAIC_KINTO_CNT           NUMBER;     -- 均等人員
        NwKTAIC_GENZAI_CNT          NUMBER;     -- 現在人員
        NwKTAIC_SHOTOKU             NUMBER;     --所得額
        -- 賦課介護基本取得データ
        NwKKIHONN_SEKISAN           NUMBER;     -- 積算税額
        NwKKIHONN_GENDO_CHOKA       NUMBER;     -- 限度超過額
        NwKKIHONN_GENGAKU_KEI       NUMBER;     -- 減額合計
        NwKKIHONN_NENZEI            NUMBER;     -- 年税額
        NwKKIHONN_NUSHI_KOJIN_NO    NUMBER;     -- 主個人番号
        NwKKIHONN_KINTO_CNT         NUMBER;     -- 均等人員
        NwKKIHONN_GENZAI_CNT        NUMBER;     -- 現在人員
        NwKKIHONN_SHINKOKU_KBN      NUMBER;     --申告区分
        NwKKIHONN_SHOTOKU           NUMBER;     --所得額
        -- 賦課介護退職取得データ
        NwKTAIN_SEKISAN             NUMBER;     -- 積算税額
        NwKTAIN_GENDO_CHOKA         NUMBER;     -- 限度超過額
        NwKTAIN_GENGAKU_KEI         NUMBER;     -- 減額合計
        NwKTAIN_NENZEI              NUMBER;     -- 年税額
        NwKTAIN_KINTO_CNT           NUMBER;     -- 均等人員
        NwKTAIN_GENZAI_CNT          NUMBER;     -- 現在人員
        NwKTAIN_SHOTOKU             NUMBER;     --所得額
        -- 計算支援基本取得データ
        NwSKIHONC_SEKISAN           NUMBER;     -- 積算税額
        NwSKIHONC_GENDO_CHOKA       NUMBER;     -- 限度超過額
        NwSKIHONC_GENGAKU_KEI       NUMBER;     -- 減額合計
        NwSKIHONC_NENZEI            NUMBER;     -- 年税額
        NwSKIHONC_NUSHI_KOJIN_NO    NUMBER;     -- 主個人番号
        NwSKIHONC_KINTO_CNT         NUMBER;     -- 均等人員
        NwSKIHONC_GENZAI_CNT        NUMBER;     -- 現在人員
        NwSKIHONC_SHINKOKU_KBN      NUMBER;     -- 申告区分
        NwSKIHONC_SHOTOKU           NUMBER;     -- 所得額
        -- 計算支援退職取得データ
        NwSTAIC_SEKISAN             NUMBER;     -- 積算税額
        NwSTAIC_GENDO_CHOKA         NUMBER;     -- 限度超過額
        NwSTAIC_GENGAKU_KEI         NUMBER;     -- 減額合計
        NwSTAIC_NENZEI              NUMBER;     -- 年税額
        NwSTAIC_KINTO_CNT           NUMBER;     -- 均等人員
        NwSTAIC_GENZAI_CNT          NUMBER;     -- 現在人員
        NwSTAIC_SHOTOKU             NUMBER;     -- 所得額
        -- 賦課支援基本取得データ
        NwSKIHONN_SEKISAN           NUMBER;     -- 積算税額
        NwSKIHONN_GENDO_CHOKA       NUMBER;     -- 限度超過額
        NwSKIHONN_GENGAKU_KEI       NUMBER;     -- 減額合計
        NwSKIHONN_NENZEI            NUMBER;     -- 年税額
        NwSKIHONN_NUSHI_KOJIN_NO    NUMBER;     -- 主個人番号
        NwSKIHONN_KINTO_CNT         NUMBER;     -- 均等人員
        NwSKIHONN_GENZAI_CNT        NUMBER;     -- 現在人員
        NwSKIHONN_SHINKOKU_KBN      NUMBER;     -- 申告区分
        NwSKIHONN_SHOTOKU           NUMBER;     -- 所得額
        -- 賦課支援退職取得データ
        NwSTAIN_SEKISAN             NUMBER;     -- 積算税額
        NwSTAIN_GENDO_CHOKA         NUMBER;     -- 限度超過額
        NwSTAIN_GENGAKU_KEI         NUMBER;     -- 減額合計
        NwSTAIN_NENZEI              NUMBER;     -- 年税額
        NwSTAIN_KINTO_CNT           NUMBER;     -- 均等人員
        NwSTAIN_GENZAI_CNT          NUMBER;     -- 現在人員
        NwSTAIN_SHOTOKU             NUMBER;     -- 所得額
        -- 計算特徴対象者取得データ
        NwJOTAI_KBN_CAL             NUMBER;     -- 特徴状態
        -- 賦課特徴対象者取得データ
        NwJOTAI_KBN_N               NUMBER;     -- 特徴状態
        NwH_KBN_CAL                 NUMBER;     -- 旧被扶養者・失業者区分
        NwH_KBN_N                   NUMBER;     -- 旧被扶養者・失業者区分
--  2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
        -- 計算子ども基本取得データ
        NwKDMKIHONC_SEKISAN         NUMBER;     -- 積算税額
        NwKDMKIHONC_GENDO_CHOKA     NUMBER;     -- 限度超過額
        NwKDMKIHONC_GENGAKU_KEI     NUMBER;     -- 減額合計
        NwKDMKIHONC_NENZEI          NUMBER;     -- 年税額
        NwKDMKIHONC_NUSHI_KOJIN_NO  NUMBER;     -- 主個人番号
        NwKDMKIHONC_KINTO_CNT       NUMBER;     -- 均等人員
        NwKDMKIHONC_GENZAI_CNT      NUMBER;     -- 現在人員
        NwKDMKIHONC_SHINKOKU_KBN    NUMBER;     -- 申告区分
        NwKDMKIHONC_SHOTOKU         NUMBER;     -- 所得額
        NwKDMKIHONC_KINTO_CNT_KDM18 NUMBER;     -- 18歳以上均等人員
        -- 賦課子ども基本（最新）取得データ
        NwKDMKIHONN_SEKISAN         NUMBER;     -- 積算税額
        NwKDMKIHONN_GENDO_CHOKA     NUMBER;     -- 限度超過額
        NwKDMKIHONN_GENGAKU_KEI     NUMBER;     -- 減額合計
        NwKDMKIHONN_NENZEI          NUMBER;     -- 年税額
        NwKDMKIHONN_NUSHI_KOJIN_NO  NUMBER;     -- 主個人番号
        NwKDMKIHONN_KINTO_CNT       NUMBER;     -- 均等人員
        NwKDMKIHONN_GENZAI_CNT      NUMBER;     -- 現在人員
        NwKDMKIHONN_SHINKOKU_KBN    NUMBER;     -- 申告区分
        NwKDMKIHONN_SHOTOKU         NUMBER;     -- 所得額
        NwKDMKIHONN_KINTO_CNT_KDM18 NUMBER;     -- 18歳以上均等人員
--  2025/08/11 ZCZL.HEJIAQI ADD END

        -- 計算基本カーソル
        CURSOR CwKIHONC IS
            SELECT * FROM ZLBTKIHON_CAL
             WHERE CHOTEI_NENDO    = i_NNENDO
             AND   NENDO_BUN       = i_NNENDO_BUN
             AND   SYS_TANMATSU_NO = i_VTANMATSU;

    BEGIN
        NwOK_CNT := 0;

        -- 計算基本取得
        FOR RwKIHONC IN CwKIHONC LOOP

            NlCHK_R := c_NNOTHING;         -- 変化なし

            NwIRY_FLG := 0;
            NwKAI_FLG := 0;
            NwSIEN_FLG := 0;
--  2025/08/11 ZCZL.HEJIAQI ADD 1.1.200.000: 子ども子育て支援金対応
            NwKDM_FLG := 0;

            -- 計算退職取得データクリア
            NwTAIC_SEKISAN           := 0;  NwTAIC_GENDO_CHOKA    := 0;
            NwTAIC_GENGAKU_KEI       := 0;  NwTAIC_NENZEI         := 0;
            NwTAIC_KINTO_CNT         := 0;  NwTAIC_GENZAI_CNT     := 0;
            NwTAIC_SHOTOKU           := 0;
            -- 賦課基本取得データクリア
            NwKIHONN_SEKISAN         := 0;  NwKIHONN_GENDO_CHOKA  := 0;
            NwKIHONN_GENGAKU_KEI     := 0;  NwKIHONN_NENZEI       := 0;
            NwKIHONN_NUSHI_KOJIN_NO  := 0;  NwKIHONN_KINTO_CNT    := 0;
            NwKIHONN_GENZAI_CNT      := 0;
            NwKIHONN_SHINKOKU_KBN    := 0;  NwKIHONN_SHOTOKU      := 0;
            NwKIHONN_YOKU_TSUCHI_NO  := 0;
            -- 賦課退職取得データクリア
            NwTAIN_SEKISAN           := 0;  NwTAIN_GENDO_CHOKA    := 0;
            NwTAIN_GENGAKU_KEI       := 0;  NwTAIN_NENZEI         := 0;
            NwTAIN_KINTO_CNT         := 0;  NwTAIN_GENZAI_CNT     := 0;
            NwTAIN_SHOTOKU           := 0;
            -- 計算介護基本取得データクリア
            NwKKIHONC_SEKISAN        := 0;  NwKKIHONC_GENDO_CHOKA := 0;
            NwKKIHONC_GENGAKU_KEI    := 0;  NwKKIHONC_NENZEI      := 0;
            NwKKIHONC_NUSHI_KOJIN_NO := 0;  NwKKIHONC_KINTO_CNT   := 0;
            NwKKIHONC_GENZAI_CNT     := 0;
            NwKKIHONC_SHINKOKU_KBN   := 0;  NwKKIHONC_SHOTOKU     := 0;
            -- 計算介護退職取得データクリア
            NwKTAIC_SEKISAN          := 0;  NwKTAIC_GENDO_CHOKA   := 0;
            NwKTAIC_GENGAKU_KEI      := 0;  NWKTAIC_NENZEI        := 0;
            NwKTAIC_KINTO_CNT        := 0;  NwKTAIC_GENZAI_CNT    := 0;
            NwKTAIC_SHOTOKU          := 0;
            -- 賦課介護基本取得データクリア
            NwKKIHONN_SEKISAN        := 0;  NwKKIHONN_GENDO_CHOKA := 0;
            NwKKIHONN_GENGAKU_KEI    := 0;  NwKKIHONN_NENZEI      := 0;
            NwKKIHONN_NUSHI_KOJIN_NO := 0;  NwKKIHONN_KINTO_CNT   := 0;
            NwKKIHONN_GENZAI_CNT     := 0;
            NwKKIHONN_SHINKOKU_KBN   := 0;  NwKKIHONN_SHOTOKU     := 0;
            -- 賦課介護退職取得データクリア
            NwKTAIN_SEKISAN          := 0;  NwKTAIN_GENDO_CHOKA   := 0;
            NwKTAIN_GENGAKU_KEI      := 0;  NwKTAIN_NENZEI        := 0;
            NwKTAIN_KINTO_CNT        := 0;  NwKTAIN_GENZAI_CNT    := 0;
            NwKTAIN_SHOTOKU          := 0;
            -- 計算支援基本取得データクリア
            NwSKIHONC_SEKISAN        := 0;  NwSKIHONC_GENDO_CHOKA := 0;
            NwSKIHONC_GENGAKU_KEI    := 0;  NwSKIHONC_NENZEI      := 0;
            NwSKIHONC_NUSHI_KOJIN_NO := 0;  NwSKIHONC_KINTO_CNT   := 0;
            NwSKIHONC_GENZAI_CNT     := 0;
            NwSKIHONC_SHINKOKU_KBN   := 0;  NwSKIHONC_SHOTOKU     := 0;
            -- 計算支援退職取得データクリア
            NwSTAIC_SEKISAN          := 0;  NwSTAIC_GENDO_CHOKA   := 0;
            NwSTAIC_GENGAKU_KEI      := 0;  NWSTAIC_NENZEI        := 0;
            NwSTAIC_KINTO_CNT        := 0;  NwSTAIC_GENZAI_CNT    := 0;
            NwSTAIC_SHOTOKU          := 0;
            -- 賦課支援基本取得データクリア
            NwSKIHONN_SEKISAN        := 0;  NwSKIHONN_GENDO_CHOKA := 0;
            NwSKIHONN_GENGAKU_KEI    := 0;  NwSKIHONN_NENZEI      := 0;
            NwSKIHONN_NUSHI_KOJIN_NO := 0;  NwSKIHONN_KINTO_CNT   := 0;
            NwSKIHONN_GENZAI_CNT     := 0;
            NwSKIHONN_SHINKOKU_KBN   := 0;  NwSKIHONN_SHOTOKU     := 0;
            -- 賦課支援退職取得データクリア
            NwSTAIN_SEKISAN          := 0;  NwSTAIN_GENDO_CHOKA   := 0;
            NwSTAIN_GENGAKU_KEI      := 0;  NwSTAIN_NENZEI        := 0;
            NwSTAIN_KINTO_CNT        := 0;  NwSTAIN_GENZAI_CNT    := 0;
            NwSTAIN_SHOTOKU          := 0;
            -- 計算特徴対象者取得データクリア
            NwJOTAI_KBN_CAL          := 0;
            -- 賦課特徴対象者取得データクリア
            NwJOTAI_KBN_N            := 0;
--  2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
            -- 計算子ども基本取得データクリア
            NwKDMKIHONC_SEKISAN        := 0;  NwKDMKIHONC_GENDO_CHOKA  := 0;
            NwKDMKIHONC_GENGAKU_KEI    := 0;  NwKDMKIHONC_NENZEI       := 0;
            NwKDMKIHONC_NUSHI_KOJIN_NO := 0;  NwKDMKIHONC_KINTO_CNT    := 0;
            NwKDMKIHONC_GENZAI_CNT     := 0;  NwKDMKIHONC_SHINKOKU_KBN := 0;
            NwKDMKIHONC_SHOTOKU        := 0;  NwKDMKIHONC_KINTO_CNT_KDM18 := 0; 
            -- 賦課子ども基本（最新）取得データクリア
            NwKDMKIHONN_SEKISAN        := 0;  NwKDMKIHONN_GENDO_CHOKA  := 0;
            NwKDMKIHONN_GENGAKU_KEI    := 0;  NwKDMKIHONN_NENZEI       := 0;
            NwKDMKIHONN_NUSHI_KOJIN_NO := 0;  NwKDMKIHONN_KINTO_CNT    := 0;
            NwKDMKIHONN_GENZAI_CNT     := 0;  NwKDMKIHONN_SHINKOKU_KBN := 0;
            NwKDMKIHONN_SHOTOKU        := 0;  NwKDMKIHONN_KINTO_CNT_KDM18 := 0; 
--  2025/08/11 ZCZL.HEJIAQI ADD END

            BEGIN
                -- 計算退職取得
                SELECT SEKISAN,
                       GENDO_CHOKA,
                       GENGAKU_KEI,
                       NENZEI,
                       KINTO_CNT,
                       GENZAI_CNT,
                       SHOTOKU
                  INTO NwTAIC_SEKISAN,
                       NwTAIC_GENDO_CHOKA,
                       NwTAIC_GENGAKU_KEI,
                       NwTAIC_NENZEI,
                       NwTAIC_KINTO_CNT,
                       NwTAIC_GENZAI_CNT,
                       NwTAIC_SHOTOKU
                  FROM ZLBTTAI_CAL
                 WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                   AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                   AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                   AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                    EXIT;
            END;

            BEGIN
                -- 計算介護基本取得
                SELECT NVL(SEKISAN, 0),
                       NVL(GENDO_CHOKA, 0),
                       NVL(GENGAKU_KEI, 0),
                       NVL(NENZEI, 0),
                       NVL(NUSHI_KOJIN_NO, 0),
                       NVL(KINTO_CNT, 0),
                       NVL(GENZAI_CNT, 0),
                       NVL(SHINKOKU_KBN, 0),
                       NVL(SHOTOKU, 0)
                INTO NwKKIHONC_SEKISAN,
                       NwKKIHONC_GENDO_CHOKA,
                       NwKKIHONC_GENGAKU_KEI,
                       NwKKIHONC_NENZEI,
                       NwKKIHONC_NUSHI_KOJIN_NO,
                       NwKKIHONC_KINTO_CNT,
                       NwKKIHONC_GENZAI_CNT,
                       NwKKIHONC_SHINKOKU_KBN,
                       NwKKIHONC_SHOTOKU
                  FROM ZLBTKAI_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                   AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                   AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                   AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NwKAI_FLG := 1;     -- 介護データなし
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                    EXIT;
            END;

            IF  NwKAI_FLG = 0 THEN      -- 介護データ有り
                BEGIN
                    -- 計算介護退職取得
                    SELECT NVL(SEKISAN, 0),
                           NVL(GENDO_CHOKA, 0),
                           NVL(GENGAKU_KEI, 0),
                           NVL(NENZEI, 0),
                           NVL(KINTO_CNT, 0),
                           NVL(GENZAI_CNT, 0),
                           NVL(SHOTOKU, 0)
                      INTO NwKTAIC_SEKISAN,
                           NwKTAIC_GENDO_CHOKA,
                           NwKTAIC_GENGAKU_KEI,
                           NwKTAIC_NENZEI,
                           NwKTAIC_KINTO_CNT,
                           NwKTAIC_GENZAI_CNT,
                           NwKTAIC_SHOTOKU
                      FROM ZLBTKAI_TAI_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                        EXIT;
                END;
            END IF;

            BEGIN
                -- 賦課基本取得
                SELECT NVL(SEKISAN, 0),
                       NVL(GENDO_CHOKA, 0),
                       NVL(GENGAKU_KEI, 0),
                       NVL(NENZEI, 0),
                       NVL(NUSHI_KOJIN_NO, 0),
                       NVL(KINTO_CNT, 0),
                       NVL(GENZAI_CNT, 0),
                       NVL(SHINKOKU_KBN, 0),
                       NVL(SHOTOKU, 0),
                       NVL(YOKU_TSUCHI_NO,0)
                  INTO NwKIHONN_SEKISAN,
                       NwKIHONN_GENDO_CHOKA,
                       NwKIHONN_GENGAKU_KEI,
                       NwKIHONN_NENZEI,
                       NwKIHONN_NUSHI_KOJIN_NO,
                       NwKIHONN_KINTO_CNT,
                       NwKIHONN_GENZAI_CNT,
                       NwKIHONN_SHINKOKU_KBN,
                       NwKIHONN_SHOTOKU,
                       NwKIHONN_YOKU_TSUCHI_NO
                  FROM ZLBTKIHON_N
                 WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                   AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                   AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                   AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NwIRY_FLG := 1;     -- 医療データなし
                    NwKAI_FLG := 1;     -- 介護データなし
                    NwSIEN_FLG := 1;    -- 支援データなし
--  2025/08/11 ZCZL.HEJIAQI ADD 1.1.200.000: 子ども子育て支援金対応
                    NwKDM_FLG := 1;     -- 子どもデータなし
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                    EXIT;
            END;

            IF NwIRY_FLG = 0 THEN       -- 医療データ有り
                BEGIN
                    -- 賦課退職取得
                    SELECT NVL(SEKISAN, 0),
                           NVL(GENDO_CHOKA, 0),
                           NVL(GENGAKU_KEI, 0),
                           NVL(NENZEI, 0),
                           NVL(KINTO_CNT, 0),
                           NVL(GENZAI_CNT, 0),
                           NVL(SHOTOKU, 0)
                      INTO NwTAIN_SEKISAN,
                           NwTAIN_GENDO_CHOKA,
                           NwTAIN_GENGAKU_KEI,
                           NwTAIN_NENZEI,
                           NwTAIN_KINTO_CNT,
                           NwTAIN_GENZAI_CNT,
                           NwTAIN_SHOTOKU
                      FROM ZLBTTAI_N
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                        EXIT;
                END;
            END IF;

            IF NwKAI_FLG = 0 THEN       -- 介護データ有り
                BEGIN
                    -- 賦課介護基本取得
                    SELECT NVL(SEKISAN, 0),
                           NVL(GENDO_CHOKA, 0),
                           NVL(GENGAKU_KEI, 0),
                           NVL(NENZEI, 0),
                           NVL(NUSHI_KOJIN_NO, 0),
                           NVL(KINTO_CNT, 0),
                           NVL(GENZAI_CNT, 0),
                           NVL(SHINKOKU_KBN, 0),
                           NVL(SHOTOKU, 0)
                      INTO NwKKIHONN_SEKISAN,
                           NwKKIHONN_GENDO_CHOKA,
                           NwKKIHONN_GENGAKU_KEI,
                           NwKKIHONN_NENZEI,
                           NwKKIHONN_NUSHI_KOJIN_NO,
                           NwKKIHONN_KINTO_CNT,
                           NwKKIHONN_GENZAI_CNT,
                           NwKKIHONN_SHINKOKU_KBN,
                           NwKKIHONN_SHOTOKU
                      FROM ZLBTKAI_KIHON_N
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NwKAI_FLG := 1;     -- 介護データなし
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                        EXIT;
                END;
            END IF;

            IF NwKAI_FLG = 0 THEN       -- 介護データ有り
                BEGIN
                    -- 賦課介護退職取得
                    SELECT NVL(SEKISAN, 0),
                           NVL(GENDO_CHOKA, 0),
                           NVL(GENGAKU_KEI, 0),
                           NVL(NENZEI, 0),
                           NVL(KINTO_CNT, 0),
                           NVL(GENZAI_CNT, 0),
                           NVL(SHOTOKU, 0)
                      INTO NwKTAIN_SEKISAN,
                           NwKTAIN_GENDO_CHOKA,
                           NwKTAIN_GENGAKU_KEI,
                           NwKTAIN_NENZEI,
                           NwKTAIN_KINTO_CNT,
                           NwKTAIN_GENZAI_CNT,
                           NwKTAIN_SHOTOKU
                      FROM ZLBTKAI_TAI_N
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                        EXIT;
                END;
            END IF;
            BEGIN
                -- 計算支援基本取得
                SELECT NVL(SEKISAN, 0),
                       NVL(GENDO_CHOKA, 0),
                       NVL(GENGAKU_KEI, 0),
                       NVL(NENZEI, 0),
                       NVL(NUSHI_KOJIN_NO, 0),
                       NVL(KINTO_CNT, 0),
                       NVL(GENZAI_CNT, 0),
                       NVL(SHINKOKU_KBN, 0),
                       NVL(SHOTOKU, 0)
                INTO NwSKIHONC_SEKISAN,
                       NwSKIHONC_GENDO_CHOKA,
                       NwSKIHONC_GENGAKU_KEI,
                       NwSKIHONC_NENZEI,
                       NwSKIHONC_NUSHI_KOJIN_NO,
                       NwSKIHONC_KINTO_CNT,
                       NwSKIHONC_GENZAI_CNT,
                       NwSKIHONC_SHINKOKU_KBN,
                       NwSKIHONC_SHOTOKU
                  FROM ZLBTSIEN_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                   AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                   AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                   AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NwSIEN_FLG := 1;     -- 支援データなし
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                    EXIT;
            END;

            IF  NwSIEN_FLG = 0 THEN      -- 支援データ有り
                BEGIN
                    -- 計算支援退職取得
                    SELECT NVL(SEKISAN, 0),
                           NVL(GENDO_CHOKA, 0),
                           NVL(GENGAKU_KEI, 0),
                           NVL(NENZEI, 0),
                           NVL(KINTO_CNT, 0),
                           NVL(GENZAI_CNT, 0),
                           NVL(SHOTOKU, 0)
                      INTO NwSTAIC_SEKISAN,
                           NwSTAIC_GENDO_CHOKA,
                           NwSTAIC_GENGAKU_KEI,
                           NwSTAIC_NENZEI,
                           NwSTAIC_KINTO_CNT,
                           NwSTAIC_GENZAI_CNT,
                           NwSTAIC_SHOTOKU
                      FROM ZLBTSIEN_TAI_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                        EXIT;
                END;
            END IF;
            IF NwSIEN_FLG = 0 THEN       -- 支援データ有り
                BEGIN
                    -- 賦課支援基本取得
                    SELECT NVL(SEKISAN, 0),
                           NVL(GENDO_CHOKA, 0),
                           NVL(GENGAKU_KEI, 0),
                           NVL(NENZEI, 0),
                           NVL(NUSHI_KOJIN_NO, 0),
                           NVL(KINTO_CNT, 0),
                           NVL(GENZAI_CNT, 0),
                           NVL(SHINKOKU_KBN, 0),
                           NVL(SHOTOKU, 0)
                      INTO NwSKIHONN_SEKISAN,
                           NwSKIHONN_GENDO_CHOKA,
                           NwSKIHONN_GENGAKU_KEI,
                           NwSKIHONN_NENZEI,
                           NwSKIHONN_NUSHI_KOJIN_NO,
                           NwSKIHONN_KINTO_CNT,
                           NwSKIHONN_GENZAI_CNT,
                           NwSKIHONN_SHINKOKU_KBN,
                           NwSKIHONN_SHOTOKU
                      FROM ZLBTSIEN_KIHON_N
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NwSIEN_FLG := 1;     -- 支援データなし
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                        EXIT;
                END;
            END IF;

            IF NwSIEN_FLG = 0 THEN       -- 支援データ有り
                BEGIN
                    -- 賦課支援退職取得
                    SELECT NVL(SEKISAN, 0),
                           NVL(GENDO_CHOKA, 0),
                           NVL(GENGAKU_KEI, 0),
                           NVL(NENZEI, 0),
                           NVL(KINTO_CNT, 0),
                           NVL(GENZAI_CNT, 0),
                           NVL(SHOTOKU, 0)
                      INTO NwSTAIN_SEKISAN,
                           NwSTAIN_GENDO_CHOKA,
                           NwSTAIN_GENGAKU_KEI,
                           NwSTAIN_NENZEI,
                           NwSTAIN_KINTO_CNT,
                           NwSTAIN_GENZAI_CNT,
                           NwSTAIN_SHOTOKU
                      FROM ZLBTSIEN_TAI_N
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                        EXIT;
                END;
            END IF;
--  2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
            BEGIN
                -- 計算子ども基本取得
                SELECT NVL(SEKISAN, 0),
                       NVL(GENDO_CHOKA, 0),
                       NVL(GENGAKU_KEI, 0),
                       NVL(NENZEI, 0),
                       NVL(NUSHI_KOJIN_NO, 0),
                       NVL(KINTO_CNT, 0),
                       NVL(GENZAI_CNT, 0),
                       NVL(SHINKOKU_KBN, 0),
                       NVL(SHOTOKU, 0),
                       NVL(KINTO_CNT_KDM18, 0)
                  INTO NwKDMKIHONC_SEKISAN,
                       NwKDMKIHONC_GENDO_CHOKA,
                       NwKDMKIHONC_GENGAKU_KEI,
                       NwKDMKIHONC_NENZEI,
                       NwKDMKIHONC_NUSHI_KOJIN_NO,
                       NwKDMKIHONC_KINTO_CNT,
                       NwKDMKIHONC_GENZAI_CNT,
                       NwKDMKIHONC_SHINKOKU_KBN,
                       NwKDMKIHONC_SHOTOKU,
                       NwKDMKIHONC_KINTO_CNT_KDM18
                  FROM ZLBTKDM_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                   AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                   AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                   AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NwKDM_FLG := 1;     -- 子どもデータなし
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                    EXIT;
            END;

            IF NwKDM_FLG = 0 THEN       -- 子どもデータ有り
                BEGIN
                    -- 賦課子ども基本取得
                    SELECT NVL(SEKISAN, 0),
                           NVL(GENDO_CHOKA, 0),
                           NVL(GENGAKU_KEI, 0),
                           NVL(NENZEI, 0),
                           NVL(NUSHI_KOJIN_NO, 0),
                           NVL(KINTO_CNT, 0),
                           NVL(GENZAI_CNT, 0),
                           NVL(SHINKOKU_KBN, 0),
                           NVL(SHOTOKU, 0),
                           NVL(KINTO_CNT_KDM18, 0)
                      INTO NwKDMKIHONN_SEKISAN,
                           NwKDMKIHONN_GENDO_CHOKA,
                           NwKDMKIHONN_GENGAKU_KEI,
                           NwKDMKIHONN_NENZEI,
                           NwKDMKIHONN_NUSHI_KOJIN_NO,
                           NwKDMKIHONN_KINTO_CNT,
                           NwKDMKIHONN_GENZAI_CNT,
                           NwKDMKIHONN_SHINKOKU_KBN,
                           NwKDMKIHONN_SHOTOKU,
                           NwKDMKIHONN_KINTO_CNT_KDM18
                      FROM ZLBTKDM_KIHON_N
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NwKDM_FLG := 1;     -- 子どもデータなし
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                        EXIT;
                END;
            END IF;
--  2025/08/11 ZCZL.HEJIAQI ADD END

            -- 更新判定
--  2025/08/11 ZCZL.HEJIAQI UPDATE START 1.1.200.000: 子ども子育て支援金対応
--            IF NwIRY_FLG = 0 AND NwKAI_FLG = 0 AND NwSIEN_FLG = 0 THEN
--                -- 医療/介護/支援共にデータ有り
            IF NwIRY_FLG = 0 AND NwKAI_FLG = 0 AND NwSIEN_FLG = 0 AND NwKDM_FLG = 0 THEN
                -- 医療/介護/支援/子ども共にデータ有り
--  2025/08/11 ZCZL.HEJIAQI UPDATE END

                IF RwKIHONC.SEKISAN         != NwKIHONN_SEKISAN         OR      -- 積算税額
                   RwKIHONC.GENDO_CHOKA     != NwKIHONN_GENDO_CHOKA     OR      -- 限度超過額
                   RwKIHONC.GENGAKU_KEI     != NwKIHONN_GENGAKU_KEI     OR      -- 減額合計
                   RwKIHONC.NENZEI          != NwKIHONN_NENZEI          OR      -- 年税額
                   RwKIHONC.NUSHI_KOJIN_NO  != NwKIHONN_NUSHI_KOJIN_NO  OR      -- 主個人番号
                   RwKIHONC.KINTO_CNT       != NwKIHONN_KINTO_CNT       OR      -- 均等人員
                   RwKIHONC.GENZAI_CNT      != NwKIHONN_GENZAI_CNT      OR      -- 現在人員
                   RwKIHONC.SHINKOKU_KBN    != NwKIHONN_SHINKOKU_KBN    OR      --申告区分
                   RwKIHONC.SHOTOKU         != NwKIHONN_SHOTOKU         OR      --所得額
                   RwKIHONC.YOKU_TSUCHI_NO  != NwKIHONN_YOKU_TSUCHI_NO  OR      --翌年度通知書番号
                   NwTAIC_SEKISAN           != NwTAIN_SEKISAN           OR      -- 積算税額
                   NwTAIC_GENDO_CHOKA       != NwTAIN_GENDO_CHOKA       OR      -- 限度超過額
                   NwTAIC_GENGAKU_KEI       != NwTAIN_GENGAKU_KEI       OR      -- 減額合計
                   NwTAIC_NENZEI            != NwTAIN_NENZEI            OR      -- 年税額
                   NwTAIC_KINTO_CNT         != NwTAIN_KINTO_CNT         OR      -- 均等人員
                   NwTAIC_GENZAI_CNT        != NwTAIN_GENZAI_CNT        OR      -- 現在人員
                   NwTAIC_SHOTOKU           != NwTAIN_SHOTOKU           OR      --所得額
                   NwKKIHONC_SEKISAN        != NwKKIHONN_SEKISAN        OR      -- 積算税額
                   NwKKIHONC_GENDO_CHOKA    != NwKKIHONN_GENDO_CHOKA    OR      -- 限度超過額
                   NwKKIHONC_GENGAKU_KEI    != NwKKIHONN_GENGAKU_KEI    OR      -- 減額合計
                   NwKKIHONC_NENZEI         != NwKKIHONN_NENZEI         OR      -- 年税額
                   NwKKIHONC_NUSHI_KOJIN_NO != NwKKIHONN_NUSHI_KOJIN_NO OR      -- 主個人番号
                   NwKKIHONC_KINTO_CNT      != NwKKIHONN_KINTO_CNT      OR      -- 均等人員
                   NwKKIHONC_SHINKOKU_KBN   != NwKKIHONN_SHINKOKU_KBN   OR      --申告区分
                   NwKKIHONC_SHOTOKU        != NwKKIHONN_SHOTOKU        OR      --所得額
                   NwKTAIC_SEKISAN          != NwKTAIN_SEKISAN          OR      -- 積算税額
                   NwKTAIC_GENDO_CHOKA      != NwKTAIN_GENDO_CHOKA      OR      -- 限度超過額
                   NwKTAIC_GENGAKU_KEI      != NwKTAIN_GENGAKU_KEI      OR      -- 減額合計
                   NwKTAIC_NENZEI           != NwKTAIN_NENZEI           OR      -- 年税額
                   NwKTAIC_KINTO_CNT        != NwKTAIN_KINTO_CNT        OR      -- 均等人員
                   NwKTAIC_SHOTOKU          != NwKTAIN_SHOTOKU          OR      -- 所得額
                   NwSKIHONC_SEKISAN        != NwSKIHONN_SEKISAN        OR      -- 積算税額
                   NwSKIHONC_GENDO_CHOKA    != NwSKIHONN_GENDO_CHOKA    OR      -- 限度超過額
                   NwSKIHONC_GENGAKU_KEI    != NwSKIHONN_GENGAKU_KEI    OR      -- 減額合計
                   NwSKIHONC_NENZEI         != NwSKIHONN_NENZEI         OR      -- 年税額
                   NwSKIHONC_NUSHI_KOJIN_NO != NwSKIHONN_NUSHI_KOJIN_NO OR      -- 主個人番号
                   NwSKIHONC_KINTO_CNT      != NwSKIHONN_KINTO_CNT      OR      -- 均等人員
                   NwSKIHONC_GENZAI_CNT     != NwSKIHONN_GENZAI_CNT     OR      -- 現在人員
                   NwSKIHONC_SHINKOKU_KBN   != NwSKIHONN_SHINKOKU_KBN   OR      -- 申告区分
                   NwSKIHONC_SHOTOKU        != NwSKIHONN_SHOTOKU        OR      -- 所得額
                   NwSTAIC_SEKISAN          != NwSTAIN_SEKISAN          OR      -- 積算税額
                   NwSTAIC_GENDO_CHOKA      != NwSTAIN_GENDO_CHOKA      OR      -- 限度超過額
                   NwSTAIC_GENGAKU_KEI      != NwSTAIN_GENGAKU_KEI      OR      -- 減額合計
                   NwSTAIC_NENZEI           != NwSTAIN_NENZEI           OR      -- 年税額
                   NwSTAIC_KINTO_CNT        != NwSTAIN_KINTO_CNT        OR      -- 均等人員
                   NwSTAIC_GENZAI_CNT       != NwSTAIN_GENZAI_CNT       OR      -- 現在人員
--  2025/08/11 ZCZL.HEJIAQI UPDATE START 1.1.200.000: 子ども子育て支援金対応
--                   NwSTAIC_SHOTOKU          != NwSTAIN_SHOTOKU          THEN    -- 所得額
                   NwSTAIC_SHOTOKU            != NwSTAIN_SHOTOKU            OR    -- 所得額
                   NwKDMKIHONC_SEKISAN        != NwKDMKIHONN_SEKISAN        OR    -- 積算税額
                   NwKDMKIHONC_GENDO_CHOKA    != NwKDMKIHONN_GENDO_CHOKA    OR    -- 限度超過額
                   NwKDMKIHONC_GENGAKU_KEI    != NwKDMKIHONN_GENGAKU_KEI    OR    -- 減額合計
                   NwKDMKIHONC_NENZEI         != NwKDMKIHONN_NENZEI         OR    -- 年税額
                   NwKDMKIHONC_NUSHI_KOJIN_NO != NwKDMKIHONN_NUSHI_KOJIN_NO OR    -- 主個人番号
                   NwKDMKIHONC_KINTO_CNT      != NwKDMKIHONN_KINTO_CNT      OR    -- 均等人員
                   NwKDMKIHONC_GENZAI_CNT     != NwKDMKIHONN_GENZAI_CNT     OR    -- 現在人員
                   NwKDMKIHONC_SHINKOKU_KBN   != NwKDMKIHONN_SHINKOKU_KBN   OR    -- 申告区分
                   NwKDMKIHONC_SHOTOKU        != NwKDMKIHONN_SHOTOKU        OR    -- 所得額
                   NwKDMKIHONC_KINTO_CNT_KDM18!= NwKDMKIHONN_KINTO_CNT_KDM18 THEN  -- 18歳以上均等人員
--  2025/08/11 ZCZL.HEJIAQI UPDATE END

                    NlCHK_R := c_NOK;

                END IF;

            ELSIF NwIRY_FLG = 1 THEN
                -- 医療にデータなし

                IF RwKIHONC.NENZEI != 0 OR RwKIHONC.FUKA_KIJITSU_CNT != 0 THEN

                    NlCHK_R := c_NOK;

                END IF;

--  2025/08/11 ZCZL.HEJIAQI UPDATE START 1.1.200.000: 子ども子育て支援金対応
--            ELSIF NwKAI_FLG = 1 AND NwSIEN_FLG = 1 THEN
--            -- 介護and支援にデータなし
--
--                IF RwKIHONC.SEKISAN         != NwKIHONN_SEKISAN         OR      -- 積算税額
--                   RwKIHONC.GENDO_CHOKA     != NwKIHONN_GENDO_CHOKA     OR      -- 限度超過額
--                   RwKIHONC.GENGAKU_KEI     != NwKIHONN_GENGAKU_KEI     OR      -- 減額合計
--                   RwKIHONC.NENZEI          != NwKIHONN_NENZEI          OR      -- 年税額
--                   RwKIHONC.NUSHI_KOJIN_NO  != NwKIHONN_NUSHI_KOJIN_NO  OR      -- 主個人番号
--                   RwKIHONC.KINTO_CNT       != NwKIHONN_KINTO_CNT       OR      -- 均等人員
--                   RwKIHONC.GENZAI_CNT      != NwKIHONN_GENZAI_CNT      OR      -- 現在人員
--                   RwKIHONC.SHINKOKU_KBN    != NwKIHONN_SHINKOKU_KBN    OR      --申告区分
--                   RwKIHONC.SHOTOKU         != NwKIHONN_SHOTOKU         OR      --所得額
--                   NwTAIC_SEKISAN           != NwTAIN_SEKISAN           OR      -- 積算税額
--                   NwTAIC_GENDO_CHOKA       != NwTAIN_GENDO_CHOKA       OR      -- 限度超過額
--                   NwTAIC_GENGAKU_KEI       != NwTAIN_GENGAKU_KEI       OR      -- 減額合計
--                   NwTAIC_NENZEI            != NwTAIN_NENZEI            OR      -- 年税額
--                   NwTAIC_KINTO_CNT         != NwTAIN_KINTO_CNT         OR      -- 均等人員
--                   NwTAIC_GENZAI_CNT        != NwTAIN_GENZAI_CNT        OR      -- 現在人員
--                   NwTAIC_SHOTOKU           != NwTAIN_SHOTOKU           THEN    --所得額
--
--                    NlCHK_R := c_NOK;
--
--                END IF;
--            ELSIF NwKAI_FLG = 1 AND NwSIEN_FLG = 0 THEN
--            -- 介護データなしand支援データあり
--
--                IF -- 医療基本
--                   RwKIHONC.SEKISAN         != NwKIHONN_SEKISAN         OR      -- 積算税額
--                   RwKIHONC.GENDO_CHOKA     != NwKIHONN_GENDO_CHOKA     OR      -- 限度超過額
--                   RwKIHONC.GENGAKU_KEI     != NwKIHONN_GENGAKU_KEI     OR      -- 減額合計
--                   RwKIHONC.NENZEI          != NwKIHONN_NENZEI          OR      -- 年税額
--                   RwKIHONC.NUSHI_KOJIN_NO  != NwKIHONN_NUSHI_KOJIN_NO  OR      -- 主個人番号
--                   RwKIHONC.KINTO_CNT       != NwKIHONN_KINTO_CNT       OR      -- 均等人員
--                   RwKIHONC.GENZAI_CNT      != NwKIHONN_GENZAI_CNT      OR      -- 現在人員
--                   RwKIHONC.SHINKOKU_KBN    != NwKIHONN_SHINKOKU_KBN    OR      -- 申告区分
--                   RwKIHONC.SHOTOKU         != NwKIHONN_SHOTOKU         OR      -- 所得額
--                   -- 医療退職
--                   NwTAIC_SEKISAN           != NwTAIN_SEKISAN           OR      -- 積算税額
--                   NwTAIC_GENDO_CHOKA       != NwTAIN_GENDO_CHOKA       OR      -- 限度超過額
--                   NwTAIC_GENGAKU_KEI       != NwTAIN_GENGAKU_KEI       OR      -- 減額合計
--                   NwTAIC_NENZEI            != NwTAIN_NENZEI            OR      -- 年税額
--                   NwTAIC_KINTO_CNT         != NwTAIN_KINTO_CNT         OR      -- 均等人員
--                   NwTAIC_GENZAI_CNT        != NwTAIN_GENZAI_CNT        OR      -- 現在人員
--                   NwTAIC_SHOTOKU           != NwTAIN_SHOTOKU           OR      -- 所得額
--                   -- 支援基本
--                   NwSKIHONC_SEKISAN        != NwSKIHONN_SEKISAN        OR      -- 積算税額
--                   NwSKIHONC_GENDO_CHOKA    != NwSKIHONN_GENDO_CHOKA    OR      -- 限度超過額
--                   NwSKIHONC_GENGAKU_KEI    != NwSKIHONN_GENGAKU_KEI    OR      -- 減額合計
--                   NwSKIHONC_NENZEI         != NwSKIHONN_NENZEI         OR      -- 年税額
--                   NwSKIHONC_NUSHI_KOJIN_NO != NwSKIHONN_NUSHI_KOJIN_NO OR      -- 主個人番号
--                   NwSKIHONC_KINTO_CNT      != NwSKIHONN_KINTO_CNT      OR      -- 均等人員
--                   NwSKIHONC_GENZAI_CNT     != NwSKIHONN_GENZAI_CNT     OR      -- 現在人員
--                   NwSKIHONC_SHINKOKU_KBN   != NwSKIHONN_SHINKOKU_KBN   OR      -- 申告区分
--                   NwSKIHONC_SHOTOKU        != NwSKIHONN_SHOTOKU        OR      -- 所得額
--                   -- 支援退職
--                   NwSTAIC_SEKISAN          != NwSTAIN_SEKISAN          OR      -- 積算税額
--                   NwSTAIC_GENDO_CHOKA      != NwSTAIN_GENDO_CHOKA      OR      -- 限度超過額
--                   NwSTAIC_GENGAKU_KEI      != NwSTAIN_GENGAKU_KEI      OR      -- 減額合計
--                   NwSTAIC_NENZEI           != NwSTAIN_NENZEI           OR      -- 年税額
--                   NwSTAIC_KINTO_CNT        != NwSTAIN_KINTO_CNT        OR      -- 均等人員
--                   NwSTAIC_GENZAI_CNT       != NwSTAIN_GENZAI_CNT       OR      -- 現在人員
--                   NwSTAIC_SHOTOKU          != NwSTAIN_SHOTOKU          THEN    -- 所得額
--
--                    NlCHK_R := c_NOK;
--
--                END IF;
--
--            ELSIF NwKAI_FLG = 0 AND NwSIEN_FLG = 1 THEN
--            -- 介護データありand支援データなし
--
--                IF -- 医療基本
--                   RwKIHONC.SEKISAN         != NwKIHONN_SEKISAN         OR      -- 積算税額
--                   RwKIHONC.GENDO_CHOKA     != NwKIHONN_GENDO_CHOKA     OR      -- 限度超過額
--                   RwKIHONC.GENGAKU_KEI     != NwKIHONN_GENGAKU_KEI     OR      -- 減額合計
--                   RwKIHONC.NENZEI          != NwKIHONN_NENZEI          OR      -- 年税額
--                   RwKIHONC.NUSHI_KOJIN_NO  != NwKIHONN_NUSHI_KOJIN_NO  OR      -- 主個人番号
--                   RwKIHONC.KINTO_CNT       != NwKIHONN_KINTO_CNT       OR      -- 均等人員
--                   RwKIHONC.GENZAI_CNT      != NwKIHONN_GENZAI_CNT      OR      -- 現在人員
--                   RwKIHONC.SHINKOKU_KBN    != NwKIHONN_SHINKOKU_KBN    OR      -- 申告区分
--                   RwKIHONC.SHOTOKU         != NwKIHONN_SHOTOKU         OR      -- 所得額
--                   -- 医療退職
--                   NwTAIC_SEKISAN           != NwTAIN_SEKISAN           OR      -- 積算税額
--                   NwTAIC_GENDO_CHOKA       != NwTAIN_GENDO_CHOKA       OR      -- 限度超過額
--                   NwTAIC_GENGAKU_KEI       != NwTAIN_GENGAKU_KEI       OR      -- 減額合計
--                   NwTAIC_NENZEI            != NwTAIN_NENZEI            OR      -- 年税額
--                   NwTAIC_KINTO_CNT         != NwTAIN_KINTO_CNT         OR      -- 均等人員
--                   NwTAIC_GENZAI_CNT        != NwTAIN_GENZAI_CNT        OR      -- 現在人員
--                   NwTAIC_SHOTOKU           != NwTAIN_SHOTOKU           OR      -- 所得額
--                   -- 介護基本
--                   NwKKIHONC_SEKISAN        != NwKKIHONN_SEKISAN        OR      -- 積算税額
--                   NwKKIHONC_GENDO_CHOKA    != NwKKIHONN_GENDO_CHOKA    OR      -- 限度超過額
--                   NwKKIHONC_GENGAKU_KEI    != NwKKIHONN_GENGAKU_KEI    OR      -- 減額合計
--                   NwKKIHONC_NENZEI         != NwKKIHONN_NENZEI         OR      -- 年税額
--                   NwKKIHONC_NUSHI_KOJIN_NO != NwKKIHONN_NUSHI_KOJIN_NO OR      -- 主個人番号
--                   NwKKIHONC_KINTO_CNT      != NwKKIHONN_KINTO_CNT      OR      -- 均等人員
--                   NwKKIHONC_SHINKOKU_KBN   != NwKKIHONN_SHINKOKU_KBN   OR      -- 申告区分
--                   NwKKIHONC_SHOTOKU        != NwKKIHONN_SHOTOKU        OR      -- 所得額
--                   -- 介護退職
--                   NwKTAIC_SEKISAN          != NwKTAIN_SEKISAN          OR      -- 積算税額
--                   NwKTAIC_GENDO_CHOKA      != NwKTAIN_GENDO_CHOKA      OR      -- 限度超過額
--                   NwKTAIC_GENGAKU_KEI      != NwKTAIN_GENGAKU_KEI      OR      -- 減額合計
--                   NwKTAIC_NENZEI           != NwKTAIN_NENZEI           OR      -- 年税額
--                   NwKTAIC_KINTO_CNT        != NwKTAIN_KINTO_CNT        OR      -- 均等人員
--                   NwKTAIC_SHOTOKU          != NwKTAIN_SHOTOKU          THEN    -- 所得額
--
--                    NlCHK_R := c_NOK;
--
--                END IF;
                  -- 介護データあり、支援データあり、子どもデータなし
                  ELSIF NwKAI_FLG = 0 AND NwSIEN_FLG = 0 AND NwKDM_FLG = 1 THEN
                      IF -- 医療基本
                         RwKIHONC.SEKISAN         != NwKIHONN_SEKISAN         OR      -- 積算税額
                         RwKIHONC.GENDO_CHOKA     != NwKIHONN_GENDO_CHOKA     OR      -- 限度超過額
                         RwKIHONC.GENGAKU_KEI     != NwKIHONN_GENGAKU_KEI     OR      -- 減額合計
                         RwKIHONC.NENZEI          != NwKIHONN_NENZEI          OR      -- 年税額
                         RwKIHONC.NUSHI_KOJIN_NO  != NwKIHONN_NUSHI_KOJIN_NO  OR      -- 主個人番号
                         RwKIHONC.KINTO_CNT       != NwKIHONN_KINTO_CNT       OR      -- 均等人員
                         RwKIHONC.GENZAI_CNT      != NwKIHONN_GENZAI_CNT      OR      -- 現在人員
                         RwKIHONC.SHINKOKU_KBN    != NwKIHONN_SHINKOKU_KBN    OR      -- 申告区分
                         RwKIHONC.SHOTOKU         != NwKIHONN_SHOTOKU         OR      -- 所得額
                         -- 医療退職
                         NwTAIC_SEKISAN           != NwTAIN_SEKISAN           OR      -- 積算税額
                         NwTAIC_GENDO_CHOKA       != NwTAIN_GENDO_CHOKA       OR      -- 限度超過額
                         NwTAIC_GENGAKU_KEI       != NwTAIN_GENGAKU_KEI       OR      -- 減額合計
                         NwTAIC_NENZEI            != NwTAIN_NENZEI            OR      -- 年税額
                         NwTAIC_KINTO_CNT         != NwTAIN_KINTO_CNT         OR      -- 均等人員
                         NwTAIC_GENZAI_CNT        != NwTAIN_GENZAI_CNT        OR      -- 現在人員
                         NwTAIC_SHOTOKU           != NwTAIN_SHOTOKU           OR      -- 所得額
                         -- 介護基本
                         NwKKIHONC_SEKISAN        != NwKKIHONN_SEKISAN        OR      -- 積算税額
                         NwKKIHONC_GENDO_CHOKA    != NwKKIHONN_GENDO_CHOKA    OR      -- 限度超過額
                         NwKKIHONC_GENGAKU_KEI    != NwKKIHONN_GENGAKU_KEI    OR      -- 減額合計
                         NwKKIHONC_NENZEI         != NwKKIHONN_NENZEI         OR      -- 年税額
                         NwKKIHONC_NUSHI_KOJIN_NO != NwKKIHONN_NUSHI_KOJIN_NO OR      -- 主個人番号
                         NwKKIHONC_KINTO_CNT      != NwKKIHONN_KINTO_CNT      OR      -- 均等人員
                         NwKKIHONC_SHINKOKU_KBN   != NwKKIHONN_SHINKOKU_KBN   OR      -- 申告区分
                         NwKKIHONC_SHOTOKU        != NwKKIHONN_SHOTOKU        OR      -- 所得額
                         -- 介護退職
                         NwKTAIC_SEKISAN          != NwKTAIN_SEKISAN          OR      -- 積算税額
                         NwKTAIC_GENDO_CHOKA      != NwKTAIN_GENDO_CHOKA      OR      -- 限度超過額
                         NwKTAIC_GENGAKU_KEI      != NwKTAIN_GENGAKU_KEI      OR      -- 減額合計
                         NwKTAIC_NENZEI           != NwKTAIN_NENZEI           OR      -- 年税額
                         NwKTAIC_KINTO_CNT        != NwKTAIN_KINTO_CNT        OR      -- 均等人員
                         NwKTAIC_SHOTOKU          != NwKTAIN_SHOTOKU          OR      -- 所得額
                         -- 支援基本
                         NwSKIHONC_SEKISAN        != NwSKIHONN_SEKISAN        OR      -- 積算税額
                         NwSKIHONC_GENDO_CHOKA    != NwSKIHONN_GENDO_CHOKA    OR      -- 限度超過額
                         NwSKIHONC_GENGAKU_KEI    != NwSKIHONN_GENGAKU_KEI    OR      -- 減額合計
                         NwSKIHONC_NENZEI         != NwSKIHONN_NENZEI         OR      -- 年税額
                         NwSKIHONC_NUSHI_KOJIN_NO != NwSKIHONN_NUSHI_KOJIN_NO OR      -- 主個人番号
                         NwSKIHONC_KINTO_CNT      != NwSKIHONN_KINTO_CNT      OR      -- 均等人員
                         NwSKIHONC_GENZAI_CNT     != NwSKIHONN_GENZAI_CNT     OR      -- 現在人員
                         NwSKIHONC_SHINKOKU_KBN   != NwSKIHONN_SHINKOKU_KBN   OR      -- 申告区分
                         NwSKIHONC_SHOTOKU        != NwSKIHONN_SHOTOKU        OR      -- 所得額
                         -- 支援退職
                         NwSTAIC_SEKISAN          != NwSTAIN_SEKISAN          OR      -- 積算税額
                         NwSTAIC_GENDO_CHOKA      != NwSTAIN_GENDO_CHOKA      OR      -- 限度超過額
                         NwSTAIC_GENGAKU_KEI      != NwSTAIN_GENGAKU_KEI      OR      -- 減額合計
                         NwSTAIC_NENZEI           != NwSTAIN_NENZEI           OR      -- 年税額
                         NwSTAIC_KINTO_CNT        != NwSTAIN_KINTO_CNT        OR      -- 均等人員
                         NwSTAIC_GENZAI_CNT       != NwSTAIN_GENZAI_CNT       OR      -- 現在人員
                         NwSTAIC_SHOTOKU          != NwSTAIN_SHOTOKU          THEN    -- 所得額

                         NlCHK_R := c_NOK;
                     END IF;

                  -- 介護データなし、支援データなし、子どもデータあり
                  ELSIF NwKAI_FLG = 1 AND NwSIEN_FLG = 1 AND NwKDM_FLG = 0 THEN
                      IF -- 医療基本
                         RwKIHONC.SEKISAN           != NwKIHONN_SEKISAN           OR   -- 積算税額
                         RwKIHONC.GENDO_CHOKA       != NwKIHONN_GENDO_CHOKA       OR   -- 限度超過額
                         RwKIHONC.GENGAKU_KEI       != NwKIHONN_GENGAKU_KEI       OR   -- 減額合計
                         RwKIHONC.NENZEI            != NwKIHONN_NENZEI            OR   -- 年税額
                         RwKIHONC.NUSHI_KOJIN_NO    != NwKIHONN_NUSHI_KOJIN_NO    OR   -- 主個人番号
                         RwKIHONC.KINTO_CNT         != NwKIHONN_KINTO_CNT         OR   -- 均等人員
                         RwKIHONC.GENZAI_CNT        != NwKIHONN_GENZAI_CNT        OR   -- 現在人員
                         RwKIHONC.SHINKOKU_KBN      != NwKIHONN_SHINKOKU_KBN      OR   -- 申告区分
                         RwKIHONC.SHOTOKU           != NwKIHONN_SHOTOKU           OR   -- 所得額
                         -- 医療退職
                         NwTAIC_SEKISAN             != NwTAIN_SEKISAN             OR   -- 積算税額
                         NwTAIC_GENDO_CHOKA         != NwTAIN_GENDO_CHOKA         OR   -- 限度超過額
                         NwTAIC_GENGAKU_KEI         != NwTAIN_GENGAKU_KEI         OR   -- 減額合計
                         NwTAIC_NENZEI              != NwTAIN_NENZEI              OR   -- 年税額
                         NwTAIC_KINTO_CNT           != NwTAIN_KINTO_CNT           OR   -- 均等人員
                         NwTAIC_GENZAI_CNT          != NwTAIN_GENZAI_CNT          OR   -- 現在人員
                         NwTAIC_SHOTOKU             != NwTAIN_SHOTOKU             OR   -- 所得額
                         -- 子ども基本
                         NwKDMKIHONC_SEKISAN        != NwKDMKIHONN_SEKISAN        OR    -- 積算税額
                         NwKDMKIHONC_GENDO_CHOKA    != NwKDMKIHONN_GENDO_CHOKA    OR    -- 限度超過額
                         NwKDMKIHONC_GENGAKU_KEI    != NwKDMKIHONN_GENGAKU_KEI    OR    -- 減額合計
                         NwKDMKIHONC_NENZEI         != NwKDMKIHONN_NENZEI         OR    -- 年税額
                         NwKDMKIHONC_NUSHI_KOJIN_NO != NwKDMKIHONN_NUSHI_KOJIN_NO OR    -- 主個人番号
                         NwKDMKIHONC_KINTO_CNT      != NwKDMKIHONN_KINTO_CNT      OR    -- 均等人員
                         NwKDMKIHONC_GENZAI_CNT     != NwKDMKIHONN_GENZAI_CNT     OR    -- 現在人員
                         NwKDMKIHONC_SHINKOKU_KBN   != NwKDMKIHONN_SHINKOKU_KBN   OR    -- 申告区分
                         NwKDMKIHONC_SHOTOKU        != NwKDMKIHONN_SHOTOKU        OR    -- 所得額
                         NwKDMKIHONC_KINTO_CNT_KDM18!= NwKDMKIHONN_KINTO_CNT_KDM18 THEN -- 18歳以上均等人員

                         NlCHK_R := c_NOK;
                     END IF;

                  -- 介護データなし、支援データなし、子どもデータなし
                  ELSIF NwKAI_FLG = 1 AND NwSIEN_FLG = 1 AND NwKDM_FLG = 1 THEN
                      IF -- 医療基本
                         RwKIHONC.SEKISAN           != NwKIHONN_SEKISAN           OR    -- 積算税額
                         RwKIHONC.GENDO_CHOKA       != NwKIHONN_GENDO_CHOKA       OR    -- 限度超過額
                         RwKIHONC.GENGAKU_KEI       != NwKIHONN_GENGAKU_KEI       OR    -- 減額合計
                         RwKIHONC.NENZEI            != NwKIHONN_NENZEI            OR    -- 年税額
                         RwKIHONC.NUSHI_KOJIN_NO    != NwKIHONN_NUSHI_KOJIN_NO    OR    -- 主個人番号
                         RwKIHONC.KINTO_CNT         != NwKIHONN_KINTO_CNT         OR    -- 均等人員
                         RwKIHONC.GENZAI_CNT        != NwKIHONN_GENZAI_CNT        OR    -- 現在人員
                         RwKIHONC.SHINKOKU_KBN      != NwKIHONN_SHINKOKU_KBN      OR    -- 申告区分
                         RwKIHONC.SHOTOKU           != NwKIHONN_SHOTOKU           OR    -- 所得額
                         -- 医療退職
                         NwTAIC_SEKISAN             != NwTAIN_SEKISAN             OR    -- 積算税額
                         NwTAIC_GENDO_CHOKA         != NwTAIN_GENDO_CHOKA         OR    -- 限度超過額
                         NwTAIC_GENGAKU_KEI         != NwTAIN_GENGAKU_KEI         OR    -- 減額合計
                         NwTAIC_NENZEI              != NwTAIN_NENZEI              OR    -- 年税額
                         NwTAIC_KINTO_CNT           != NwTAIN_KINTO_CNT           OR    -- 均等人員
                         NwTAIC_GENZAI_CNT          != NwTAIN_GENZAI_CNT          OR    -- 現在人員
                         NwTAIC_SHOTOKU             != NwTAIN_SHOTOKU             THEN  -- 所得額

                         NlCHK_R := c_NOK;
                     END IF;

                  -- 介護データなし、支援データあり、子どもデータあり
                  ELSIF NwKAI_FLG = 1 AND NwSIEN_FLG = 0 AND NwKDM_FLG = 0 THEN
                      IF -- 医療基本
                         RwKIHONC.SEKISAN           != NwKIHONN_SEKISAN           OR    -- 積算税額
                         RwKIHONC.GENDO_CHOKA       != NwKIHONN_GENDO_CHOKA       OR    -- 限度超過額
                         RwKIHONC.GENGAKU_KEI       != NwKIHONN_GENGAKU_KEI       OR    -- 減額合計
                         RwKIHONC.NENZEI            != NwKIHONN_NENZEI            OR    -- 年税額
                         RwKIHONC.NUSHI_KOJIN_NO    != NwKIHONN_NUSHI_KOJIN_NO    OR    -- 主個人番号
                         RwKIHONC.KINTO_CNT         != NwKIHONN_KINTO_CNT         OR    -- 均等人員
                         RwKIHONC.GENZAI_CNT        != NwKIHONN_GENZAI_CNT        OR    -- 現在人員
                         RwKIHONC.SHINKOKU_KBN      != NwKIHONN_SHINKOKU_KBN      OR    -- 申告区分
                         RwKIHONC.SHOTOKU           != NwKIHONN_SHOTOKU           OR    -- 所得額
                         -- 医療退職
                         NwTAIC_SEKISAN             != NwTAIN_SEKISAN             OR    -- 積算税額
                         NwTAIC_GENDO_CHOKA         != NwTAIN_GENDO_CHOKA         OR    -- 限度超過額
                         NwTAIC_GENGAKU_KEI         != NwTAIN_GENGAKU_KEI         OR    -- 減額合計
                         NwTAIC_NENZEI              != NwTAIN_NENZEI              OR    -- 年税額
                         NwTAIC_KINTO_CNT           != NwTAIN_KINTO_CNT           OR    -- 均等人員
                         NwTAIC_GENZAI_CNT          != NwTAIN_GENZAI_CNT          OR    -- 現在人員
                         NwTAIC_SHOTOKU             != NwTAIN_SHOTOKU             OR    -- 所得額
                         -- 支援基本
                         NwSKIHONC_SEKISAN          != NwSKIHONN_SEKISAN          OR    -- 積算税額
                         NwSKIHONC_GENDO_CHOKA      != NwSKIHONN_GENDO_CHOKA      OR    -- 限度超過額
                         NwSKIHONC_GENGAKU_KEI      != NwSKIHONN_GENGAKU_KEI      OR    -- 減額合計
                         NwSKIHONC_NENZEI           != NwSKIHONN_NENZEI           OR    -- 年税額
                         NwSKIHONC_NUSHI_KOJIN_NO   != NwSKIHONN_NUSHI_KOJIN_NO   OR    -- 主個人番号
                         NwSKIHONC_KINTO_CNT        != NwSKIHONN_KINTO_CNT        OR    -- 均等人員
                         NwSKIHONC_GENZAI_CNT       != NwSKIHONN_GENZAI_CNT       OR    -- 現在人員
                         NwSKIHONC_SHINKOKU_KBN     != NwSKIHONN_SHINKOKU_KBN     OR    -- 申告区分
                         NwSKIHONC_SHOTOKU          != NwSKIHONN_SHOTOKU          OR    -- 所得額
                         -- 支援退職
                         NwSTAIC_SEKISAN            != NwSTAIN_SEKISAN            OR    -- 積算税額
                         NwSTAIC_GENDO_CHOKA        != NwSTAIN_GENDO_CHOKA        OR    -- 限度超過額
                         NwSTAIC_GENGAKU_KEI        != NwSTAIN_GENGAKU_KEI        OR    -- 減額合計
                         NwSTAIC_NENZEI             != NwSTAIN_NENZEI             OR    -- 年税額
                         NwSTAIC_KINTO_CNT          != NwSTAIN_KINTO_CNT          OR    -- 均等人員
                         NwSTAIC_GENZAI_CNT         != NwSTAIN_GENZAI_CNT         OR    -- 現在人員
                         NwSTAIC_SHOTOKU            != NwSTAIN_SHOTOKU            OR    -- 所得額
                         -- 子ども基本
                         NwKDMKIHONC_SEKISAN        != NwKDMKIHONN_SEKISAN        OR    -- 積算税額
                         NwKDMKIHONC_GENDO_CHOKA    != NwKDMKIHONN_GENDO_CHOKA    OR    -- 限度超過額
                         NwKDMKIHONC_GENGAKU_KEI    != NwKDMKIHONN_GENGAKU_KEI    OR    -- 減額合計
                         NwKDMKIHONC_NENZEI         != NwKDMKIHONN_NENZEI         OR    -- 年税額
                         NwKDMKIHONC_NUSHI_KOJIN_NO != NwKDMKIHONN_NUSHI_KOJIN_NO OR    -- 主個人番号
                         NwKDMKIHONC_KINTO_CNT      != NwKDMKIHONN_KINTO_CNT      OR    -- 均等人員
                         NwKDMKIHONC_GENZAI_CNT     != NwKDMKIHONN_GENZAI_CNT     OR    -- 現在人員
                         NwKDMKIHONC_SHINKOKU_KBN   != NwKDMKIHONN_SHINKOKU_KBN   OR    -- 申告区分
                         NwKDMKIHONC_SHOTOKU        != NwKDMKIHONN_SHOTOKU        OR    -- 所得額
                         NwKDMKIHONC_KINTO_CNT_KDM18!= NwKDMKIHONN_KINTO_CNT_KDM18 THEN -- 18歳以上均等人員

                         NlCHK_R := c_NOK;
                     END IF;

                  -- 介護データなし、支援データあり、子どもデータなし
                  ELSIF NwKAI_FLG = 1 AND NwSIEN_FLG = 0 AND NwKDM_FLG = 1 THEN
                      IF -- 医療基本
                         RwKIHONC.SEKISAN           != NwKIHONN_SEKISAN           OR    -- 積算税額
                         RwKIHONC.GENDO_CHOKA       != NwKIHONN_GENDO_CHOKA       OR    -- 限度超過額
                         RwKIHONC.GENGAKU_KEI       != NwKIHONN_GENGAKU_KEI       OR    -- 減額合計
                         RwKIHONC.NENZEI            != NwKIHONN_NENZEI            OR    -- 年税額
                         RwKIHONC.NUSHI_KOJIN_NO    != NwKIHONN_NUSHI_KOJIN_NO    OR    -- 主個人番号
                         RwKIHONC.KINTO_CNT         != NwKIHONN_KINTO_CNT         OR    -- 均等人員
                         RwKIHONC.GENZAI_CNT        != NwKIHONN_GENZAI_CNT        OR    -- 現在人員
                         RwKIHONC.SHINKOKU_KBN      != NwKIHONN_SHINKOKU_KBN      OR    -- 申告区分
                         RwKIHONC.SHOTOKU           != NwKIHONN_SHOTOKU           OR    -- 所得額
                         -- 医療退職
                         NwTAIC_SEKISAN             != NwTAIN_SEKISAN             OR    -- 積算税額
                         NwTAIC_GENDO_CHOKA         != NwTAIN_GENDO_CHOKA         OR    -- 限度超過額
                         NwTAIC_GENGAKU_KEI         != NwTAIN_GENGAKU_KEI         OR    -- 減額合計
                         NwTAIC_NENZEI              != NwTAIN_NENZEI              OR    -- 年税額
                         NwTAIC_KINTO_CNT           != NwTAIN_KINTO_CNT           OR    -- 均等人員
                         NwTAIC_GENZAI_CNT          != NwTAIN_GENZAI_CNT          OR    -- 現在人員
                         NwTAIC_SHOTOKU             != NwTAIN_SHOTOKU             OR    -- 所得額
                         -- 支援基本
                         NwSKIHONC_SEKISAN          != NwSKIHONN_SEKISAN          OR    -- 積算税額
                         NwSKIHONC_GENDO_CHOKA      != NwSKIHONN_GENDO_CHOKA      OR    -- 限度超過額
                         NwSKIHONC_GENGAKU_KEI      != NwSKIHONN_GENGAKU_KEI      OR    -- 減額合計
                         NwSKIHONC_NENZEI           != NwSKIHONN_NENZEI           OR    -- 年税額
                         NwSKIHONC_NUSHI_KOJIN_NO   != NwSKIHONN_NUSHI_KOJIN_NO   OR    -- 主個人番号
                         NwSKIHONC_KINTO_CNT        != NwSKIHONN_KINTO_CNT        OR    -- 均等人員
                         NwSKIHONC_GENZAI_CNT       != NwSKIHONN_GENZAI_CNT       OR    -- 現在人員
                         NwSKIHONC_SHINKOKU_KBN     != NwSKIHONN_SHINKOKU_KBN     OR    -- 申告区分
                         NwSKIHONC_SHOTOKU          != NwSKIHONN_SHOTOKU          OR    -- 所得額
                         -- 支援退職
                         NwSTAIC_SEKISAN            != NwSTAIN_SEKISAN            OR    -- 積算税額
                         NwSTAIC_GENDO_CHOKA        != NwSTAIN_GENDO_CHOKA        OR    -- 限度超過額
                         NwSTAIC_GENGAKU_KEI        != NwSTAIN_GENGAKU_KEI        OR    -- 減額合計
                         NwSTAIC_NENZEI             != NwSTAIN_NENZEI             OR    -- 年税額
                         NwSTAIC_KINTO_CNT          != NwSTAIN_KINTO_CNT          OR    -- 均等人員
                         NwSTAIC_GENZAI_CNT         != NwSTAIN_GENZAI_CNT         OR    -- 現在人員
                         NwSTAIC_SHOTOKU            != NwSTAIN_SHOTOKU            THEN  -- 所得額

                         NlCHK_R := c_NOK;
                     END IF;

                  -- 介護データあり、支援データなし、子どもデータあり
                  ELSIF NwKAI_FLG = 0 AND NwSIEN_FLG = 1 AND NwKDM_FLG = 0 THEN
                      IF -- 医療基本
                         RwKIHONC.SEKISAN           != NwKIHONN_SEKISAN           OR    -- 積算税額
                         RwKIHONC.GENDO_CHOKA       != NwKIHONN_GENDO_CHOKA       OR    -- 限度超過額
                         RwKIHONC.GENGAKU_KEI       != NwKIHONN_GENGAKU_KEI       OR    -- 減額合計
                         RwKIHONC.NENZEI            != NwKIHONN_NENZEI            OR    -- 年税額
                         RwKIHONC.NUSHI_KOJIN_NO    != NwKIHONN_NUSHI_KOJIN_NO    OR    -- 主個人番号
                         RwKIHONC.KINTO_CNT         != NwKIHONN_KINTO_CNT         OR    -- 均等人員
                         RwKIHONC.GENZAI_CNT        != NwKIHONN_GENZAI_CNT        OR    -- 現在人員
                         RwKIHONC.SHINKOKU_KBN      != NwKIHONN_SHINKOKU_KBN      OR    -- 申告区分
                         RwKIHONC.SHOTOKU           != NwKIHONN_SHOTOKU           OR    -- 所得額
                         -- 医療退職
                         NwTAIC_SEKISAN             != NwTAIN_SEKISAN             OR    -- 積算税額
                         NwTAIC_GENDO_CHOKA         != NwTAIN_GENDO_CHOKA         OR    -- 限度超過額
                         NwTAIC_GENGAKU_KEI         != NwTAIN_GENGAKU_KEI         OR    -- 減額合計
                         NwTAIC_NENZEI              != NwTAIN_NENZEI              OR    -- 年税額
                         NwTAIC_KINTO_CNT           != NwTAIN_KINTO_CNT           OR    -- 均等人員
                         NwTAIC_GENZAI_CNT          != NwTAIN_GENZAI_CNT          OR    -- 現在人員
                         NwTAIC_SHOTOKU             != NwTAIN_SHOTOKU             OR    -- 所得額
                         -- 介護基本
                         NwKKIHONC_SEKISAN          != NwKKIHONN_SEKISAN          OR    -- 積算税額
                         NwKKIHONC_GENDO_CHOKA      != NwKKIHONN_GENDO_CHOKA      OR    -- 限度超過額
                         NwKKIHONC_GENGAKU_KEI      != NwKKIHONN_GENGAKU_KEI      OR    -- 減額合計
                         NwKKIHONC_NENZEI           != NwKKIHONN_NENZEI           OR    -- 年税額
                         NwKKIHONC_NUSHI_KOJIN_NO   != NwKKIHONN_NUSHI_KOJIN_NO   OR    -- 主個人番号
                         NwKKIHONC_KINTO_CNT        != NwKKIHONN_KINTO_CNT        OR    -- 均等人員
                         NwKKIHONC_SHINKOKU_KBN     != NwKKIHONN_SHINKOKU_KBN     OR    -- 申告区分
                         NwKKIHONC_SHOTOKU          != NwKKIHONN_SHOTOKU          OR    -- 所得額
                         -- 介護退職
                         NwKTAIC_SEKISAN            != NwKTAIN_SEKISAN            OR    -- 積算税額
                         NwKTAIC_GENDO_CHOKA        != NwKTAIN_GENDO_CHOKA        OR    -- 限度超過額
                         NwKTAIC_GENGAKU_KEI        != NwKTAIN_GENGAKU_KEI        OR    -- 減額合計
                         NwKTAIC_NENZEI             != NwKTAIN_NENZEI             OR    -- 年税額
                         NwKTAIC_KINTO_CNT          != NwKTAIN_KINTO_CNT          OR    -- 均等人員
                         NwKTAIC_SHOTOKU            != NwKTAIN_SHOTOKU            OR    -- 所得額
                         -- 子ども基本
                         NwKDMKIHONC_SEKISAN        != NwKDMKIHONN_SEKISAN        OR    -- 積算税額
                         NwKDMKIHONC_GENDO_CHOKA    != NwKDMKIHONN_GENDO_CHOKA    OR    -- 限度超過額
                         NwKDMKIHONC_GENGAKU_KEI    != NwKDMKIHONN_GENGAKU_KEI    OR    -- 減額合計
                         NwKDMKIHONC_NENZEI         != NwKDMKIHONN_NENZEI         OR    -- 年税額
                         NwKDMKIHONC_NUSHI_KOJIN_NO != NwKDMKIHONN_NUSHI_KOJIN_NO OR    -- 主個人番号
                         NwKDMKIHONC_KINTO_CNT      != NwKDMKIHONN_KINTO_CNT      OR    -- 均等人員
                         NwKDMKIHONC_GENZAI_CNT     != NwKDMKIHONN_GENZAI_CNT     OR    -- 現在人員
                         NwKDMKIHONC_SHINKOKU_KBN   != NwKDMKIHONN_SHINKOKU_KBN   OR    -- 申告区分
                         NwKDMKIHONC_SHOTOKU        != NwKDMKIHONN_SHOTOKU        OR    -- 所得額
                         NwKDMKIHONC_KINTO_CNT_KDM18!= NwKDMKIHONN_KINTO_CNT_KDM18 THEN -- 18歳以上均等人員

                         NlCHK_R := c_NOK;
                     END IF;

                  -- 介護データあり、支援データなし、子どもデータなし
                  ELSIF NwKAI_FLG = 0 AND NwSIEN_FLG = 1 AND NwKDM_FLG = 1 THEN
                      IF -- 医療基本
                         RwKIHONC.SEKISAN           != NwKIHONN_SEKISAN           OR    -- 積算税額
                         RwKIHONC.GENDO_CHOKA       != NwKIHONN_GENDO_CHOKA       OR    -- 限度超過額
                         RwKIHONC.GENGAKU_KEI       != NwKIHONN_GENGAKU_KEI       OR    -- 減額合計
                         RwKIHONC.NENZEI            != NwKIHONN_NENZEI            OR    -- 年税額
                         RwKIHONC.NUSHI_KOJIN_NO    != NwKIHONN_NUSHI_KOJIN_NO    OR    -- 主個人番号
                         RwKIHONC.KINTO_CNT         != NwKIHONN_KINTO_CNT         OR    -- 均等人員
                         RwKIHONC.GENZAI_CNT        != NwKIHONN_GENZAI_CNT        OR    -- 現在人員
                         RwKIHONC.SHINKOKU_KBN      != NwKIHONN_SHINKOKU_KBN      OR    -- 申告区分
                         RwKIHONC.SHOTOKU           != NwKIHONN_SHOTOKU           OR    -- 所得額
                         -- 医療退職
                         NwTAIC_SEKISAN             != NwTAIN_SEKISAN             OR    -- 積算税額
                         NwTAIC_GENDO_CHOKA         != NwTAIN_GENDO_CHOKA         OR    -- 限度超過額
                         NwTAIC_GENGAKU_KEI         != NwTAIN_GENGAKU_KEI         OR    -- 減額合計
                         NwTAIC_NENZEI              != NwTAIN_NENZEI              OR    -- 年税額
                         NwTAIC_KINTO_CNT           != NwTAIN_KINTO_CNT           OR    -- 均等人員
                         NwTAIC_GENZAI_CNT          != NwTAIN_GENZAI_CNT          OR    -- 現在人員
                         NwTAIC_SHOTOKU             != NwTAIN_SHOTOKU             OR    -- 所得額
                         -- 介護基本
                         NwKKIHONC_SEKISAN          != NwKKIHONN_SEKISAN          OR    -- 積算税額
                         NwKKIHONC_GENDO_CHOKA      != NwKKIHONN_GENDO_CHOKA      OR    -- 限度超過額
                         NwKKIHONC_GENGAKU_KEI      != NwKKIHONN_GENGAKU_KEI      OR    -- 減額合計
                         NwKKIHONC_NENZEI           != NwKKIHONN_NENZEI           OR    -- 年税額
                         NwKKIHONC_NUSHI_KOJIN_NO   != NwKKIHONN_NUSHI_KOJIN_NO   OR    -- 主個人番号
                         NwKKIHONC_KINTO_CNT        != NwKKIHONN_KINTO_CNT        OR    -- 均等人員
                         NwKKIHONC_SHINKOKU_KBN     != NwKKIHONN_SHINKOKU_KBN     OR    -- 申告区分
                         NwKKIHONC_SHOTOKU          != NwKKIHONN_SHOTOKU          OR    -- 所得額
                         -- 介護退職
                         NwKTAIC_SEKISAN            != NwKTAIN_SEKISAN            OR    -- 積算税額
                         NwKTAIC_GENDO_CHOKA        != NwKTAIN_GENDO_CHOKA        OR    -- 限度超過額
                         NwKTAIC_GENGAKU_KEI        != NwKTAIN_GENGAKU_KEI        OR    -- 減額合計
                         NwKTAIC_NENZEI             != NwKTAIN_NENZEI             OR    -- 年税額
                         NwKTAIC_KINTO_CNT          != NwKTAIN_KINTO_CNT          OR    -- 均等人員
                         NwKTAIC_SHOTOKU            != NwKTAIN_SHOTOKU            THEN  -- 所得額

                         NlCHK_R := c_NOK;
                     END IF;
--  2025/08/11 ZCZL.HEJIAQI UPDATE END
            END IF;

            IF NlCHK_R != c_NOK THEN
                BEGIN
                  -- 計算特徴対象者 特徴状態 取得
                  SELECT JOTAI_KBN
                    INTO NwJOTAI_KBN_CAL
                    FROM ZLBTTOKU_KIHON_CAL
                   WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                     AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                     AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                     AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                     AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                     AND SYS_TANMATSU_NO = i_VTANMATSU;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                     NwJOTAI_KBN_CAL := 9;     -- 特徴対象者データなし
                   WHEN OTHERS THEN
                     NlRTN := c_NERR;
                     VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                     EXIT;
                END;

                -- 計算特徴対象者チェック
                IF NwJOTAI_KBN_CAL != 9 THEN
                    BEGIN
                      -- 賦課特徴対象者 特徴状態 取得
                      SELECT JOTAI_KBN
                        INTO NwJOTAI_KBN_N
                        FROM ZLBTTOKU_KIHON_N
                       WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                         AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                         AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                         AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                         AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                    EXCEPTION
                       WHEN NO_DATA_FOUND THEN
                         NwJOTAI_KBN_N := 9;     -- 特徴対象者データなし
                       WHEN OTHERS THEN
                         NlRTN := c_NERR;
                         VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                         EXIT;
                    END;

                    -- 特徴状態チェック
                    IF NwJOTAI_KBN_CAL != NwJOTAI_KBN_N THEN
                        NlCHK_R := c_NOK;        -- 変更あり
                    END IF;

                END IF;

                -- 変更状態チェック
                IF NlCHK_R != c_NOK THEN
                    -- 翌年度通知書番号チェック
                    IF RwKIHONC.YOKU_TSUCHI_NO != 0 THEN
                        BEGIN
                          -- 翌年度計算特徴対象者 特徴状態 取得
                          SELECT JOTAI_KBN
                            INTO NwJOTAI_KBN_CAL
                            FROM ZLBTTOKU_KIHON_CAL
                           WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                             AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                             AND CHOTEI_NENDO    = (RwKIHONC.CHOTEI_NENDO)+1
                             AND NENDO_BUN       = (RwKIHONC.NENDO_BUN)+1
                             AND TSUCHI_NO       = RwKIHONC.YOKU_TSUCHI_NO
                             AND SYS_TANMATSU_NO = i_VTANMATSU;
                        EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                            NwJOTAI_KBN_CAL := 9;     -- 特徴対象者データなし
                          WHEN OTHERS THEN
                            NlRTN := c_NERR;
                            VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                            EXIT;
                        END;

                        -- 翌年度計算特徴者対象チェック
                        IF NwJOTAI_KBN_CAL != 9 THEN
                            BEGIN
                              -- 翌年度の賦課特徴対象者 特徴状態 取得
                              SELECT JOTAI_KBN
                                INTO NwJOTAI_KBN_N
                                FROM ZLBTTOKU_KIHON_N
                               WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                                 AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                                 AND CHOTEI_NENDO    = (RwKIHONC.CHOTEI_NENDO)+1
                                 AND NENDO_BUN       = (RwKIHONC.NENDO_BUN)+1
                                 AND TSUCHI_NO       = RwKIHONC.YOKU_TSUCHI_NO;
                            EXCEPTION
                              WHEN NO_DATA_FOUND THEN
                                NwJOTAI_KBN_N := 9;     -- 特徴対象者データなし
                              WHEN OTHERS THEN
                                NlRTN := c_NERR;
                                VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                                EXIT;
                            END;

                            -- 特徴状態チェック
                            IF NwJOTAI_KBN_CAL != NwJOTAI_KBN_N THEN
                                NlCHK_R := c_NOK;       -- 変更あり
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END IF;
            -- 現年度期別データチェック
            IF NlCHK_R != c_NOK THEN
               BEGIN
                 -- 該当個人の最新期別テーブルの件数を確認
                 SELECT COUNT(KOKU_SETAI_NO)
                   INTO NCNT_N
                   FROM ZLBTKIBETSU_N
                  WHERE KOKU_SETAI_NO      = RwKIHONC.KOKU_SETAI_NO
                    AND SANTEIDANTAI_CD    = RwKIHONC.SANTEIDANTAI_CD
                    AND CHOTEINENDO        = RwKIHONC.CHOTEI_NENDO
                    AND NENDOBUN           = RwKIHONC.NENDO_BUN
                    AND TSUCHI_NO          = RwKIHONC.TSUCHI_NO;
                 -- 0件の場合
                 IF NCNT_N = 0 THEN
                   NlCHK_R := c_NOK;       -- 変更あり
                 -- N件の場合
                 ELSE
                   -- 件数を確認
                   SELECT COUNT(A. KOKU_SETAI_NO)
                     INTO NCNT_CAL
                     FROM ZLBTKIBETSU_N A,ZLBTKIBETSU_CAL B
                    WHERE A.KOKU_SETAI_NO     = RwKIHONC.KOKU_SETAI_NO
                      AND A.SANTEIDANTAI_CD   = RwKIHONC.SANTEIDANTAI_CD
                      AND A.CHOTEINENDO       = RwKIHONC.CHOTEI_NENDO
                      AND A.NENDOBUN          = RwKIHONC.NENDO_BUN
                      AND A.TSUCHI_NO         = RwKIHONC.TSUCHI_NO
                      AND B.SYS_TANMATSU_NO   = i_VTANMATSU
                      AND A.KAMOKU_CD         = B.KAMOKU_CD
                      AND A.KAMOKUS_CD        = B.KAMOKUS_CD
                      AND A.KOKU_SETAI_NO     = B.KOKU_SETAI_NO
                      AND A.SANTEIDANTAI_CD   = B.SANTEIDANTAI_CD
                      AND A.KIWARIDANTAI_CD   = B.KIWARIDANTAI_CD
                      AND A.GENNENKANEN_KBN   = B.GENNENKANEN_KBN
                      AND A.CHOTEINENDO       = B.CHOTEINENDO
                      AND A.NENDOBUN          = B.NENDOBUN
                      AND A.TSUCHI_NO         = B.TSUCHI_NO
                      AND A.RONRIKIBETSU      = B.RONRIKIBETSU
                      AND A.NENGETSU          = B.NENGETSU
                      AND A.NUSHI_KOJIN_NO    = B.NUSHI_KOJIN_NO
                      AND A.ZEN_ZEIGAKU       = B.ZEN_ZEIGAKU
                      AND A.TAI_ZEIGAKU       = B.TAI_ZEIGAKU
                      AND NVL(A.KOJISOTATSU_KBN,0)   = NVL(B.KOJISOTATSU_KBN,0);
                   -- =N件
                   IF NCNT_N = NCNT_CAL THEN
                     -- 更新前の翌年度通知書番号を取得
                     BEGIN
                       SELECT NVL(YOKU_TSUCHI_NO,0),NVL(IDO_JIYU,0)
                         INTO NYOKU_TSUCHI_NO_N, NIDO_JIYU_N
                         FROM ZLBTKIHON_N
                        WHERE KOKU_SETAI_NO      = RwKIHONC.KOKU_SETAI_NO
                          AND SANTEIDANTAI_CD    = RwKIHONC.SANTEIDANTAI_CD
                          AND CHOTEI_NENDO       = RwKIHONC.CHOTEI_NENDO
                          AND NENDO_BUN          = RwKIHONC.NENDO_BUN
                          AND TSUCHI_NO          = RwKIHONC.TSUCHI_NO;
                     EXCEPTION
                        WHEN OTHERS THEN
                          NYOKU_TSUCHI_NO_N := 0;
                          NIDO_JIYU_N := 0;
                     END;
                     -- 更新後の翌年度通知書番号を取得
                     BEGIN
                       SELECT NVL(YOKU_TSUCHI_NO,0),NVL(IDO_JIYU,0)
                         INTO NYOKU_TSUCHI_NO_CAL, NIDO_JIYU_CAL
                         FROM ZLBTKIHON_CAL
                        WHERE KOKU_SETAI_NO      = RwKIHONC.KOKU_SETAI_NO
                          AND SANTEIDANTAI_CD    = RwKIHONC.SANTEIDANTAI_CD
                          AND CHOTEI_NENDO       = RwKIHONC.CHOTEI_NENDO
                          AND NENDO_BUN          = RwKIHONC.NENDO_BUN
                          AND TSUCHI_NO          = RwKIHONC.TSUCHI_NO
                          AND SYS_TANMATSU_NO    = i_VTANMATSU;
                     EXCEPTION
                        WHEN OTHERS THEN
                          NYOKU_TSUCHI_NO_CAL := 0;
                          NIDO_JIYU_CAL := 0;
                     END;
                     -- 新規に翌年度通知書番号が採番
                     IF NYOKU_TSUCHI_NO_N = 0 AND NYOKU_TSUCHI_NO_CAL != 0 THEN
                       NlCHK_R := c_NOK;       -- 変更あり
                     ELSE
                       NlCHK_R := c_NNOTHING;  -- 変化なし
                     END IF;
                   -- !=N件
                   ELSE
                     NlCHK_R := c_NOK;       -- 変更あり
                   END IF;
                 END IF;
               EXCEPTION
               -- 異常処理
                 WHEN OTHERS THEN
                   NlRTN := c_NERR;
                   VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                   EXIT;
               END;
               -- 翌年度期別データチェック
               IF NlCHK_R != c_NOK THEN
                 BEGIN
                   -- 翌年度通知書番号が無し
                   IF NYOKU_TSUCHI_NO_CAL = 0 THEN
                     NlCHK_R := c_NNOTHING;  -- 変化なし
                   ELSE
                     -- 翌年度通知書番号が有り
                     -- 該当個人の最新期別テーブルの件数を確認
                     SELECT COUNT(KOKU_SETAI_NO)
                       INTO NCNT_N
                       FROM ZLBTKIBETSU_N
                      WHERE KOKU_SETAI_NO      = RwKIHONC.KOKU_SETAI_NO
                        AND SANTEIDANTAI_CD    = RwKIHONC.SANTEIDANTAI_CD
                        AND CHOTEINENDO        = (RwKIHONC.CHOTEI_NENDO)+1
                        AND NENDOBUN           = (RwKIHONC.NENDO_BUN)+1
                        AND TSUCHI_NO          = RwKIHONC.YOKU_TSUCHI_NO;
                     -- 0件の場合
                     IF NCNT_N = 0 THEN
                       NlCHK_R := c_NOK;       -- 変更あり
                     -- N件の場合
                     ELSE
                       SELECT COUNT(A. KOKU_SETAI_NO)
                         INTO NCNT_CAL
                         FROM ZLBTKIBETSU_N A,ZLBTKIBETSU_CAL B
                        WHERE A.KOKU_SETAI_NO     = RwKIHONC.KOKU_SETAI_NO
                          AND A.SANTEIDANTAI_CD   = RwKIHONC.SANTEIDANTAI_CD
                          AND A.CHOTEINENDO       = (RwKIHONC.CHOTEI_NENDO)+1
                          AND A.NENDOBUN          = (RwKIHONC.NENDO_BUN)+1
                          AND A.TSUCHI_NO         = RwKIHONC.YOKU_TSUCHI_NO
                          AND B.SYS_TANMATSU_NO   = i_VTANMATSU
                          AND A.KAMOKU_CD         = B.KAMOKU_CD
                          AND A.KAMOKUS_CD        = B.KAMOKUS_CD
                          AND A.KOKU_SETAI_NO     = B.KOKU_SETAI_NO
                          AND A.SANTEIDANTAI_CD   = B.SANTEIDANTAI_CD
                          AND A.KIWARIDANTAI_CD   = B.KIWARIDANTAI_CD
                          AND A.GENNENKANEN_KBN   = B.GENNENKANEN_KBN
                          AND A.CHOTEINENDO       = B.CHOTEINENDO
                          AND A.NENDOBUN          = B.NENDOBUN
                          AND A.TSUCHI_NO         = B.TSUCHI_NO
                          AND A.RONRIKIBETSU      = B.RONRIKIBETSU
                          AND A.NENGETSU          = B.NENGETSU
                          AND A.NUSHI_KOJIN_NO    = B.NUSHI_KOJIN_NO
                          AND A.ZEN_ZEIGAKU       = B.ZEN_ZEIGAKU
                          AND A.TAI_ZEIGAKU       = B.TAI_ZEIGAKU
                          AND NVL(A.KOJISOTATSU_KBN,0)   = NVL(B.KOJISOTATSU_KBN,0);
                       -- =N件
                       IF NCNT_N = NCNT_CAL THEN
                         NlCHK_R := c_NNOTHING;  -- 変化なし
                       -- !=N件
                       ELSE
                         IF NCNT_CAL = 0 THEN
                           SELECT COUNT(KOKU_SETAI_NO)
                             INTO NCNT_N
                             FROM ZLBTKIBETSU_N
                            WHERE KOKU_SETAI_NO      = RwKIHONC.KOKU_SETAI_NO
                              AND SANTEIDANTAI_CD    = RwKIHONC.SANTEIDANTAI_CD
                              AND CHOTEINENDO        = (RwKIHONC.CHOTEI_NENDO)+1
                              AND NENDOBUN           = (RwKIHONC.NENDO_BUN)+1
                              AND TSUCHI_NO          = RwKIHONC.YOKU_TSUCHI_NO
                              AND ZEN_ZEIGAKU       > 0;
                           -- 0件の場合
                           IF NCNT_N = 0 THEN
                             NlCHK_R := c_NNOTHING;  -- 変化なし
                           -- !=N件
                           ELSE
                             NlCHK_R := c_NOK;       -- 変更あり
                           END IF;
                         ELSE
                           NlCHK_R := c_NOK;       -- 変更あり
                         END IF;
                       END IF;
                     END IF;
                   END IF;
                 EXCEPTION
                 -- 異常処理
                    WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                    EXIT;
                 END;
               END IF;
            END IF;
            IF NlCHK_R != c_NOK THEN
                BEGIN
                  -- 計算旧被扶養者・失業者区分 取得
                  SELECT H_KBN
                    INTO NwH_KBN_CAL
                    FROM ZLBTEXT_CAL
                   WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                     AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                     AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                     AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                     AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                     AND SYS_TANMATSU_NO = i_VTANMATSU;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                     NwH_KBN_CAL := 9;    -- 旧被扶養者・失業者区分データなし
                   WHEN OTHERS THEN
                     NlRTN := c_NERR;
                     VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                     EXIT;
                END;

                BEGIN
                  -- 賦課旧被扶養者・失業者区分 取得
                  SELECT H_KBN
                    INTO NwH_KBN_N
                    FROM ZLBTEXT_N
                   WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                     AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                     AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                     AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                     AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                     NwH_KBN_N := 9;     -- 旧被扶養者・失業者区分データなし
                   WHEN OTHERS THEN
                     NlRTN := c_NERR;
                     VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                     EXIT;
                END;

                -- 旧被扶養者・失業者区分チェック
                IF NwH_KBN_CAL != NwH_KBN_N THEN
                  IF NwH_KBN_CAL = 9 AND NwH_KBN_N = 0 THEN
                    BEGIN
                      -- 賦課拡張（最新）取得
                      SELECT COUNT(*)
                        INTO NCNT_N
                        FROM ZLBTEXT_N
                       WHERE KOKU_SETAI_NO            = RwKIHONC.KOKU_SETAI_NO
                         AND SANTEIDANTAI_CD          = RwKIHONC.SANTEIDANTAI_CD
                         AND CHOTEI_NENDO             = RwKIHONC.CHOTEI_NENDO
                         AND NENDO_BUN                = RwKIHONC.NENDO_BUN
                         AND TSUCHI_NO                = RwKIHONC.TSUCHI_NO
                         AND SHOGAI_SHOTOKU           = 0
                         AND SHOGAI_RITSU             = 0
                         AND GENMEN_KBN               = 0
                         AND GENMEN_RITSU             = 0
                         AND IRYO_NENREI_KEIGEN       = 0
                         AND IRYO_SHOGAI_GENMEN       = 0
                         AND IRYO_NENREI_KEIGEN_T     = 0
                         AND IRYO_SHOGAI_GENMEN_T     = 0
                         AND KAI_NENREI_KEIGEN        = 0
                         AND KAI_SHOGAI_GENMEN        = 0
                         AND KAI_NENREI_KEIGEN_T      = 0
                         AND KAI_SHOGAI_GENMEN_T      = 0
                         AND SHI_NENREI_KEIGEN        = 0
                         AND SHI_SHOGAI_GENMEN        = 0
                         AND SHI_NENREI_KEIGEN_T      = 0
                         AND SHI_SHOGAI_GENMEN_T      = 0
                         AND IRYO_KEIKA_H_SHOTOKU     = 0
                         AND IRYO_KEIKA_H_SHOTOKU_T   = 0
                         AND KAI_KEIKA_H_SHOTOKU      = 0
                         AND KAI_KEIKA_H_SHOTOKU_T    = 0
                         AND SIEN_KEIKA_H_SHOTOKU     = 0
                         AND SIEN_KEIKA_H_SHOTOKU_T   = 0
                         AND IRYO_KEIKA_H_SHISAN      = 0
                         AND IRYO_KEIKA_H_SHISAN_T    = 0
                         AND KAI_KEIKA_H_SHISAN       = 0
                         AND KAI_KEIKA_H_SHISAN_T     = 0
                         AND SIEN_KEIKA_H_SHISAN      = 0
                         AND SIEN_KEIKA_H_SHISAN_T    = 0
                         AND IRYO_KEIKA_H_KINTOWARI   = 0
                         AND IRYO_KEIKA_H_KINTOWARI_T = 0
                         AND KAI_KEIKA_H_KINTOWARI    = 0
                         AND KAI_KEIKA_H_KINTOWARI_T  = 0
                         AND SIEN_KEIKA_H_KINTOWARI   = 0
                         AND SIEN_KEIKA_H_KINTOWARI_T = 0
                         AND IRYO_KEIKA_BYODOWARI     = 0
                         AND IRYO_KEIKA_BYODOWARI_T   = 0
                         AND KAI_KEIKA_BYODOWARI      = 0
                         AND KAI_KEIKA_BYODOWARI_T    = 0
                         AND SIEN_KEIKA_BYODOWARI     = 0
                         AND SIEN_KEIKA_BYODOWARI_T   = 0
-- 2025/08/11 ZCZL.HEJIAQI UPDATE START 1.1.200.000:子ども子育て支援金対応
--                         AND H_KBN                    = 0;
                         AND H_KBN                    = 0
                         AND KDM_NENREI_KEIGEN        = 0
                         AND KDM_SHOGAI_GENMEN        = 0
                         AND KDM_KEIKA_H_SHOTOKU      = 0
                         AND KDM_KEIKA_H_SHISAN       = 0
                         AND KDM_KEIKA_H_KINTOWARI    = 0
                         AND KDM_KEIKA_BYODOWARI      = 0;
-- 2025/08/11 ZCZL.HEJIAQI UPDATE END
                      -- 0件の場合
                      IF NCNT_N = 0 THEN
                        NlCHK_R := c_NOK;       -- 変更あり
                      -- !=N件
                      ELSE
                        NlCHK_R := c_NNOTHING;  -- 変化なし
                      END IF;
                    EXCEPTION
                       WHEN OTHERS THEN
                         NlRTN := c_NERR;
                         VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                         EXIT;
                    END;
                  ELSE
                    NlCHK_R := c_NOK;        -- 変更あり
                  END IF;
                END IF;
            END IF;
            IF NlCHK_R != c_NOK THEN
              IF i_NJIKKOU_KBN = c_NONLNIN AND NlCHK_R = c_NNOTHING THEN  -- オンラインで変更無しの場合
                NULL;
              ELSE
                BEGIN
                    -- レコード削除
                    DELETE FROM ZLBTKIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    DELETE FROM ZLBTTAI_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    DELETE FROM ZLBTKAI_KIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    DELETE FROM ZLBTKAI_TAI_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    DELETE FROM ZLBTSIEN_KIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    DELETE FROM ZLBTSIEN_TAI_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

--  2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
                    -- 計算子ども基本削除
                    DELETE FROM ZLBTKDM_KIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;
--  2025/08/11 ZCZL.HEJIAQI ADD END

                    DELETE FROM ZLBTKIBETSU_CAL
                     WHERE KAMOKU_CD       = c_NKAMOKU_CD
                       AND KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEINENDO     = RwKIHONC.CHOTEI_NENDO
                       AND NENDOBUN        = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    DELETE FROM ZLBTKOJIN_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    DELETE FROM ZLBTSHOTOKU_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    DELETE FROM ZLBTEXT_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;
                    -- 計算特徴対象者TBL削除
                    DELETE FROM ZLBTTOKU_KIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                  IF RwKIHONC.YOKU_TSUCHI_NO != 0 THEN
                    -- 翌年度計算基本TBL削除
                    DELETE FROM ZLBTKIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = (RwKIHONC.CHOTEI_NENDO)+1
                       AND NENDO_BUN       = (RwKIHONC.NENDO_BUN)+1
                       AND TSUCHI_NO       = RwKIHONC.YOKU_TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    -- 翌年度計算退職基本TBL削除
                    DELETE FROM ZLBTTAI_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = (RwKIHONC.CHOTEI_NENDO)+1
                       AND NENDO_BUN       = (RwKIHONC.NENDO_BUN)+1
                       AND TSUCHI_NO       = RwKIHONC.YOKU_TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    -- 翌年度計算介護基本TBL削除
                    DELETE FROM ZLBTKAI_KIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = (RwKIHONC.CHOTEI_NENDO)+1
                       AND NENDO_BUN       = (RwKIHONC.NENDO_BUN)+1
                       AND TSUCHI_NO       = RwKIHONC.YOKU_TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    -- 翌年度計算介護退職基本TBL削除
                    DELETE FROM ZLBTKAI_TAI_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = (RwKIHONC.CHOTEI_NENDO)+1
                       AND NENDO_BUN       = (RwKIHONC.NENDO_BUN)+1
                       AND TSUCHI_NO       = RwKIHONC.YOKU_TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    -- 翌年度計算支援基本TBL削除
                    DELETE FROM ZLBTSIEN_KIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = (RwKIHONC.CHOTEI_NENDO)+1
                       AND NENDO_BUN       = (RwKIHONC.NENDO_BUN)+1
                       AND TSUCHI_NO       = RwKIHONC.YOKU_TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    -- 翌年度計算支援退職基本TBL削除
                    DELETE FROM ZLBTSIEN_TAI_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = (RwKIHONC.CHOTEI_NENDO)+1
                       AND NENDO_BUN       = (RwKIHONC.NENDO_BUN)+1
                       AND TSUCHI_NO       = RwKIHONC.YOKU_TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

--  2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
                    -- 翌年度計算子ども基本削除
                     DELETE FROM ZLBTKDM_KIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = (RwKIHONC.CHOTEI_NENDO)+1
                       AND NENDO_BUN       = (RwKIHONC.NENDO_BUN)+1
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;
--  2025/08/11 ZCZL.HEJIAQI ADD END

                    -- 翌年度計算期別TBL削除
                    DELETE FROM ZLBTKIBETSU_CAL
                     WHERE KAMOKU_CD       = c_NKAMOKU_CD
                       AND KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEINENDO     = (RwKIHONC.CHOTEI_NENDO)+1
                       AND NENDOBUN        = (RwKIHONC.NENDO_BUN)+1
                       AND TSUCHI_NO       = RwKIHONC.YOKU_TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    -- 翌年度計算特徴対象者TBL削除
                    DELETE FROM ZLBTTOKU_KIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = (RwKIHONC.CHOTEI_NENDO)+1
                       AND NENDO_BUN       = (RwKIHONC.NENDO_BUN)+1
                       AND TSUCHI_NO       = RwKIHONC.YOKU_TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;
                  END IF;

                EXCEPTION
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                        EXIT;
                END;
              END IF;
            ELSE
                NwOK_CNT := NwOK_CNT + 1;
            END IF;

        END LOOP;

        IF NlRTN = c_NOK THEN
            IF NwOK_CNT > 0 THEN
                -- 出力対象あり
                NlCHK_R := c_NOK;
            ELSE
                NlCHK_R := c_NNOTHING;
            END IF;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subChkGennen 出力判定' || SQLERRM;
    END subChkGennen;

-------------------------------------------------------------------------------
--  02 現年用チェック(過年度課税計算用)
-------------------------------------------------------------------------------
    PROCEDURE subChkGennen2 IS

        NwOK_CNT                    NUMBER;
        NwIRY_FLG                   NUMBER(1);
        NwKAI_FLG                   NUMBER(1);
        NwSIEN_FLG                  NUMBER(1);
--  2025/08/11 ZCZL.HEJIAQI ADD 1.1.200.000: 子ども子育て支援金対応
        NwKDM_FLG                   NUMBER(1);

        NCNT_N                      NUMBER;

        -- 計算退職取得データ
        NwTAIC_SEKISAN              NUMBER;     -- 積算税額
        NwTAIC_GENDO_CHOKA          NUMBER;     -- 限度超過額
        NwTAIC_GENGAKU_KEI          NUMBER;     -- 減額合計
        NwTAIC_NENZEI               NUMBER;     -- 年税額
        NwTAIC_KINTO_CNT            NUMBER;     -- 均等人員
        NwTAIC_GENZAI_CNT           NUMBER;     -- 現在人員
        NwTAIC_SHOTOKU              NUMBER;     --所得額
        -- 賦課基本取得データ
        NwKIHONN_SEKISAN            NUMBER;     -- 積算税額
        NwKIHONN_GENDO_CHOKA        NUMBER;     -- 限度超過額
        NwKIHONN_GENGAKU_KEI        NUMBER;     -- 減額合計
        NwKIHONN_NENZEI             NUMBER;     -- 年税額
        NwKIHONN_NUSHI_KOJIN_NO     NUMBER;     -- 主個人番号
        NwKIHONN_KINTO_CNT          NUMBER;     -- 均等人員
        NwKIHONN_GENZAI_CNT         NUMBER;     -- 現在人員
        NwKIHONN_SHINKOKU_KBN       NUMBER;     --申告区分
        NwKIHONN_SHOTOKU            NUMBER;     --所得額
        -- 賦課退職取得データ
        NwTAIN_SEKISAN              NUMBER;     -- 積算税額
        NwTAIN_GENDO_CHOKA          NUMBER;     -- 限度超過額
        NwTAIN_GENGAKU_KEI          NUMBER;     -- 減額合計
        NwTAIN_NENZEI               NUMBER;     -- 年税額
        NwTAIN_KINTO_CNT            NUMBER;     -- 均等人員
        NwTAIN_GENZAI_CNT           NUMBER;     -- 現在人員
        NwTAIN_SHOTOKU              NUMBER;     --所得額
        -- 計算介護基本取得データ
        NwKKIHONC_SEKISAN           NUMBER;     -- 積算税額
        NwKKIHONC_GENDO_CHOKA       NUMBER;     -- 限度超過額
        NwKKIHONC_GENGAKU_KEI       NUMBER;     -- 減額合計
        NwKKIHONC_NENZEI            NUMBER;     -- 年税額
        NwKKIHONC_NUSHI_KOJIN_NO    NUMBER;     -- 主個人番号
        NwKKIHONC_KINTO_CNT         NUMBER;     -- 均等人員
        NwKKIHONC_GENZAI_CNT        NUMBER;     -- 現在人員
        NwKKIHONC_SHINKOKU_KBN      NUMBER;     --申告区分
        NwKKIHONC_SHOTOKU           NUMBER;     --所得額
        -- 計算介護退職取得データ
        NwKTAIC_SEKISAN             NUMBER;     -- 積算税額
        NwKTAIC_GENDO_CHOKA         NUMBER;     -- 限度超過額
        NwKTAIC_GENGAKU_KEI         NUMBER;     -- 減額合計
        NwKTAIC_NENZEI              NUMBER;     -- 年税額
        NwKTAIC_KINTO_CNT           NUMBER;     -- 均等人員
        NwKTAIC_GENZAI_CNT          NUMBER;     -- 現在人員
        NwKTAIC_SHOTOKU             NUMBER;     --所得額
        -- 賦課介護基本取得データ
        NwKKIHONN_SEKISAN           NUMBER;     -- 積算税額
        NwKKIHONN_GENDO_CHOKA       NUMBER;     -- 限度超過額
        NwKKIHONN_GENGAKU_KEI       NUMBER;     -- 減額合計
        NwKKIHONN_NENZEI            NUMBER;     -- 年税額
        NwKKIHONN_NUSHI_KOJIN_NO    NUMBER;     -- 主個人番号
        NwKKIHONN_KINTO_CNT         NUMBER;     -- 均等人員
        NwKKIHONN_GENZAI_CNT        NUMBER;     -- 現在人員
        NwKKIHONN_SHINKOKU_KBN      NUMBER;     --申告区分
        NwKKIHONN_SHOTOKU           NUMBER;     --所得額
        -- 賦課介護退職取得データ
        NwKTAIN_SEKISAN             NUMBER;     -- 積算税額
        NwKTAIN_GENDO_CHOKA         NUMBER;     -- 限度超過額
        NwKTAIN_GENGAKU_KEI         NUMBER;     -- 減額合計
        NwKTAIN_NENZEI              NUMBER;     -- 年税額
        NwKTAIN_KINTO_CNT           NUMBER;     -- 均等人員
        NwKTAIN_GENZAI_CNT          NUMBER;     -- 現在人員
        NwKTAIN_SHOTOKU             NUMBER;     --所得額
        -- 計算支援基本取得データ
        NwSKIHONC_SEKISAN           NUMBER;     -- 積算税額
        NwSKIHONC_GENDO_CHOKA       NUMBER;     -- 限度超過額
        NwSKIHONC_GENGAKU_KEI       NUMBER;     -- 減額合計
        NwSKIHONC_NENZEI            NUMBER;     -- 年税額
        NwSKIHONC_NUSHI_KOJIN_NO    NUMBER;     -- 主個人番号
        NwSKIHONC_KINTO_CNT         NUMBER;     -- 均等人員
        NwSKIHONC_GENZAI_CNT        NUMBER;     -- 現在人員
        NwSKIHONC_SHINKOKU_KBN      NUMBER;     -- 申告区分
        NwSKIHONC_SHOTOKU           NUMBER;     -- 所得額
        -- 計算支援退職取得データ
        NwSTAIC_SEKISAN             NUMBER;     -- 積算税額
        NwSTAIC_GENDO_CHOKA         NUMBER;     -- 限度超過額
        NwSTAIC_GENGAKU_KEI         NUMBER;     -- 減額合計
        NwSTAIC_NENZEI              NUMBER;     -- 年税額
        NwSTAIC_KINTO_CNT           NUMBER;     -- 均等人員
        NwSTAIC_GENZAI_CNT          NUMBER;     -- 現在人員
        NwSTAIC_SHOTOKU             NUMBER;     -- 所得額
        -- 賦課支援基本取得データ
        NwSKIHONN_SEKISAN           NUMBER;     -- 積算税額
        NwSKIHONN_GENDO_CHOKA       NUMBER;     -- 限度超過額
        NwSKIHONN_GENGAKU_KEI       NUMBER;     -- 減額合計
        NwSKIHONN_NENZEI            NUMBER;     -- 年税額
        NwSKIHONN_NUSHI_KOJIN_NO    NUMBER;     -- 主個人番号
        NwSKIHONN_KINTO_CNT         NUMBER;     -- 均等人員
        NwSKIHONN_GENZAI_CNT        NUMBER;     -- 現在人員
        NwSKIHONN_SHINKOKU_KBN      NUMBER;     -- 申告区分
        NwSKIHONN_SHOTOKU           NUMBER;     -- 所得額
        -- 賦課支援退職取得データ
        NwSTAIN_SEKISAN             NUMBER;     -- 積算税額
        NwSTAIN_GENDO_CHOKA         NUMBER;     -- 限度超過額
        NwSTAIN_GENGAKU_KEI         NUMBER;     -- 減額合計
        NwSTAIN_NENZEI              NUMBER;     -- 年税額
        NwSTAIN_KINTO_CNT           NUMBER;     -- 均等人員
        NwSTAIN_GENZAI_CNT          NUMBER;     -- 現在人員
        NwSTAIN_SHOTOKU             NUMBER;     -- 所得額
        NwH_KBN_CAL                 NUMBER;     -- 旧被扶養者・失業者区分
        NwH_KBN_N                   NUMBER;     -- 旧被扶養者・失業者区分
--  2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
        -- 計算子ども基本取得データ
        NwKDMKIHONC_SEKISAN         NUMBER;     -- 積算税額
        NwKDMKIHONC_GENDO_CHOKA     NUMBER;     -- 限度超過額
        NwKDMKIHONC_GENGAKU_KEI     NUMBER;     -- 減額合計
        NwKDMKIHONC_NENZEI          NUMBER;     -- 年税額
        NwKDMKIHONC_NUSHI_KOJIN_NO  NUMBER;     -- 主個人番号
        NwKDMKIHONC_KINTO_CNT       NUMBER;     -- 均等人員
        NwKDMKIHONC_GENZAI_CNT      NUMBER;     -- 現在人員
        NwKDMKIHONC_SHINKOKU_KBN    NUMBER;     -- 申告区分
        NwKDMKIHONC_SHOTOKU         NUMBER;     -- 所得額
        NwKDMKIHONC_KINTO_CNT_KDM18 NUMBER;     -- 18歳以上均等人員
        -- 賦課子ども基本（最新）取得データ
        NwKDMKIHONN_SEKISAN         NUMBER;     -- 積算税額
        NwKDMKIHONN_GENDO_CHOKA     NUMBER;     -- 限度超過額
        NwKDMKIHONN_GENGAKU_KEI     NUMBER;     -- 減額合計
        NwKDMKIHONN_NENZEI          NUMBER;     -- 年税額
        NwKDMKIHONN_NUSHI_KOJIN_NO  NUMBER;     -- 主個人番号
        NwKDMKIHONN_KINTO_CNT       NUMBER;     -- 均等人員
        NwKDMKIHONN_GENZAI_CNT      NUMBER;     -- 現在人員
        NwKDMKIHONN_SHINKOKU_KBN    NUMBER;     -- 申告区分
        NwKDMKIHONN_SHOTOKU         NUMBER;     -- 所得額
        NwKDMKIHONN_KINTO_CNT_KDM18 NUMBER;     -- 18歳以上均等人員
--  2025/08/11 ZCZL.HEJIAQI ADD END

        -- 計算基本カーソル(現年分)
        CURSOR CwKIHONC IS
            SELECT * FROM ZLBTKIHON_CAL
             WHERE SYS_TANMATSU_NO = i_VTANMATSU;

    BEGIN
        NwOK_CNT := 0;

        -- 計算基本取得
        FOR RwKIHONC IN CwKIHONC LOOP

            NlCHK_R := c_NNOTHING;         -- 変化なし

            NwIRY_FLG := 0;
            NwKAI_FLG := 0;
            NwSIEN_FLG := 0;
--  2025/08/11 ZCZL.HEJIAQI ADD 1.1.200.000: 子ども子育て支援金対応
            NwKDM_FLG := 0;

            -- 計算退職取得データクリア
            NwTAIC_SEKISAN           := 0;  NwTAIC_GENDO_CHOKA    := 0;
            NwTAIC_GENGAKU_KEI       := 0;  NwTAIC_NENZEI         := 0;
            NwTAIC_KINTO_CNT         := 0;  NwTAIC_GENZAI_CNT     := 0;
            NwTAIC_SHOTOKU           := 0;
            -- 賦課基本取得データクリア
            NwKIHONN_SEKISAN         := 0;  NwKIHONN_GENDO_CHOKA  := 0;
            NwKIHONN_GENGAKU_KEI     := 0;  NwKIHONN_NENZEI       := 0;
            NwKIHONN_NUSHI_KOJIN_NO  := 0;  NwKIHONN_KINTO_CNT    := 0;
            NwKIHONN_GENZAI_CNT      := 0;
            NwKIHONN_SHINKOKU_KBN    := 0;  NwKIHONN_SHOTOKU      := 0;
            -- 賦課退職取得データクリア
            NwTAIN_SEKISAN           := 0;  NwTAIN_GENDO_CHOKA    := 0;
            NwTAIN_GENGAKU_KEI       := 0;  NwTAIN_NENZEI         := 0;
            NwTAIN_KINTO_CNT         := 0;  NwTAIN_GENZAI_CNT     := 0;
            NwTAIN_SHOTOKU           := 0;
            -- 計算介護基本取得データクリア
            NwKKIHONC_SEKISAN        := 0;  NwKKIHONC_GENDO_CHOKA := 0;
            NwKKIHONC_GENGAKU_KEI    := 0;  NwKKIHONC_NENZEI      := 0;
            NwKKIHONC_NUSHI_KOJIN_NO := 0;  NwKKIHONC_KINTO_CNT   := 0;
            NwKKIHONC_GENZAI_CNT     := 0;
            NwKKIHONC_SHINKOKU_KBN   := 0;  NwKKIHONC_SHOTOKU     := 0;
            -- 計算介護退職取得データクリア
            NwKTAIC_SEKISAN          := 0;  NwKTAIC_GENDO_CHOKA   := 0;
            NwKTAIC_GENGAKU_KEI      := 0;  NWKTAIC_NENZEI        := 0;
            NwKTAIC_KINTO_CNT        := 0;  NwKTAIC_GENZAI_CNT    := 0;
            NwKTAIC_SHOTOKU          := 0;
            -- 賦課介護基本取得データクリア
            NwKKIHONN_SEKISAN        := 0;  NwKKIHONN_GENDO_CHOKA := 0;
            NwKKIHONN_GENGAKU_KEI    := 0;  NwKKIHONN_NENZEI      := 0;
            NwKKIHONN_NUSHI_KOJIN_NO := 0;  NwKKIHONN_KINTO_CNT   := 0;
            NwKKIHONN_GENZAI_CNT     := 0;
            NwKKIHONN_SHINKOKU_KBN   := 0;  NwKKIHONN_SHOTOKU     := 0;
            -- 賦課介護退職取得データクリア
            NwKTAIN_SEKISAN          := 0;  NwKTAIN_GENDO_CHOKA   := 0;
            NwKTAIN_GENGAKU_KEI      := 0;  NwKTAIN_NENZEI        := 0;
            NwKTAIN_KINTO_CNT        := 0;  NwKTAIN_GENZAI_CNT    := 0;
            NwKTAIN_SHOTOKU          := 0;
            -- 計算支援基本取得データクリア
            NwSKIHONC_SEKISAN        := 0;  NwSKIHONC_GENDO_CHOKA := 0;
            NwSKIHONC_GENGAKU_KEI    := 0;  NwSKIHONC_NENZEI      := 0;
            NwSKIHONC_NUSHI_KOJIN_NO := 0;  NwSKIHONC_KINTO_CNT   := 0;
            NwSKIHONC_GENZAI_CNT     := 0;
            NwSKIHONC_SHINKOKU_KBN   := 0;  NwSKIHONC_SHOTOKU     := 0;
            -- 計算支援退職取得データクリア
            NwSTAIC_SEKISAN          := 0;  NwSTAIC_GENDO_CHOKA   := 0;
            NwSTAIC_GENGAKU_KEI      := 0;  NWSTAIC_NENZEI        := 0;
            NwSTAIC_KINTO_CNT        := 0;  NwSTAIC_GENZAI_CNT    := 0;
            NwSTAIC_SHOTOKU          := 0;
            -- 賦課支援基本取得データクリア
            NwSKIHONN_SEKISAN        := 0;  NwSKIHONN_GENDO_CHOKA := 0;
            NwSKIHONN_GENGAKU_KEI    := 0;  NwSKIHONN_NENZEI      := 0;
            NwSKIHONN_NUSHI_KOJIN_NO := 0;  NwSKIHONN_KINTO_CNT   := 0;
            NwSKIHONN_GENZAI_CNT     := 0;
            NwSKIHONN_SHINKOKU_KBN   := 0;  NwSKIHONN_SHOTOKU     := 0;
            -- 賦課支援退職取得データクリア
            NwSTAIN_SEKISAN          := 0;  NwSTAIN_GENDO_CHOKA   := 0;
            NwSTAIN_GENGAKU_KEI      := 0;  NwSTAIN_NENZEI        := 0;
            NwSTAIN_KINTO_CNT        := 0;  NwSTAIN_GENZAI_CNT    := 0;
            NwSTAIN_SHOTOKU          := 0;
--  2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
            -- 計算子ども基本取得データクリア
            NwKDMKIHONC_SEKISAN        := 0;  NwKDMKIHONC_GENDO_CHOKA  := 0;
            NwKDMKIHONC_GENGAKU_KEI    := 0;  NwKDMKIHONC_NENZEI       := 0;
            NwKDMKIHONC_NUSHI_KOJIN_NO := 0;  NwKDMKIHONC_KINTO_CNT    := 0;
            NwKDMKIHONC_GENZAI_CNT     := 0;  NwKDMKIHONC_SHINKOKU_KBN := 0;
            NwKDMKIHONC_SHOTOKU        := 0;  NwKDMKIHONC_KINTO_CNT_KDM18  := 0;
            -- 賦課子ども基本（最新）取得データクリア
            NwKDMKIHONN_SEKISAN        := 0;  NwKDMKIHONN_GENDO_CHOKA  := 0;
            NwKDMKIHONN_GENGAKU_KEI    := 0;  NwKDMKIHONN_NENZEI       := 0;
            NwKDMKIHONN_NUSHI_KOJIN_NO := 0;  NwKDMKIHONN_KINTO_CNT    := 0;
            NwKDMKIHONN_GENZAI_CNT     := 0;  NwKDMKIHONN_SHINKOKU_KBN := 0;
            NwKDMKIHONN_SHOTOKU        := 0;  NwKDMKIHONN_KINTO_CNT_KDM18  := 0;
--  2025/08/11 ZCZL.HEJIAQI ADD END

            BEGIN
                -- 計算退職取得
                SELECT SEKISAN,
                       GENDO_CHOKA,
                       GENGAKU_KEI,
                       NENZEI,
                       KINTO_CNT,
                       GENZAI_CNT,
                       SHOTOKU
                  INTO NwTAIC_SEKISAN,
                       NwTAIC_GENDO_CHOKA,
                       NwTAIC_GENGAKU_KEI,
                       NwTAIC_NENZEI,
                       NwTAIC_KINTO_CNT,
                       NwTAIC_GENZAI_CNT,
                       NwTAIC_SHOTOKU
                  FROM ZLBTTAI_CAL
                 WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                   AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                   AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                   AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
                    EXIT;
            END;

            BEGIN
                -- 計算介護基本取得
                SELECT NVL(SEKISAN, 0),
                       NVL(GENDO_CHOKA, 0),
                       NVL(GENGAKU_KEI, 0),
                       NVL(NENZEI, 0),
                       NVL(NUSHI_KOJIN_NO, 0),
                       NVL(KINTO_CNT, 0),
                       NVL(GENZAI_CNT, 0),
                       NVL(SHINKOKU_KBN, 0),
                       NVL(SHOTOKU, 0)
                  INTO NwKKIHONC_SEKISAN,
                       NwKKIHONC_GENDO_CHOKA,
                       NwKKIHONC_GENGAKU_KEI,
                       NwKKIHONC_NENZEI,
                       NwKKIHONC_NUSHI_KOJIN_NO,
                       NwKKIHONC_KINTO_CNT,
                       NwKKIHONC_GENZAI_CNT,
                       NwKKIHONC_SHINKOKU_KBN,
                       NwKKIHONC_SHOTOKU
                  FROM ZLBTKAI_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                   AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                   AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                   AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NwKAI_FLG := 1;     -- 介護データなし
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
                    EXIT;
            END;

            IF  NwKAI_FLG = 0 THEN      -- 介護データ有り
                BEGIN
                    -- 計算介護退職取得
                    SELECT NVL(SEKISAN, 0),
                           NVL(GENDO_CHOKA, 0),
                           NVL(GENGAKU_KEI, 0),
                           NVL(NENZEI, 0),
                           NVL(KINTO_CNT, 0),
                           NVL(GENZAI_CNT, 0),
                           NVL(SHOTOKU, 0)
                      INTO NwKTAIC_SEKISAN,
                           NwKTAIC_GENDO_CHOKA,
                           NwKTAIC_GENGAKU_KEI,
                           NwKTAIC_NENZEI,
                           NwKTAIC_KINTO_CNT,
                           NwKTAIC_GENZAI_CNT,
                           NwKTAIC_SHOTOKU
                      FROM ZLBTKAI_TAI_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
                        EXIT;
                END;
            END IF;
            BEGIN
                -- 計算支援基本取得
                SELECT NVL(SEKISAN, 0),
                       NVL(GENDO_CHOKA, 0),
                       NVL(GENGAKU_KEI, 0),
                       NVL(NENZEI, 0),
                       NVL(NUSHI_KOJIN_NO, 0),
                       NVL(KINTO_CNT, 0),
                       NVL(GENZAI_CNT, 0),
                       NVL(SHINKOKU_KBN, 0),
                       NVL(SHOTOKU, 0)
                  INTO NwSKIHONC_SEKISAN,
                       NwSKIHONC_GENDO_CHOKA,
                       NwSKIHONC_GENGAKU_KEI,
                       NwSKIHONC_NENZEI,
                       NwSKIHONC_NUSHI_KOJIN_NO,
                       NwSKIHONC_KINTO_CNT,
                       NwSKIHONC_GENZAI_CNT,
                       NwSKIHONC_SHINKOKU_KBN,
                       NwSKIHONC_SHOTOKU
                  FROM ZLBTSIEN_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                   AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                   AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                   AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NwSIEN_FLG := 1;     -- 支援データなし
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
                    EXIT;
            END;

            IF  NwSIEN_FLG = 0 THEN      -- 支援データ有り
                BEGIN
                    -- 計算支援退職取得
                    SELECT NVL(SEKISAN, 0),
                           NVL(GENDO_CHOKA, 0),
                           NVL(GENGAKU_KEI, 0),
                           NVL(NENZEI, 0),
                           NVL(KINTO_CNT, 0),
                           NVL(GENZAI_CNT, 0),
                           NVL(SHOTOKU, 0)
                      INTO NwSTAIC_SEKISAN,
                           NwSTAIC_GENDO_CHOKA,
                           NwSTAIC_GENGAKU_KEI,
                           NwSTAIC_NENZEI,
                           NwSTAIC_KINTO_CNT,
                           NwSTAIC_GENZAI_CNT,
                           NwSTAIC_SHOTOKU
                      FROM ZLBTSIEN_TAI_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
                        EXIT;
                END;
            END IF;

            BEGIN
                -- 賦課基本取得
                SELECT NVL(SEKISAN, 0),
                       NVL(GENDO_CHOKA, 0),
                       NVL(GENGAKU_KEI, 0),
                       NVL(NENZEI, 0),
                       NVL(NUSHI_KOJIN_NO, 0),
                       NVL(KINTO_CNT, 0),
                       NVL(GENZAI_CNT, 0),
                       NVL(SHINKOKU_KBN, 0),
                       NVL(SHOTOKU, 0)
                  INTO NwKIHONN_SEKISAN,
                       NwKIHONN_GENDO_CHOKA,
                       NwKIHONN_GENGAKU_KEI,
                       NwKIHONN_NENZEI,
                       NwKIHONN_NUSHI_KOJIN_NO,
                       NwKIHONN_KINTO_CNT,
                       NwKIHONN_GENZAI_CNT,
                       NwKIHONN_SHINKOKU_KBN,
                       NwKIHONN_SHOTOKU
                  FROM ZLBTKIHON_N
                 WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                   AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                   AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                   AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NwIRY_FLG := 1;     -- 医療データなし
                    NwKAI_FLG := 1;     -- 介護データなし
--  2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
                    NwSIEN_FLG := 1;    -- 支援データなし
                    NwKDM_FLG := 1;     -- 子どもデータなし
--  2025/08/11 ZCZL.HEJIAQI ADD END
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
                    EXIT;
            END;

            IF NwIRY_FLG = 0 THEN       -- 医療データ有り
                BEGIN
                    -- 賦課退職取得
                    SELECT NVL(SEKISAN, 0),
                           NVL(GENDO_CHOKA, 0),
                           NVL(GENGAKU_KEI, 0),
                           NVL(NENZEI, 0),
                           NVL(KINTO_CNT, 0),
                           NVL(GENZAI_CNT, 0),
                           NVL(SHOTOKU, 0)
                      INTO NwTAIN_SEKISAN,
                           NwTAIN_GENDO_CHOKA,
                           NwTAIN_GENGAKU_KEI,
                           NwTAIN_NENZEI,
                           NwTAIN_KINTO_CNT,
                           NwTAIN_GENZAI_CNT,
                           NwTAIN_SHOTOKU
                      FROM ZLBTTAI_N
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
                        EXIT;
                END;
            END IF;

            IF NwKAI_FLG = 0 THEN       -- 介護データ有り
                BEGIN
                    -- 賦課介護基本取得
                    SELECT NVL(SEKISAN, 0),
                           NVL(GENDO_CHOKA, 0),
                           NVL(GENGAKU_KEI, 0),
                           NVL(NENZEI, 0),
                           NVL(NUSHI_KOJIN_NO, 0),
                           NVL(KINTO_CNT, 0),
                           NVL(GENZAI_CNT, 0),
                           NVL(SHINKOKU_KBN, 0),
                           NVL(SHOTOKU, 0)
                      INTO NwKKIHONN_SEKISAN,
                           NwKKIHONN_GENDO_CHOKA,
                           NwKKIHONN_GENGAKU_KEI,
                           NwKKIHONN_NENZEI,
                           NwKKIHONN_NUSHI_KOJIN_NO,
                           NwKKIHONN_KINTO_CNT,
                           NwKKIHONN_GENZAI_CNT,
                           NwKKIHONN_SHINKOKU_KBN,
                           NwKKIHONN_SHOTOKU
                      FROM ZLBTKAI_KIHON_N
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NwKAI_FLG := 1;     -- 介護データなし
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
                        EXIT;
                END;
            END IF;

            IF NwKAI_FLG = 0 THEN       -- 介護データ有り
                BEGIN
                    -- 賦課介護退職取得
                    SELECT NVL(SEKISAN, 0),
                           NVL(GENDO_CHOKA, 0),
                           NVL(GENGAKU_KEI, 0),
                           NVL(NENZEI, 0),
                           NVL(KINTO_CNT, 0),
                           NVL(GENZAI_CNT, 0),
                           NVL(SHOTOKU, 0)
                      INTO NwKTAIN_SEKISAN,
                           NwKTAIN_GENDO_CHOKA,
                           NwKTAIN_GENGAKU_KEI,
                           NwKTAIN_NENZEI,
                           NwKTAIN_KINTO_CNT,
                           NwKTAIN_GENZAI_CNT,
                           NwKTAIN_SHOTOKU
                      FROM ZLBTKAI_TAI_N
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
                        EXIT;
                END;
            END IF;
            IF NwSIEN_FLG = 0 THEN       -- 支援データ有り
                BEGIN
                    -- 賦課支援基本取得
                    SELECT NVL(SEKISAN, 0),
                           NVL(GENDO_CHOKA, 0),
                           NVL(GENGAKU_KEI, 0),
                           NVL(NENZEI, 0),
                           NVL(NUSHI_KOJIN_NO, 0),
                           NVL(KINTO_CNT, 0),
                           NVL(GENZAI_CNT, 0),
                           NVL(SHINKOKU_KBN, 0),
                           NVL(SHOTOKU, 0)
                      INTO NwSKIHONN_SEKISAN,
                           NwSKIHONN_GENDO_CHOKA,
                           NwSKIHONN_GENGAKU_KEI,
                           NwSKIHONN_NENZEI,
                           NwSKIHONN_NUSHI_KOJIN_NO,
                           NwSKIHONN_KINTO_CNT,
                           NwSKIHONN_GENZAI_CNT,
                           NwSKIHONN_SHINKOKU_KBN,
                           NwSKIHONN_SHOTOKU
                      FROM ZLBTSIEN_KIHON_N
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NwSIEN_FLG := 1;     -- 支援データなし
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
                        EXIT;
                END;
            END IF;

            IF NwSIEN_FLG = 0 THEN       -- 支援データ有り
                BEGIN
                    -- 賦課支援退職取得
                    SELECT NVL(SEKISAN, 0),
                           NVL(GENDO_CHOKA, 0),
                           NVL(GENGAKU_KEI, 0),
                           NVL(NENZEI, 0),
                           NVL(KINTO_CNT, 0),
                           NVL(GENZAI_CNT, 0),
                           NVL(SHOTOKU, 0)
                      INTO NwSTAIN_SEKISAN,
                           NwSTAIN_GENDO_CHOKA,
                           NwSTAIN_GENGAKU_KEI,
                           NwSTAIN_NENZEI,
                           NwSTAIN_KINTO_CNT,
                           NwSTAIN_GENZAI_CNT,
                           NwSTAIN_SHOTOKU
                      FROM ZLBTSIEN_TAI_N
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
                        EXIT;
                END;
            END IF;
--  2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
            BEGIN
                -- 計算子ども基本取得
                SELECT NVL(SEKISAN, 0),
                       NVL(GENDO_CHOKA, 0),
                       NVL(GENGAKU_KEI, 0),
                       NVL(NENZEI, 0),
                       NVL(NUSHI_KOJIN_NO, 0),
                       NVL(KINTO_CNT, 0),
                       NVL(GENZAI_CNT, 0),
                       NVL(SHINKOKU_KBN, 0),
                       NVL(SHOTOKU, 0),
                       NVL(KINTO_CNT_KDM18, 0)
                  INTO NwKDMKIHONC_SEKISAN,
                       NwKDMKIHONC_GENDO_CHOKA,
                       NwKDMKIHONC_GENGAKU_KEI,
                       NwKDMKIHONC_NENZEI,
                       NwKDMKIHONC_NUSHI_KOJIN_NO,
                       NwKDMKIHONC_KINTO_CNT,
                       NwKDMKIHONC_GENZAI_CNT,
                       NwKDMKIHONC_SHINKOKU_KBN,
                       NwKDMKIHONC_SHOTOKU,
                       NwKDMKIHONC_KINTO_CNT_KDM18
                  FROM ZLBTKDM_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                   AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                   AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                   AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                   AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NwKDM_FLG := 1;     -- 子どもデータなし
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
                    EXIT;
            END;

            IF NwKDM_FLG = 0 THEN       -- 子どもデータ有り
                BEGIN
                    -- 賦課子ども基本取得
                    SELECT NVL(SEKISAN, 0),
                           NVL(GENDO_CHOKA, 0),
                           NVL(GENGAKU_KEI, 0),
                           NVL(NENZEI, 0),
                           NVL(NUSHI_KOJIN_NO, 0),
                           NVL(KINTO_CNT, 0),
                           NVL(GENZAI_CNT, 0),
                           NVL(SHINKOKU_KBN, 0),
                           NVL(SHOTOKU, 0),
                           NVL(KINTO_CNT_KDM18, 0)
                      INTO NwKDMKIHONN_SEKISAN,
                           NwKDMKIHONN_GENDO_CHOKA,
                           NwKDMKIHONN_GENGAKU_KEI,
                           NwKDMKIHONN_NENZEI,
                           NwKDMKIHONN_NUSHI_KOJIN_NO,
                           NwKDMKIHONN_KINTO_CNT,
                           NwKDMKIHONN_GENZAI_CNT,
                           NwKDMKIHONN_SHINKOKU_KBN,
                           NwKDMKIHONN_SHOTOKU,
                           NwKDMKIHONN_KINTO_CNT_KDM18
                      FROM ZLBTKDM_KIHON_N
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NwKDM_FLG := 1;     -- 子どもデータなし
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
                        EXIT;
                END;
            END IF;
--  2025/08/11 ZCZL.HEJIAQI ADD END


--  2025/08/11 ZCZL.HEJIAQI UPDATE START 1.1.200.000: 子ども子育て支援金対応
--            IF NwIRY_FLG = 0 AND NwKAI_FLG = 0 AND NwSIEN_FLG = 0 THEN
--                -- 医療/介護/支援共にデータ有り
            IF NwIRY_FLG = 0 AND NwKAI_FLG = 0 AND NwSIEN_FLG = 0 AND NwKDM_FLG = 0 THEN
                -- 医療/介護/支援/子ども共にデータ有り
--  2025/08/11 ZCZL.HEJIAQI UPDATE END

                IF RwKIHONC.SEKISAN         != NwKIHONN_SEKISAN         OR      -- 積算税額
                   RwKIHONC.GENDO_CHOKA     != NwKIHONN_GENDO_CHOKA     OR      -- 限度超過額
                   RwKIHONC.GENGAKU_KEI     != NwKIHONN_GENGAKU_KEI     OR      -- 減額合計
                   RwKIHONC.NENZEI          != NwKIHONN_NENZEI          OR      -- 年税額
                   RwKIHONC.NUSHI_KOJIN_NO  != NwKIHONN_NUSHI_KOJIN_NO  OR      -- 主個人番号
                   RwKIHONC.KINTO_CNT       != NwKIHONN_KINTO_CNT       OR      -- 均等人員
                   RwKIHONC.GENZAI_CNT      != NwKIHONN_GENZAI_CNT      OR      -- 現在人員
                   NwTAIC_SEKISAN           != NwTAIN_SEKISAN           OR      -- 積算税額
                   NwTAIC_GENDO_CHOKA       != NwTAIN_GENDO_CHOKA       OR      -- 限度超過額
                   NwTAIC_GENGAKU_KEI       != NwTAIN_GENGAKU_KEI       OR      -- 減額合計
                   NwTAIC_NENZEI            != NwTAIN_NENZEI            OR      -- 年税額
                   NwTAIC_KINTO_CNT         != NwTAIN_KINTO_CNT         OR      -- 均等人員
                   NwTAIC_GENZAI_CNT        != NwTAIN_GENZAI_CNT        OR      -- 現在人員
                   NwTAIC_SHOTOKU           != NwTAIN_SHOTOKU           OR      --所得額
                   NwKKIHONC_SEKISAN        != NwKKIHONN_SEKISAN        OR      -- 積算税額
                   NwKKIHONC_GENDO_CHOKA    != NwKKIHONN_GENDO_CHOKA    OR      -- 限度超過額
                   NwKKIHONC_GENGAKU_KEI    != NwKKIHONN_GENGAKU_KEI    OR      -- 減額合計
                   NwKKIHONC_NENZEI         != NwKKIHONN_NENZEI         OR      -- 年税額
                   NwKKIHONC_NUSHI_KOJIN_NO != NwKKIHONN_NUSHI_KOJIN_NO OR      -- 主個人番号
                   NwKKIHONC_KINTO_CNT      != NwKKIHONN_KINTO_CNT      OR      -- 均等人員
                   NwKTAIC_SEKISAN          != NwKTAIN_SEKISAN          OR      -- 積算税額
                   NwKTAIC_GENDO_CHOKA      != NwKTAIN_GENDO_CHOKA      OR      -- 限度超過額
                   NwKTAIC_GENGAKU_KEI      != NwKTAIN_GENGAKU_KEI      OR      -- 減額合計
                   NwKTAIC_NENZEI           != NwKTAIN_NENZEI           OR      -- 年税額
                   NwKTAIC_KINTO_CNT        != NwKTAIN_KINTO_CNT        OR      -- 均等人員
                   NwKTAIC_SHOTOKU          != NwKTAIN_SHOTOKU          OR      -- 所得額
                   NwSKIHONC_SEKISAN        != NwSKIHONN_SEKISAN        OR      -- 積算税額
                   NwSKIHONC_GENDO_CHOKA    != NwSKIHONN_GENDO_CHOKA    OR      -- 限度超過額
                   NwSKIHONC_GENGAKU_KEI    != NwSKIHONN_GENGAKU_KEI    OR      -- 減額合計
                   NwSKIHONC_NENZEI         != NwSKIHONN_NENZEI         OR      -- 年税額
                   NwSKIHONC_NUSHI_KOJIN_NO != NwSKIHONN_NUSHI_KOJIN_NO OR      -- 主個人番号
                   NwSKIHONC_KINTO_CNT      != NwSKIHONN_KINTO_CNT      OR      -- 均等人員
                   NwSKIHONC_GENZAI_CNT     != NwSKIHONN_GENZAI_CNT     OR      -- 現在人員
                   NwSTAIC_SEKISAN          != NwSTAIN_SEKISAN          OR      -- 積算税額
                   NwSTAIC_GENDO_CHOKA      != NwSTAIN_GENDO_CHOKA      OR      -- 限度超過額
                   NwSTAIC_GENGAKU_KEI      != NwSTAIN_GENGAKU_KEI      OR      -- 減額合計
                   NwSTAIC_NENZEI           != NwSTAIN_NENZEI           OR      -- 年税額
                   NwSTAIC_KINTO_CNT        != NwSTAIN_KINTO_CNT        OR      -- 均等人員
                   NwSTAIC_GENZAI_CNT       != NwSTAIN_GENZAI_CNT       OR      -- 現在人員
--  2025/08/11 ZCZL.HEJIAQI UPDATE START 1.1.200.000: 子ども子育て支援金対応
--                   NwSTAIC_SHOTOKU          != NwSTAIN_SHOTOKU          THEN    -- 所得額
                   NwSTAIC_SHOTOKU            != NwSTAIN_SHOTOKU            OR    -- 所得額
                   NwKDMKIHONC_SEKISAN        != NwKDMKIHONN_SEKISAN        OR    -- 積算税額
                   NwKDMKIHONC_GENDO_CHOKA    != NwKDMKIHONN_GENDO_CHOKA    OR    -- 限度超過額
                   NwKDMKIHONC_GENGAKU_KEI    != NwKDMKIHONN_GENGAKU_KEI    OR    -- 減額合計
                   NwKDMKIHONC_NENZEI         != NwKDMKIHONN_NENZEI         OR    -- 年税額
                   NwKDMKIHONC_NUSHI_KOJIN_NO != NwKDMKIHONN_NUSHI_KOJIN_NO OR    -- 主個人番号
                   NwKDMKIHONC_KINTO_CNT      != NwKDMKIHONN_KINTO_CNT      OR    -- 均等人員
                   NwKDMKIHONC_GENZAI_CNT     != NwKDMKIHONN_GENZAI_CNT     OR    -- 現在人員
                   NwKDMKIHONC_SHINKOKU_KBN   != NwKDMKIHONN_SHINKOKU_KBN   OR    -- 申告区分
                   NwKDMKIHONC_SHOTOKU        != NwKDMKIHONN_SHOTOKU        OR    -- 所得額
                   NwKDMKIHONC_KINTO_CNT_KDM18!= NwKDMKIHONN_KINTO_CNT_KDM18 THEN    -- 18歳以上均等人員
--  2025/08/11 ZCZL.HEJIAQI UPDATE END

                    NlCHK_R := c_NOK;

                END IF;

            END IF;
            IF NwIRY_FLG = 1 THEN
                -- 医療にデータなし

                IF RwKIHONC.NENZEI != 0 OR RwKIHONC.FUKA_KIJITSU_CNT != 0 OR NwTAIC_NENZEI != 0 THEN

                    NlCHK_R := c_NOK;

                END IF;

            END IF;
--  2025/08/11 ZCZL.HEJIAQI UPDATE START 1.1.200.000: 子ども子育て支援金対応
--            IF NwKAI_FLG = 1 AND NwSIEN_FLG = 1 THEN
--                -- 介護and支援にデータなし
--
--                IF RwKIHONC.SEKISAN         != NwKIHONN_SEKISAN         OR      -- 積算税額
--                   RwKIHONC.GENDO_CHOKA     != NwKIHONN_GENDO_CHOKA     OR      -- 限度超過額
--                   RwKIHONC.GENGAKU_KEI     != NwKIHONN_GENGAKU_KEI     OR      -- 減額合計
--                   RwKIHONC.NENZEI          != NwKIHONN_NENZEI          OR      -- 年税額
--                   RwKIHONC.NUSHI_KOJIN_NO  != NwKIHONN_NUSHI_KOJIN_NO  OR      -- 主個人番号
--                   RwKIHONC.KINTO_CNT       != NwKIHONN_KINTO_CNT       OR      -- 均等人員
--                   RwKIHONC.GENZAI_CNT      != NwKIHONN_GENZAI_CNT      OR      -- 現在人員
--                   NwTAIC_SEKISAN           != NwTAIN_SEKISAN           OR      -- 積算税額
--                   NwTAIC_GENDO_CHOKA       != NwTAIN_GENDO_CHOKA       OR      -- 限度超過額
--                   NwTAIC_GENGAKU_KEI       != NwTAIN_GENGAKU_KEI       OR      -- 減額合計
--                   NwTAIC_NENZEI            != NwTAIN_NENZEI            OR      -- 年税額
--                   NwTAIC_KINTO_CNT         != NwTAIN_KINTO_CNT         OR      -- 均等人員
--                   NwTAIC_GENZAI_CNT        != NwTAIN_GENZAI_CNT        OR      -- 現在人員
--                   NwTAIC_SHOTOKU           != NwTAIN_SHOTOKU           THEN    --所得額
--
--                    NlCHK_R := c_NOK;
--
--                END IF;
--
--            END IF;
--            IF NwKAI_FLG = 1 AND NwSIEN_FLG = 0 THEN
--                -- 介護データなしかつ支援データあり
--                IF -- 医療基本
--                   RwKIHONC.SEKISAN         != NwKIHONN_SEKISAN         OR      -- 積算税額
--                   RwKIHONC.GENDO_CHOKA     != NwKIHONN_GENDO_CHOKA     OR      -- 限度超過額
--                   RwKIHONC.GENGAKU_KEI     != NwKIHONN_GENGAKU_KEI     OR      -- 減額合計
--                   RwKIHONC.NENZEI          != NwKIHONN_NENZEI          OR      -- 年税額
--                   RwKIHONC.NUSHI_KOJIN_NO  != NwKIHONN_NUSHI_KOJIN_NO  OR      -- 主個人番号
--                   RwKIHONC.KINTO_CNT       != NwKIHONN_KINTO_CNT       OR      -- 均等人員
--                   RwKIHONC.GENZAI_CNT      != NwKIHONN_GENZAI_CNT      OR      -- 現在人員
--                   -- 医療退職
--                   NwTAIC_SEKISAN           != NwTAIN_SEKISAN           OR      -- 積算税額
--                   NwTAIC_GENDO_CHOKA       != NwTAIN_GENDO_CHOKA       OR      -- 限度超過額
--                   NwTAIC_GENGAKU_KEI       != NwTAIN_GENGAKU_KEI       OR      -- 減額合計
--                   NwTAIC_NENZEI            != NwTAIN_NENZEI            OR      -- 年税額
--                   NwTAIC_KINTO_CNT         != NwTAIN_KINTO_CNT         OR      -- 均等人員
--                   NwTAIC_GENZAI_CNT        != NwTAIN_GENZAI_CNT        OR      -- 現在人員
--                   NwTAIC_SHOTOKU           != NwTAIN_SHOTOKU           OR      -- 所得額
--                   -- 支援基本
--                   NwSKIHONC_SEKISAN        != NwSKIHONN_SEKISAN        OR      -- 積算税額
--                   NwSKIHONC_GENDO_CHOKA    != NwSKIHONN_GENDO_CHOKA    OR      -- 限度超過額
--                   NwSKIHONC_GENGAKU_KEI    != NwSKIHONN_GENGAKU_KEI    OR      -- 減額合計
--                   NwSKIHONC_NENZEI         != NwSKIHONN_NENZEI         OR      -- 年税額
--                   NwSKIHONC_NUSHI_KOJIN_NO != NwSKIHONN_NUSHI_KOJIN_NO OR      -- 主個人番号
--                   NwSKIHONC_KINTO_CNT      != NwSKIHONN_KINTO_CNT      OR      -- 均等人員
--                   NwSKIHONC_GENZAI_CNT     != NwSKIHONN_GENZAI_CNT     OR      -- 現在人員
--                   -- 支援退職
--                   NwSTAIC_SEKISAN          != NwSTAIN_SEKISAN          OR      -- 積算税額
--                   NwSTAIC_GENDO_CHOKA      != NwSTAIN_GENDO_CHOKA      OR      -- 限度超過額
--                   NwSTAIC_GENGAKU_KEI      != NwSTAIN_GENGAKU_KEI      OR      -- 減額合計
--                   NwSTAIC_NENZEI           != NwSTAIN_NENZEI           OR      -- 年税額
--                   NwSTAIC_KINTO_CNT        != NwSTAIN_KINTO_CNT        OR      -- 均等人員
--                   NwSTAIC_GENZAI_CNT       != NwSTAIN_GENZAI_CNT       OR      -- 現在人員
--                   NwSTAIC_SHOTOKU          != NwSTAIN_SHOTOKU          THEN    -- 所得額
--
--                    NlCHK_R := c_NOK;
--
--                END IF;
--
--            END IF;
--
--            IF NwKAI_FLG = 0 AND NwSIEN_FLG = 1 THEN
--                -- 介護データありかつ支援データなし
--                IF -- 医療基本
--                   RwKIHONC.SEKISAN         != NwKIHONN_SEKISAN         OR      -- 積算税額
--                   RwKIHONC.GENDO_CHOKA     != NwKIHONN_GENDO_CHOKA     OR      -- 限度超過額
--                   RwKIHONC.GENGAKU_KEI     != NwKIHONN_GENGAKU_KEI     OR      -- 減額合計
--                   RwKIHONC.NENZEI          != NwKIHONN_NENZEI          OR      -- 年税額
--                   RwKIHONC.NUSHI_KOJIN_NO  != NwKIHONN_NUSHI_KOJIN_NO  OR      -- 主個人番号
--                   RwKIHONC.KINTO_CNT       != NwKIHONN_KINTO_CNT       OR      -- 均等人員
--                   RwKIHONC.GENZAI_CNT      != NwKIHONN_GENZAI_CNT      OR      -- 現在人員
--                   -- 医療退職
--                   NwTAIC_SEKISAN           != NwTAIN_SEKISAN           OR      -- 積算税額
--                   NwTAIC_GENDO_CHOKA       != NwTAIN_GENDO_CHOKA       OR      -- 限度超過額
--                   NwTAIC_GENGAKU_KEI       != NwTAIN_GENGAKU_KEI       OR      -- 減額合計
--                   NwTAIC_NENZEI            != NwTAIN_NENZEI            OR      -- 年税額
--                   NwTAIC_KINTO_CNT         != NwTAIN_KINTO_CNT         OR      -- 均等人員
--                   NwTAIC_GENZAI_CNT        != NwTAIN_GENZAI_CNT        OR      -- 現在人員
--                   NwTAIC_SHOTOKU           != NwTAIN_SHOTOKU           OR      -- 所得額
--                   -- 介護基本
--                   NwKKIHONC_SEKISAN        != NwKKIHONN_SEKISAN        OR      -- 積算税額
--                   NwKKIHONC_GENDO_CHOKA    != NwKKIHONN_GENDO_CHOKA    OR      -- 限度超過額
--                   NwKKIHONC_GENGAKU_KEI    != NwKKIHONN_GENGAKU_KEI    OR      -- 減額合計
--                   NwKKIHONC_NENZEI         != NwKKIHONN_NENZEI         OR      -- 年税額
--                   NwKKIHONC_NUSHI_KOJIN_NO != NwKKIHONN_NUSHI_KOJIN_NO OR      -- 主個人番号
--                   NwKKIHONC_KINTO_CNT      != NwKKIHONN_KINTO_CNT      OR      -- 均等人員
--                   -- 介護退職
--                   NwKTAIC_SEKISAN          != NwKTAIN_SEKISAN          OR      -- 積算税額
--                   NwKTAIC_GENDO_CHOKA      != NwKTAIN_GENDO_CHOKA      OR      -- 限度超過額
--                   NwKTAIC_GENGAKU_KEI      != NwKTAIN_GENGAKU_KEI      OR      -- 減額合計
--                   NwKTAIC_NENZEI           != NwKTAIN_NENZEI           OR      -- 年税額
--                   NwKTAIC_KINTO_CNT        != NwKTAIN_KINTO_CNT        OR      -- 均等人員
--                   NwKTAIC_SHOTOKU          != NwKTAIN_SHOTOKU          THEN    -- 所得税
--
--                    NlCHK_R := c_NOK;
--
--                END IF;
--
--            END IF;
            -- 介護データあり、支援データあり、子どもデータなし
            IF NwKAI_FLG = 0 AND NwSIEN_FLG = 0 AND NwKDM_FLG = 1 THEN
                IF -- 医療基本
                   RwKIHONC.SEKISAN         != NwKIHONN_SEKISAN         OR      -- 積算税額
                   RwKIHONC.GENDO_CHOKA     != NwKIHONN_GENDO_CHOKA     OR      -- 限度超過額
                   RwKIHONC.GENGAKU_KEI     != NwKIHONN_GENGAKU_KEI     OR      -- 減額合計
                   RwKIHONC.NENZEI          != NwKIHONN_NENZEI          OR      -- 年税額
                   RwKIHONC.NUSHI_KOJIN_NO  != NwKIHONN_NUSHI_KOJIN_NO  OR      -- 主個人番号
                   RwKIHONC.KINTO_CNT       != NwKIHONN_KINTO_CNT       OR      -- 均等人員
                   RwKIHONC.GENZAI_CNT      != NwKIHONN_GENZAI_CNT      OR      -- 現在人員
                   -- 医療退職
                   NwTAIC_SEKISAN           != NwTAIN_SEKISAN           OR      -- 積算税額
                   NwTAIC_GENDO_CHOKA       != NwTAIN_GENDO_CHOKA       OR      -- 限度超過額
                   NwTAIC_GENGAKU_KEI       != NwTAIN_GENGAKU_KEI       OR      -- 減額合計
                   NwTAIC_NENZEI            != NwTAIN_NENZEI            OR      -- 年税額
                   NwTAIC_KINTO_CNT         != NwTAIN_KINTO_CNT         OR      -- 均等人員
                   NwTAIC_GENZAI_CNT        != NwTAIN_GENZAI_CNT        OR      -- 現在人員
                   NwTAIC_SHOTOKU           != NwTAIN_SHOTOKU           OR      -- 所得額
                   -- 介護基本
                   NwKKIHONC_SEKISAN        != NwKKIHONN_SEKISAN        OR      -- 積算税額
                   NwKKIHONC_GENDO_CHOKA    != NwKKIHONN_GENDO_CHOKA    OR      -- 限度超過額
                   NwKKIHONC_GENGAKU_KEI    != NwKKIHONN_GENGAKU_KEI    OR      -- 減額合計
                   NwKKIHONC_NENZEI         != NwKKIHONN_NENZEI         OR      -- 年税額
                   NwKKIHONC_NUSHI_KOJIN_NO != NwKKIHONN_NUSHI_KOJIN_NO OR      -- 主個人番号
                   NwKKIHONC_KINTO_CNT      != NwKKIHONN_KINTO_CNT      OR      -- 均等人員
                   -- 介護退職
                   NwKTAIC_SEKISAN          != NwKTAIN_SEKISAN          OR      -- 積算税額
                   NwKTAIC_GENDO_CHOKA      != NwKTAIN_GENDO_CHOKA      OR      -- 限度超過額
                   NwKTAIC_GENGAKU_KEI      != NwKTAIN_GENGAKU_KEI      OR      -- 減額合計
                   NwKTAIC_NENZEI           != NwKTAIN_NENZEI           OR      -- 年税額
                   NwKTAIC_KINTO_CNT        != NwKTAIN_KINTO_CNT        OR      -- 均等人員
                   NwKTAIC_SHOTOKU          != NwKTAIN_SHOTOKU          OR      -- 所得額
                   -- 支援基本
                   NwSKIHONC_SEKISAN        != NwSKIHONN_SEKISAN        OR      -- 積算税額
                   NwSKIHONC_GENDO_CHOKA    != NwSKIHONN_GENDO_CHOKA    OR      -- 限度超過額
                   NwSKIHONC_GENGAKU_KEI    != NwSKIHONN_GENGAKU_KEI    OR      -- 減額合計
                   NwSKIHONC_NENZEI         != NwSKIHONN_NENZEI         OR      -- 年税額
                   NwSKIHONC_NUSHI_KOJIN_NO != NwSKIHONN_NUSHI_KOJIN_NO OR      -- 主個人番号
                   NwSKIHONC_KINTO_CNT      != NwSKIHONN_KINTO_CNT      OR      -- 均等人員
                   NwSKIHONC_GENZAI_CNT     != NwSKIHONN_GENZAI_CNT     OR      -- 現在人員
                   -- 支援退職
                   NwSTAIC_SEKISAN          != NwSTAIN_SEKISAN          OR      -- 積算税額
                   NwSTAIC_GENDO_CHOKA      != NwSTAIN_GENDO_CHOKA      OR      -- 限度超過額
                   NwSTAIC_GENGAKU_KEI      != NwSTAIN_GENGAKU_KEI      OR      -- 減額合計
                   NwSTAIC_NENZEI           != NwSTAIN_NENZEI           OR      -- 年税額
                   NwSTAIC_KINTO_CNT        != NwSTAIN_KINTO_CNT        OR      -- 均等人員
                   NwSTAIC_GENZAI_CNT       != NwSTAIN_GENZAI_CNT       OR      -- 現在人員
                   NwSTAIC_SHOTOKU          != NwSTAIN_SHOTOKU          THEN    -- 所得額

                   NlCHK_R := c_NOK;
               END IF;
            END IF;

            -- 介護データなし、支援データなし、子どもデータあり
            IF NwKAI_FLG = 1 AND NwSIEN_FLG = 1 AND NwKDM_FLG = 0 THEN
                IF -- 医療基本
                   RwKIHONC.SEKISAN           != NwKIHONN_SEKISAN           OR   -- 積算税額
                   RwKIHONC.GENDO_CHOKA       != NwKIHONN_GENDO_CHOKA       OR   -- 限度超過額
                   RwKIHONC.GENGAKU_KEI       != NwKIHONN_GENGAKU_KEI       OR   -- 減額合計
                   RwKIHONC.NENZEI            != NwKIHONN_NENZEI            OR   -- 年税額
                   RwKIHONC.NUSHI_KOJIN_NO    != NwKIHONN_NUSHI_KOJIN_NO    OR   -- 主個人番号
                   RwKIHONC.KINTO_CNT         != NwKIHONN_KINTO_CNT         OR   -- 均等人員
                   RwKIHONC.GENZAI_CNT        != NwKIHONN_GENZAI_CNT        OR   -- 現在人員
                   -- 医療退職
                   NwTAIC_SEKISAN             != NwTAIN_SEKISAN             OR   -- 積算税額
                   NwTAIC_GENDO_CHOKA         != NwTAIN_GENDO_CHOKA         OR   -- 限度超過額
                   NwTAIC_GENGAKU_KEI         != NwTAIN_GENGAKU_KEI         OR   -- 減額合計
                   NwTAIC_NENZEI              != NwTAIN_NENZEI              OR   -- 年税額
                   NwTAIC_KINTO_CNT           != NwTAIN_KINTO_CNT           OR   -- 均等人員
                   NwTAIC_GENZAI_CNT          != NwTAIN_GENZAI_CNT          OR   -- 現在人員
                   NwTAIC_SHOTOKU             != NwTAIN_SHOTOKU             OR   -- 所得額
                   -- 子ども基本
                   NwKDMKIHONC_SEKISAN        != NwKDMKIHONN_SEKISAN        OR    -- 積算税額
                   NwKDMKIHONC_GENDO_CHOKA    != NwKDMKIHONN_GENDO_CHOKA    OR    -- 限度超過額
                   NwKDMKIHONC_GENGAKU_KEI    != NwKDMKIHONN_GENGAKU_KEI    OR    -- 減額合計
                   NwKDMKIHONC_NENZEI         != NwKDMKIHONN_NENZEI         OR    -- 年税額
                   NwKDMKIHONC_NUSHI_KOJIN_NO != NwKDMKIHONN_NUSHI_KOJIN_NO OR    -- 主個人番号
                   NwKDMKIHONC_KINTO_CNT      != NwKDMKIHONN_KINTO_CNT      OR    -- 均等人員
                   NwKDMKIHONC_GENZAI_CNT     != NwKDMKIHONN_GENZAI_CNT     OR    -- 現在人員
                   NwKDMKIHONC_SHINKOKU_KBN   != NwKDMKIHONN_SHINKOKU_KBN   OR    -- 申告区分
                   NwKDMKIHONC_SHOTOKU        != NwKDMKIHONN_SHOTOKU        OR    -- 所得額
                   NwKDMKIHONC_KINTO_CNT_KDM18!= NwKDMKIHONN_KINTO_CNT_KDM18 THEN -- 18歳以上均等人員

                   NlCHK_R := c_NOK;
               END IF;
            END IF;

            -- 介護データなし、支援データなし、子どもデータなし
            IF NwKAI_FLG = 1 AND NwSIEN_FLG = 1 AND NwKDM_FLG = 1 THEN
                IF -- 医療基本
                   RwKIHONC.SEKISAN           != NwKIHONN_SEKISAN           OR    -- 積算税額
                   RwKIHONC.GENDO_CHOKA       != NwKIHONN_GENDO_CHOKA       OR    -- 限度超過額
                   RwKIHONC.GENGAKU_KEI       != NwKIHONN_GENGAKU_KEI       OR    -- 減額合計
                   RwKIHONC.NENZEI            != NwKIHONN_NENZEI            OR    -- 年税額
                   RwKIHONC.NUSHI_KOJIN_NO    != NwKIHONN_NUSHI_KOJIN_NO    OR    -- 主個人番号
                   RwKIHONC.KINTO_CNT         != NwKIHONN_KINTO_CNT         OR    -- 均等人員
                   RwKIHONC.GENZAI_CNT        != NwKIHONN_GENZAI_CNT        OR    -- 現在人員
                   -- 医療退職
                   NwTAIC_SEKISAN             != NwTAIN_SEKISAN             OR    -- 積算税額
                   NwTAIC_GENDO_CHOKA         != NwTAIN_GENDO_CHOKA         OR    -- 限度超過額
                   NwTAIC_GENGAKU_KEI         != NwTAIN_GENGAKU_KEI         OR    -- 減額合計
                   NwTAIC_NENZEI              != NwTAIN_NENZEI              OR    -- 年税額
                   NwTAIC_KINTO_CNT           != NwTAIN_KINTO_CNT           OR    -- 均等人員
                   NwTAIC_GENZAI_CNT          != NwTAIN_GENZAI_CNT          OR    -- 現在人員
                   NwTAIC_SHOTOKU             != NwTAIN_SHOTOKU             THEN  -- 所得額

                   NlCHK_R := c_NOK;
               END IF;
            END IF;

            -- 介護データなし、支援データあり、子どもデータあり
            IF NwKAI_FLG = 1 AND NwSIEN_FLG = 0 AND NwKDM_FLG = 0 THEN
                IF -- 医療基本
                   RwKIHONC.SEKISAN           != NwKIHONN_SEKISAN           OR    -- 積算税額
                   RwKIHONC.GENDO_CHOKA       != NwKIHONN_GENDO_CHOKA       OR    -- 限度超過額
                   RwKIHONC.GENGAKU_KEI       != NwKIHONN_GENGAKU_KEI       OR    -- 減額合計
                   RwKIHONC.NENZEI            != NwKIHONN_NENZEI            OR    -- 年税額
                   RwKIHONC.NUSHI_KOJIN_NO    != NwKIHONN_NUSHI_KOJIN_NO    OR    -- 主個人番号
                   RwKIHONC.KINTO_CNT         != NwKIHONN_KINTO_CNT         OR    -- 均等人員
                   RwKIHONC.GENZAI_CNT        != NwKIHONN_GENZAI_CNT        OR    -- 現在人員
                   -- 医療退職
                   NwTAIC_SEKISAN             != NwTAIN_SEKISAN             OR    -- 積算税額
                   NwTAIC_GENDO_CHOKA         != NwTAIN_GENDO_CHOKA         OR    -- 限度超過額
                   NwTAIC_GENGAKU_KEI         != NwTAIN_GENGAKU_KEI         OR    -- 減額合計
                   NwTAIC_NENZEI              != NwTAIN_NENZEI              OR    -- 年税額
                   NwTAIC_KINTO_CNT           != NwTAIN_KINTO_CNT           OR    -- 均等人員
                   NwTAIC_GENZAI_CNT          != NwTAIN_GENZAI_CNT          OR    -- 現在人員
                   NwTAIC_SHOTOKU             != NwTAIN_SHOTOKU             OR    -- 所得額
                   -- 支援基本
                   NwSKIHONC_SEKISAN          != NwSKIHONN_SEKISAN          OR    -- 積算税額
                   NwSKIHONC_GENDO_CHOKA      != NwSKIHONN_GENDO_CHOKA      OR    -- 限度超過額
                   NwSKIHONC_GENGAKU_KEI      != NwSKIHONN_GENGAKU_KEI      OR    -- 減額合計
                   NwSKIHONC_NENZEI           != NwSKIHONN_NENZEI           OR    -- 年税額
                   NwSKIHONC_NUSHI_KOJIN_NO   != NwSKIHONN_NUSHI_KOJIN_NO   OR    -- 主個人番号
                   NwSKIHONC_KINTO_CNT        != NwSKIHONN_KINTO_CNT        OR    -- 均等人員
                   NwSKIHONC_GENZAI_CNT       != NwSKIHONN_GENZAI_CNT       OR    -- 現在人員
                   -- 支援退職
                   NwSTAIC_SEKISAN            != NwSTAIN_SEKISAN            OR    -- 積算税額
                   NwSTAIC_GENDO_CHOKA        != NwSTAIN_GENDO_CHOKA        OR    -- 限度超過額
                   NwSTAIC_GENGAKU_KEI        != NwSTAIN_GENGAKU_KEI        OR    -- 減額合計
                   NwSTAIC_NENZEI             != NwSTAIN_NENZEI             OR    -- 年税額
                   NwSTAIC_KINTO_CNT          != NwSTAIN_KINTO_CNT          OR    -- 均等人員
                   NwSTAIC_GENZAI_CNT         != NwSTAIN_GENZAI_CNT         OR    -- 現在人員
                   NwSTAIC_SHOTOKU            != NwSTAIN_SHOTOKU            OR    -- 所得額
                   -- 子ども基本
                   NwKDMKIHONC_SEKISAN        != NwKDMKIHONN_SEKISAN        OR    -- 積算税額
                   NwKDMKIHONC_GENDO_CHOKA    != NwKDMKIHONN_GENDO_CHOKA    OR    -- 限度超過額
                   NwKDMKIHONC_GENGAKU_KEI    != NwKDMKIHONN_GENGAKU_KEI    OR    -- 減額合計
                   NwKDMKIHONC_NENZEI         != NwKDMKIHONN_NENZEI         OR    -- 年税額
                   NwKDMKIHONC_NUSHI_KOJIN_NO != NwKDMKIHONN_NUSHI_KOJIN_NO OR    -- 主個人番号
                   NwKDMKIHONC_KINTO_CNT      != NwKDMKIHONN_KINTO_CNT      OR    -- 均等人員
                   NwKDMKIHONC_GENZAI_CNT     != NwKDMKIHONN_GENZAI_CNT     OR    -- 現在人員
                   NwKDMKIHONC_SHINKOKU_KBN   != NwKDMKIHONN_SHINKOKU_KBN   OR    -- 申告区分
                   NwKDMKIHONC_SHOTOKU        != NwKDMKIHONN_SHOTOKU        OR    -- 所得額
                   NwKDMKIHONC_KINTO_CNT_KDM18!= NwKDMKIHONN_KINTO_CNT_KDM18 THEN -- 18歳以上均等人員

                   NlCHK_R := c_NOK;
               END IF;
            END IF;

            -- 介護データなし、支援データあり、子どもデータなし
            IF NwKAI_FLG = 1 AND NwSIEN_FLG = 0 AND NwKDM_FLG = 1 THEN
                IF -- 医療基本
                   RwKIHONC.SEKISAN           != NwKIHONN_SEKISAN           OR    -- 積算税額
                   RwKIHONC.GENDO_CHOKA       != NwKIHONN_GENDO_CHOKA       OR    -- 限度超過額
                   RwKIHONC.GENGAKU_KEI       != NwKIHONN_GENGAKU_KEI       OR    -- 減額合計
                   RwKIHONC.NENZEI            != NwKIHONN_NENZEI            OR    -- 年税額
                   RwKIHONC.NUSHI_KOJIN_NO    != NwKIHONN_NUSHI_KOJIN_NO    OR    -- 主個人番号
                   RwKIHONC.KINTO_CNT         != NwKIHONN_KINTO_CNT         OR    -- 均等人員
                   RwKIHONC.GENZAI_CNT        != NwKIHONN_GENZAI_CNT        OR    -- 現在人員
                   -- 医療退職
                   NwTAIC_SEKISAN             != NwTAIN_SEKISAN             OR    -- 積算税額
                   NwTAIC_GENDO_CHOKA         != NwTAIN_GENDO_CHOKA         OR    -- 限度超過額
                   NwTAIC_GENGAKU_KEI         != NwTAIN_GENGAKU_KEI         OR    -- 減額合計
                   NwTAIC_NENZEI              != NwTAIN_NENZEI              OR    -- 年税額
                   NwTAIC_KINTO_CNT           != NwTAIN_KINTO_CNT           OR    -- 均等人員
                   NwTAIC_GENZAI_CNT          != NwTAIN_GENZAI_CNT          OR    -- 現在人員
                   NwTAIC_SHOTOKU             != NwTAIN_SHOTOKU             OR    -- 所得額
                   -- 支援基本
                   NwSKIHONC_SEKISAN          != NwSKIHONN_SEKISAN          OR    -- 積算税額
                   NwSKIHONC_GENDO_CHOKA      != NwSKIHONN_GENDO_CHOKA      OR    -- 限度超過額
                   NwSKIHONC_GENGAKU_KEI      != NwSKIHONN_GENGAKU_KEI      OR    -- 減額合計
                   NwSKIHONC_NENZEI           != NwSKIHONN_NENZEI           OR    -- 年税額
                   NwSKIHONC_NUSHI_KOJIN_NO   != NwSKIHONN_NUSHI_KOJIN_NO   OR    -- 主個人番号
                   NwSKIHONC_KINTO_CNT        != NwSKIHONN_KINTO_CNT        OR    -- 均等人員
                   NwSKIHONC_GENZAI_CNT       != NwSKIHONN_GENZAI_CNT       OR    -- 現在人員
                   -- 支援退職
                   NwSTAIC_SEKISAN            != NwSTAIN_SEKISAN            OR    -- 積算税額
                   NwSTAIC_GENDO_CHOKA        != NwSTAIN_GENDO_CHOKA        OR    -- 限度超過額
                   NwSTAIC_GENGAKU_KEI        != NwSTAIN_GENGAKU_KEI        OR    -- 減額合計
                   NwSTAIC_NENZEI             != NwSTAIN_NENZEI             OR    -- 年税額
                   NwSTAIC_KINTO_CNT          != NwSTAIN_KINTO_CNT          OR    -- 均等人員
                   NwSTAIC_GENZAI_CNT         != NwSTAIN_GENZAI_CNT         OR    -- 現在人員
                   NwSTAIC_SHOTOKU            != NwSTAIN_SHOTOKU            THEN  -- 所得額

                   NlCHK_R := c_NOK;
               END IF;
            END IF;

            -- 介護データあり、支援データなし、子どもデータあり
            IF NwKAI_FLG = 0 AND NwSIEN_FLG = 1 AND NwKDM_FLG = 0 THEN
                IF -- 医療基本
                   RwKIHONC.SEKISAN           != NwKIHONN_SEKISAN           OR    -- 積算税額
                   RwKIHONC.GENDO_CHOKA       != NwKIHONN_GENDO_CHOKA       OR    -- 限度超過額
                   RwKIHONC.GENGAKU_KEI       != NwKIHONN_GENGAKU_KEI       OR    -- 減額合計
                   RwKIHONC.NENZEI            != NwKIHONN_NENZEI            OR    -- 年税額
                   RwKIHONC.NUSHI_KOJIN_NO    != NwKIHONN_NUSHI_KOJIN_NO    OR    -- 主個人番号
                   RwKIHONC.KINTO_CNT         != NwKIHONN_KINTO_CNT         OR    -- 均等人員
                   RwKIHONC.GENZAI_CNT        != NwKIHONN_GENZAI_CNT        OR    -- 現在人員
                   -- 医療退職
                   NwTAIC_SEKISAN             != NwTAIN_SEKISAN             OR    -- 積算税額
                   NwTAIC_GENDO_CHOKA         != NwTAIN_GENDO_CHOKA         OR    -- 限度超過額
                   NwTAIC_GENGAKU_KEI         != NwTAIN_GENGAKU_KEI         OR    -- 減額合計
                   NwTAIC_NENZEI              != NwTAIN_NENZEI              OR    -- 年税額
                   NwTAIC_KINTO_CNT           != NwTAIN_KINTO_CNT           OR    -- 均等人員
                   NwTAIC_GENZAI_CNT          != NwTAIN_GENZAI_CNT          OR    -- 現在人員
                   NwTAIC_SHOTOKU             != NwTAIN_SHOTOKU             OR    -- 所得額
                   -- 介護基本
                   NwKKIHONC_SEKISAN          != NwKKIHONN_SEKISAN          OR    -- 積算税額
                   NwKKIHONC_GENDO_CHOKA      != NwKKIHONN_GENDO_CHOKA      OR    -- 限度超過額
                   NwKKIHONC_GENGAKU_KEI      != NwKKIHONN_GENGAKU_KEI      OR    -- 減額合計
                   NwKKIHONC_NENZEI           != NwKKIHONN_NENZEI           OR    -- 年税額
                   NwKKIHONC_NUSHI_KOJIN_NO   != NwKKIHONN_NUSHI_KOJIN_NO   OR    -- 主個人番号
                   NwKKIHONC_KINTO_CNT        != NwKKIHONN_KINTO_CNT        OR    -- 均等人員
                   -- 介護退職
                   NwKTAIC_SEKISAN            != NwKTAIN_SEKISAN            OR    -- 積算税額
                   NwKTAIC_GENDO_CHOKA        != NwKTAIN_GENDO_CHOKA        OR    -- 限度超過額
                   NwKTAIC_GENGAKU_KEI        != NwKTAIN_GENGAKU_KEI        OR    -- 減額合計
                   NwKTAIC_NENZEI             != NwKTAIN_NENZEI             OR    -- 年税額
                   NwKTAIC_KINTO_CNT          != NwKTAIN_KINTO_CNT          OR    -- 均等人員
                   NwKTAIC_SHOTOKU            != NwKTAIN_SHOTOKU            OR    -- 所得額
                   -- 子ども基本
                   NwKDMKIHONC_SEKISAN        != NwKDMKIHONN_SEKISAN        OR    -- 積算税額
                   NwKDMKIHONC_GENDO_CHOKA    != NwKDMKIHONN_GENDO_CHOKA    OR    -- 限度超過額
                   NwKDMKIHONC_GENGAKU_KEI    != NwKDMKIHONN_GENGAKU_KEI    OR    -- 減額合計
                   NwKDMKIHONC_NENZEI         != NwKDMKIHONN_NENZEI         OR    -- 年税額
                   NwKDMKIHONC_NUSHI_KOJIN_NO != NwKDMKIHONN_NUSHI_KOJIN_NO OR    -- 主個人番号
                   NwKDMKIHONC_KINTO_CNT      != NwKDMKIHONN_KINTO_CNT      OR    -- 均等人員
                   NwKDMKIHONC_GENZAI_CNT     != NwKDMKIHONN_GENZAI_CNT     OR    -- 現在人員
                   NwKDMKIHONC_SHINKOKU_KBN   != NwKDMKIHONN_SHINKOKU_KBN   OR    -- 申告区分
                   NwKDMKIHONC_SHOTOKU        != NwKDMKIHONN_SHOTOKU        OR    -- 所得額
                   NwKDMKIHONC_KINTO_CNT_KDM18!= NwKDMKIHONN_KINTO_CNT_KDM18 THEN -- 18歳以上均等人員

                   NlCHK_R := c_NOK;
               END IF;
            END IF;

            -- 介護データあり、支援データなし、子どもデータなし
            IF NwKAI_FLG = 0 AND NwSIEN_FLG = 1 AND NwKDM_FLG = 1 THEN
                IF -- 医療基本
                   RwKIHONC.SEKISAN           != NwKIHONN_SEKISAN           OR    -- 積算税額
                   RwKIHONC.GENDO_CHOKA       != NwKIHONN_GENDO_CHOKA       OR    -- 限度超過額
                   RwKIHONC.GENGAKU_KEI       != NwKIHONN_GENGAKU_KEI       OR    -- 減額合計
                   RwKIHONC.NENZEI            != NwKIHONN_NENZEI            OR    -- 年税額
                   RwKIHONC.NUSHI_KOJIN_NO    != NwKIHONN_NUSHI_KOJIN_NO    OR    -- 主個人番号
                   RwKIHONC.KINTO_CNT         != NwKIHONN_KINTO_CNT         OR    -- 均等人員
                   RwKIHONC.GENZAI_CNT        != NwKIHONN_GENZAI_CNT        OR    -- 現在人員
                   -- 医療退職
                   NwTAIC_SEKISAN             != NwTAIN_SEKISAN             OR    -- 積算税額
                   NwTAIC_GENDO_CHOKA         != NwTAIN_GENDO_CHOKA         OR    -- 限度超過額
                   NwTAIC_GENGAKU_KEI         != NwTAIN_GENGAKU_KEI         OR    -- 減額合計
                   NwTAIC_NENZEI              != NwTAIN_NENZEI              OR    -- 年税額
                   NwTAIC_KINTO_CNT           != NwTAIN_KINTO_CNT           OR    -- 均等人員
                   NwTAIC_GENZAI_CNT          != NwTAIN_GENZAI_CNT          OR    -- 現在人員
                   NwTAIC_SHOTOKU             != NwTAIN_SHOTOKU             OR    -- 所得額
                   -- 介護基本
                   NwKKIHONC_SEKISAN          != NwKKIHONN_SEKISAN          OR    -- 積算税額
                   NwKKIHONC_GENDO_CHOKA      != NwKKIHONN_GENDO_CHOKA      OR    -- 限度超過額
                   NwKKIHONC_GENGAKU_KEI      != NwKKIHONN_GENGAKU_KEI      OR    -- 減額合計
                   NwKKIHONC_NENZEI           != NwKKIHONN_NENZEI           OR    -- 年税額
                   NwKKIHONC_NUSHI_KOJIN_NO   != NwKKIHONN_NUSHI_KOJIN_NO   OR    -- 主個人番号
                   NwKKIHONC_KINTO_CNT        != NwKKIHONN_KINTO_CNT        OR    -- 均等人員
                   -- 介護退職
                   NwKTAIC_SEKISAN            != NwKTAIN_SEKISAN            OR    -- 積算税額
                   NwKTAIC_GENDO_CHOKA        != NwKTAIN_GENDO_CHOKA        OR    -- 限度超過額
                   NwKTAIC_GENGAKU_KEI        != NwKTAIN_GENGAKU_KEI        OR    -- 減額合計
                   NwKTAIC_NENZEI             != NwKTAIN_NENZEI             OR    -- 年税額
                   NwKTAIC_KINTO_CNT          != NwKTAIN_KINTO_CNT          OR    -- 均等人員
                   NwKTAIC_SHOTOKU            != NwKTAIN_SHOTOKU            THEN  -- 所得額

                   NlCHK_R := c_NOK;
               END IF;
            END IF;
--  2025/08/11 ZCZL.HEJIAQI UPDATE END

            IF NlCHK_R != c_NOK THEN
                BEGIN
                  -- 計算旧被扶養者・失業者区分 取得
                  SELECT H_KBN
                    INTO NwH_KBN_CAL
                    FROM ZLBTEXT_CAL
                   WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                     AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                     AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                     AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                     AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                     AND SYS_TANMATSU_NO = i_VTANMATSU;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                     NwH_KBN_CAL := 9;    -- 旧被扶養者・失業者区分データなし
                   WHEN OTHERS THEN
                     NlRTN := c_NERR;
                     VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
                     EXIT;
                END;

                BEGIN
                  -- 賦課旧被扶養者・失業者区分 取得
                  SELECT H_KBN
                    INTO NwH_KBN_N
                    FROM ZLBTEXT_N
                   WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                     AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                     AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                     AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                     AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                     NwH_KBN_N := 9;      -- 旧被扶養者・失業者区分データなし
                   WHEN OTHERS THEN
                     NlRTN := c_NERR;
                     VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
                     EXIT;
                END;

                -- 旧被扶養者・失業者区分チェック
                IF NwH_KBN_CAL != NwH_KBN_N THEN
                  IF NwH_KBN_CAL = 9 AND NwH_KBN_N = 0 THEN
                    BEGIN
                      -- 賦課拡張（最新）取得
                      SELECT COUNT(*)
                        INTO NCNT_N
                        FROM ZLBTEXT_N
                       WHERE KOKU_SETAI_NO            = RwKIHONC.KOKU_SETAI_NO
                         AND SANTEIDANTAI_CD          = RwKIHONC.SANTEIDANTAI_CD
                         AND CHOTEI_NENDO             = RwKIHONC.CHOTEI_NENDO
                         AND NENDO_BUN                = RwKIHONC.NENDO_BUN
                         AND TSUCHI_NO                = RwKIHONC.TSUCHI_NO
                         AND SHOGAI_SHOTOKU           = 0
                         AND SHOGAI_RITSU             = 0
                         AND GENMEN_KBN               = 0
                         AND GENMEN_RITSU             = 0
                         AND IRYO_NENREI_KEIGEN       = 0
                         AND IRYO_SHOGAI_GENMEN       = 0
                         AND IRYO_NENREI_KEIGEN_T     = 0
                         AND IRYO_SHOGAI_GENMEN_T     = 0
                         AND KAI_NENREI_KEIGEN        = 0
                         AND KAI_SHOGAI_GENMEN        = 0
                         AND KAI_NENREI_KEIGEN_T      = 0
                         AND KAI_SHOGAI_GENMEN_T      = 0
                         AND SHI_NENREI_KEIGEN        = 0
                         AND SHI_SHOGAI_GENMEN        = 0
                         AND SHI_NENREI_KEIGEN_T      = 0
                         AND SHI_SHOGAI_GENMEN_T      = 0
                         AND IRYO_KEIKA_H_SHOTOKU     = 0
                         AND IRYO_KEIKA_H_SHOTOKU_T   = 0
                         AND KAI_KEIKA_H_SHOTOKU      = 0
                         AND KAI_KEIKA_H_SHOTOKU_T    = 0
                         AND SIEN_KEIKA_H_SHOTOKU     = 0
                         AND SIEN_KEIKA_H_SHOTOKU_T   = 0
                         AND IRYO_KEIKA_H_SHISAN      = 0
                         AND IRYO_KEIKA_H_SHISAN_T    = 0
                         AND KAI_KEIKA_H_SHISAN       = 0
                         AND KAI_KEIKA_H_SHISAN_T     = 0
                         AND SIEN_KEIKA_H_SHISAN      = 0
                         AND SIEN_KEIKA_H_SHISAN_T    = 0
                         AND IRYO_KEIKA_H_KINTOWARI   = 0
                         AND IRYO_KEIKA_H_KINTOWARI_T = 0
                         AND KAI_KEIKA_H_KINTOWARI    = 0
                         AND KAI_KEIKA_H_KINTOWARI_T  = 0
                         AND SIEN_KEIKA_H_KINTOWARI   = 0
                         AND SIEN_KEIKA_H_KINTOWARI_T = 0
                         AND IRYO_KEIKA_BYODOWARI     = 0
                         AND IRYO_KEIKA_BYODOWARI_T   = 0
                         AND KAI_KEIKA_BYODOWARI      = 0
                         AND KAI_KEIKA_BYODOWARI_T    = 0
                         AND SIEN_KEIKA_BYODOWARI     = 0
                         AND SIEN_KEIKA_BYODOWARI_T   = 0
-- 2025/08/11 ZCZL.HEJIAQI UPDATE START 1.1.200.000:子ども子育て支援金対応
--                         AND H_KBN                    = 0;
                         AND H_KBN                    = 0
                         AND KDM_NENREI_KEIGEN        = 0
                         AND KDM_SHOGAI_GENMEN        = 0
                         AND KDM_KEIKA_H_SHOTOKU      = 0
                         AND KDM_KEIKA_H_SHISAN       = 0
                         AND KDM_KEIKA_H_KINTOWARI    = 0
                         AND KDM_KEIKA_BYODOWARI      = 0;
-- 2025/08/11 ZCZL.HEJIAQI UPDATE END
                      -- 0件の場合
                      IF NCNT_N = 0 THEN
                        NlCHK_R := c_NOK;       -- 変更あり
                      -- !=N件
                      ELSE
                        NlCHK_R := c_NNOTHING;  -- 変化なし
                      END IF;
                    EXCEPTION
                       WHEN OTHERS THEN
                         NlRTN := c_NERR;
                         VlMSG := 'subChkGennen 出力判定' || SQLERRM;
                         EXIT;
                    END;
                  ELSE
                    NlCHK_R := c_NOK;        -- 変更あり
                  END IF;
                END IF;
            END IF;

            IF NlCHK_R != c_NOK THEN
              IF i_NJIKKOU_KBN = c_NONLNIN AND NlCHK_R = c_NNOTHING THEN  -- オンラインで変更無しの場合
                NULL;
              ELSE
                BEGIN
                    -- レコード削除
                    DELETE FROM ZLBTKIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    DELETE FROM ZLBTTAI_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    DELETE FROM ZLBTKAI_KIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    DELETE FROM ZLBTKAI_TAI_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    DELETE FROM ZLBTSIEN_KIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    DELETE FROM ZLBTSIEN_TAI_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

--  2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
                    DELETE FROM ZLBTKDM_KIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;
--  2025/08/11 ZCZL.HEJIAQI ADD END

                    DELETE FROM ZLBTKIBETSU_CAL
                     WHERE KAMOKU_CD       = c_NKAMOKU_CD
                       AND KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEINENDO     = RwKIHONC.CHOTEI_NENDO
                       AND NENDOBUN        = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    DELETE FROM ZLBTKOJIN_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    DELETE FROM ZLBTSHOTOKU_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    DELETE FROM ZLBTEXT_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    -- 計算特徴対象者TBL削除
                    DELETE FROM ZLBTTOKU_KIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                EXCEPTION
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
                        EXIT;
                END;
              END IF;
            ELSE
                NwOK_CNT := NwOK_CNT + 1;
            END IF;

        END LOOP;

        IF NlRTN = c_NOK THEN
            IF NwOK_CNT > 0 THEN
                -- 出力対象あり
                NlCHK_R := c_NOK;
            ELSE
                NlCHK_R := c_NNOTHING;
            END IF;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subChkGennen2 出力判定' || SQLERRM;
    END subChkGennen2;

-------------------------------------------------------------------------------
--  02 過年用チェック(バッチ用)
-------------------------------------------------------------------------------
    PROCEDURE subChkKanen IS

        NwOK_CNT                    NUMBER;
        NwIRY_KIHON_FLG             NUMBER(1);
        NwKAI_KIHON_FLG             NUMBER(1);
        NwIRY_ZEIGAKU_CAL           NUMBER;
        NwKAI_ZEIGAKU_CAL           NUMBER;
        NwIRY_ZEIGAKU_N             NUMBER;
        NwKAI_ZEIGAKU_N             NUMBER;
        NwIRY_TAI_FLG               NUMBER(1);
        NwKAI_TAI_FLG               NUMBER(1);
        NwIRY_TAI_ZEIGAKU_CAL       NUMBER;
        NwKAI_TAI_ZEIGAKU_CAL       NUMBER;
        NwIRY_TAI_ZEIGAKU_N         NUMBER;
        NwKAI_TAI_ZEIGAKU_N         NUMBER;
        NwIRY_TAI_NENZEI_CAL        NUMBER;
        NwKAI_TAI_NENZEI_CAL        NUMBER;
-- 1変数追加
        NwCNT                       NUMBER;
        NwIRY_NENZEI_CAL            NUMBER;
        NwKAI_NENZEI_CAL            NUMBER;
        NwlCHK_R                 NUMBER;

        NwSIEN_KIHON_FLG            NUMBER(1);
        NwSIEN_ZEIGAKU_CAL          NUMBER;
        NwSIEN_ZEIGAKU_N            NUMBER;
        NwSIEN_TAI_FLG              NUMBER(1);
        NwSIEN_TAI_ZEIGAKU_CAL      NUMBER;
        NwSIEN_TAI_ZEIGAKU_N        NUMBER;
        NwSIEN_TAI_NENZEI_CAL       NUMBER;
        NwSIEN_NENZEI_CAL           NUMBER;
--  2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
        NwKDM_KIHON_FLG             NUMBER(1);
        NwKDM_ZEIGAKU_CAL           NUMBER;
        NwKDM_ZEIGAKU_N             NUMBER;
        NwKDM_NENZEI_CAL            NUMBER;
--  2025/08/11 ZCZL.HEJIAQI ADD END

        RwKIHONC                    ZLBTKIHON_CAL%ROWTYPE;

        -- 計算基本カーソル
        CURSOR CwTAISHO IS
            SELECT DISTINCT SANTEIDANTAI_CD, TSUCHI_NO
              FROM ZLBTKIHON_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND CHOTEI_NENDO    = i_NNENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND SYS_TANMATSU_NO = i_VTANMATSU;

    BEGIN
        NwOK_CNT := 0;

        -- システム条件より増・減対象年度を取得
        subJokenSel;

        IF NlRTN = c_NOK THEN

            FOR RwTAISHO IN CwTAISHO LOOP

                NlCHK_R := c_NNOTHING;         -- 変化なし

                NwIRY_KIHON_FLG   := 0;
                NwKAI_KIHON_FLG   := 0;

                NwIRY_ZEIGAKU_CAL := 0;
                NwIRY_ZEIGAKU_N   := 0;
                NwKAI_ZEIGAKU_CAL := 0;
                NwKAI_ZEIGAKU_N   := 0;

                NwIRY_TAI_FLG         := 0;
                NwKAI_TAI_FLG         := 0;
                NwIRY_TAI_ZEIGAKU_CAL := 0;
                NwIRY_TAI_ZEIGAKU_N   := 0;
                NwKAI_TAI_ZEIGAKU_CAL := 0;
                NwKAI_TAI_ZEIGAKU_N   := 0;
                NwIRY_TAI_NENZEI_CAL  := 0;
                NwKAI_TAI_NENZEI_CAL  := 0;

-- 1変数クリア追加
                NwIRY_NENZEI_CAL  := 0;
                NwKAI_NENZEI_CAL  := 0;

                NwSIEN_KIHON_FLG       := 0;
                NwSIEN_ZEIGAKU_CAL     := 0;
                NwSIEN_ZEIGAKU_N       := 0;
                NwSIEN_TAI_FLG         := 0;
                NwSIEN_TAI_ZEIGAKU_CAL := 0;
                NwSIEN_TAI_ZEIGAKU_N   := 0;
                NwSIEN_TAI_NENZEI_CAL  := 0;
                NwSIEN_NENZEI_CAL  := 0;
-- 2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
                NwKDM_KIHON_FLG         := 0;
                NwKDM_ZEIGAKU_CAL       := 0;
                NwKDM_ZEIGAKU_N         := 0;
                NwKDM_NENZEI_CAL        := 0;
-- 2025/08/11 ZCZL.HEJIAQI ADD END

                BEGIN
                    -- 計算基本取得
                    SELECT * INTO RwKIHONC
                      FROM ZLBTKIHON_CAL
                     WHERE KOKU_SETAI_NO   = i_NSETAI
                       AND SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = i_NNENDO
                       AND NENDO_BUN       = i_NNENDO_BUN
                       AND SYS_TANMATSU_NO = i_VTANMATSU
             AND TSUCHI_NO       = RwTAISHO.TSUCHI_NO;

                    NwIRY_ZEIGAKU_CAL := RwKIHONC.KANENDO + RwKIHONC.NENZEI;
-- 1変数セット追加
                    NwIRY_NENZEI_CAL  := RwKIHONC.NENZEI;

                EXCEPTION
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                        EXIT;
                END;

                BEGIN
                    -- 賦課基本(最新)取得
                    SELECT KANENDO + NENZEI INTO NwIRY_ZEIGAKU_N
                      FROM ZLBTKIHON_N
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
-- 1同一データ特定で通知書番号が不足
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND CHOTEI_NENDO    = (SELECT MAX(CHOTEI_NENDO)
                                                FROM ZLBTKIHON_N
                                               WHERE KOKU_SETAI_NO   =  RwKIHONC.KOKU_SETAI_NO
                                                 AND SANTEIDANTAI_CD =  RwKIHONC.SANTEIDANTAI_CD
                                                 AND CHOTEI_NENDO    <= RwKIHONC.CHOTEI_NENDO
                                                 AND NENDO_BUN       =  RwKIHONC.NENDO_BUN)
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NwIRY_KIHON_FLG := 1;       -- 賦課基本データなし
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                        EXIT;
                END;

                -- 計算介護基本取得
                BEGIN
-- 1変数セット追加
                    SELECT KANENDO + NENZEI,NENZEI INTO NwKAI_ZEIGAKU_CAL,NwKAI_NENZEI_CAL
                      FROM ZLBTKAI_KIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
-- 1同一データ特定で通知書番号が不足
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    BEGIN
                        -- 賦課介護基本(最新)取得
                        SELECT KANENDO + NENZEI INTO NwKAI_ZEIGAKU_N
                          FROM ZLBTKAI_KIHON_N
                         WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                           AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
-- 1同一データ特定で通知書番号が不足
                           AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                           AND CHOTEI_NENDO    = (SELECT MAX(CHOTEI_NENDO)
                                                    FROM ZLBTKAI_KIHON_N
                                                   WHERE KOKU_SETAI_NO   =  RwKIHONC.KOKU_SETAI_NO
                                                     AND SANTEIDANTAI_CD =  RwKIHONC.SANTEIDANTAI_CD
                                                     AND CHOTEI_NENDO    <= RwKIHONC.CHOTEI_NENDO
                                                     AND NENDO_BUN       =  RwKIHONC.NENDO_BUN)
                           AND NENDO_BUN       = RwKIHONC.NENDO_BUN;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            NwKAI_KIHON_FLG := 1;       -- 賦課介護基本データなし
                        WHEN OTHERS THEN
                            NlRTN := c_NERR;
                            VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                            EXIT;
                    END;

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        -- 計算介護基本が存在しない場合は±０として扱う
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                        EXIT;
                END;

                -- 計算支援基本取得
                BEGIN
-- 1変数セット追加
                    SELECT KANENDO + NENZEI,NENZEI INTO NwSIEN_ZEIGAKU_CAL,NwSIEN_NENZEI_CAL
                      FROM ZLBTSIEN_KIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
-- 1同一データ特定で通知書番号が不足
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    BEGIN
                        -- 賦課支援基本(最新)取得
                        SELECT KANENDO + NENZEI INTO NwSIEN_ZEIGAKU_N
                          FROM ZLBTSIEN_KIHON_N
                         WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                           AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
-- 1同一データ特定で通知書番号が不足
                           AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                           AND CHOTEI_NENDO    = (SELECT MAX(CHOTEI_NENDO)
                                                    FROM ZLBTSIEN_KIHON_N
                                                   WHERE KOKU_SETAI_NO   =  RwKIHONC.KOKU_SETAI_NO
                                                     AND SANTEIDANTAI_CD =  RwKIHONC.SANTEIDANTAI_CD
                                                     AND CHOTEI_NENDO    <= RwKIHONC.CHOTEI_NENDO
                                                     AND NENDO_BUN       =  RwKIHONC.NENDO_BUN)
                           AND NENDO_BUN       = RwKIHONC.NENDO_BUN;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            NwSIEN_KIHON_FLG := 1;       -- 賦課支援基本データなし
                        WHEN OTHERS THEN
                            NlRTN := c_NERR;
                            VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                            EXIT;
                    END;

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        -- 計算支援基本が存在しない場合は±０として扱う
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                        EXIT;
                END;
--  2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
                -- 計算子ども基本取得
                BEGIN
-- 1変数セット追加
                    SELECT KANENDO + NENZEI,NENZEI INTO NwKDM_ZEIGAKU_CAL,NwKDM_NENZEI_CAL
                      FROM ZLBTKDM_KIHON_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
-- 1同一データ特定で通知書番号が不足
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND SYS_TANMATSU_NO = i_VTANMATSU;

                    BEGIN
                        -- 賦課子ども基本(最新)取得
                        SELECT KANENDO + NENZEI INTO NwKDM_ZEIGAKU_N
                          FROM ZLBTKDM_KIHON_N
                         WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                           AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
-- 1同一データ特定で通知書番号が不足
                           AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                           AND CHOTEI_NENDO    = (SELECT MAX(CHOTEI_NENDO)
                                                    FROM ZLBTKDM_KIHON_N
                                                   WHERE KOKU_SETAI_NO   =  RwKIHONC.KOKU_SETAI_NO
                                                     AND SANTEIDANTAI_CD =  RwKIHONC.SANTEIDANTAI_CD
                                                     AND CHOTEI_NENDO    <= RwKIHONC.CHOTEI_NENDO
                                                     AND NENDO_BUN       =  RwKIHONC.NENDO_BUN)
                           AND NENDO_BUN       = RwKIHONC.NENDO_BUN;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            NwKDM_KIHON_FLG := 1;       -- 賦課子ども基本データ取得失敗
                        WHEN OTHERS THEN
                            NlRTN := c_NERR;
                            VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                            EXIT;
                    END;

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NwKDM_KIHON_FLG := 1;           -- 計算子ども基本データ取得失敗
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                        EXIT;
                END;
--  2025/08/11 ZCZL.HEJIAQI ADD END


                BEGIN
                    -- 計算退職取得
                    SELECT KANENDO + NENZEI ,NENZEI INTO NwIRY_TAI_ZEIGAKU_CAL,NwIRY_TAI_NENZEI_CAL
                      FROM ZLBTTAI_CAL
                     WHERE KOKU_SETAI_NO   = i_NSETAI
                       AND SANTEIDANTAI_CD = RwTAISHO.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = i_NNENDO
                       AND NENDO_BUN       = i_NNENDO_BUN
                       AND SYS_TANMATSU_NO = i_VTANMATSU
                       AND TSUCHI_NO       = RwTAISHO.TSUCHI_NO;

                EXCEPTION
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                        EXIT;
                END;
                BEGIN
                    -- 賦課退職(最新)取得
                    SELECT KANENDO + NENZEI INTO NwIRY_TAI_ZEIGAKU_N
                      FROM ZLBTTAI_N
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND CHOTEI_NENDO    = (SELECT MAX(CHOTEI_NENDO)
                                                FROM ZLBTKIHON_N
                                               WHERE KOKU_SETAI_NO   =  RwKIHONC.KOKU_SETAI_NO
                                                 AND SANTEIDANTAI_CD =  RwKIHONC.SANTEIDANTAI_CD
                                                 AND CHOTEI_NENDO    <= RwKIHONC.CHOTEI_NENDO
                                                 AND NENDO_BUN       =  RwKIHONC.NENDO_BUN)
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NwIRY_TAI_FLG := 1;       -- 賦課退職データなし
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                        EXIT;
                END;
                -- 計算介護退職取得
                BEGIN
                    SELECT KANENDO + NENZEI ,NENZEI INTO NwKAI_TAI_ZEIGAKU_CAL,NwKAI_TAI_NENZEI_CAL
                      FROM ZLBTKAI_TAI_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND SYS_TANMATSU_NO = i_VTANMATSU;
                    BEGIN
                        -- 賦課介護退職(最新)取得
                        SELECT KANENDO + NENZEI INTO NwKAI_TAI_ZEIGAKU_N
                          FROM ZLBTKAI_TAI_N
                         WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                           AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                           AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                           AND CHOTEI_NENDO    = (SELECT MAX(CHOTEI_NENDO)
                                                    FROM ZLBTKAI_TAI_N
                                                   WHERE KOKU_SETAI_NO   =  RwKIHONC.KOKU_SETAI_NO
                                                     AND SANTEIDANTAI_CD =  RwKIHONC.SANTEIDANTAI_CD
                                                     AND CHOTEI_NENDO    <= RwKIHONC.CHOTEI_NENDO
                                                     AND NENDO_BUN       =  RwKIHONC.NENDO_BUN)
                           AND NENDO_BUN       = RwKIHONC.NENDO_BUN;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            NwKAI_TAI_FLG := 1;       -- 賦課介護退職データなし
                        WHEN OTHERS THEN
                            NlRTN := c_NERR;
                            VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                            EXIT;
                    END;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        -- 計算介護退職が存在しない場合は±０として扱う
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                        EXIT;
                END;
                -- 計算支援退職取得
                BEGIN
                    SELECT KANENDO + NENZEI ,NENZEI INTO NwSIEN_TAI_ZEIGAKU_CAL,NwSIEN_TAI_NENZEI_CAL
                      FROM ZLBTSIEN_TAI_CAL
                     WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                       AND CHOTEI_NENDO    = RwKIHONC.CHOTEI_NENDO
                       AND NENDO_BUN       = RwKIHONC.NENDO_BUN
                       AND SYS_TANMATSU_NO = i_VTANMATSU;
                    BEGIN
                        -- 賦課支援退職(最新)取得
                        SELECT KANENDO + NENZEI INTO NwSIEN_TAI_ZEIGAKU_N
                          FROM ZLBTSIEN_TAI_N
                         WHERE KOKU_SETAI_NO   = RwKIHONC.KOKU_SETAI_NO
                           AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                           AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO
                           AND CHOTEI_NENDO    = (SELECT MAX(CHOTEI_NENDO)
                                                    FROM ZLBTSIEN_TAI_N
                                                   WHERE KOKU_SETAI_NO   =  RwKIHONC.KOKU_SETAI_NO
                                                     AND SANTEIDANTAI_CD =  RwKIHONC.SANTEIDANTAI_CD
                                                     AND CHOTEI_NENDO    <= RwKIHONC.CHOTEI_NENDO
                                                     AND NENDO_BUN       =  RwKIHONC.NENDO_BUN)
                           AND NENDO_BUN       = RwKIHONC.NENDO_BUN;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            NwSIEN_TAI_FLG := 1;       -- 賦課支援退職データなし
                        WHEN OTHERS THEN
                            NlRTN := c_NERR;
                            VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                            EXIT;
                    END;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        -- 計算支援退職が存在しない場合は±０として扱う
                        NULL;
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                        EXIT;
                END;
                -- 更新判定
--  2025/08/11 ZCZL.HEJIAQI UPDATE 1.1.200.000: 子ども子育て支援金対応
--                IF NwIRY_KIHON_FLG = 0 AND NwKAI_KIHON_FLG = 0 AND NwSIEN_KIHON_FLG = 0 THEN
                  IF NwIRY_KIHON_FLG = 0 AND NwKAI_KIHON_FLG = 0 AND NwSIEN_KIHON_FLG = 0 AND NwKDM_KIHON_FLG = 0 THEN

--  2025/08/11 ZCZL.HEJIAQI UPDATE 1.1.200.000: 子ども子育て支援金対応
--                -- 基本/支援基本/介護基本共にデータ有り
                  -- 基本/支援基本/介護基本/子ども基本共にデータ有り
                    IF (NwIRY_ZEIGAKU_CAL > NwIRY_ZEIGAKU_N  OR
                        NwSIEN_ZEIGAKU_CAL > NwSIEN_ZEIGAKU_N OR
--  2025/08/11 ZCZL.HEJIAQI UPDATE START 1.1.200.000: 子ども子育て支援金対応
--                        NwKAI_ZEIGAKU_CAL > NwKAI_ZEIGAKU_N) AND
                        NwKAI_ZEIGAKU_CAL > NwKAI_ZEIGAKU_N OR
                        NwKDM_ZEIGAKU_CAL > NwKDM_ZEIGAKU_N) AND
--  2025/08/11 ZCZL.HEJIAQI UPDATE END
                        i_NNENDO_BUN >= NlNENDO_ZO           THEN       -- 増額
                        NlCHK_R := c_NOK;
                    END IF;

                    IF (NwIRY_ZEIGAKU_CAL < NwIRY_ZEIGAKU_N  OR
                        NwSIEN_ZEIGAKU_CAL < NwSIEN_ZEIGAKU_N OR
--  2025/08/11 ZCZL.HEJIAQI UPDATE START 1.1.200.000: 子ども子育て支援金対応
--                        NwKAI_ZEIGAKU_CAL < NwKAI_ZEIGAKU_N) AND
                        NwKAI_ZEIGAKU_CAL < NwKAI_ZEIGAKU_N OR
                        NwKDM_ZEIGAKU_CAL < NwKDM_ZEIGAKU_N) AND
--  2025/08/11 ZCZL.HEJIAQI UPDATE END
                        i_NNENDO_BUN >= NlNENDO_GEN          THEN       -- 減額
                        NlCHK_R := c_NOK;
                    END IF;

                ELSIF NwIRY_KIHON_FLG = 1 THEN
                    -- 基本にデータなし
                    IF (NwIRY_ZEIGAKU_CAL > 0  OR
                        NwSIEN_ZEIGAKU_CAL >0 OR
--  2025/08/11 ZCZL.HEJIAQI UPDATE START 1.1.200.000: 子ども子育て支援金対応
--                        NwKAI_ZEIGAKU_CAL > 0) AND
                        NwKAI_ZEIGAKU_CAL > 0 OR
                        NwKDM_ZEIGAKU_CAL > 0) AND
--  2025/08/11 ZCZL.HEJIAQI UPDATE END
                        i_NNENDO_BUN >= NlNENDO_ZO THEN     -- 増額
                        NlCHK_R := c_NOK;
                    END IF;
--  2025/08/11 ZCZL.HEJIAQI UPDATE START 1.1.200.000: 子ども子育て支援金対応
--                ELSIF NwKAI_KIHON_FLG = 1 AND NwSIEN_KIHON_FLG = 1 THEN
--                    -- 介護基本にデータなしかつ支援基本にデータなし
                ELSIF NwKAI_KIHON_FLG = 1 AND NwSIEN_KIHON_FLG = 1 AND NwKDM_KIHON_FLG = 1 THEN
                    -- 介護基本にデータなしかつ支援基本にデータなしかつ子ども基本にデータなし
--  2025/08/11 ZCZL.HEJIAQI UPDATE END
                    IF NwIRY_ZEIGAKU_CAL > NwIRY_ZEIGAKU_N AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN          -- 増額
                        NlCHK_R := c_NOK;
                    END IF;

                    IF NwIRY_ZEIGAKU_CAL < NwIRY_ZEIGAKU_N AND
                       i_NNENDO_BUN >= NlNENDO_GEN THEN         -- 減額
                        NlCHK_R := c_NOK;
                    END IF;

                    IF NwKAI_ZEIGAKU_CAL > 0 AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN      -- 増額
                        NlCHK_R := c_NOK;
                    END IF;
                    IF NwSIEN_ZEIGAKU_CAL > 0 AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN      -- 増額
                        NlCHK_R := c_NOK;
                    END IF;
--  2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
                    IF NwKDM_ZEIGAKU_CAL > 0 AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN      -- 増額
                        NlCHK_R := c_NOK;
                    END IF;


                ELSIF NwKAI_KIHON_FLG = 1 AND NwSIEN_KIHON_FLG = 1 AND NwKDM_KIHON_FLG = 0 THEN
                    -- 介護基本にデータなしかつ支援基本にデータなしかつ子ども基本にデータあり
                    IF (NwIRY_ZEIGAKU_CAL > NwIRY_ZEIGAKU_N  OR
                       NwKDM_ZEIGAKU_CAL  > NwKDM_ZEIGAKU_N) AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN          -- 増額
                        NlCHK_R := c_NOK;
                    END IF;

                    IF (NwIRY_ZEIGAKU_CAL < NwIRY_ZEIGAKU_N  OR
                       NwKDM_ZEIGAKU_CAL  < NwKDM_ZEIGAKU_N) AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN          -- 減額
                        NlCHK_R := c_NOK;
                    END IF;

                    IF NwKAI_ZEIGAKU_CAL > 0 AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN      -- 増額
                        NlCHK_R := c_NOK;
                    END IF;

                    IF NwSIEN_ZEIGAKU_CAL > 0 AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN      -- 増額
                        NlCHK_R := c_NOK;
                    END IF;
--  2025/08/11 ZCZL.HEJIAQI ADD END


--  2025/08/11 ZCZL.HEJIAQI UPDATE START 1.1.200.000: 子ども子育て支援金対応
--                ELSIF NwSIEN_KIHON_FLG = 1 AND NwKAI_KIHON_FLG = 0 THEN
--                    -- 支援基本にデータなしかつ介護基本にデータあり
                ELSIF NwSIEN_KIHON_FLG = 1 AND NwKAI_KIHON_FLG = 0 AND NwKDM_KIHON_FLG = 1 THEN
                    -- 支援基本にデータなしかつ介護基本にデータありかつ子ども基本にデータなし
--  2025/08/11 ZCZL.HEJIAQI UPDATE END
                    IF (NwIRY_ZEIGAKU_CAL > NwIRY_ZEIGAKU_N  OR
                       NwKAI_ZEIGAKU_CAL > NwKAI_ZEIGAKU_N)  AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN          -- 増額
                        NlCHK_R := c_NOK;
                    END IF;

                    IF (NwIRY_ZEIGAKU_CAL < NwIRY_ZEIGAKU_N  OR
                       NwKAI_ZEIGAKU_CAL < NwKAI_ZEIGAKU_N)  AND
                       i_NNENDO_BUN >= NlNENDO_GEN THEN         -- 減額
                        NlCHK_R := c_NOK;
                    END IF;

                    IF NwSIEN_ZEIGAKU_CAL > 0 AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN      -- 増額
                        NlCHK_R := c_NOK;
                    END IF;
--  2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
                    IF NwKDM_ZEIGAKU_CAL > 0 AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN      -- 増額
                        NlCHK_R := c_NOK;
                    END IF;


                ELSIF NwSIEN_KIHON_FLG = 1 AND NwKAI_KIHON_FLG = 0 AND NwKDM_KIHON_FLG = 0 THEN
                    -- 支援基本にデータなしかつ介護基本にデータありかつ子ども基本にデータあり
                    IF (NwIRY_ZEIGAKU_CAL > NwIRY_ZEIGAKU_N  OR
                       NwKAI_ZEIGAKU_CAL  > NwKAI_ZEIGAKU_N  OR
                       NwKDM_ZEIGAKU_CAL  > NwKDM_ZEIGAKU_N) AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN          -- 増額
                        NlCHK_R := c_NOK;
                    END IF;

                    IF (NwIRY_ZEIGAKU_CAL < NwIRY_ZEIGAKU_N  OR
                       NwKAI_ZEIGAKU_CAL  < NwKAI_ZEIGAKU_N  OR
                       NwKDM_ZEIGAKU_CAL  < NwKDM_ZEIGAKU_N) AND
                       i_NNENDO_BUN >= NlNENDO_GEN THEN         -- 減額
                        NlCHK_R := c_NOK;
                    END IF;

                    IF NwSIEN_ZEIGAKU_CAL > 0 AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN      -- 増額
                        NlCHK_R := c_NOK;
                    END IF;
--  2025/08/11 ZCZL.HEJIAQI ADD END
--  2025/08/11 ZCZL.HEJIAQI UPDATE START 1.1.200.000: 子ども子育て支援金対応
--                ELSIF NwSIEN_KIHON_FLG = 0 AND NwKAI_KIHON_FLG = 1 THEN
                    -- 支援基本にデータありかつ介護基本にデータなし
                ELSIF NwSIEN_KIHON_FLG = 0 AND NwKAI_KIHON_FLG = 1 AND NwKDM_KIHON_FLG = 1 THEN
                    -- 支援基本にデータありかつ介護基本にデータなしかつ子ども基本にデータなし
--  2025/08/11 ZCZL.HEJIAQI UPDATE END
                    IF (NwIRY_ZEIGAKU_CAL > NwIRY_ZEIGAKU_N   OR
                       NwSIEN_ZEIGAKU_CAL > NwSIEN_ZEIGAKU_N) AND
                       i_NNENDO_BUN       >= NlNENDO_ZO       THEN     -- 増額
                        NlCHK_R := c_NOK;
                    END IF;

                    IF (NwIRY_ZEIGAKU_CAL < NwIRY_ZEIGAKU_N   OR
                       NwSIEN_ZEIGAKU_CAL < NwSIEN_ZEIGAKU_N) AND
                       i_NNENDO_BUN       >= NlNENDO_GEN      THEN     -- 減額
                        NlCHK_R := c_NOK;
                    END IF;

                    IF NwKAI_ZEIGAKU_CAL > 0           AND
                       i_NNENDO_BUN      >= NlNENDO_ZO THEN            -- 増額
                        NlCHK_R := c_NOK;
                    END IF;
--  2025/08/11 ZCZL.HEJIAQI ADD START 1.1.200.000: 子ども子育て支援金対応
                    IF NwKDM_ZEIGAKU_CAL > 0 AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN      -- 増額
                        NlCHK_R := c_NOK;
                    END IF;


                ELSIF NwSIEN_KIHON_FLG = 0 AND NwKAI_KIHON_FLG = 1 AND NwKDM_KIHON_FLG = 0 THEN
                    -- 支援基本にデータありかつ介護基本にデータなしかつ子ども基本にデータあり
                    IF (NwIRY_ZEIGAKU_CAL > NwIRY_ZEIGAKU_N   OR
                       NwSIEN_ZEIGAKU_CAL > NwSIEN_ZEIGAKU_N  OR
                       NwKDM_ZEIGAKU_CAL  > NwKDM_ZEIGAKU_N)  AND
                       i_NNENDO_BUN       >= NlNENDO_ZO       THEN     -- 増額
                        NlCHK_R := c_NOK;
                    END IF;

                    IF (NwIRY_ZEIGAKU_CAL < NwIRY_ZEIGAKU_N   OR
                       NwSIEN_ZEIGAKU_CAL < NwSIEN_ZEIGAKU_N  OR
                       NwKDM_ZEIGAKU_CAL  < NwKDM_ZEIGAKU_N)  AND
                       i_NNENDO_BUN       >= NlNENDO_GEN      THEN     -- 減額
                        NlCHK_R := c_NOK;
                    END IF;

                    IF NwKAI_ZEIGAKU_CAL > 0           AND
                       i_NNENDO_BUN      >= NlNENDO_ZO THEN            -- 増額
                        NlCHK_R := c_NOK;
                    END IF;


                ELSIF NwSIEN_KIHON_FLG = 0 AND NwKAI_KIHON_FLG = 0 AND NwKDM_KIHON_FLG = 1 THEN
                    -- 支援基本にデータありかつ介護基本にデータありかつ子ども基本にデータなし
                    IF (NwIRY_ZEIGAKU_CAL > NwIRY_ZEIGAKU_N   OR
                       NwSIEN_ZEIGAKU_CAL > NwSIEN_ZEIGAKU_N  OR
                       NwKAI_ZEIGAKU_CAL  > NwKAI_ZEIGAKU_N)  AND
                       i_NNENDO_BUN       >= NlNENDO_ZO       THEN     -- 増額
                        NlCHK_R := c_NOK;
                    END IF;

                    IF (NwIRY_ZEIGAKU_CAL < NwIRY_ZEIGAKU_N   OR
                       NwSIEN_ZEIGAKU_CAL < NwSIEN_ZEIGAKU_N  OR
                       NwKAI_ZEIGAKU_CAL  < NwKAI_ZEIGAKU_N)  AND
                       i_NNENDO_BUN       >= NlNENDO_GEN      THEN     -- 減額
                        NlCHK_R := c_NOK;
                    END IF;

                    IF NwKDM_ZEIGAKU_CAL > 0           AND
                       i_NNENDO_BUN      >= NlNENDO_ZO THEN            -- 増額
                        NlCHK_R := c_NOK;
                    END IF;
--  2025/08/11 ZCZL.HEJIAQI ADD END

                END IF;


                IF NwIRY_TAI_FLG = 0 AND NwSIEN_TAI_FLG = 0 AND NwKAI_TAI_FLG = 0 THEN
                    -- 退職/介護退職共にデータ有り
                    -- 退職/介護退職共にデータ有り
                    IF (NwIRY_TAI_ZEIGAKU_CAL > NwIRY_TAI_ZEIGAKU_N  OR
                        NwSIEN_TAI_ZEIGAKU_CAL > NwSIEN_TAI_ZEIGAKU_N OR
                        NwKAI_TAI_ZEIGAKU_CAL > NwKAI_TAI_ZEIGAKU_N) AND
                        i_NNENDO_BUN >= NlNENDO_ZO           THEN       -- 増額
                        NlCHK_R := c_NOK;
                    END IF;
                    IF (NwIRY_TAI_ZEIGAKU_CAL < NwIRY_TAI_ZEIGAKU_N  OR
                        NwSIEN_TAI_ZEIGAKU_CAL < NwSIEN_TAI_ZEIGAKU_N OR
                        NwKAI_TAI_ZEIGAKU_CAL < NwKAI_TAI_ZEIGAKU_N) AND
                        i_NNENDO_BUN >= NlNENDO_GEN          THEN       -- 減額
                        NlCHK_R := c_NOK;
                    END IF;
                ELSIF NwIRY_TAI_FLG = 1 THEN
                    -- 退職にデータなし
                    IF (NwIRY_TAI_ZEIGAKU_CAL > 0  OR
                       NwSIEN_TAI_ZEIGAKU_CAL > 0 OR
                        NwKAI_TAI_ZEIGAKU_CAL > 0) AND
                        i_NNENDO_BUN >= NlNENDO_ZO THEN     -- 増額
                        NlCHK_R := c_NOK;
                    END IF;
                ELSIF NwKAI_TAI_FLG = 1 AND NwSIEN_TAI_FLG = 1 THEN
                    -- 介護退職にデータなしかつ支援退職にデータなし
                    IF NwIRY_TAI_ZEIGAKU_CAL > NwIRY_TAI_ZEIGAKU_N AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN          -- 増額
                        NlCHK_R := c_NOK;
                    END IF;
                    IF NwIRY_TAI_ZEIGAKU_CAL < NwIRY_TAI_ZEIGAKU_N AND
                       i_NNENDO_BUN >= NlNENDO_GEN THEN         -- 減額
                        NlCHK_R := c_NOK;
                    END IF;
                    IF NwKAI_TAI_ZEIGAKU_CAL > 0 AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN      -- 増額
                        NlCHK_R := c_NOK;
                    END IF;
                    IF NwSIEN_TAI_ZEIGAKU_CAL > 0 AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN      -- 増額
                        NlCHK_R := c_NOK;
                    END IF;

                ELSIF NwSIEN_TAI_FLG = 1 AND NwKAI_TAI_FLG = 0 THEN
                    -- 支援退職にデータなしかつ介護退職にデータあり
                    IF (NwIRY_TAI_ZEIGAKU_CAL > NwIRY_TAI_ZEIGAKU_N  OR
                        NwKAI_TAI_ZEIGAKU_CAL > NwKAI_TAI_ZEIGAKU_N) AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN          -- 増額
                        NlCHK_R := c_NOK;
                    END IF;
                    IF (NwIRY_TAI_ZEIGAKU_CAL < NwIRY_TAI_ZEIGAKU_N  OR
                        NwKAI_TAI_ZEIGAKU_CAL < NwKAI_TAI_ZEIGAKU_N) AND
                       i_NNENDO_BUN >= NlNENDO_GEN THEN         -- 減額
                        NlCHK_R := c_NOK;
                    END IF;
                    IF NwSIEN_TAI_ZEIGAKU_CAL > 0 AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN      -- 増額
                        NlCHK_R := c_NOK;
                    END IF;
                ELSIF NwSIEN_TAI_FLG = 0 AND NwKAI_TAI_FLG = 1 THEN
                    -- 支援退職にデータありかつ介護退職にデータなし
                    IF (NwIRY_TAI_ZEIGAKU_CAL  > NwIRY_TAI_ZEIGAKU_N   OR
                        NwSIEN_TAI_ZEIGAKU_CAL > NwSIEN_TAI_ZEIGAKU_N) AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN          -- 増額
                        NlCHK_R := c_NOK;
                    END IF;
                    IF (NwIRY_TAI_ZEIGAKU_CAL  < NwIRY_TAI_ZEIGAKU_N   OR
                        NwSIEN_TAI_ZEIGAKU_CAL < NwSIEN_TAI_ZEIGAKU_N) AND
                       i_NNENDO_BUN >= NlNENDO_GEN THEN         -- 減額
                        NlCHK_R := c_NOK;
                    END IF;
                    IF NwKAI_TAI_ZEIGAKU_CAL > 0 AND
                       i_NNENDO_BUN >= NlNENDO_ZO THEN      -- 増額
                        NlCHK_R := c_NOK;
                    END IF;
                END IF;

-- 1計算の税額\0で賦課のTBL未存在時は変更無しで返却

                -- 医療・介護・支援ともに年税額で且つ賦課基本が存在する場合
                IF NlCHK_R = c_NOK AND NwIRY_NENZEI_CAL = 0 AND NwKAI_NENZEI_CAL = 0 AND NwSIEN_NENZEI_CAL = 0 THEN
                  -- 賦課が存在するか
                  BEGIN
                    SELECT COUNT(*) INTO NwCNT
                      FROM ZLBTKIHON_N
                     WHERE KOKU_SETAI_NO   = i_NSETAI
                       AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                       AND CHOTEI_NENDO    = i_NNENDO
                       AND NENDO_BUN       = i_NNENDO_BUN
                       AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                  EXCEPTION
                    WHEN OTHERS THEN
                      NlRTN := c_NERR;
                      VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                  END;
                  IF NwCNT > 0 THEN               -- 賦課存在？
                    NlCHK_R := c_NOK;             -- 減額
                  Else
                    IF NlCHK_R = c_NOK AND NwIRY_TAI_NENZEI_CAL = 0 AND NwKAI_TAI_NENZEI_CAL = 0
                                                                    AND NwSIEN_TAI_NENZEI_CAL = 0 THEN
                      -- 賦課が存在するか
                      BEGIN
                        SELECT COUNT(*) INTO NwCNT
                          FROM ZLBTTAI_N
                         WHERE KOKU_SETAI_NO   = i_NSETAI
                           AND SANTEIDANTAI_CD = RwKIHONC.SANTEIDANTAI_CD
                           AND CHOTEI_NENDO    = i_NNENDO
                           AND NENDO_BUN       = i_NNENDO_BUN
                           AND TSUCHI_NO       = RwKIHONC.TSUCHI_NO;
                      EXCEPTION
                        WHEN OTHERS THEN
                          NlRTN := c_NERR;
                          VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                      END;
                      IF NwCNT > 0 THEN               -- 賦課存在？
                        NlCHK_R := c_NOK;             -- 減額
                      Else
                        NlCHK_R := c_NNOTHING;        -- 変化なし
                      END IF;
                    END IF;
                  END IF;
                END IF;
                IF NlCHK_R != c_NOK THEN

                  IF i_NJIKKOU_KBN = c_NONLNIN AND NlCHK_R = c_NNOTHING THEN  -- オンラインで変更無しの場合
                    NULL;
                  ELSE

                    -- レコード削除
                    subDelData(RwKIHONC);
                  END IF;
                ELSE
                    NwOK_CNT := NwOK_CNT + 1;
                END IF;

            END LOOP;
            IF NlRTN = c_NOK THEN
                IF NwOK_CNT > 0 THEN
                    -- 出力対象あり
                    NwlCHK_R := c_NOK;
                    subChkGennen2;           -- 現年用チェック
                ELSE
-- 引数の年度分と同一調定年度に対して減のデータを作成していないかチェックを追加
-- ここまでの処理は引数の調定年度・年度分に対してのみ変更無しかチェックしている
-- 引数の年度分と同一調定年度のデータは、減になった時のみ作成される(変更なしは作成されない)
                  BEGIN
                    Select count(*) into NwOK_CNT from ZLBTKIHON_CAL
                     Where SYS_TANMATSU_NO = i_VTANMATSU;
                  EXCEPTION
                    WHEN OTHERS THEN
                      NlRTN := c_NERR;
                      VlMSG := 'subChkKanen 出力判定' || SQLERRM;
                  END;
                  IF NlRTN = c_NOK THEN
                    IF NwOK_CNT > 0 THEN
-- 引数の年度分と同一調定年度のデータは、増減なしでも作成される様になった為に増減なしかの判断を追加
-- →現年用のチェック処理呼出し
                      subChkGennen2;           -- 現年用チェック
                    ELSE
                      NlCHK_R := c_NNOTHING;
                    END IF;
                  END IF;
                END IF;
            END IF;

        END IF;

    END subChkKanen;
-------------------------------------------------------------------------------
--  00 メイン
-------------------------------------------------------------------------------
BEGIN

----- 初期処理 -----
    NlRTN := c_NOK;

    -- 仮算定異動計算機能がオンの場合、仮算定中か判定を行う
    IF i_NJIKKOU_KBN = c_NONLNIN THEN
      IF ZLBPK00010.FCFFJKN2(411) = 1 THEN
        -- 仮算定判断
        IZAN_MODE := ZLBPK00010.FCZANMODE_ONL(i_NNENDO, i_NNENDO_BUN, i_NKIJUNBI);
      ELSE
        IZAN_MODE := 0;
      END IF;
    ELSE
      IZAN_MODE := 0;
    END IF;

----- 主処理 -----
    IF i_NGENNEN_KANEN = c_NGENNEN THEN

      IF IZAN_MODE = 1 THEN
        subChkKarisan;          -- 仮算定用チェック
      ELSE
        subChkGennen;           -- 現年用チェック
      END IF;

    ELSE

        subChkKanen;            -- 過年用チェック

    END IF;

----- 終了処理 -----
    IF NlRTN = c_NOK THEN           -- 正常
        BEGIN
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'COMMIT発行 ' || SQLERRM;
        END;
    END IF;

    IF NlRTN = c_NERR THEN          -- 異常
        BEGIN
            ROLLBACK;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
    END IF;

    -- ログ出力
    IF NlRTN = c_NERR THEN
        IF i_NJIKKOU_KBN = c_NBATCH THEN

            -- バッチ起動時(ﾛｸﾞTBL出力)
            bRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSBUPCHK', 1, '', '','ZLBSBUPCHK ' || VlMSG, i_NSHOKUINKOJIN, i_VTANMATSU);
        ELSIF i_NTRENBAN = -1 THEN

            -- オンライン起動時(テストの時のみ)
            DBMS_OUTPUT.PUT_LINE('ZLBSBUPCHK ' || VlMSG);

        END IF;
    END IF;
    -- 返却値設定
    IF NlRTN = c_NOK THEN
        o_NRESULT := NlCHK_R;           -- OK or 対象外
    ELSE
        o_NRESULT := c_NERR;
    END IF;
END ZLBSBUPCHK;
/