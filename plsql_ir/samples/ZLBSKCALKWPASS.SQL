CREATE OR REPLACE PROCEDURE ZLBSKCALKWPASS(i_NGENKA_KBN            IN  NUMBER,
--1.1.200.000
                                          i_NTSUCHI_NO            IN  NUMBER,
                                          i_NNENDO                IN  NUMBER,
                                          i_NNENDO_BUN            IN  NUMBER,
                                          i_NSHORIBI              IN  NUMBER,
                                          i_NDANTAI               IN  NUMBER,
                                          i_NSETAI                IN  NUMBER,
                                          i_NJIKKOU_KBN           IN  NUMBER,
                                          i_VTANMATSU             IN  NVARCHAR2,
                                          i_NTRENBAN              IN  NUMBER,
                                          o_NRESULT               OUT NUMBER,
                                          i_NKOSEIBI              IN  NUMBER := 0)
-------------------------------------------------------------------------------
-- 業務名   ZLB（国保税）
-- ＰＧ名   ZLBSKCALKWPASS
-- 名称     計算期別作成（過年度分）
-- 処理概要 賦課基本、賦課期別、計算基本を元に期割計算を行なう。
--          税額試算の場合は賦課TBLではなく更正前TBLを元に期割計算を行なう。
--          （基本的にZLBSKCALKWよりコピー）
-- 引き数    i_NTSUCHI_NO            通知書番号
--          i_NNENDO                調定年度
--          i_NNENDO_BUN            年度分
--          i_NSHORIBI              処理日
--          i_NDANTAI               算定団体コード
--          i_NSETAI                国保世帯番号(ログ出力用)
--          i_NJIKKOU_KBN           実行区分(0:バッチから起動 本算定/月例...
--                                           1:オンライン起動 即時
--                                           2:オンライン起動 税額試算)
--          i_VTANMATSU             端末番号
--          i_NTRENBAN              登録連番
--          o_NRESULT               処理結果
--  作成者   ZCZL.GUORUIHUA
--  作成日   2023/08/01
--  Version 0.2.000.000
------------------------------------------------------------------------------
--変更履歴
--2025/08/12 ZCZL.WANGMING Update 1.1.200.000:子ども子育て支援金対応
------------------------------------------------------------------------------
IS

    TYPE MTNUMARRAY1  IS TABLE OF NUMBER(1)  INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY2  IS TABLE OF NUMBER(2)  INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY4  IS TABLE OF NUMBER(4)  INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY8  IS TABLE OF NUMBER(8)  INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY10 IS TABLE OF NUMBER(10) INDEX BY BINARY_INTEGER;
    TYPE MTNUMARRAY12 IS TABLE OF NUMBER(12) INDEX BY BINARY_INTEGER;

-------------------------------------------------------------------------------
-- 定数の定義
-------------------------------------------------------------------------------
    c_NOK               CONSTANT NUMBER(1)  := 0;   -- 処理正常
    c_NERR              CONSTANT NUMBER(1)  := 1;   -- 処理異常

    -- エラーログSTEP NO
    c_NSTEPNO           CONSTANT NUMBER := 99;

    c_NKAMOKU_CD        CONSTANT NUMBER(3)  := 15;  -- 科目コード
    c_NKAMOKUS_CD       CONSTANT NUMBER(2)  := 1;   -- 科目詳細コード
    c_NKAMOKUS_CD_2     CONSTANT NUMBER(2)  := 2;   -- 科目詳細コード(特徴)

    -- 端数
    c_NHASU_1           CONSTANT NUMBER := -3;
    c_NHASU_2           CONSTANT NUMBER := -2;
    c_NHASU_3           CONSTANT NUMBER := 0;
    c_NHASU_10          CONSTANT NUMBER := -1;
    c_NHASU_KBN_1       CONSTANT NUMBER := 0;       -- c_NHASU_1に対応
    c_NHASU_KBN_2       CONSTANT NUMBER := 1;       -- c_NHASU_2に対応
    c_NHASU_KBN_3       CONSTANT NUMBER := 2;       -- c_NHASU_3に対応
    c_NHASU_KBN_10      CONSTANT NUMBER := 3;

    -- 処理区分
    c_NMODE_ZEN         CONSTANT NUMBER(1) := 0;        -- 全体処理
    c_NMODE_TAI         CONSTANT NUMBER(1) := 1;        -- 退職処理

    -- 実行区分
    c_NBATCH        CONSTANT NUMBER(1) := 0;        -- バッチ(本算定/月例/仮算定/過年度)
    c_NONLNIN       CONSTANT NUMBER(1) := 1;        -- オンライン(即時/期割)
    c_NTEST         CONSTANT NUMBER(1) := 2;        -- オンライン(税額試算)

    -- 現年・過年
    c_NGENNEN           CONSTANT NUMBER(1) := 0;    -- 現年
    c_NKANEN            CONSTANT NUMBER(1) := 1;    -- 過年

    -- 算定団体
    c_NDANTAI           CONSTANT NUMBER := 1;       -- 合併後算定団体

    -- 不均一課税
    c_NFKAZEI           CONSTANT NUMBER := 1;       -- 不均一課税を行なう

    -- 納期区分
    c_NNOUKI_0          CONSTANT NUMBER(1) := 0;
    c_NNOUKI_3          CONSTANT NUMBER(1) := 3;
-------------------------------------------------------------------------------
-- ワークエリアの定義
-------------------------------------------------------------------------------
    NlRTN                   NUMBER(1);
    BlRTN                   BOOLEAN;
    VlMSG                   NVARCHAR2(100);

    NlTSUCHI_NO             NUMBER(12);         -- 通知書番号
    NlNENZEI                NUMBER(10);         -- 年税額
    NlGENMEN                NUMBER(10);         -- 減免額
    NlTAI_NENZEI            NUMBER(10);         -- 退年税額
    NlTAI_GENMEN            NUMBER(10);         -- 退減免額
    NlKAI_NENZEI            NUMBER(10);         -- 介護年税額
    NlKAI_TAI_NENZEI        NUMBER(10);         -- 介護退年税額
    NlSIEN_NENZEI           NUMBER(10);         -- 支援年税額
    NlSIEN_TAI_NENZEI       NUMBER(10);         -- 支援退年税額
    NlNENZEI_SV             NUMBER(10);         -- 保存用年税額
    NlNENZEI_HAN            NUMBER(12);         -- 増減判定用年税額
    NlSAGAKU                NUMBER(10);         -- 差額
    NlTAI_SAGAKU            NUMBER(10);         -- 退差額
    NlKAI_SAGAKU            NUMBER(10);         -- 介護差額
    NlKAI_TAI_SAGAKU        NUMBER(10);         -- 介護退差額
    NlSIEN_SAGAKU           NUMBER(10);         -- 支援差額
    NlSIEN_TAI_SAGAKU       NUMBER(10);         -- 支援退差額
    NlLOOP_FLG              NUMBER(1);
    NlCUT_COL               NUMBER;
    NlKIWARIDANTAI_CD       NUMBER;             -- 期割団体コード(過年度：収納条件取得時使用)
    NlZO_FLG                NUMBER(1);          -- 増FLG（0:減/1:増）

    MlNOUKI                 MTNUMARRAY4;        -- 納期区分
    MlKIBETSU               MTNUMARRAY4;        -- 期別
    MlIRY_ZEI               MTNUMARRAY8;        -- 医療全体税額
    MlIRY_TAI_ZEI           MTNUMARRAY8;        -- 医療退職税額
    MlKAI_ZEI               MTNUMARRAY8;        -- 介護全体税額
    MlKAI_TAI_ZEI           MTNUMARRAY8;        -- 介護退職税額
    MlSIEN_ZEI              MTNUMARRAY8;        -- 支援全体税額
    MlSIEN_TAI_ZEI          MTNUMARRAY8;        -- 支援退職税額
    MlKIZEI                 MTNUMARRAY10;       -- 期別税額
    MlTAI_KIZEI             MTNUMARRAY10;       -- 退期別税額
    MlNUSI_KOJIN_NO         MTNUMARRAY12;       -- 主個人番号
    MlKAMOKUS_CD            MTNUMARRAY2;        --科目詳細コード

    MlCAL_CHOTEI_NENDO      MTNUMARRAY8;        -- 計算調定年度
    MlCAL_NENDO_BUN         MTNUMARRAY8;        -- 計算年度分
    MlCAL_TSUCHI_NO         MTNUMARRAY12;       -- 計算通知書番号
    MlCAL_KIBETSU           MTNUMARRAY8;        -- 計算期別
    MlCAL_NUSI_KOJIN_NO     MTNUMARRAY12;       -- 計算主個人番号
    MlCAL_ZEI               MTNUMARRAY10;       -- 計算全体税額
    MlCAL_TAI_ZEI           MTNUMARRAY10;       -- 計算退職税額
    MlCAL_NOUFU_KBN         MTNUMARRAY4;        -- 計算納付書区分
    MlCAL_KAMOKUS_CD        MTNUMARRAY2;        --計算科目詳細コード	--

    RlKIHONCAL              ZLBTKIHON_CAL%ROWTYPE;      -- 計算基本
    RlTAICAL                ZLBTTAI_CAL%ROWTYPE;        -- 計算退職
    RlKAIKIHONCAL           ZLBTKAI_KIHON_CAL%ROWTYPE;  -- 計算介護基本
    RlKAITAICAL             ZLBTKAI_TAI_CAL%ROWTYPE;    -- 計算介護退職
    RlSIENKIHONCAL          ZLBTSIEN_KIHON_CAL%ROWTYPE; -- 計算支援基本
    RlSIENTAICAL            ZLBTSIEN_TAI_CAL%ROWTYPE;   -- 計算支援退職
    RlKIBETSUCAL            ZLBTKIBETSU_CAL%ROWTYPE;    -- 計算期別
--2025/08/12 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
    NlKDM_NENZEI            NUMBER(10);                 -- 子ども年税額
    NlKDM_SAGAKU            NUMBER(10);                 -- 子ども差額
    MlKDM_ZEI               MTNUMARRAY10;                -- 子ども全体税額
    RlKDMKIHONCAL           ZLBTKDM_KIHON_CAL%ROWTYPE;  -- 計算子ども基本
--2025/08/12 ZCZL.WANGMING ADD END

-------------------------------------------------------------------------------
-- 12 最大期別取得
-------------------------------------------------------------------------------
    FUNCTION funcMaxKibetsuGet RETURN NUMBER IS

        NwIX                NUMBER(2);

    BEGIN

        FOR IDX IN REVERSE 1..13 LOOP

            IF MlNOUKI(IDX) = 3 THEN
                NwIX := IDX;
                EXIT;
            END IF;

        END LOOP;

        RETURN(NwIX);

    END funcMaxKibetsuGet;
-------------------------------------------------------------------------------
-- 11 現在期別判定
--  i_NwMODE=0:全体,1:退職 RETURN=0:到来分(処理20),1:未到来分(処理30)
-------------------------------------------------------------------------------
    FUNCTION funcGenzaiKibetsu(i_NwMODE       IN  NUMBER,
                               o_NwGENKIBETSU OUT NUMBER) RETURN NUMBER IS

        NwRTN               NUMBER;
        NwGenKibetsu        NUMBER;
        NwNEN               NUMBER;
        NwTUKI              NUMBER;

    BEGIN

        NwRTN        := 0;
        NwGenKibetsu := 0;

        -- 年と月を算出
        NwNEN  := TRUNC(i_NSHORIBI, -4) / 10000;
        NwTUKI := TRUNC(i_NSHORIBI - TRUNC(i_NSHORIBI, -4), -2) / 100;

        IF i_NGENKA_KBN = c_NGENNEN THEN        -- 現年

            IF RlKIHONCAL.CHOTEI_NENDO != NwNEN THEN
                IF NwTUKI IN (4, 5) THEN
                    NwGenKibetsu := 13;
                ELSIF NwTUKI IN (1, 2, 3) THEN
                    NwGenKibetsu := NwTUKI + 9;
                END IF;
            ELSE
                NwGenKibetsu := NwTUKI - 3;
                IF NwGenKibetsu = 1 THEN
                    IF i_NwMODE = c_NMODE_ZEN THEN     -- 処理モードが「全体」
--2025/08/12 ZCZL.WANGMING UPDATE 1.1.200.000:子ども子育て支援金対応
--                        NlNENZEI_SV := NVL(RlKIHONCAL.NENZEI, 0) + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0);
                        NlNENZEI_SV := NVL(RlKIHONCAL.NENZEI, 0) + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0)+ NVL(RlKDMKIHONCAL.NENZEI, 0);
                    ELSE
                        NlNENZEI_SV := NVL(RlTAICAL.NENZEI, 0)  + NVL(RlKAITAICAL.NENZEI, 0) + NVL(RlSIENTAICAL.NENZEI, 0);
                    END IF;
                    NwRTN := 1;
                END IF;
            END IF;

        ELSE                -- 過年

--2025/08/12 ZCZL.WANGMING UPDATE START 1.1.200.000:子ども子育て支援金対応
--          IF (NlNENZEI + NlKAI_NENZEI + NlSIEN_NENZEI) >=
--                         (RlKIHONCAL.NENZEI + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0)) THEN
          IF (NlNENZEI + NlKAI_NENZEI + NlSIEN_NENZEI + NlKDM_NENZEI) >=
                         (RlKIHONCAL.NENZEI + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0) + NVL(RlKDMKIHONCAL.NENZEI, 0)) THEN
--2025/08/12 ZCZL.WANGMING UPDATE END
           --税額「減」の場合・・・更正前年税額（医療＋介護）＞更正後年税額（医療＋介護）
            FOR IDX IN REVERSE 1..13 LOOP
              --後ろの期別で有効な期別を取得
              IF MlNOUKI(IDX) > 0 THEN
                NwGenKibetsu := IDX;
                EXIT;
              END IF;
            END LOOP;
          ELSE
            --税額「増」の場合
            IF NwTUKI IN (1, 2, 3) THEN
                NwGenKibetsu := NwTUKI + 9;
            ELSE
              IF RlKIHONCAL.CHOTEI_NENDO != NwNEN AND NwTUKI = 4 THEN
                NwGenKibetsu := 13;
              ELSE
                NwGenKibetsu := NwTUKI - 3;
              END IF;
            END IF;

          END IF;

        END IF;

        o_NwGENKIBETSU := NwGenKibetsu;

        RETURN(NwRTN);

    END funcGenzaiKibetsu;
-------------------------------------------------------------------------------
-- 期割処理20
--  1期～現在期までの期割処理
-------------------------------------------------------------------------------
    FUNCTION funcKiwari20_FUTU(i_NwMODE     IN NUMBER,
                          i_NwGENZAIKI IN NUMBER) RETURN NUMBER IS
        NwRTN               NUMBER(1);     -- 戻り値
        NwIX                NUMBER(2);     -- ループ用INDEX
        NwWK_ZEIGAKU        NUMBER;        -- マイナス直前税額
        NwWK_INDEX          NUMBER(2);     -- インデックス保持
        NwNEXT_KIBETSU      NUMBER;        -- 次期別
        NwNENZEI            NUMBER;        -- 計算年税
        NwSUMZEIGAKU        NUMBER;        -- 普徴の税額
        NwSUMZEIGAKU_TOKU   NUMBER;        -- 特徴の税額
    BEGIN
        -- 初期化
        NwRTN        := 0;
        NwWK_ZEIGAKU := 0;
        NlNENZEI_HAN := 0;      -- 増減判定用年税額
        NlNENZEI_SV  := 0;      -- 保存用年税額
        NwSUMZEIGAKU := 0;
        NwSUMZEIGAKU_TOKU := 0;
        -- 増減判定用年税額算出
        IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
--2025/08/12 ZCZL.WANGMING UPDATE 1.1.200.000:子ども子育て支援金対応
--            NlNENZEI_HAN := NVL(RlKIHONCAL.NENZEI, 0) + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0);
            NlNENZEI_HAN := NVL(RlKIHONCAL.NENZEI, 0) + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0) + NVL(RlKDMKIHONCAL.NENZEI, 0);
            NwNENZEI := NlNENZEI_HAN;
        ELSE                            -- 退職
            NlNENZEI_HAN := NVL(RlTAICAL.NENZEI, 0) + NVL(RlKAITAICAL.NENZEI, 0) + NVL(RlSIENTAICAL.NENZEI, 0);
            NwNENZEI := NlNENZEI_HAN;
        END IF;
        IF NlNENZEI_HAN = 0 THEN
            NwWK_INDEX := 1;
        ELSE
            -- 最終期までで増減判断
            FOR NwIX IN 1..24 LOOP
                IF NlNENZEI_HAN < 0 THEN
                    EXIT;
                ELSE
                    -- 納期設定判定
                    IF (NwIX >= 14  AND  MlNOUKI(NwIX) > 0) OR    -- 特徴期別ＯＲ現在期（-1期）までの、納期月
                       (NwIX <= 13 AND NwIX < i_NwGENZAIKI AND MlNOUKI(NwIX) > 0) THEN
                        NwWK_INDEX   := NwIX; --ループ用INDEXの値を保持
                        IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
                            -- 期別金額が有り
                            IF MlKIZEI(NwIX) > 0 THEN
                                NwWK_ZEIGAKU := NlNENZEI_HAN;                      -- マイナス直前の増減判定用税額をセーブ
                                NlNENZEI_HAN := NlNENZEI_HAN - MlKIZEI(NwIX);      -- 増減判定用税額-期別金額
                            END IF;
                        ELSE                            -- 退職
                            IF MlTAI_KIZEI(NwIX) > 0 THEN
                                NwWK_ZEIGAKU := NlNENZEI_HAN;                      -- マイナス直前の増減判定用税額をセーブ
                                NlNENZEI_HAN := NlNENZEI_HAN - MlTAI_KIZEI(NwIX);  -- 増減判定用税額-期別金額
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END LOOP;
        END IF;
        -- 保存用年税額 へ (マイナス直前税額)or(現在期－１期)の税額をセット
        -- マイナス直前税額＝0
        IF (NwWK_ZEIGAKU = 0) THEN
          NlNENZEI_SV := NlNENZEI_HAN;  -- 増減判定用税額
        -- 増減判定用税額＞0
        ELSIF (NlNENZEI_HAN > 0) THEN
          NlNENZEI_SV := NlNENZEI_HAN;  -- 増減判定用税額
        -- 増減判定用税額＝0
        ELSIF(NlNENZEI_HAN = 0) THEN
          NlNENZEI_SV := NlNENZEI_HAN ; -- 増減判定用税額
        -- 以外
        ELSE
          NlNENZEI_SV := NwWK_ZEIGAKU;  -- マイナス直前税額
        END IF;
        -- 期別税額セット
        IF NlNENZEI_HAN >= 0 AND NwNENZEI > 0 THEN
            -- 期別税額がプラスの場合
            FOR NwIX IN 1..24 LOOP
                -- 納期設定判定
                IF (NwIX >=14  AND MlNOUKI(NwIX) > 0) OR     -- 特徴期別ＯＲ現在期（-1期）までの、納期月
                   (NwIX <=13 AND NwIX <i_NwGENZAIKI AND MlNOUKI(NwIX) > 0) THEN
                    IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
                        MlCAL_ZEI(NwIX) := MlKIZEI(NwIX);          -- 期別更新用変数にセット
                    ELSE                            -- 退職
                        MlCAL_TAI_ZEI(NwIX) := MlTAI_KIZEI(NwIX);  -- 期別更新用変数にセット
                    END IF;
                     -- 個人番号未セット
                    IF NlLOOP_FLG = 0 THEN
                        -- 普徴期別且つ現在期には更正後の世帯主をセット。特徴期別は無条件に賦課期別の個人番号をセット。
                        IF (NwIX <= 13 AND NwIX = i_NwGENZAIKI) THEN
                            MlCAL_NUSI_KOJIN_NO(NwIX) := RlKIHONCAL.NUSHI_KOJIN_NO;  -- 計算基本ＴＢＬ主個人番号
                        ELSE
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);      -- 賦課基本ＴＢＬ主個人番号
                        END IF;
                    END IF;
                END IF;
            END LOOP;
        ELSE
            -- 期別税額がマイナスの場合
            -- 賦課期別の10月～3月に普徴期別が存在した場合は、普徴期別(納期到来)→特徴期別の順で金額調整
            BEGIN
                IF i_NwMODE = c_NMODE_ZEN THEN
                    -- 全体
                    SELECT NVL(SUM(ZEN_ZEIGAKU),0) INTO NwSUMZEIGAKU FROM ZLBTKIBETSU_N
                     WHERE KAMOKU_CD       =  c_NKAMOKU_CD
                       AND KAMOKUS_CD      =  1
                       AND KOKU_SETAI_NO   =  i_NSETAI
                       AND SANTEIDANTAI_CD =  i_NDANTAI
                       AND CHOTEINENDO     =  i_NNENDO
                       AND NENDOBUN        =  i_NNENDO_BUN
                       AND TSUCHI_NO       =  i_NTSUCHI_NO
                       AND RONRIKIBETSU    >= 7
                       AND RONRIKIBETSU    <= 12;
                      -- セーブ値から特徴金額取得
                      -- 全体
                      NwSUMZEIGAKU_TOKU := 0;
                      FOR NwIX IN 20..24 LOOP
                          NwSUMZEIGAKU_TOKU :=  NwSUMZEIGAKU_TOKU + MlKIZEI(NwIX);
                      END LOOP;
                ELSE
                    -- 退職
                    SELECT NVL(SUM(TAI_ZEIGAKU),0) INTO NwSUMZEIGAKU FROM ZLBTKIBETSU_N
                     WHERE KAMOKU_CD       =  c_NKAMOKU_CD
                       AND KAMOKUS_CD      =  1
                       AND KOKU_SETAI_NO   =  i_NSETAI
                       AND SANTEIDANTAI_CD =  i_NDANTAI
                       AND CHOTEINENDO     =  i_NNENDO
                       AND NENDOBUN        =  i_NNENDO_BUN
                       AND TSUCHI_NO       =  i_NTSUCHI_NO
                       AND RONRIKIBETSU    >= 7
                       AND RONRIKIBETSU    <= 12;
                      -- セーブ値から特徴金額取得
                      -- 退職
                      NwSUMZEIGAKU_TOKU := 0;
                      FOR NwIX IN 20..24 LOOP
                          NwSUMZEIGAKU_TOKU :=  NwSUMZEIGAKU_TOKU + MlTAI_KIZEI(NwIX);
                      END LOOP;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    NwRTN := c_NERR;
                    VlMSG := '賦課期別税情報取得エラー(国保世帯番号='||i_NSETAI||')'||SQLERRM;
                    RETURN(NwRTN);
            END;
            -- (10月～3月に普徴の期別データ有りOR 10月～3月に特徴の期別データ無し) AND 年税が0円以上(普徴の期別データよりマイナス)
            IF (NwSUMZEIGAKU > 0 OR NwSUMZEIGAKU_TOKU = 0) AND NwWK_INDEX != 1 THEN
                -- 増減判定用年税額再算出
                IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
--2025/08/12 ZCZL.WANGMING UPDATE 1.1.200.000:子ども子育て支援金対応
--                    NlNENZEI_HAN := NVL(RlKIHONCAL.NENZEI, 0) + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0);
                    NlNENZEI_HAN := NVL(RlKIHONCAL.NENZEI, 0) + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0)+ NVL(RlKDMKIHONCAL.NENZEI, 0);
                ELSE                            -- 退職
                    NlNENZEI_HAN := NVL(RlTAICAL.NENZEI, 0) + NVL(RlKAITAICAL.NENZEI, 0) + NVL(RlSIENTAICAL.NENZEI, 0);
                END IF;
                -- 特徴期別からまず引く
                FOR NwIX IN 14..24 LOOP
                  IF NlNENZEI_HAN < 0 THEN
                      EXIT;
                  ELSE
                      -- 納期設定判定
                      IF MlNOUKI(NwIX) > 0 THEN
                          NwWK_INDEX   := NwIX; --ループ用INDEXの値を保持
                          IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
                              -- 期別金額が有り
                              IF MlKIZEI(NwIX) > 0 THEN
                                 NwWK_ZEIGAKU := NlNENZEI_HAN;                      -- マイナス直前の増減判定用税額をセーブ
                                 NlNENZEI_HAN := NlNENZEI_HAN - MlKIZEI(NwIX);      -- 増減判定用税額-期別金額
                              END IF;
                          ELSE                            -- 退職
                              IF MlTAI_KIZEI(NwIX) > 0 THEN
                                  NwWK_ZEIGAKU := NlNENZEI_HAN;                      -- マイナス直前の増減判定用税額をセーブ
                                  NlNENZEI_HAN := NlNENZEI_HAN - MlTAI_KIZEI(NwIX);  -- 増減判定用税額-期別金額
                              END IF;
                          END IF;
                      END IF;
                  END IF;
                  IF NwIX = 24 THEN
                      -- 特徴期別全てマイナスしても残額有り→普徴期別から引く
                      FOR NwIX2 IN 1..13 LOOP
                        IF NlNENZEI_HAN < 0 THEN
                            EXIT;
                        ELSE
                            -- 納期設定判定
                            IF NwIX2 <i_NwGENZAIKI AND MlNOUKI(NwIX2) > 0 THEN
                                NwWK_INDEX   := NwIX2; --ループ用INDEXの値を保持
                                IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
                                    -- 期別金額が有り
                                    IF MlKIZEI(NwIX2) > 0 THEN
                                        NwWK_ZEIGAKU := NlNENZEI_HAN;                      -- マイナス直前の増減判定用税額をセーブ
                                        NlNENZEI_HAN := NlNENZEI_HAN - MlKIZEI(NwIX2);     -- 増減判定用税額-期別金額
                                    END IF;
                                ELSE                            -- 退職
                                    IF MlTAI_KIZEI(NwIX2) > 0 THEN
                                        NwWK_ZEIGAKU := NlNENZEI_HAN;                      -- マイナス直前の増減判定用税額をセーブ
                                        NlNENZEI_HAN := NlNENZEI_HAN - MlTAI_KIZEI(NwIX2); -- 増減判定用税額-期別金額
                                    END IF;
                                END IF;
                            END IF;
                        END IF;
                      END LOOP;
                  END IF;
                END LOOP;
                IF (NwWK_INDEX >= 1 AND  NwWK_INDEX <= 13) THEN
                    -- 特徴期別は変更なしで普徴期別のみで調整
                    FOR NwIX IN 1..NwWK_INDEX LOOP
                        IF i_NwMODE = c_NMODE_ZEN THEN
                            MlCAL_ZEI(NwIX) := MlKIZEI(NwIX);          -- 期別更新用変数にセット
                        ELSE
                            MlCAL_TAI_ZEI(NwIX) := MlTAI_KIZEI(NwIX);  -- 期別更新用変数にセット
                        END IF;
                        -- 個人番号未セット
                        IF NlLOOP_FLG = 0 THEN
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);     -- 賦課基本ＴＢＬ主個人番号
                        END IF;
                    END LOOP;
                    FOR NwIX IN 14..24 LOOP
                        IF i_NwMODE = c_NMODE_ZEN THEN
                            MlCAL_ZEI(NwIX) := MlKIZEI(NwIX);          -- 期別更新用変数にセット
                        ELSE
                            MlCAL_TAI_ZEI(NwIX) := MlTAI_KIZEI(NwIX);  -- 期別更新用変数にセット
                        END IF;
                        -- 個人番号未セット
                        IF NlLOOP_FLG = 0 THEN
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);     -- 賦課基本ＴＢＬ主個人番号
                        END IF;
                    END LOOP;
                ELSE
                    -- 普徴期別は全て\0で特徴期別で調整
                    FOR NwIX IN 14..NwWK_INDEX LOOP
                        IF i_NwMODE = c_NMODE_ZEN THEN
                            MlCAL_ZEI(NwIX) := MlKIZEI(NwIX);          -- 期別更新用変数にセット
                        ELSE
                            MlCAL_TAI_ZEI(NwIX) := MlTAI_KIZEI(NwIX);  -- 期別更新用変数にセット
                        END IF;
                        -- 個人番号未セット
                        IF NlLOOP_FLG = 0 THEN
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);     -- 賦課基本ＴＢＬ主個人番号
                        END IF;
                    END LOOP;
                END IF;
                -- \0(マイナス)になった期に残額をセット
                IF i_NwMODE = c_NMODE_ZEN THEN
                    MlCAL_ZEI(NwWK_INDEX)     := NwWK_ZEIGAKU;
                ELSE
                    MlCAL_TAI_ZEI(NwWK_INDEX) := NwWK_ZEIGAKU;
                END IF;
                IF NlLOOP_FLG = 0 THEN
                    MlCAL_NUSI_KOJIN_NO(NwWK_INDEX) := MlNUSI_KOJIN_NO(NwWK_INDEX);
                END IF;
                NwNEXT_KIBETSU := NwWK_INDEX + 1;
                -- 残りの期を\0クリア
                IF (NwWK_INDEX >= 1 AND  NwWK_INDEX <= 13) THEN -- 普徴期別のみ
                    FOR NwIX IN NwNEXT_KIBETSU..13 LOOP
                        IF i_NwMODE = c_NMODE_ZEN THEN   -- 全体
                            MlCAL_ZEI(NwIX) := 0;
                            MlIRY_ZEI(NwIX) := 0;
                            MlKAI_ZEI(NwIX) := 0;
                            MlSIEN_ZEI(NwIX) := 0;
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
                            MlKDM_ZEI(NwIX)  := 0;
                        ELSE                             -- 退職
                            MlCAL_TAI_ZEI(NwIX) := 0;
                            MlIRY_TAI_ZEI(NwIX) := 0;
                            MlKAI_TAI_ZEI(NwIX) := 0;
                            MlSIEN_TAI_ZEI(NwIX) := 0;
                        END IF;
                        IF NlLOOP_FLG = 0 THEN           -- 主個人番号未セット
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);
                        END IF;
                    END LOOP;
                ELSE -- 特徴+全普徴期別クリア
                    FOR NwIX IN NwNEXT_KIBETSU..24 LOOP -- 特徴期別クリア
                        IF i_NwMODE = c_NMODE_ZEN THEN   -- 全体
                            MlCAL_ZEI(NwIX) := 0;
                            MlIRY_ZEI(NwIX) := 0;
                            MlKAI_ZEI(NwIX) := 0;
                            MlSIEN_ZEI(NwIX) := 0;
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
                            MlKDM_ZEI(NwIX)  := 0;
                        ELSE                             -- 退職
                            MlCAL_TAI_ZEI(NwIX) := 0;
                            MlIRY_TAI_ZEI(NwIX) := 0;
                            MlKAI_TAI_ZEI(NwIX) := 0;
                            MlSIEN_TAI_ZEI(NwIX) := 0;
                        END IF;
                        IF NlLOOP_FLG = 0 THEN           -- 主個人番号未セット
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);
                        END IF;
                    END LOOP;
                    FOR NwIX IN 1..13 LOOP -- 普徴期別全クリア
                        IF i_NwMODE = c_NMODE_ZEN THEN   -- 全体
                            MlCAL_ZEI(NwIX) := 0;
                            MlIRY_ZEI(NwIX) := 0;
                            MlKAI_ZEI(NwIX) := 0;
                            MlSIEN_ZEI(NwIX) := 0;
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
                            MlKDM_ZEI(NwIX)  := 0;
                        ELSE                             -- 退職
                            MlCAL_TAI_ZEI(NwIX) := 0;
                            MlIRY_TAI_ZEI(NwIX) := 0;
                            MlKAI_TAI_ZEI(NwIX) := 0;
                            MlSIEN_TAI_ZEI(NwIX) := 0;
                        END IF;
                        IF NlLOOP_FLG = 0 THEN           -- 主個人番号未セット
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);
                        END IF;
                    END LOOP;
                END IF;
                NlNENZEI_SV  := 0;
                NlNENZEI_HAN := 0;
            ELSE
                FOR NwIX IN 1..NwWK_INDEX - 1 LOOP -- マイナス直前期までループ
                    IF (NwIX >=14  AND MlNOUKI(NwIX) > 0) OR     -- 特徴期別ＯＲ現在期（-1期）までの、納期月
                       (NwIX <=13 AND NwIX <i_NwGENZAIKI AND MlNOUKI(NwIX) > 0) THEN
                        IF i_NwMODE = c_NMODE_ZEN THEN
                            MlCAL_ZEI(NwIX) := MlKIZEI(NwIX);          -- 期別更新用変数にセット
                        ELSE
                            MlCAL_TAI_ZEI(NwIX) := MlTAI_KIZEI(NwIX);  -- 期別更新用変数にセット
                        END IF;
                        -- 個人番号未セット
                        IF NlLOOP_FLG = 0 THEN
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);     -- 賦課基本ＴＢＬ主個人番号
                        END IF;
                    END IF;
                END LOOP;
                -- \0になった期に残額をセット
                IF i_NwMODE = c_NMODE_ZEN THEN
                    MlCAL_ZEI(NwWK_INDEX)     := NwWK_ZEIGAKU;
                ELSE
                    MlCAL_TAI_ZEI(NwWK_INDEX) := NwWK_ZEIGAKU;
                END IF;
                IF NlLOOP_FLG = 0 THEN
                    -- 現在期別前なら今までの主個人番号をセットする。
                    MlCAL_NUSI_KOJIN_NO(NwWK_INDEX) := MlNUSI_KOJIN_NO(NwWK_INDEX);
                END IF;
                NwNEXT_KIBETSU := NwWK_INDEX + 1;
                -- 残りの期をクリア
                FOR NwIX IN NwNEXT_KIBETSU..24 LOOP
                    IF i_NwMODE = c_NMODE_ZEN THEN   -- 全体
                        MlCAL_ZEI(NwIX) := 0;
                        MlIRY_ZEI(NwIX) := 0;
                        MlKAI_ZEI(NwIX) := 0;
                        MlSIEN_ZEI(NwIX) := 0;
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
                        MlKDM_ZEI(NwIX)  := 0;
                    ELSE                             -- 退職
                        MlCAL_TAI_ZEI(NwIX) := 0;
                        MlIRY_TAI_ZEI(NwIX) := 0;
                        MlKAI_TAI_ZEI(NwIX) := 0;
                        MlSIEN_TAI_ZEI(NwIX) := 0;
                    END IF;
                    IF NlLOOP_FLG = 0 THEN           -- 主個人番号未セット
                        MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);
                    END IF;
                END LOOP;
            END IF;
        END IF;
        IF NlNENZEI_HAN <= 0 THEN
            NwRTN := 1;
        END IF;
        RETURN(NwRTN);
    END funcKiwari20_FUTU;
-------------------------------------------------------------------------------
-- 10 期割処理20
--  1期～現在期までの期割処理
-------------------------------------------------------------------------------
    FUNCTION funcKiwari20(i_NwMODE     IN NUMBER,
                          i_NwGENZAIKI IN NUMBER) RETURN NUMBER IS

        NwRTN               NUMBER(1);
        NwIX                NUMBER(2);
        NwWK_ZEIGAKU        NUMBER;         -- マイナス直前税額
        NwWK_INDEX          NUMBER(2);      -- インデックス保持
        NwNEXT_KIBETSU      NUMBER;         -- 次期別

    BEGIN
        NwRTN        := 0;
        NlNENZEI_HAN := 0;      -- 増減判定用年税額
        NlNENZEI_SV  := 0;      -- 保存用年税額

        -- 増減判定用年税額算出
        IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
--2025/08/12 ZCZL.WANGMING UPDATE 1.1.200.000:子ども子育て支援金対応
--            NlNENZEI_HAN := NVL(RlKIHONCAL.NENZEI, 0) + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0);
            NlNENZEI_HAN := NVL(RlKIHONCAL.NENZEI, 0) + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0)+ NVL(RlKDMKIHONCAL.NENZEI, 0);
        ELSE                            -- 退職
            NlNENZEI_HAN := NVL(RlTAICAL.NENZEI, 0) + NVL(RlKAITAICAL.NENZEI, 0) + NVL(RlSIENTAICAL.NENZEI, 0);
        END IF;

        -- 最終期までで増減判断
        FOR NwIX IN 1..24 LOOP
            IF NlNENZEI_HAN < 0 THEN

                EXIT;

            ELSE

                -- 特徴全期+普徴1期～現在期 かつ 納期設定対象
                IF (NwIX >= 14 AND MlNOUKI(NwIX) > 0) OR
                   (NwIX <= 13 AND NwIX <= i_NwGENZAIKI AND MlNOUKI(NwIX) > 0) THEN
                    NwWK_INDEX   := NwIX;
                    NwWK_ZEIGAKU := NlNENZEI_HAN;

                    IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
                        NlNENZEI_HAN := NlNENZEI_HAN - MlKIZEI(NwIX);
                    ELSE                            -- 退職
                        NlNENZEI_HAN := NlNENZEI_HAN - MlTAI_KIZEI(NwIX);
                    END IF;

                END IF;

            END IF;
        END LOOP;

        -- 期別税額セット
        IF NlNENZEI_HAN >= 0 THEN

            -- 期別税額がプラスの場合(現在期以降で再振分け)
            -- 現在期以降の税額を算出する為、税額をセット
            IF i_NwMODE = c_NMODE_ZEN THEN       -- 全体
--2025/08/12 ZCZL.WANGMING UPDATE 1.1.200.000:子ども子育て支援金対応
--                NlNENZEI_SV := NVL(RlKIHONCAL.NENZEI, 0) + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0);
                NlNENZEI_SV := NVL(RlKIHONCAL.NENZEI, 0) + NVL(RlKAIKIHONCAL.NENZEI, 0) + NVL(RlSIENKIHONCAL.NENZEI, 0)+ NVL(RlKDMKIHONCAL.NENZEI, 0);
            ELSE                                -- 退職
                NlNENZEI_SV := NVL(RlTAICAL.NENZEI, 0) + NVL(RlKAITAICAL.NENZEI, 0) + NVL(RlSIENTAICAL.NENZEI, 0);
            END IF;

            FOR NwIX IN 1..24 LOOP
                -- 特徴全期+普徴1期～現在期-1 かつ 納期設定対象
                IF (NwIX >= 14 AND MlNOUKI(NwIX) > 0) OR
                   (NwIX <= 13 AND NwIX <= i_NwGENZAIKI-1 AND MlNOUKI(NwIX) > 0) THEN

                    IF i_NwMODE = c_NMODE_ZEN THEN  -- 全体
                        MlCAL_ZEI(NwIX) := MlKIZEI(NwIX);
                        NlNENZEI_SV     := NlNENZEI_SV - MlKIZEI(NwIX);
                    ELSE                            -- 退職
                        MlCAL_TAI_ZEI(NwIX) := MlTAI_KIZEI(NwIX);
                        NlNENZEI_SV         := NlNENZEI_SV - MlTAI_KIZEI(NwIX);
                    END IF;

                    IF NlLOOP_FLG = 0 THEN
                        IF NwIX = i_NwGENZAIKI THEN
                            MlCAL_NUSI_KOJIN_NO(NwIX) := RlKIHONCAL.NUSHI_KOJIN_NO;
                        ELSIF NwIX >= 14 AND NwIX-13 >= i_NwGENZAIKI THEN
                            MlCAL_NUSI_KOJIN_NO(NwIX) := RlKIHONCAL.NUSHI_KOJIN_NO;
                        ELSE
                            MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);
                        END IF;
                    END IF;
                END IF;
            END LOOP;

        ELSE

            -- 期別税額がマイナスの場合
            FOR NwIX IN 1..24 LOOP
                IF MlNOUKI(NwIX) > 0 THEN      -- 納期区分

                    IF i_NwMODE = c_NMODE_ZEN THEN
                        MlCAL_ZEI(NwIX) := MlKIZEI(NwIX);
                    ELSE
                        MlCAL_TAI_ZEI(NwIX) := MlTAI_KIZEI(NwIX);
                    END IF;

                    IF NlLOOP_FLG = 0 THEN
                        MlCAL_NUSI_KOJIN_NO(NwIX) := MlNUSI_KOJIN_NO(NwIX);
                    END IF;

                END IF;
            END LOOP;

            -- \0になった期に残額をセット
            IF i_NwMODE = c_NMODE_ZEN THEN
                MlCAL_ZEI(NwWK_INDEX)     := NwWK_ZEIGAKU;
            ELSE
                MlCAL_TAI_ZEI(NwWK_INDEX) := NwWK_ZEIGAKU;
            END IF;
            IF NlLOOP_FLG = 0 THEN
                MlCAL_NUSI_KOJIN_NO(NwWK_INDEX) := RlKIHONCAL.NUSHI_KOJIN_NO;
            END IF;
            NwNEXT_KIBETSU := NwWK_INDEX + 1;

            -- 残りの期をクリア
            FOR NwIX IN NwNEXT_KIBETSU..24 LOOP
                IF i_NwMODE = c_NMODE_ZEN THEN
                    MlCAL_ZEI(NwIX) := 0;
                    MlIRY_ZEI(NwIX) := 0;
                    MlKAI_ZEI(NwIX) := 0;
                    MlSIEN_ZEI(NwIX) := 0;
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
                    MlKDM_ZEI(NwIX)  := 0;
                ELSE
                    MlCAL_TAI_ZEI(NwIX) := 0;
                    MlIRY_TAI_ZEI(NwIX) := 0;
                    MlKAI_TAI_ZEI(NwIX) := 0;
                    MlSIEN_TAI_ZEI(NwIX) := 0;
                END IF;
                IF NlLOOP_FLG = 0 THEN
                    MlCAL_NUSI_KOJIN_NO(NwIX) := RlKIHONCAL.NUSHI_KOJIN_NO;
                END IF;
            END LOOP;
            NlNENZEI_SV  := 0;
            NlNENZEI_HAN := 0;
        END IF;

        IF NlNENZEI_HAN <= 0 THEN
            NwRTN := 1;
        END IF;

        RETURN(NwRTN);

    END funcKiwari20;
-------------------------------------------------------------------------------
-- 09 期割処理30
-------------------------------------------------------------------------------
    PROCEDURE subKiwari30(i_NwMODE     IN NUMBER,
                          i_NwGENZAIKI IN NUMBER) IS

        NwIX                NUMBER(2);
        NwZANKI_CNT         NUMBER(2);      -- 残期数
        NwMAXKI             NUMBER(2);      -- 最大期別
        NwKIZEI_AFT         NUMBER;         -- 処理後期別税額
        NwFLG               NUMBER(1);
        NwLASTKI            NUMBER(2);      -- 最終期別
        NwHASU              NUMBER;         -- 端数
        NwCHOSEIKI          NUMBER(2);      -- 調整期

    BEGIN
        NwZANKI_CNT  := 0;      -- 残期数
        NlNENZEI_HAN := 0;      -- 増減判定用年税額

        -- 納期の最大期別を取得
        NwMAXKI := funcMaxKibetsuGet;   -- 12 最大期別取得

        -- 残期数計算(普通納期以外は1)
        FOR NwIX IN i_NwGENZAIKI..13 LOOP
            IF MlNOUKI(NwIX) IN (1, 2, 3) THEN     -- 納期区分
                NwZANKI_CNT := NwZANKI_CNT + 1;
            END IF;
        END LOOP;
        IF NwZANKI_CNT = 0 THEN
            NwZANKI_CNT := 1;
        END IF;

        -- 端数処理後期別税額セット
        NwFLG       := 0;
        NwKIZEI_AFT := TRUNC((NlNENZEI_SV / NwZANKI_CNT), NlCUT_COL);

        FOR NwIX IN i_NwGENZAIKI..13 LOOP
            IF MlNOUKI(NwIX) IN (1, 2, 3) THEN     -- 納期区分
                IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
                    MlCAL_ZEI(NwIX)     := NwKIZEI_AFT;
                ELSE                                    -- 退職
                    MlCAL_TAI_ZEI(NwIX) := NwKIZEI_AFT;
                END IF;

                IF NlLOOP_FLG = 0 THEN
                    MlCAL_NUSI_KOJIN_NO(NwIX) := RlKIHONCAL.NUSHI_KOJIN_NO;
                END IF;

                NwFLG := 1;
            ELSIF MlNOUKI(NwIX) = 4 THEN           -- 納期区分
                IF NlLOOP_FLG = 0 THEN
                    MlCAL_NUSI_KOJIN_NO(NwIX) := RlKIHONCAL.NUSHI_KOJIN_NO;
                END IF;
            END IF;
        END LOOP;

        -- 最終期別セット 納期区分が1,2,3以外の場合のみ
        IF NwFLG = 0 THEN
            -- 最終期を求める
            NwLASTKI := i_NwGENZAIKI;
            FOR NwIX IN i_NwGENZAIKI..13 LOOP
                IF MlNOUKI(NwIX) = 4 THEN      -- 納期区分
                    EXIT;
                ELSE
                    NwLASTKI := NwLASTKI + 1;
                    IF NwIX = 13 THEN
                        NwLASTKI := NwMAXKI;
                    END IF;
                END IF;
            END LOOP;

            IF NwLASTKI = i_NwGENZAIKI THEN
                -- 随時期で現在の期別税額が変更される場合
                IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
                    MlCAL_ZEI(NwLASTKI)     := NwKIZEI_AFT;
                ELSE                                    -- 退職
                    MlCAL_TAI_ZEI(NwLASTKI) := NwKIZEI_AFT;
                END IF;
            ELSE
                -- 納期がない期は求めた最終期に算出した税額を足しこむ
                IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
                    MlCAL_ZEI(NwLASTKI)     := MlCAL_ZEI(NwLASTKI)     + NwKIZEI_AFT;
                ELSE                                    -- 退職
                    MlCAL_TAI_ZEI(NwLASTKI) := MlCAL_TAI_ZEI(NwLASTKI) + NwKIZEI_AFT;
                END IF;
            END IF;

            IF NlLOOP_FLG = 0 THEN
                MlCAL_NUSI_KOJIN_NO(NwLASTKI) := RlKIHONCAL.NUSHI_KOJIN_NO;
            END IF;
        END IF;

        -- 調整期計算
        NwHASU     := (NlNENZEI_SV - (NwKIZEI_AFT * NwZANKI_CNT));  -- 端数算出
        NwCHOSEIKI := i_NwGENZAIKI;

        FOR NwIX IN i_NwGENZAIKI..13 LOOP
            IF MlNOUKI(NwIX) > 0 THEN      -- 納期区分
                EXIT;
            ELSE
                NwCHOSEIKI := NwCHOSEIKI + 1;
                IF NwCHOSEIKI = 13 THEN
                    NwCHOSEIKI := NwMAXKI;
                END IF;
            END IF;
        END LOOP;

        -- 最終セット(端数の足し込み)
        IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
            MlCAL_ZEI(NwCHOSEIKI) := MlCAL_ZEI(NwCHOSEIKI) + NwHASU;
            IF RlKIHONCAL.GENZON_KBN = 1 THEN       -- 現存区分
                MlCAL_ZEI(NwCHOSEIKI)           := NlNENZEI_SV;
                MlCAL_NUSI_KOJIN_NO(NwCHOSEIKI) := RlKIHONCAL.NUSHI_KOJIN_NO;

                NwCHOSEIKI := NwCHOSEIKI + 1;
                FOR NwIX IN NwCHOSEIKI..13 LOOP
                    MlCAL_ZEI(NwIX) := 0;
                END LOOP;
            END IF;
        ELSE                                    -- 退職
            MlCAL_TAI_ZEI(NwCHOSEIKI) := MlCAL_TAI_ZEI(NwCHOSEIKI) + NwHASU;
            IF RlKIHONCAL.SETAI_KBN = 0 THEN        -- 世帯区分
                MlCAL_TAI_ZEI(NwCHOSEIKI) := NlNENZEI_SV;
                IF NlLOOP_FLG = 0 THEN
                    MlCAL_NUSI_KOJIN_NO(NwCHOSEIKI) := RlKIHONCAL.NUSHI_KOJIN_NO;
                END IF;

                NwCHOSEIKI := NwCHOSEIKI + 1;
                FOR NwIX IN NwCHOSEIKI..13 LOOP
                    MlCAL_TAI_ZEI(NwIX) := 0;
                    IF MlCAL_TAI_ZEI(NwIX) > MlCAL_ZEI(NwIX) THEN
                        NlNENZEI_HAN        := MlCAL_TAI_ZEI(NwIX) - MlCAL_ZEI(NwIX);
                        MlCAL_TAI_ZEI(NwIX) := MlCAL_ZEI(NwIX);
                        IF NwIX < 13 THEN
                            NwCHOSEIKI := NwIX + 1;
                            MlCAL_TAI_ZEI(NwCHOSEIKI) := MlCAL_TAI_ZEI(NwCHOSEIKI) + NlNENZEI_HAN;
                        END IF;
                    END IF;
                END LOOP;
                MlCAL_TAI_ZEI(13) := NlNENZEI_HAN;
            END IF;
        END IF;

    END subKiwari30;
-------------------------------------------------------------------------------
-- 09-1 期割処理40(過年度用)
-------------------------------------------------------------------------------
    PROCEDURE subKiwari40(i_NwMODE     IN NUMBER,
                          i_NwGENZAIKI IN NUMBER) IS


        -- 収納条件取得
        CURSOR CwSHUNOJKNK IS
            SELECT * FROM ZLBTSHUNOJKNK
             WHERE KAMOKU_CD       =  c_NKAMOKU_CD
               AND KAMOKUS_CD      =  c_NKAMOKUS_CD
               AND KIWARIDANTAI_CD =  NlKIWARIDANTAI_CD
               AND DANTAING_KBN    =  0
               AND CHOTEINENDO     =  i_NNENDO
               AND GENNENKANEN_KBN =  c_NKANEN
               AND HYOJIYOKIBETSU  >  0
               AND RONRIKIBETSU    >= i_NwGENZAIKI
             ORDER BY RONRIKIBETSU;

    BEGIN
        -- 現在期以降の最初の納期月に税額をセットする
        FOR RwSHUNOJKNK IN CwSHUNOJKNK LOOP
            IF i_NwMODE = c_NMODE_ZEN THEN          -- 全体
                MlCAL_ZEI(RwSHUNOJKNK.RONRIKIBETSU)     := NlNENZEI_SV;
            ELSE                                    -- 退職
                MlCAL_TAI_ZEI(RwSHUNOJKNK.RONRIKIBETSU) := NlNENZEI_SV;
            END IF;
            EXIT;
        END LOOP;

        NlZO_FLG := 1;

    END subKiwari40;
-------------------------------------------------------------------------------
-- 08 期割処理メイン
-------------------------------------------------------------------------------
    PROCEDURE subKiwariMain(i_NwMODE IN NUMBER) IS
        NwRTN           NUMBER(1);
        NwGENZAIKI      NUMBER(2);
    BEGIN
        NwRTN      := 1;
        NwGENZAIKI := 0;

        IF funcGenzaiKibetsu(i_NwMODE, NwGENZAIKI) = 0 THEN      -- 11 現在期別判定
            -- １期～現在期までの処理
          IF NVL(ZLBPK00010.FCFFJKN2(103),0) = 1 THEN
            NwRTN := funcKiwari20_FUTU(i_NwMODE, NwGENZAIKI);    -- 10 期割処理20(OS版)
          ELSE
            NwRTN := funcKiwari20(i_NwMODE, NwGENZAIKI);         -- 10 期割処理20
          END IF;
        ELSE
            NwRTN := 0;
        END IF;

        IF NwRTN = 0 THEN
            IF i_NNENDO = i_NNENDO_BUN THEN
                -- 現在期～最終期までの処理
                subKiwari30(i_NwMODE, NwGENZAIKI);   -- 09 期割処理30
            ELSE                                    -- 過年
                -- 現在期～最終期までの処理(過年)
                subKiwari40(i_NwMODE, NwGENZAIKI);   -- 09-2 期割処理40
            END IF;
        END IF;

    END subKiwariMain;
-------------------------------------------------------------------------------
-- 07 計算期別セット
-------------------------------------------------------------------------------
    PROCEDURE subCalKibetsuSet(i_NwMODE IN NUMBER) IS
        NwRTN               NUMBER(1);
        NwIX                NUMBER(2);
        NwKIZEI             NUMBER;         -- 期別税額
        NwNUSHI_KOJIN_NO    NUMBER;         -- 主個人番号
        NwGENZAIKI          NUMBER(2);      -- 現在期別
    BEGIN

        FOR NwIX IN 1..24 LOOP
            NwKIZEI          := 0;      -- 期別税額
            NwNUSHI_KOJIN_NO := 0;      -- 主個人番号

            IF MlKIBETSU(NwIX) > 0 THEN
                IF i_NwMODE = c_NMODE_ZEN THEN     -- 全体
                    NwKIZEI := MlKIZEI(NwIX);
                    IF MlNUSI_KOJIN_NO(NwIX) = 0 THEN
                        NwNUSHI_KOJIN_NO := RlKIHONCAL.NUSHI_KOJIN_NO;
                    ELSE
                        NwNUSHI_KOJIN_NO := MlNUSI_KOJIN_NO(NwIX);
                    END IF;
                END IF;
            END IF;

            MlCAL_CHOTEI_NENDO(NwIX)  := i_NNENDO;          -- 計算調定年度
            MlCAL_TSUCHI_NO(NwIX)     := i_NTSUCHI_NO;      -- 計算通知書番号
            IF NwIX < 14 THEN
                MlCAL_KIBETSU(NwIX)   := NwIX;              -- 計算期別(普徴)
            ELSE
                MlCAL_KIBETSU(NwIX)   := NwIX-13;           -- 計算期別(特徴)
            END IF;
            MlCAL_KAMOKUS_CD(NwIX)    := MlKAMOKUS_CD(NwIX);-- 科目詳細コード
            MlCAL_NUSI_KOJIN_NO(NwIX) := NwNUSHI_KOJIN_NO;  -- 計算主個人番号
            MlCAL_ZEI(NwIX)           := NwKIZEI;           -- 計算全体税額
            MlCAL_TAI_ZEI(NwIX)       := MlTAI_KIZEI(NwIX); -- 計算退職税額

        END LOOP;

        NwRTN := funcGenzaiKibetsu(0, NwGENZAIKI);      -- 11 現在期別判定
        FOR NwIX IN NwGENZAIKI..24 LOOP
            MlCAL_NUSI_KOJIN_NO(NwIX) := RlKIHONCAL.NUSHI_KOJIN_NO; -- 計算主個人番号
        END LOOP;

    END subCalKibetsuSet;
-------------------------------------------------------------------------------
-- 06 計算期別更新
-------------------------------------------------------------------------------
    PROCEDURE subInsert IS

        NwIX            NUMBER(2);
        NwSYSDATE       NUMBER(8);
        NwTUKI          NUMBER(2);

        -- 収納条件取得
        CURSOR CwSHUNOJKNK IS
            SELECT * FROM ZLBTSHUNOJKNK
             WHERE KAMOKU_CD       =  c_NKAMOKU_CD
               AND KIWARIDANTAI_CD =  NlKIWARIDANTAI_CD
               AND DANTAING_KBN    =  0
               AND CHOTEINENDO     =  i_NNENDO
               AND GENNENKANEN_KBN =  c_NKANEN
               AND HYOJIYOKIBETSU  >  0
             ORDER BY RONRIKIBETSU;

    BEGIN

        -- システム日付取得
        NwSYSDATE := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD'));

        RlKIBETSUCAL.KAMOKU_CD       := c_NKAMOKU_CD;               -- 科目コード(固定)
        RlKIBETSUCAL.KAMOKUS_CD      := c_NKAMOKUS_CD;              -- 科目詳細コード(固定)
        RlKIBETSUCAL.KOKU_SETAI_NO   := RlKIHONCAL.KOKU_SETAI_NO;   -- 国保世帯番号(固定)
        RlKIBETSUCAL.SANTEIDANTAI_CD := i_NDANTAI;                  -- 算定団体コード(固定)
        RlKIBETSUCAL.KIWARIDANTAI_CD := NlKIWARIDANTAI_CD;          -- 期割団体コード
        RlKIBETSUCAL.DANTAING_KBN    := 0;                          -- 団体内外区分(固定)
        IF i_NNENDO = i_NNENDO_BUN THEN     -- 課税年度と年度分が同じ場合は0
            RlKIBETSUCAL.GENNENKANEN_KBN := 0;                      -- 現年過年区分(現年)
        ELSE
            RlKIBETSUCAL.GENNENKANEN_KBN := 1;                      -- 現年過年区分(過年)
        END IF;
        RlKIBETSUCAL.CHOTEINENDO     := 0;                          -- 調定年度
        RlKIBETSUCAL.NENDOBUN        := i_NNENDO_BUN;               -- 年度分(固定)
        RlKIBETSUCAL.TSUCHI_NO       := 0;                          -- 通知書番号
        RlKIBETSUCAL.RONRIKIBETSU    := 0;                          -- 論理期別
        RlKIBETSUCAL.R_NO            := RlKIHONCAL.R_NO;            -- 履歴番号(固定)
        RlKIBETSUCAL.NENGETSU        := 0;                          -- 年月
        RlKIBETSUCAL.NUSHI_KOJIN_NO  := 0;                          -- 納税義務者個人番号

        IF NVL(i_NKOSEIBI, 0) > 0 THEN
          RlKIBETSUCAL.KOSEI_BI      := i_NKOSEIBI;                 -- 更正日(引数)
        ELSE
          RlKIBETSUCAL.KOSEI_BI      := NwSYSDATE;                  -- 更正日(システム日付)
        END IF;

        RlKIBETSUCAL.ZEN_ZEIGAKU     := 0;                          -- 全体税額
        RlKIBETSUCAL.TAI_ZEIGAKU     := 0;                          -- 退職税額
        RlKIBETSUCAL.IR_ZEN_ZEIGAKU  := 0;                          -- 医療全体税額
        RlKIBETSUCAL.IR_TAI_ZEIGAKU  := 0;                          -- 医療退職税額
        RlKIBETSUCAL.KAI_ZEN_ZEIGAKU := 0;                          -- 介護全体税額
        RlKIBETSUCAL.KAI_TAI_ZEIGAKU := 0;                          -- 介護退職税額
        RlKIBETSUCAL.IR_ZEN_FNKSNGAKU  := 0;                -- 不能欠損額(医療全体)(固定)
        RlKIBETSUCAL.IR_TAI_FNKSNGAKU  := 0;                -- 不能欠損額(医療退職)(固定)
        RlKIBETSUCAL.KAI_ZEN_FNKSNGAKU := 0;                -- 不能欠損額(介護全体)(固定)
        RlKIBETSUCAL.KAI_TAI_FNKSNGAKU := 0;                -- 不能欠損額(介護退職)(固定)
        RlKIBETSUCAL.SYS_SAKUSEIBI       := 0;
        RlKIBETSUCAL.SYS_KOSHINBI        := 0;
        RlKIBETSUCAL.SYS_JIKAN           := 0;
        RlKIBETSUCAL.SYS_SHOKUINKOJIN_NO := '0';
        RlKIBETSUCAL.SYS_TANMATSU_NO     := i_VTANMATSU;
        RlKIBETSUCAL.SIEN_ZEN_ZEIGAKU := 0;                 -- 支援全体税額
        RlKIBETSUCAL.SIEN_TAI_ZEIGAKU := 0;                 -- 支援退職税額
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
        RlKIBETSUCAL.KDM_ZEN_ZEIGAKU  := 0;                 -- 子ども全体税額
        RlKIBETSUCAL.SIEN_ZEN_FNKSNGAKU := 0;               -- 不能欠損額(支援全体)(固定)
        RlKIBETSUCAL.SIEN_TAI_FNKSNGAKU := 0;               -- 不能欠損額(支援退職)(固定)
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
        RlKIBETSUCAL.KDM_ZEN_FNKSNGAKU  := 0;               -- 不能欠損額（子ども全体）(固定)

        -- 現年時 または 過年度時かつ差額減額時はシステム条件の納期区分で出力判定
        IF i_NNENDO = i_NNENDO_BUN OR
           (i_NNENDO <> i_NNENDO_BUN  AND NlZO_FLG = 0) THEN

            -- 期別計算TBLの項目セット
            FOR NwIX IN 1..24 LOOP

                IF MlNOUKI(NwIX) > 0 THEN

                    RlKIBETSUCAL.CHOTEINENDO    := MlCAL_CHOTEI_NENDO(NwIX);    -- 調定年度
                    RlKIBETSUCAL.TSUCHI_NO      := MlCAL_TSUCHI_NO(NwIX);       -- 通知書番号
                    RlKIBETSUCAL.RONRIKIBETSU   := MlCAL_KIBETSU(NwIX);         -- 論理期別
                    RlKIBETSUCAL.KAMOKUS_CD     := MlCAL_KAMOKUS_CD(NwIX);      --科目詳細コード

                    IF MlCAL_KAMOKUS_CD(NwIX) = c_NKAMOKUS_CD THEN  -- 普通徴収
                        IF NwIX < 10 THEN                                       -- 年月
                            RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + (NwIX + 3);
                        ELSIF NwIX <= 13 THEN
                            RlKIBETSUCAL.NENGETSU   := (MlCAL_CHOTEI_NENDO(NwIX) + 1) * 100 + (NwIX - 9);
                        END IF;
                    ELSE
                        CASE NwIX
                          WHEN 14  THEN
                            RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 4;
                          WHEN 16  THEN
                            RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 6;
                          WHEN 18  THEN
                            RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 8;
                          WHEN 20  THEN
                            RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 10;
                          WHEN 22  THEN
                            RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 12;
                          WHEN 24  THEN
                            RlKIBETSUCAL.NENGETSU   := (MlCAL_CHOTEI_NENDO(NwIX) + 1) * 100 + 2;
                        END CASE;
                    END IF;
                       -- 納税義務者個人番号
                    IF MlCAL_NUSI_KOJIN_NO(NwIX) != 0 THEN
                        RlKIBETSUCAL.NUSHI_KOJIN_NO := MlCAL_NUSI_KOJIN_NO(NwIX);
                    ELSE
                        RlKIBETSUCAL.NUSHI_KOJIN_NO := RlKIHONCAL.NUSHI_KOJIN_NO;
                    END IF;
                    RlKIBETSUCAL.ZEN_ZEIGAKU     := MlCAL_ZEI(NwIX);            -- 全体税額
                    RlKIBETSUCAL.TAI_ZEIGAKU     := MlCAL_TAI_ZEI(NwIX);        -- 退職税額
                    RlKIBETSUCAL.IR_ZEN_ZEIGAKU  := MlIRY_ZEI(NwIX);            -- 医療全体税額
                    RlKIBETSUCAL.IR_TAI_ZEIGAKU  := MlIRY_TAI_ZEI(NwIX);        -- 医療退職税額
                    RlKIBETSUCAL.KAI_ZEN_ZEIGAKU := MlKAI_ZEI(NwIX);            -- 介護全体税額
                    RlKIBETSUCAL.KAI_TAI_ZEIGAKU := MlKAI_TAI_ZEI(NwIX);          -- 介護退職税額
                    RlKIBETSUCAL.SIEN_ZEN_ZEIGAKU := MlSIEN_ZEI(NwIX);          -- 支援全体税額
                    RlKIBETSUCAL.SIEN_TAI_ZEIGAKU := MlSIEN_TAI_ZEI(NwIX);      -- 支援退職税額
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
                    RlKIBETSUCAL.KDM_ZEN_ZEIGAKU  := MlKDM_ZEI(NwIX);           -- 子ども全体税額

                   BEGIN
                        INSERT INTO ZLBTKIBETSU_CAL VALUES RlKIBETSUCAL;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NlRTN := c_NERR;
                            VlMSG := 'subInsert 計算期別登録(国保世帯番号='||
                                     i_NSETAI||')'||SQLERRM;
                            EXIT;
                    END;

                END IF;
            END LOOP;

        ELSE
            -- 過年度時かつ差額増額時は収納条件に存在する期すべて出力
            FOR RwSHUNOJKNK IN CwSHUNOJKNK LOOP

                NwIX := RwSHUNOJKNK.RONRIKIBETSU;

                -- 特徴の場合、インデックス+13とする
                IF RwSHUNOJKNK.KAMOKUS_CD = c_NKAMOKUS_CD_2 THEN
                  NwIX := NwIX + 13;
                END IF;

                RlKIBETSUCAL.CHOTEINENDO    := MlCAL_CHOTEI_NENDO(NwIX);    -- 調定年度
                RlKIBETSUCAL.TSUCHI_NO      := MlCAL_TSUCHI_NO(NwIX);       -- 通知書番号
                RlKIBETSUCAL.RONRIKIBETSU   := MlCAL_KIBETSU(NwIX);         -- 論理期別
                RlKIBETSUCAL.KAMOKUS_CD     := MlCAL_KAMOKUS_CD(NwIX);      --科目詳細コード
                IF MlCAL_KAMOKUS_CD(NwIX) = c_NKAMOKUS_CD THEN  -- 普通徴収
                    IF NwIX < 10 THEN                                       -- 年月
                        RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + (NwIX + 3);
                    ELSIF NwIX <= 13 THEN
                        RlKIBETSUCAL.NENGETSU   := (MlCAL_CHOTEI_NENDO(NwIX) + 1) * 100 + (NwIX - 9);
                    END IF;
                ELSE
                    CASE NwIX
                      WHEN 14  THEN
                        RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 4;
                      WHEN 16  THEN
                        RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 6;
                      WHEN 18  THEN
                        RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 8;
                      WHEN 20  THEN
                        RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 10;
                      WHEN 22  THEN
                        RlKIBETSUCAL.NENGETSU   := MlCAL_CHOTEI_NENDO(NwIX) * 100 + 12;
                      WHEN 24  THEN
                        RlKIBETSUCAL.NENGETSU   := (MlCAL_CHOTEI_NENDO(NwIX) + 1) * 100 + 2;
                    END CASE;
                END IF;
                   -- 納税義務者個人番号
                IF MlCAL_NUSI_KOJIN_NO(NwIX) != 0 THEN
                    RlKIBETSUCAL.NUSHI_KOJIN_NO := MlCAL_NUSI_KOJIN_NO(NwIX);
                ELSE
                    RlKIBETSUCAL.NUSHI_KOJIN_NO := RlKIHONCAL.NUSHI_KOJIN_NO;
                END IF;
                RlKIBETSUCAL.ZEN_ZEIGAKU     := MlCAL_ZEI(NwIX);            -- 全体税額
                RlKIBETSUCAL.TAI_ZEIGAKU     := MlCAL_TAI_ZEI(NwIX);        -- 退職税額
                RlKIBETSUCAL.IR_ZEN_ZEIGAKU  := MlIRY_ZEI(NwIX);            -- 医療全体税額
                RlKIBETSUCAL.IR_TAI_ZEIGAKU  := MlIRY_TAI_ZEI(NwIX);        -- 医療退職税額
                RlKIBETSUCAL.KAI_ZEN_ZEIGAKU := MlKAI_ZEI(NwIX);            -- 介護全体税額
                RlKIBETSUCAL.KAI_TAI_ZEIGAKU := MlKAI_TAI_ZEI(NwIX);          -- 介護退職税額
                RlKIBETSUCAL.SIEN_ZEN_ZEIGAKU  := MlSIEN_ZEI(NwIX);          -- 支援全体税額
                RlKIBETSUCAL.SIEN_TAI_ZEIGAKU  := MlSIEN_TAI_ZEI(NwIX);      -- 支援退職税額
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
                RlKIBETSUCAL.KDM_ZEN_ZEIGAKU   := MlKDM_ZEI(NwIX);           -- 子ども全体税額

                BEGIN
                    INSERT INTO ZLBTKIBETSU_CAL VALUES RlKIBETSUCAL;
                EXCEPTION
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlMSG := 'subInsert 計算期別登録(国保世帯番号='||
                                 i_NSETAI||')'||SQLERRM;
                        EXIT;
                END;

            END LOOP;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlMSG := 'subInsert 計算期別登録(国保世帯番号='||
                     i_NSETAI||')'||SQLERRM;
    END subInsert;
-------------------------------------------------------------------------------
-- 05 主処理
-------------------------------------------------------------------------------
    PROCEDURE subMain IS
    BEGIN

        -- 差額により処理をコントロール
        IF (NlSAGAKU     = 0 AND NlTAI_SAGAKU     = 0) AND
           (NlKAI_SAGAKU = 0 AND NlKAI_TAI_SAGAKU = 0) AND
--2025/08/12 ZCZL.WANGMING UPDATE START 1.1.200.000:子ども子育て支援金対応
--           (NlSIEN_SAGAKU = 0 AND NlSIEN_TAI_SAGAKU = 0) THEN
           (NlSIEN_SAGAKU = 0 AND NlSIEN_TAI_SAGAKU = 0) AND
           (NlKDM_SAGAKU = 0) THEN
--2025/08/12 ZCZL.WANGMING UPDATE END
            subCalKibetsuSet(0);    -- 07 計算期別セット  (全体)
            RlKIHONCAL.NENZEI    := NlNENZEI;           -- 全体年税額
            RlTAICAL.NENZEI      := NlTAI_NENZEI;       -- 退職年税額
            RlKAIKIHONCAL.NENZEI := NlKAI_NENZEI;       -- 介護全体年税額
            RlKAITAICAL.NENZEI   := NlKAI_TAI_NENZEI;   -- 介護退職年税額
            RlSIENKIHONCAL.NENZEI := NlSIEN_NENZEI;       -- 支援全体年税額
            RlSIENTAICAL.NENZEI   := NlSIEN_TAI_NENZEI;   -- 支援退職年税額
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
            RlKDMKIHONCAL.NENZEI  := NlKDM_NENZEI;        -- 子ども全体年税額
        ELSE
            IF (NlSAGAKU     > 0 AND NlTAI_SAGAKU     > 0) OR
               (NlKAI_SAGAKU > 0 AND NlKAI_TAI_SAGAKU > 0) OR
               (NlSAGAKU     > 0 AND NlKAI_TAI_SAGAKU > 0) OR
               (NlKAI_SAGAKU > 0 AND NlTAI_SAGAKU     > 0) OR

               (NlSIEN_SAGAKU > 0 AND NlSIEN_TAI_SAGAKU > 0) OR
               (NlSAGAKU     > 0 AND NlSIEN_TAI_SAGAKU  > 0) OR
               (NlKAI_SAGAKU > 0 AND NlSIEN_TAI_SAGAKU  > 0) OR
               (NlSIEN_SAGAKU > 0 AND NlKAI_TAI_SAGAKU  > 0) OR
--2025/08/12 ZCZL.WANGMING UPDATE START 1.1.200.000:子ども子育て支援金対応
--               (NlSIEN_SAGAKU > 0 AND NlTAI_SAGAKU      > 0) THEN
               (NlSIEN_SAGAKU > 0 AND NlTAI_SAGAKU      > 0) OR
               (NlKDM_SAGAKU > 0 AND NlSIEN_TAI_SAGAKU > 0) OR
               (NlKDM_SAGAKU > 0 AND NlKAI_TAI_SAGAKU > 0) OR
                (NlKDM_SAGAKU > 0 AND NlTAI_SAGAKU > 0) THEN
--2025/08/12 ZCZL.WANGMING UPDATE END
                subKiwariMain(0);   -- 08 期割処理メイン  (全体)
                IF i_NJIKKOU_KBN != c_NTEST THEN    -- 「賦課試算」以外
                    NlLOOP_FLG := 1;
                    subKiwariMain(1);   -- 08 期割処理メイン  (退職)
                END IF;
            ELSE
                IF (NlSAGAKU = 0 AND NlTAI_SAGAKU > 0) THEN
                    subCalKibetsuSet(0);    -- 07 計算期別セット  (全体)
                    RlKIHONCAL.NENZEI    := NlNENZEI;           -- 全体年税額
                    RlKAIKIHONCAL.NENZEI := NlKAI_NENZEI;       -- 介護全体年税額
                    RlSIENKIHONCAL.NENZEI := NlSIEN_NENZEI;     -- 支援全体年税額
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
                    RlKDMKIHONCAL.NENZEI  := NlKDM_NENZEI;      -- 子ども全体年税額
                    IF i_NJIKKOU_KBN != c_NTEST THEN    -- 「賦課試算」以外
                        subKiwariMain(1);   -- 08 期割処理メイン  (退職)
                    END IF;
                ELSE
                    IF (NlSAGAKU > 0 AND NlTAI_SAGAKU = 0) THEN
                        IF i_NJIKKOU_KBN != c_NTEST THEN    -- 「賦課試算」以外
                            subCalKibetsuSet(1);    -- 07 計算期別セット  (退職)
                            RlTAICAL.NENZEI      := NlTAI_NENZEI;       -- 退職年税額
                            RlKAITAICAL.NENZEI   := NlKAI_TAI_NENZEI;   -- 介護退職年税額
                            RlSIENTAICAL.NENZEI  := NlSIEN_TAI_NENZEI;  -- 支援退職年税額
                        END IF;
                        subKiwariMain(0);   -- 08 期割処理メイン  (全体)
                    ELSE
                        IF (NlKAI_SAGAKU = 0 AND NlKAI_TAI_SAGAKU > 0) THEN
                            subCalKibetsuSet(0);    -- 07 計算期別セット  (全体)
                            RlKIHONCAL.NENZEI    := NlNENZEI;           -- 全体年税額
                            RlKAIKIHONCAL.NENZEI := NlKAI_NENZEI;       -- 介護全体年税額
                            RlSIENKIHONCAL.NENZEI := NlSIEN_NENZEI;     -- 支援全体年税額
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
                            RlKDMKIHONCAL.NENZEI  := NlKDM_NENZEI;      -- 子ども全体年税額
                            IF i_NJIKKOU_KBN != c_NTEST THEN    -- 「賦課試算」以外
                                subKiwariMain(1);   -- 08 期割処理メイン  (退職)
                            END IF;
                        ELSE
                            IF (NlKAI_SAGAKU > 0 AND NlKAI_TAI_SAGAKU = 0) THEN
                                IF i_NJIKKOU_KBN != c_NTEST THEN    -- 「賦課試算」以外
                                    subCalKibetsuSet(1);    -- 07 計算期別セット  (退職)
                                    RlTAICAL.NENZEI      := NlTAI_NENZEI;       -- 退職年税額
                                    RlKAITAICAL.NENZEI   := NlKAI_TAI_NENZEI;   -- 介護退職年税額
                                    RlSIENTAICAL.NENZEI  := NlSIEN_TAI_NENZEI;  -- 支援退職年税額
                                END IF;
                                subKiwariMain(0);   -- 08 期割処理メイン  (全体)
                            ELSE

                                IF (NlSIEN_SAGAKU = 0 AND NlSIEN_TAI_SAGAKU > 0) THEN
                                    subCalKibetsuSet(0);    -- 07 計算期別セット  (全体)
                                    RlKIHONCAL.NENZEI    := NlNENZEI;           -- 全体年税額
                                    RlKAIKIHONCAL.NENZEI := NlKAI_NENZEI;       -- 介護全体年税額
                                    RlSIENKIHONCAL.NENZEI := NlSIEN_NENZEI;     -- 支援全体年税額
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
                                    RlKDMKIHONCAL.NENZEI  := NlKDM_NENZEI;      -- 子ども全体年税額
                                    IF i_NJIKKOU_KBN != c_NTEST THEN    -- 「賦課試算」以外
                                        subKiwariMain(1);   -- 08 期割処理メイン  (退職)
                                    END IF;
                                ELSE
                                    IF (NlSIEN_SAGAKU > 0 AND NlSIEN_TAI_SAGAKU = 0) THEN
                                        IF i_NJIKKOU_KBN != c_NTEST THEN    -- 「賦課試算」以外
                                            subCalKibetsuSet(1);    -- 07 計算期別セット  (退職)
                                            RlTAICAL.NENZEI      := NlTAI_NENZEI;       -- 退職年税額
                                            RlKAITAICAL.NENZEI   := NlKAI_TAI_NENZEI;   -- 介護退職年税額
                                            RlSIENTAICAL.NENZEI  := NlSIEN_TAI_NENZEI;  -- 支援退職年税額
                                        END IF;
                                        subKiwariMain(0);   -- 08 期割処理メイン  (全体)
                                    ELSE
--2025/08/12 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
                                      IF (NlKDM_SAGAKU > 0) THEN
                                         IF i_NJIKKOU_KBN != c_NTEST THEN    -- 「賦課試算」以外
                                           subCalKibetsuSet(1);    -- 07 計算期別セット  (退職)
                                           RlTAICAL.NENZEI      := NlTAI_NENZEI;       -- 退職年税額
                                           RlKAITAICAL.NENZEI   := NlKAI_TAI_NENZEI;   -- 介護退職年税額
                                           RlSIENTAICAL.NENZEI  := NlSIEN_TAI_NENZEI;  -- 支援退職年税額
                                         END IF;
                                         subKiwariMain(0);   -- 08 期割処理メイン  (全体)
                                      ELSE
--2025/08/12 ZCZL.WANGMING ADD END
                                        subKiwariMain(0);   -- 08 期割処理メイン  (全体)
                                        IF i_NJIKKOU_KBN != c_NTEST THEN    -- 「賦課試算」以外
                                            NlLOOP_FLG := 1;
                                            subKiwariMain(1);   -- 08 期割処理メイン  (退職)
                                        END IF;
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
                                      END IF;
                                    END IF;
                                END IF;
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END IF;
        END IF;

    END subMain;
-------------------------------------------------------------------------------
-- 04-2 賦課試算用 ワークエリア退避
-------------------------------------------------------------------------------
    PROCEDURE subWorkSaveTS IS
        NwIX                NUMBER(2);

        -- 更正前期別(賦課試算)カーソル
        CURSOR CwKIBETSU IS
            SELECT * FROM ZLBTKIBETSU_TS
             WHERE SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
               AND CHOTEINENDO     = i_NNENDO               -- 調定年度
               AND NENDOBUN        = i_NNENDO_BUN           -- 年度分
               AND TSUCHI_NO       = i_NTSUCHI_NO           -- 通知書番号
               AND SYS_TANMATSU_NO = i_VTANMATSU;
    BEGIN

        -- 更正前基本(賦課試算)取得
        BEGIN
            SELECT NENZEI, GENMEN INTO NlNENZEI, NlGENMEN
              FROM ZLBTKIHON_TS
             WHERE SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
               AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
               AND NENDO_BUN       = i_NNENDO_BUN           -- 年度分
               AND TSUCHI_NO       = i_NTSUCHI_NO           -- 通知書番号
               AND SYS_TANMATSU_NO = i_VTANMATSU;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subWorkSaveTS 更正前基本取得(国保世帯番号='||
                         i_NSETAI||')'||SQLERRM;
        END;

        -- 更正前介護基本(賦課試算)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI INTO NlKAI_NENZEI
                  FROM ZLBTKAI_KIHON_TS
                 WHERE SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN           -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO           -- 通知書番号
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSaveTS 更正前介護基本取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;

        -- 更正前支援基本(賦課試算)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI INTO NlSIEN_NENZEI
                  FROM ZLBTSIEN_KIHON_TS
                 WHERE SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN           -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO           -- 通知書番号
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSaveTS 更正前支援基本取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;

--2025/08/12 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
        -- 更正前子ども基本(賦課試算)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI INTO NlKDM_NENZEI
                  FROM ZLBTKDM_KIHON_TS
                 WHERE SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN    -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO;   -- 通知書番号
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSaveTS 更正前子ども基本取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
--2025/08/12 ZCZL.WANGMING ADD END

        -- 更正前期別(賦課試算)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                FOR RwKIBETSU IN CwKIBETSU LOOP
                    NwIX := RwKIBETSU.RONRIKIBETSU;

                    -- 特徴の場合、インデックス+13とする
                    IF RwKIBETSU.KAMOKUS_CD = c_NKAMOKUS_CD_2 THEN
                      NwIX := NwIX + 13;
                    END IF;

                    MlKIBETSU(NwIX)       := RwKIBETSU.RONRIKIBETSU;      -- 期別
                    MlKAMOKUS_CD(NwIX)    := RwKIBETSU.KAMOKUS_CD;        --科目詳細コード
                    MlKIZEI(NwIX)         := RwKIBETSU.ZEN_ZEIGAKU;       -- 期別税額
                    MlTAI_KIZEI(NwIX)     := RwKIBETSU.TAI_ZEIGAKU;       -- 退期別税額
                    MlNUSI_KOJIN_NO(NwIX) := RwKIBETSU.NUSHI_KOJIN_NO;    -- 主個人番号
                    MlIRY_ZEI(NwIX)       := RwKIBETSU.IR_ZEN_ZEIGAKU;    -- 医療全体税額
                    MlIRY_TAI_ZEI(NwIX)   := RwKIBETSU.IR_TAI_ZEIGAKU;    -- 医療退職税額
                    MlKAI_ZEI(NwIX)       := RwKIBETSU.KAI_ZEN_ZEIGAKU;   -- 介護全体税額
                    MlKAI_TAI_ZEI(NwIX)   := RwKIBETSU.KAI_TAI_ZEIGAKU;   -- 介護退職税額
                    MlSIEN_ZEI(NwIX)      := RwKIBETSU.SIEN_ZEN_ZEIGAKU;  -- 支援全体税額
                    MlSIEN_TAI_ZEI(NwIX)  := RwKIBETSU.SIEN_TAI_ZEIGAKU;  -- 支援退職税額
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
                    MlKDM_ZEI(NwIX)       := RwKIBETSU.KDM_ZEN_ZEIGAKU;   -- 子ども全体税額

                END LOOP;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSaveTS 更正前期別取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;

        IF NlRTN = c_NOK THEN
            -- 差額算出(医療全体,医療退職(0),介護全体,介護退職(0))
            NlSAGAKU         := ABS(NlNENZEI     - RlKIHONCAL.NENZEI);
            NlTAI_SAGAKU     := 0;
            NlKAI_SAGAKU     := ABS(NlKAI_NENZEI - RlKAIKIHONCAL.NENZEI);
            NlKAI_TAI_SAGAKU := 0;
            NlSIEN_SAGAKU     := ABS(NlSIEN_NENZEI - RlSIENKIHONCAL.NENZEI);
            NlSIEN_TAI_SAGAKU := 0;
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
            NlKDM_SAGAKU      := ABS(NlKDM_NENZEI - RlKDMKIHONCAL.NENZEI);

        END IF;

    END subWorkSaveTS;
-------------------------------------------------------------------------------
-- 04-1 ワークエリア退避
-------------------------------------------------------------------------------
    PROCEDURE subWorkSave IS

        NwIX                NUMBER(2);

        -- 賦課期別(最新)カーソル
        CURSOR CwKIBETSU IS
            SELECT * FROM ZLBTKIBETSU_N
             WHERE SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
               AND CHOTEINENDO     = i_NNENDO        -- 調定年度
               AND NENDOBUN        = i_NNENDO_BUN           -- 年度分
               AND TSUCHI_NO       = i_NTSUCHI_NO;          -- 通知書番号

    BEGIN

        -- 賦課基本(最新)取得
        BEGIN
            SELECT NENZEI, GENMEN INTO NlNENZEI, NlGENMEN
              FROM ZLBTKIHON_N
             WHERE SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
               AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
               AND NENDO_BUN       = i_NNENDO_BUN           -- 年度分
               AND TSUCHI_NO       = i_NTSUCHI_NO;          -- 通知書番号
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subWorkSave 賦課基本(最新)取得(国保世帯番号='||
                         i_NSETAI||')'||SQLERRM;
        END;

        -- 賦課退職(最新)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI, GENMEN INTO NlTAI_NENZEI, NlTAI_GENMEN
                  FROM ZLBTTAI_N
                 WHERE SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN           -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO;          -- 通知書番号
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSave 賦課退職(最新)取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;

        -- 賦課介護基本(最新)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI INTO NlKAI_NENZEI
                  FROM ZLBTKAI_KIHON_N
                 WHERE SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN           -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO;          -- 通知書番号
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSave 賦課介護基本(最新)取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;

        -- 賦課介護退職(最新)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI INTO NlKAI_TAI_NENZEI
                  FROM ZLBTKAI_TAI_N
                 WHERE SANTEIDANTAI_CD = i_NDANTAI     -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN           -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO;          -- 通知書番号
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSave 賦課介護退職(最新)取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;

        -- 賦課支援基本(最新)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI INTO NlSIEN_NENZEI
                  FROM ZLBTSIEN_KIHON_N
                 WHERE SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN    -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO;   -- 通知書番号
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSave 賦課支援基本(最新)取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;

        -- 賦課支援退職(最新)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI INTO NlSIEN_TAI_NENZEI
                  FROM ZLBTSIEN_TAI_N
                 WHERE SANTEIDANTAI_CD = i_NDANTAI      -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO       -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN   -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO;  -- 通知書番号
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSave 賦課支援退職(最新)取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;

--2025/08/12 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
        -- 賦課子ども基本(最新)取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT NENZEI INTO NlKDM_NENZEI
                  FROM ZLBTKDM_KIHON_N
                 WHERE SANTEIDANTAI_CD = i_NDANTAI       -- 算定団体コード
                   AND CHOTEI_NENDO    = i_NNENDO        -- 調定年度
                   AND NENDO_BUN       = i_NNENDO_BUN    -- 年度分
                   AND TSUCHI_NO       = i_NTSUCHI_NO;   -- 通知書番号
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSave 賦課子ども基本(最新)取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
--2025/08/12 ZCZL.WANGMING ADD END

        -- 賦課期別取得
        IF NlRTN = c_NOK THEN
            BEGIN
                FOR RwKIBETSU_N IN CwKIBETSU LOOP
                    NwIX := RwKIBETSU_N.RONRIKIBETSU;

                    -- 特徴の場合、インデックス+13とする
                    IF RwKIBETSU_N.KAMOKUS_CD = c_NKAMOKUS_CD_2 THEN
                      NwIX := NwIX + 13;
                    END IF;

                    MlKIBETSU(NwIX)       := RwKIBETSU_N.RONRIKIBETSU;      -- 期別
                    MlKAMOKUS_CD(NwIX)    := RwKIBETSU_N.KAMOKUS_CD;        --科目詳細コード
                    MlKIZEI(NwIX)         := RwKIBETSU_N.ZEN_ZEIGAKU;       -- 期別税額
                    MlTAI_KIZEI(NwIX)     := RwKIBETSU_N.TAI_ZEIGAKU;       -- 退期別税額
                    MlNUSI_KOJIN_NO(NwIX) := RwKIBETSU_N.NUSHI_KOJIN_NO;    -- 主個人番号
                    MlIRY_ZEI(NwIX)       := RwKIBETSU_N.IR_ZEN_ZEIGAKU;    -- 医療全体税額
                    MlIRY_TAI_ZEI(NwIX)   := RwKIBETSU_N.IR_TAI_ZEIGAKU;    -- 医療退職税額
                    MlKAI_ZEI(NwIX)       := RwKIBETSU_N.KAI_ZEN_ZEIGAKU;   -- 介護全体税額
                    MlKAI_TAI_ZEI(NwIX)   := RwKIBETSU_N.KAI_TAI_ZEIGAKU;   -- 介護退職税額
                    MlSIEN_ZEI(NwIX)      := RwKIBETSU_N.SIEN_ZEN_ZEIGAKU;  -- 支援全体税額
                    MlSIEN_TAI_ZEI(NwIX)  := RwKIBETSU_N.SIEN_TAI_ZEIGAKU;  -- 支援退職税額
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
                    MlKDM_ZEI(NwIX)       := RwKIBETSU_N.KDM_ZEN_ZEIGAKU;  -- 子ども全体税額
                END LOOP;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subWorkSave 賦課期別(最新)取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;

        IF NlRTN = c_NOK THEN
            -- 差額算出(医療全体,医療退職,介護全体,介護退職)
            NlSAGAKU         := ABS(NlNENZEI     - RlKIHONCAL.NENZEI);
            NlTAI_SAGAKU     := ABS(NlTAI_NENZEI - RlTAICAL.NENZEI);
            NlKAI_SAGAKU     := ABS(NlKAI_NENZEI - RlKAIKIHONCAL.NENZEI);
            NlKAI_TAI_SAGAKU := ABS(NlKAI_TAI_NENZEI - RlKAITAICAL.NENZEI);
            NlSIEN_SAGAKU     := ABS(NlSIEN_NENZEI - RlSIENKIHONCAL.NENZEI);
            NlSIEN_TAI_SAGAKU := ABS(NlSIEN_TAI_NENZEI - RlSIENTAICAL.NENZEI);
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
            NlKDM_SAGAKU     := ABS(NlKDM_NENZEI - RlKDMKIHONCAL.NENZEI);
        END IF;
    END subWorkSave;
-------------------------------------------------------------------------------
-- 03 計算TBL取得
-------------------------------------------------------------------------------
    PROCEDURE subKihonSel IS
    BEGIN

        -- 計算基本取得
        BEGIN
            SELECT * INTO RlKIHONCAL FROM ZLBTKIHON_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND CHOTEI_NENDO    = i_NNENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NTSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'subKihonSel 計算基本取得(国保世帯番号='||
                         i_NSETAI ||')'||SQLERRM;
        END;

        -- 計算退職取得
        IF NlRTN = c_NOK AND i_NJIKKOU_KBN != c_NTEST THEN          -- 「賦課試算」以外の場合
            BEGIN
                SELECT * INTO RlTAICAL FROM ZLBTTAI_CAL
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                   AND SANTEIDANTAI_CD = i_NDANTAI
                   AND CHOTEI_NENDO    = i_NNENDO
                   AND NENDO_BUN       = i_NNENDO_BUN
                   AND TSUCHI_NO       = i_NTSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subKihonSel 計算退職取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;

        -- 計算介護基本取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT * INTO RlKAIKIHONCAL FROM ZLBTKAI_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                   AND SANTEIDANTAI_CD = i_NDANTAI
                   AND CHOTEI_NENDO    = i_NNENDO
                   AND NENDO_BUN       = i_NNENDO_BUN
                   AND TSUCHI_NO       = i_NTSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subKihonSel 計算介護基本取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;

        -- 計算介護退職取得
        IF NlRTN = c_NOK AND i_NJIKKOU_KBN != c_NTEST THEN          -- 「賦課試算」以外の場合
            BEGIN
                SELECT * INTO RlKAITAICAL FROM ZLBTKAI_TAI_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND CHOTEI_NENDO    = i_NNENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NTSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subKihonSel 計算介護退職取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;

        -- 計算支援基本取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT * INTO RlSIENKIHONCAL FROM ZLBTSIEN_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                   AND SANTEIDANTAI_CD = i_NDANTAI
                   AND CHOTEI_NENDO    = i_NNENDO
                   AND NENDO_BUN       = i_NNENDO_BUN
                   AND TSUCHI_NO       = i_NTSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subKihonSel 計算支援基本取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;

        -- 計算介護退職取得
        IF NlRTN = c_NOK AND i_NJIKKOU_KBN != c_NTEST THEN          -- 「賦課試算」以外の場合
            BEGIN
                SELECT * INTO RlSIENTAICAL FROM ZLBTSIEN_TAI_CAL
             WHERE KOKU_SETAI_NO   = i_NSETAI
               AND SANTEIDANTAI_CD = i_NDANTAI
               AND CHOTEI_NENDO    = i_NNENDO
               AND NENDO_BUN       = i_NNENDO_BUN
               AND TSUCHI_NO       = i_NTSUCHI_NO
               AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subKihonSel 計算支援退職取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
--2025/08/12 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
        -- 計算子ども基本取得
        IF NlRTN = c_NOK THEN
            BEGIN
                SELECT * INTO RlKDMKIHONCAL FROM ZLBTKDM_KIHON_CAL
                 WHERE KOKU_SETAI_NO   = i_NSETAI
                   AND SANTEIDANTAI_CD = i_NDANTAI
                   AND CHOTEI_NENDO    = i_NNENDO
                   AND NENDO_BUN       = i_NNENDO_BUN
                   AND TSUCHI_NO       = i_NTSUCHI_NO
                   AND SYS_TANMATSU_NO = i_VTANMATSU;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlMSG := 'subKihonSel 計算子ども基本取得(国保世帯番号='||
                             i_NSETAI||')'||SQLERRM;
            END;
        END IF;
--2025/08/12 ZCZL.WANGMING ADD END

    END subKihonSel;
-------------------------------------------------------------------------------
-- 02 システム条件取得
-------------------------------------------------------------------------------
    PROCEDURE subJokenSel IS

        NwFUKI_KAZEI        ZLBTJOKEN.FUKI_KAZEI%TYPE;
        RwJOKEN             ZLBTJOKEN%ROWTYPE;

    BEGIN

        -- システム条件より不均一課税を取得(年度分)
        SELECT FUKI_KAZEI INTO NwFUKI_KAZEI FROM ZLBTJOKEN
         WHERE NENDO            = i_NNENDO_BUN
           AND SANTEIDANTAI_CD  = c_NDANTAI;

        -- 不均一課税か否か
        IF NwFUKI_KAZEI = c_NFKAZEI THEN        -- 不均一課税を行なう
            -- 算定団体コード
            NlKIWARIDANTAI_CD := i_NDANTAI;     -- ﾊﾟﾗﾒｰﾀの算定団体コード
        ELSE
            NlKIWARIDANTAI_CD := c_NDANTAI;     -- 合併後の算定団体コード
        END IF;

        -- システム条件より端数、納期区分を取得(年度分)
        SELECT * INTO RwJOKEN FROM ZLBTJOKEN
          WHERE NENDO           = i_NNENDO_BUN
            AND SANTEIDANTAI_CD = NlKIWARIDANTAI_CD;

        -- 月次端数処理の保存
        CASE RwJOKEN.TSUKIWARI_HASU
            WHEN c_NHASU_KBN_2  THEN NlCUT_COL := c_NHASU_2;       -- 100単位
            WHEN c_NHASU_KBN_1  THEN NlCUT_COL := c_NHASU_1;       -- 1000単位
            WHEN c_NHASU_KBN_3  THEN NlCUT_COL := c_NHASU_3;       -- 行なわない
            WHEN c_NHASU_KBN_10 THEN NlCUT_COL := c_NHASU_10;      --10単位
            ELSE NULL;
        END CASE;

        IF i_NNENDO = i_NNENDO_BUN THEN
          -- 納期区分の保存
          MlNOUKI(1)  := RwJOKEN.NOKI_1;      -- 納期4月
          MlNOUKI(2)  := RwJOKEN.NOKI_2;      -- 納期5月
          MlNOUKI(3)  := RwJOKEN.NOKI_3;      -- 納期6月
          MlNOUKI(4)  := RwJOKEN.NOKI_4;      -- 納期7月
          MlNOUKI(5)  := RwJOKEN.NOKI_5;      -- 納期8月
          MlNOUKI(6)  := RwJOKEN.NOKI_6;      -- 納期9月
          MlNOUKI(7)  := RwJOKEN.NOKI_7;      -- 納期10月
          MlNOUKI(8)  := RwJOKEN.NOKI_8;      -- 納期11月
          MlNOUKI(9)  := RwJOKEN.NOKI_9;      -- 納期12月
          MlNOUKI(10) := RwJOKEN.NOKI_10;     -- 納期1月
          MlNOUKI(11) := RwJOKEN.NOKI_11;     -- 納期2月
          MlNOUKI(12) := RwJOKEN.NOKI_12;     -- 納期3月
          MlNOUKI(13) := RwJOKEN.NOKI_13;     -- 納期4月
          -- 特徴納期区分の設定
          MlNOUKI(14)  := c_NNOUKI_3;          -- 納期4月
          MlNOUKI(15)  := c_NNOUKI_0;          -- 納期5月
          MlNOUKI(16)  := c_NNOUKI_3;          -- 納期6月
          MlNOUKI(17)  := c_NNOUKI_0;          -- 納期7月
          MlNOUKI(18)  := c_NNOUKI_3;          -- 納期8月
          MlNOUKI(19)  := c_NNOUKI_0;          -- 納期9月
          MlNOUKI(20)  := c_NNOUKI_3;          -- 納期10月
          MlNOUKI(21)  := c_NNOUKI_0;          -- 納期11月
          MlNOUKI(22)  := c_NNOUKI_3;          -- 納期12月
          MlNOUKI(23)  := c_NNOUKI_0;          -- 納期1月
          MlNOUKI(24)  := c_NNOUKI_3;          -- 納期2月
    END IF;

    EXCEPTION
        WHEN OTHERS THEN
           NlRTN := c_NERR;
           VlMSG := 'subJokenSel システム条件取得(国保世帯番号='||
                    i_NSETAI||')'||SQLERRM;
    END subJokenSel;

-------------------------------------------------------------------------------
-- 02 収納条件期別条件取得
-------------------------------------------------------------------------------
    PROCEDURE subGetNouki IS

    -- 収納条件期別
      Cursor CwSHUNOJKNK Is
        Select RONRIKIBETSU,HYOJIYOKIBETSU,KAMOKUS_CD From ZLBTSHUNOJKNK
        Where KAMOKU_CD     = c_NKAMOKU_CD
          AND KIWARIDANTAI_CD =  NlKIWARIDANTAI_CD
          AND DANTAING_KBN    =  0
          And CHOTEINENDO   = i_NNENDO
          And GENNENKANEN_KBN = c_NKANEN
         Order By RONRIKIBETSU;

    NwIX NUMBER;
  BEGIN
        NlRTN := 0;

    --ループ
    For CwSHUNOJKNKRec IN CwSHUNOJKNK Loop
      NwIX := CwSHUNOJKNKRec.RONRIKIBETSU;

      -- 特徴の場合、インデックス+13とする
      IF CwSHUNOJKNKRec.KAMOKUS_CD = c_NKAMOKUS_CD_2 THEN
        NwIX := NwIX + 13;
      END IF;

          -- 表示用期別の保存
          MlNOUKI(NwIX)  := CwSHUNOJKNKRec.HYOJIYOKIBETSU;
    END Loop;

    EXCEPTION
        WHEN OTHERS THEN
           NlRTN := c_NERR;
           VlMSG := 'subGetNouki 収納条件取得(国保世帯番号='||
                    i_NSETAI||')'||SQLERRM;
  END;
-------------------------------------------------------------------------------
-- 01 初期化
-------------------------------------------------------------------------------
    PROCEDURE subInit IS

        NwIX                NUMBER(2);

    BEGIN

        NlNENZEI            := 0;           -- 年税額
        NlGENMEN            := 0;           -- 減免額
        NlTAI_NENZEI        := 0;           -- 退年税額
        NlTAI_GENMEN        := 0;           -- 退減免額
        NlKAI_NENZEI        := 0;           -- 介護年税額
        NlKAI_TAI_NENZEI    := 0;           -- 介護退年税額
        NlNENZEI_SV         := 0;           -- 保存用年税額
        NlSAGAKU            := 0;           -- 差額
        NlTAI_SAGAKU        := 0;           -- 退差額
        NlKAI_SAGAKU        := 0;           -- 介護差額
        NlKAI_TAI_SAGAKU    := 0;           -- 介護退差額
        NlSIEN_NENZEI       := 0;           -- 支援年税額
        NlSIEN_TAI_NENZEI   := 0;           -- 支援退年税額
        NlSIEN_SAGAKU       := 0;           -- 支援差額
        NlSIEN_TAI_SAGAKU   := 0;           -- 支援退差額
--2025/08/12 ZCZL.WANGMING ADD START 1.1.200.000:子ども子育て支援金対応
        NlKDM_NENZEI        := 0;           --子ども年税額
        NlKDM_SAGAKU        := 0;           --子ども差額
--2025/08/12 ZCZL.WANGMING ADD END

        NlLOOP_FLG          := 0;
        NlCUT_COL           := 0;

        NlZO_FLG            := 0;

        FOR NwIX IN 1..24 LOOP
            MlNOUKI(NwIX)               := 0;       -- 納期区分
            -- 賦課期別用ワーク
            MlKIBETSU(NwIX)             := 0;       -- 期別
            MlIRY_ZEI(NwIX)             := 0;       -- 医療全体税額
            MlIRY_TAI_ZEI(NwIX)         := 0;       -- 医療退職税額
            MlKAI_ZEI(NwIX)             := 0;       -- 介護全体税額
            MlKAI_TAI_ZEI(NwIX)         := 0;       -- 介護退職税額
            MlSIEN_ZEI(NwIX)             := 0;      -- 支援全体税額
            MlSIEN_TAI_ZEI(NwIX)         := 0;      -- 支援退職税額
--2025/08/12 ZCZL.WANGMING ADD 1.1.200.000:子ども子育て支援金対応
            MlKDM_ZEI(NwIX)              := 0;      -- 子ども全体税額
            MlKIZEI(NwIX)               := 0;       -- 期別税額
            MlTAI_KIZEI(NwIX)           := 0;       -- 退期別税額
            MlNUSI_KOJIN_NO(NwIX)       := 0;       -- 主個人番号
            IF NwIX < 14 THEN
                MlKAMOKUS_CD(NwIX)	:= c_NKAMOKUS_CD;   -- 科目詳細コード(普徴)
            ELSE
                MlKAMOKUS_CD(NwIX)	:= c_NKAMOKUS_CD_2; -- 科目詳細コード(特徴)
            END IF;
            -- 計算期別用ワーク
            MlCAL_CHOTEI_NENDO(NwIX)    := i_NNENDO;        -- 計算調定年度
            MlCAL_NENDO_BUN(NwIX)       := i_NNENDO_BUN;    -- 計算年度分
            MlCAL_TSUCHI_NO(NwIX)       := i_NTSUCHI_NO;    -- 計算通知書番号
            IF NwIX < 14 THEN
                MlCAL_KIBETSU(NwIX)     := NwIX;            -- 計算期別(普徴)
            ELSE
                MlCAL_KIBETSU(NwIX)     := NwIX-13;         -- 計算期別(特徴)
            END IF;
            MlCAL_NUSI_KOJIN_NO(NwIX)   := 0;               -- 計算主個人番号
            MlCAL_ZEI(NwIX)             := 0;               -- 計算全体税額
            MlCAL_TAI_ZEI(NwIX)         := 0;               -- 計算退職税額
            MlCAL_NOUFU_KBN(NwIX)       := 0;               -- 計算納付書区分
            IF NwIX < 14 THEN
                MlCAL_KAMOKUS_CD(NwIX)  := c_NKAMOKUS_CD;   -- 計算科目詳細コード(普徴)
            ELSE
                MlCAL_KAMOKUS_CD(NwIX)  := c_NKAMOKUS_CD_2; -- 計算科目詳細コード(特徴)
            END IF;
        END LOOP;

    END subInit;
-------------------------------------------------------------------------------
-- 00 メイン
-------------------------------------------------------------------------------
BEGIN
    NlRTN := 0;
    VlMSG := NULL;

----- 初期処理 -----
    subInit;                        -- 01 初期化

    subJokenSel;                    -- 02 システム条件取得

    IF NlRTN = c_NOK THEN
    -- 過年
        IF i_NNENDO <> i_NNENDO_BUN THEN
          subGetNouki;            -- 02 収納条件期別取得
        END IF;
    END IF;

    IF NlRTN = c_NOK THEN
        subKihonSel;                -- 03 計算テーブル取得
    END IF;

    IF NlRTN = c_NOK THEN
        IF i_NJIKKOU_KBN != c_NTEST THEN    -- 実行区分が「賦課試算」以外

            subWorkSave;        -- 04-1 ワークエリア退避

        ELSE                                -- 実行区分が「賦課試算」

            subWorkSaveTS;      -- 04-2 賦課試算用 ワークエリア退避

        END IF;
    END IF;

----- 主処理 -----
    IF NlRTN = c_NOK THEN
        subMain;                    -- 05 主処理
    END IF;

    IF NlRTN = c_NOK THEN
        subInsert;                  -- 06 計算期別更新
    END IF;

----- 終了処理 -----
    IF NlRTN = c_NOK THEN       -- 正常
        BEGIN
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlMSG := 'COMMIT発行(国保世帯番号='||i_NSETAI||')'||SQLERRM;
        END;
    END IF;

    IF NlRTN != c_NOK THEN      -- 異常
        BEGIN
            ROLLBACK;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
    END IF;

    -- ログ出力
    IF NlRTN != c_NOK AND VlMSG IS NOT NULL THEN
        IF i_NJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時

            BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSKCALKWPASS', 1, '', '','ZLBSKCALKW ' || VlMSG, '', i_VTANMATSU);

        ELSIF i_NTRENBAN = -1 THEN

            -- テストの時のみ有効
            DBMS_OUTPUT.PUT_LINE('ZLBSKCALKW ' || VlMSG);

        END IF;
    END IF;

    o_NRESULT := NlRTN;

END ZLBSKCALKWPASS;
/
