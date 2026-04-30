CREATE OR REPLACE PROCEDURE ZLBSKCALSHK(i_NCHOTEI_NENDO       IN  NUMBER,
--1.1.200.000
                                          i_NNENDO_BUN          IN  NUMBER,
                                          i_NKOKU_SETAI_NO      IN  NUMBER,
                                          i_NKOJIN_NO           IN  NUMBER,
                                          i_NFUKA_KIJITSU       IN  NUMBER,
                                          i_NKIJUN_NENGAPPI     IN  NUMBER,
                                          i_NJIKKOU_KBN         IN  NUMBER,
                                          i_VMASIN_NO           IN  NVARCHAR2,
                                          i_NTRENBAN            IN  NUMBER,
--2025/10/05 JSFIT.MORI Update Start 1.0.802.001:QA18011 基盤安定処理時は産前産後均等割減額をしない対応
--                                          o_NRESULT             OUT NUMBER)
                                          o_NRESULT             OUT NUMBER,
                                          i_JOKEN_KBN3          IN NUMBER DEFAULT 0)
--2025/10/05 JSFIT.MORI Update End
-------------------------------------------------------------------------------
-- 業務名   ZLB（国保税）
-- ＰＧ名   ZLBSKCALSHK
-- 名称     計算個人作成
-- 処理概要 資格基本TMPを元に計算個人の資格関連および各月の資格区分を作成する。
-- 引き数   i_NCHOTEI_NENDO         調定年度
--          i_NNEDOBUN              年度分
--          i_NKOKU_SETAI_NO        国保世帯番号
--          i_NKOJIN_NO             個人番号
--          i_NFUKA_KIJITSU         賦課期日
--          i_NKIJUN_NNGAPPI        基準日
--          i_NJIKKOU_KBN           実行区分(0:バッチから起動 本算定/月例...
--                                           1:オンライン起動 即時)
--          i_VMASIN_NO             端末番号
--          i_NTRENBAN              登録連番
--          o_NRESULT               処理結果(0:正常終了、9:異常終了)
-- 作成者   ZCZL.FUBOYU
-- 作成日   2023/08/02
-- Version 0.2.000.000
-------------------------------------------------------------------------------------
--変更履歴
--2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
--2024/05/07 ZCZL.ZHOUGUILIN Add 0.3.000.100: 国保2次にマージ作業
--2025/08/11 ZCZL.LIUHUAJUN UPDATE 1.1.200.000:子ども子育て支援金対応
--2025/12/02 ZCZL.LISHUAI UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00081
--2025/12/12 ZCZL.XIESHUN ADD 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00109
--2025/10/05 JSFIT.MORI Add 1.0.802.001:QA18011対応 基盤安定産前産後考慮追加
-------------------------------------------------------------------------------
IS
-------------------------------------------------------------------------------
-- コンストの定義
-------------------------------------------------------------------------------
    -- 戻り値  定数
    c_NOK            CONSTANT NUMBER(1) := 0;        -- 正常
    c_NERR           CONSTANT NUMBER(1) := 9;        -- 異常
    -- 介護対象者チェック(KHSFKKAICHECK)  定数
    c_NMODE          CONSTANT NUMBER(1) := 1;        -- 呼び出しモード
    c_NHANKBN_M      CONSTANT NUMBER(1) := 1;        -- 判定区分(年月)
    c_NHANKBN_D      CONSTANT NUMBER(1) := 0;        -- 判定区分(年月日)
    -- 介護事由判定(ZLBSKKAIJIYHNT)  定数
    c_NMODE_JL      CONSTANT NUMBER(1) := 1;        -- 呼び出しモード
    -- 実行区分
    c_NBATCH        CONSTANT NUMBER(1) := 0;        -- バッチから起動
    c_NONLNIN       CONSTANT NUMBER(1) := 1;        -- オンライン起動
    c_NZER          CONSTANT NUMBER(1) := 2;        -- バッチから起動(2:税率試算
-------------------------------------------------------------------------------
-- カーソルの定義
-------------------------------------------------------------------------------
    -- 資格基本カーソル
    CURSOR ClSHIKAKU(p_NKOKU_SETAI_NO NUMBER, p_NKOJIN_NO NUMBER) IS
        SELECT * FROM ZLBTSHIKAKU_TMP
         WHERE KOKU_SETAI_NO   = p_NKOKU_SETAI_NO
           AND KOJIN_NO        = p_NKOJIN_NO
           AND SAKUJO_KBN      = 0
           AND SYS_TANMATSU_NO = i_VMASIN_NO
         ORDER BY R_NO, TAI_R_NO, SYS_KOSHINBI, IDO_RENBAN;
    CURSOR CUR_KANWA(p_NKOKU_SETAI_NO NUMBER, p_NKOJIN_NO NUMBER) IS
        SELECT * FROM ZLBTKANWA_TAISHO_TMP
          WHERE KOKU_SETAI_NO = p_NKOKU_SETAI_NO
            AND KOJIN_NO     = p_NKOJIN_NO
            AND TAISHO_KBN IN (1,8)
            AND SAKUJO_KBN   = 0
--賦課期日以前に特定同一非該当のデータは取得しない
            AND (TEKIJOGAI_EBI = 0 OR TEKIJOGAI_EBI > i_NFUKA_KIJITSU)
            AND SYS_TANMATSU_NO = i_VMASIN_NO
          ORDER BY R_NO;
-------------------------------------------------------------------------------
-- ワークエリアの定義
-------------------------------------------------------------------------------
    -- 戻り値用
    NlRTN                   NUMBER(1);      -- Return値
    BlRTN                   BOOLEAN;        -- LOG採取結果
    VlSQLERRM               VARCHAR2(256);
    NlSEINENGAPI            GABTATENAKIHON.SEINENGAPI%TYPE;     -- 生年月日
    RlSHIKAKU               ZLBTSHIKAKU_TMP%ROWTYPE;
    RlKOJIN                 ZLBTKOJIN_CAL%ROWTYPE;
    RlKANWATAISHO           ZLBTKANWA_TAISHO_TMP%ROWTYPE;
    RlKOJIN_SAVE            ZLBTKOJIN_CAL%ROWTYPE;
    NlTOKUDO_HIGAI_TUKI     NUMBER(2);      -- 特定同一非該当月
    NlINS_TAISHO            NUMBER(1);      -- 出力対象(0:対象外 1:対象)
    NlSOSHITSU_BI           NUMBER(8);      -- Work喪失日
    NlHIGAI_BI              NUMBER(8);      -- Work非該当日
    NlHENSHU_BI             NUMBER(8);      -- 編集基準日
    NlFUKA_SHIK_KBN         NUMBER(1);      -- 賦課発生時資格区分
    NlKAIGO_KAISI           NUMBER(2);      -- 介護開始年齢
    NlKAIGO_SHURYO          NUMBER(2);      -- 介護終了年齢
    NlNUSHI_75FLG           NUMBER(1) := 0; -- 主75歳到達フラグ
    NwRTN                   NUMBER(1);
    -- 資格事由ワーク
    NwSIKAKU_GAI_JIYU       NUMBER(2);      -- 資格該当事由
    NwSIKAKU_GAI_BI         NUMBER(8);      -- 資格該当日
    NwSIKAKU_HIGAI_JIYU     NUMBER(2);      -- 資格非該当事由
    NwSIKAKU_HIGAI_BI       NUMBER(8);      -- 資格非該当日
    NwTAI_HIGAI_BI          NUMBER(8);      -- 退職非該当日
    NwTAI_HIGAI_BI_FUYO     NUMBER(8);      --退職非該当日（扶養）
    NwJIKKOU_KBN            NUMBER(1);      -- 実行区分
    V_MSG      NVARCHAR2(256) := '';
    NSHIKAKU_KIJUN_NENGAPPI NUMBER ;  --資格基準年月日
    NlKANWA_CALKBN        NUMBER := 0;               --緩和終了日の自動補正機能（0：パッケージ標準、1：計算時の自動判定のみ行う、2：計算時の自動判定及びKHSTKANWA_TAISHOの更新を行う）
    -- システム日時
    c_ISYSDATE            CONSTANT PLS_INTEGER    := TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDD')); -- システム日付
    c_ISYSTIME            CONSTANT PLS_INTEGER    := TO_NUMBER(TO_CHAR(SYSDATE, 'HH24MISS')); -- システム時間
    NlSOKYU_CALKBN        NUMBER := 0;               --遡及賦課の資格自動補正機能（0：自動補正しない、1：自動補正する、9：ZLBSKCALSHKCUS）
    NSHUTOKU_BI_HOSEI     NUMBER := 0;               --遡及賦課の資格自動補正有無（0：補正なし、1：補正あり）
    NSOSHITSU_BI_HOSEI    NUMBER := 0;               --遡及賦課の資格自動補正有無（0：補正なし、1：補正あり）
    NwCNT2               NUMBER := 0;         --件数
    NSHIK_CNT               NUMBER ;
    NLOOP_CNT               NUMBER ;
    NIDO_RENBAN             NUMBER ;
------------------------------------------------------------------------------------
--  日付の加減算を行う。(増減年数, 増減月数, 増減日数,西暦基準日) 返り値: 増減後西暦
------------------------------------------------------------------------------------
Function funcDayad( hiYear Number, hiMonth Number, hiDay Number ,hlYYYYMMDD In Number ) Return Number Is
  wlSeirekiZogen Number;
Begin
  wlSeirekiZogen := 0;
  wlSeirekiZogen := KKAPK0020.FDATECAL(hlYYYYMMDD, 0, hiDay, hiMonth, hiYear);
  Return( wlSeirekiZogen );
End funcDayad;
-------------------------------------------------------------------------------
-- XX ポイントセット(失業者)
-------------------------------------------------------------------------------
    PROCEDURE subPointShitsu(i_NIDX IN NUMBER, i_NKBN IN NUMBER) IS
    BEGIN
        CASE i_NIDX
          WHEN 1  THEN RlKOJIN.SHITSU_4  := i_NKBN;
          WHEN 2  THEN RlKOJIN.SHITSU_5  := i_NKBN;
          WHEN 3  THEN RlKOJIN.SHITSU_6  := i_NKBN;
          WHEN 4  THEN RlKOJIN.SHITSU_7  := i_NKBN;
          WHEN 5  THEN RlKOJIN.SHITSU_8  := i_NKBN;
          WHEN 6  THEN RlKOJIN.SHITSU_9  := i_NKBN;
          WHEN 7  THEN RlKOJIN.SHITSU_10 := i_NKBN;
          WHEN 8  THEN RlKOJIN.SHITSU_11 := i_NKBN;
          WHEN 9  THEN RlKOJIN.SHITSU_12 := i_NKBN;
          WHEN 10 THEN RlKOJIN.SHITSU_1  := i_NKBN;
          WHEN 11 THEN RlKOJIN.SHITSU_2  := i_NKBN;
          WHEN 12 THEN RlKOJIN.SHITSU_3  := i_NKBN;
          ELSE NULL;
        END CASE;
    END subPointShitsu;
-------------------------------------------------------------------------------
-- XX ポイントセット(介護)
-------------------------------------------------------------------------------
    PROCEDURE subPointKai(i_NIDX IN NUMBER, i_NKBN IN NUMBER) IS
    BEGIN
        CASE i_NIDX
          WHEN 1  THEN RlKOJIN.KAI_SHIK_4  := i_NKBN;
          WHEN 2  THEN RlKOJIN.KAI_SHIK_5  := i_NKBN;
          WHEN 3  THEN RlKOJIN.KAI_SHIK_6  := i_NKBN;
          WHEN 4  THEN RlKOJIN.KAI_SHIK_7  := i_NKBN;
          WHEN 5  THEN RlKOJIN.KAI_SHIK_8  := i_NKBN;
          WHEN 6  THEN RlKOJIN.KAI_SHIK_9  := i_NKBN;
          WHEN 7  THEN RlKOJIN.KAI_SHIK_10 := i_NKBN;
          WHEN 8  THEN RlKOJIN.KAI_SHIK_11 := i_NKBN;
          WHEN 9  THEN RlKOJIN.KAI_SHIK_12 := i_NKBN;
          WHEN 10 THEN RlKOJIN.KAI_SHIK_1  := i_NKBN;
          WHEN 11 THEN RlKOJIN.KAI_SHIK_2  := i_NKBN;
          WHEN 12 THEN RlKOJIN.KAI_SHIK_3  := i_NKBN;
          ELSE NULL;
        END CASE;
    END subPointKai;
-------------------------------------------------------------------------------
-- XX ポイントセット
-------------------------------------------------------------------------------
    PROCEDURE subPoint(i_NIDX IN NUMBER, i_NKBN IN NUMBER) IS
    BEGIN
        CASE i_NIDX
          WHEN 1  THEN RlKOJIN.SHIK_4  := i_NKBN;
          WHEN 2  THEN RlKOJIN.SHIK_5  := i_NKBN;
          WHEN 3  THEN RlKOJIN.SHIK_6  := i_NKBN;
          WHEN 4  THEN RlKOJIN.SHIK_7  := i_NKBN;
          WHEN 5  THEN RlKOJIN.SHIK_8  := i_NKBN;
          WHEN 6  THEN RlKOJIN.SHIK_9  := i_NKBN;
          WHEN 7  THEN RlKOJIN.SHIK_10 := i_NKBN;
          WHEN 8  THEN RlKOJIN.SHIK_11 := i_NKBN;
          WHEN 9  THEN RlKOJIN.SHIK_12 := i_NKBN;
          WHEN 10 THEN RlKOJIN.SHIK_1  := i_NKBN;
          WHEN 11 THEN RlKOJIN.SHIK_2  := i_NKBN;
          WHEN 12 THEN RlKOJIN.SHIK_3  := i_NKBN;
          ELSE NULL;
        END CASE;
    END subPoint;
-------------------------------------------------------------------------------
-- XX ポイント取得
-------------------------------------------------------------------------------
    FUNCTION funcPointGet(i_NIDX IN NUMBER) RETURN NUMBER IS
        NwKBN           NUMBER;
    BEGIN
        CASE i_NIDX
          WHEN 1  THEN NwKBN := RlKOJIN.SHIK_4;
          WHEN 2  THEN NwKBN := RlKOJIN.SHIK_5;
          WHEN 3  THEN NwKBN := RlKOJIN.SHIK_6;
          WHEN 4  THEN NwKBN := RlKOJIN.SHIK_7;
          WHEN 5  THEN NwKBN := RlKOJIN.SHIK_8;
          WHEN 6  THEN NwKBN := RlKOJIN.SHIK_9;
          WHEN 7  THEN NwKBN := RlKOJIN.SHIK_10;
          WHEN 8  THEN NwKBN := RlKOJIN.SHIK_11;
          WHEN 9  THEN NwKBN := RlKOJIN.SHIK_12;
          WHEN 10 THEN NwKBN := RlKOJIN.SHIK_1;
          WHEN 11 THEN NwKBN := RlKOJIN.SHIK_2;
          WHEN 12 THEN NwKBN := RlKOJIN.SHIK_3;
          ELSE NULL;
        END CASE;
        RETURN(NwKBN);
    END funcPointGet;
-------------------------------------------------------------------------------
-- XX 年取得
-------------------------------------------------------------------------------
    FUNCTION funcYear(i_NDATE IN NUMBER) RETURN NUMBER IS
        NwNEN           NUMBER(4);
    BEGIN
        NwNEN := 0;
        NwNEN := TRUNC(i_NDATE, -4) / 10000;
        RETURN(NwNEN);
    END funcYear;
-------------------------------------------------------------------------------
-- XX 月取得
-------------------------------------------------------------------------------
    FUNCTION funcMonth(i_NDATE IN NUMBER) RETURN NUMBER IS
        NwTUKI          NUMBER(2);
    BEGIN
        NwTUKI := 0;
        NwTUKI := TRUNC(i_NDATE - TRUNC(i_NDATE, -4), -2) / 100;
        RETURN(NwTUKI);
    END funcMonth;
-------------------------------------------------------------------------------
-- XX 日取得
-------------------------------------------------------------------------------
    FUNCTION funcDay(i_NDATE IN NUMBER) RETURN NUMBER IS
        NwHI            NUMBER(2);
    BEGIN
        NwHI := 0;
        NwHI := i_NDATE - TRUNC(i_NDATE, -2);
        RETURN(NwHI);
    END funcDay;
-------------------------------------------------------------------------------
-- 15 各月の失業者資格区分セット
-------------------------------------------------------------------------------
    PROCEDURE subShitsuGyoshaSet(i_RSHIKAKU IN ZLBTSHIKAKU_TMP%ROWTYPE,
                                i_SHITSU_SBI IN NUMBER,
                                i_SHITSU_EBI IN NUMBER,
                                i_KAISU     IN PLS_INTEGER ) IS
        NwRTN               NUMBER;
        NwIDX               NUMBER;
        NwSHIK_KBN          NUMBER(2);
        NwSHITSU_KBN         NUMBER(2);
        NwKAIKIJUNBI        NUMBER(8);
    BEGIN
        FOR NwIDX IN 1..12 LOOP
            NwSHITSU_KBN := 0;
            NwSHIK_KBN := funcPointGet(NwIDX);
            IF NwSHIK_KBN = 0 OR (NwSHIK_KBN = 2 AND i_RSHIKAKU.SHIK_KBN <> 5) THEN
                NwSHITSU_KBN := 0;
            ELSE
                IF i_SHITSU_SBI IS NULL OR i_SHITSU_EBI IS NULL THEN
                    NlRTN := c_NERR;
                    VlSQLERRM := '失業者開始日または失業者終了日はヌル' ||
                                 '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                 ')' || SQLERRM;
                    RETURN;
                END IF;
                    IF NwIDX < 10 THEN
                        -- 4～12月(NwIDX:1～9)
                        NwKAIKIJUNBI := (i_NNENDO_BUN * 10000) +
                                        ((NwIDX + 3) * 100) + 1;
                    ELSE
                        -- 1～3月(NwIDX:10～12)※翌年
                        NwKAIKIJUNBI := ((i_NNENDO_BUN + 1) * 10000) +
                                        ((NwIDX - 9)       * 100) + 1;
                    END IF;
                    NwKAIKIJUNBI := TO_NUMBER(TO_CHAR(LAST_DAY(TO_DATE(NwKAIKIJUNBI, 'YYYYMMDD')),'YYYYMMDD'));
                    -- 失業者対象者判定
                    IF i_SHITSU_SBI <= NwKAIKIJUNBI AND i_SHITSU_EBI >= NwKAIKIJUNBI THEN
                        NwSHITSU_KBN := 1;
                    END IF;
            END IF;
            IF i_KAISU > 1 AND NwSHITSU_KBN = 0 THEN
              --2回目からの失業者資格0の場合は、セットしない
              NULL;
            ELSE
              subPointShitsu(NwIDX, NwSHITSU_KBN);
            END IF;
            IF i_KAISU > 1 AND NwSHITSU_KBN = 1 THEN
                RlKOJIN.SHITSU_HIGAI_BI := i_SHITSU_EBI;
            END IF;
        END LOOP;
    END subShitsuGyoshaSet;
-------------------------------------------------------------------------------
-- 14 年齢区分セット
--    年度分の1月1日時点で22歳以下であれば計算個人の拡張項目3に1をセット
-------------------------------------------------------------------------------
    PROCEDURE subNenreiSet(i_NNENDO_BUN IN NUMBER) IS
    IRTN        PLS_INTEGER;
    BEGIN
      IRTN := c_NOK;
      -- 基準日時点(1月1日)の年齢算出
      BEGIN
        IF NlSEINENGAPI > 0 THEN
          IRTN := KKAPK0020.FAgeGet(TO_CHAR(NlSEINENGAPI),TO_CHAR(i_NNENDO_BUN * 10000 + 101));
        ELSE
          IRTN := NULL;
        END IF;
         -- 22歳以下判定
        IF IRTN <= 22 THEN
          RlKOJIN.CUST_3 := 1;                         -- 年齢が22歳以下
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          NlRTN := c_NERR;
          VlSQLERRM := 'subNenreiSet 年齢区分セット ' ||
                       '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                       ')' || SQLERRM;
      END;
    END subNenreiSet;
-------------------------------------------------------------------------------
-- 13 身障減免・外国人留学生区分セット
--    賦課個人TMPに設定されていれば計算個人の拡張項目1まはた2に1をセット
--    (拡張項目1=身障者減免区分、拡張項目2=外国人留学生)
-------------------------------------------------------------------------------
    PROCEDURE subShinsho_GaikokuSet(i_RSHIKAKU IN ZLBTSHIKAKU_TMP%ROWTYPE) IS
    NwCNT               NUMBER;
    BEGIN
      NwCNT   := c_NOK;
      -- 賦課個人TMPを検索
      BEGIN
        SELECT COUNT(*) INTO NwCNT FROM ZLBTEXTKJN_TMP
         WHERE KOKU_SETAI_NO =  i_RSHIKAKU.KOKU_SETAI_NO
           AND KOJIN_NO      =  i_RSHIKAKU.KOJIN_NO
           AND SYS_TANMATSU_NO = i_VMASIN_NO
           AND K_SHURUI      =  6;
        -- 賦課個人にデータ有り
        IF NwCNT != 0 THEN
          RlKOJIN.CUST_1 := 1;  -- 身障減免区分(有り)
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          NlRTN := c_NERR;
          VlSQLERRM := 'funcChkFuka 賦課個人TMP 身障減免対象検索 ' ||
                       '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                       ')' || SQLERRM;
      END;
      IF NwCNT = c_NOK THEN
        BEGIN
          SELECT COUNT(*) INTO NwCNT FROM ZLBTEXTKJN_TMP
           WHERE KOKU_SETAI_NO =  i_RSHIKAKU.KOKU_SETAI_NO
             AND KOJIN_NO      =  i_RSHIKAKU.KOJIN_NO
             AND SYS_TANMATSU_NO = i_VMASIN_NO
             AND K_SHURUI      =  7;
          -- 賦課個人にデータ有り
          IF NwCNT != 0 THEN
            RlKOJIN.CUST_2 := 1;    -- 外国人留学生区分(有り)
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            NlRTN := c_NERR;
            VlSQLERRM := 'funcChkFuka 賦課個人TMP 外国人留学生対象検索 ' ||
                         '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                         ')' || SQLERRM;
        END;
      END IF;
    END subShinsho_GaikokuSet;
-------------------------------------------------------------------------------
-- 12 各月の介護区分セット
-------------------------------------------------------------------------------
    PROCEDURE subKaiShutokuSet(i_RSHIKAKU IN ZLBTSHIKAKU_TMP%ROWTYPE) IS
        NwRTN               NUMBER;
        NwKAI_KAISI         NUMBER(8);      -- 介護開始日
        NwIDX               NUMBER;
        NwSHIK_KBN          NUMBER(2);
        NwKAI_KBN           NUMBER(2);
        NwKAIKIJUNBI        NUMBER(8);
    BEGIN
        FOR NwIDX IN 1..12 LOOP
            NwKAI_KBN := 0;
            NwSHIK_KBN := funcPointGet(NwIDX);
            IF NwSHIK_KBN = 0 THEN
                NwKAI_KBN := 0;
            ELSIF NwSHIK_KBN = 2 THEN
                NwKAI_KBN := 2;
            ELSIF NwSHIK_KBN IN (1, 3, 11, 13) THEN
                -- 介護開始日の算出
                NwKAI_KAISI := KKAPK0020.FDATECAL(NlSEINENGAPI, 0, -1, 0, NlKAIGO_KAISI);
                IF NwKAI_KAISI IS NULL THEN
                    NlRTN := c_NERR;
                    VlSQLERRM := 'KKAPK0020.FDATECAL 介護開始日算出' ||
                                 '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                 ')' || SQLERRM;
                    RETURN;
                END IF;
                IF i_NKIJUN_NENGAPPI >= NwKAI_KAISI THEN
                    IF NwIDX < 10 THEN
                        -- 4～12月(NwIDX:1～9)
                        NwKAIKIJUNBI := (i_NNENDO_BUN * 10000) +
                                        ((NwIDX + 3) * 100) + 1;
                    ELSE
                        -- 1～3月(NwIDX:10～12)※翌年
                        NwKAIKIJUNBI := ((i_NNENDO_BUN + 1) * 10000) +
                                        ((NwIDX - 9)       * 100) + 1;
                    END IF;
                    -- 介護対象者判定
                    NwRTN := KHSFKKAICHECK(c_NMODE, c_NHANKBN_M, i_NKOJIN_NO,
                                          NwKAIKIJUNBI, NwKAI_KBN, i_VMASIN_NO);
                END IF;
            END IF;
            subPointKai(NwIDX, NwKAI_KBN);
        END LOOP;
    END subKaiShutokuSet;
-------------------------------------------------------------------------------
-- 11 各月の退職区分(非該当分)セット
-------------------------------------------------------------------------------
    PROCEDURE subHigaitoSet(i_RSHIKAKU IN ZLBTSHIKAKU_TMP%ROWTYPE) IS
        NwHIGAI_BI          NUMBER(8);      -- Work非該当日
        NwHIGAI_BI2         NUMBER(8);      -- Work非該当日
        NwIDX               NUMBER;
        NwS_IDX             NUMBER;
        NwADD_MONTH         NUMBER;         -- ループ開始月
    BEGIN
        IF NlHIGAI_BI <= 0 THEN
            RETURN;
        END IF;
        NwHIGAI_BI := NlHIGAI_BI;
        IF funcMonth(NwHIGAI_BI) >= 1 AND funcMonth(NwHIGAI_BI) <= 3 THEN
            -- 前年算出
            NwHIGAI_BI2 := KKAPK0020.FDATECAL(NwHIGAI_BI, 0, 0, 0, -1);
            IF NwHIGAI_BI2 IS NULL THEN
                NlRTN := c_NERR;
                VlSQLERRM := 'KKAPK0020.FDATECAL 退職非該当日算出(前年)' ||
                             '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                             ')' || SQLERRM;
                RETURN;
            ELSE
                NwHIGAI_BI := NwHIGAI_BI2;
            END IF;
        END IF;
        IF funcYear(NwHIGAI_BI) = i_NNENDO_BUN THEN
            -- ループ制御用に月を変換(4～12月を1～9,1～3月を10～12)
            IF funcMonth(NwHIGAI_BI) >= 4 AND funcMonth(NwHIGAI_BI) <= 12 THEN
                NwADD_MONTH := -3;
            ELSE
                NwADD_MONTH := 9;
            END IF;
            NwHIGAI_BI2 := KKAPK0020.FDATECAL(NwHIGAI_BI, 0, 0, NwADD_MONTH, 0);
            IF NwHIGAI_BI2 IS NULL THEN
                NlRTN := c_NERR;
                VlSQLERRM := 'KKAPK0020.FDATECAL 退職非該当月算出' ||
                             '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                             ')' || SQLERRM;
                RETURN;
            END IF;
            NwS_IDX := funcMonth(NwHIGAI_BI2);
        ELSIF funcYear(NwHIGAI_BI) < i_NNENDO_BUN THEN
            NwS_IDX := 1;
        ELSE
            NwS_IDX := 0;
        END IF;
        IF NwS_IDX != 0 THEN
            FOR NwIDX IN NwS_IDX..12 LOOP
                CASE funcPointGet(NwIDX)
                  WHEN 11 THEN subPoint(NwIDX, 1);
                  WHEN 13 THEN subPoint(NwIDX, 3);
                  ELSE NULL;
                END CASE;
            END LOOP;
        END IF;
    END subHigaitoSet;
-------------------------------------------------------------------------------
-- 10 各月の退職区分(該当分)セット
-------------------------------------------------------------------------------
    PROCEDURE subGaitoSet(i_RSHIKAKU IN ZLBTSHIKAKU_TMP%ROWTYPE) IS
        NwGAI_BI            NUMBER(8);      -- Work該当日
        NwGAI_BI2           NUMBER(8);      -- Work該当日
        NwIDX               NUMBER;
        NwS_IDX             NUMBER;
        NwADD_MONTH         NUMBER;         -- ループ開始月
    BEGIN
        IF i_RSHIKAKU.Z_GAI_BI <= 0 THEN
            RETURN;
        END IF;
        NwGAI_BI := i_RSHIKAKU.Z_GAI_BI;
        IF funcMonth(NwGAI_BI) >= 1 AND funcMonth(NwGAI_BI) <= 3 THEN
            -- 前年算出
            NwGAI_BI2 := KKAPK0020.FDATECAL(NwGAI_BI, 0, 0, 0, -1);
            IF NwGAI_BI2 IS NULL THEN
                NlRTN := c_NERR;
                VlSQLERRM := 'KKAPK0020.FDATECAL 退職該当日算出(前年)' ||
                             '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                             ')' || SQLERRM;
                RETURN;
            ELSE
                NwGAI_BI := NwGAI_BI2;
            END IF;
        END IF;
        IF funcYear(NwGAI_BI) = i_NNENDO_BUN THEN
            -- ループ制御用に月を変換(4～12月を1～9,1～3月を10～12)
            IF funcMonth(NwGAI_BI) >= 4 AND funcMonth(NwGAI_BI) <= 12 THEN
                NwADD_MONTH := -3;
            ELSE
                NwADD_MONTH := 9;
            END IF;
            NwGAI_BI2 := KKAPK0020.FDATECAL(NwGAI_BI, 0, 0, NwADD_MONTH, 0);
            IF NwGAI_BI2 IS NULL THEN
                NlRTN := c_NERR;
                VlSQLERRM := 'KKAPK0020.FDATECAL 退職該当日算出' ||
                             '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                             ')' || SQLERRM;
                RETURN;
            END IF;
            NwS_IDX := funcMonth(NwGAI_BI2);
        ELSIF funcYear(NwGAI_BI) < i_NNENDO_BUN THEN
            NwS_IDX := 1;
        ELSE
            NwS_IDX := 0;
        END IF;
        IF NwS_IDX != 0 THEN
            FOR NwIDX IN NwS_IDX..12 LOOP
                CASE funcPointGet(NwIDX)
                  WHEN 1 THEN subPoint(NwIDX, 11);
                  WHEN 3 THEN subPoint(NwIDX, 13);
                  ELSE NULL;
                END CASE;
            END LOOP;
        END IF;
    END subGaitoSet;
-------------------------------------------------------------------------------
-- 09 各月の資格区分(喪失分)セット
-------------------------------------------------------------------------------
    PROCEDURE subSosituSet(i_RSHIKAKU IN ZLBTSHIKAKU_TMP%ROWTYPE) IS
        NwSOSITU_BI         NUMBER(8);      -- Work喪失日
        NwSOSITU_BI2        NUMBER(8);      -- Work喪失日
        NwIDX               NUMBER;
        NwS_IDX             NUMBER;
        NwADD_MONTH         NUMBER;         -- ループ開始月
    BEGIN
        IF NlSOSHITSU_BI <= 0 THEN
            RETURN;
        END IF;
        NwSOSITU_BI := NlSOSHITSU_BI;
        IF funcMonth(NwSOSITU_BI) >= 1 AND funcMonth(NwSOSITU_BI) <= 3 THEN
            -- 前年算出
            NwSOSITU_BI2 := KKAPK0020.FDATECAL(NwSOSITU_BI, 0, 0, 0, -1);
            IF NwSOSITU_BI2 IS NULL THEN
                NlRTN := c_NERR;
                VlSQLERRM := 'KKAPK0020.FDATECAL 喪失日算出(前年)' ||
                             '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                             ')' || SQLERRM;
                RETURN;
            ELSE
                NwSOSITU_BI := NwSOSITU_BI2;
            END IF;
        END IF;
        IF funcYear(NwSOSITU_BI) = i_NNENDO_BUN THEN
            -- ループ制御用に月を変換(4～12月を1～9,1～3月を10～12)
            IF funcMonth(NwSOSITU_BI) >= 4 AND funcMonth(NwSOSITU_BI) <= 12 THEN
                NwADD_MONTH := -3;
            ELSE
                NwADD_MONTH := 9;
            END IF;
            NwSOSITU_BI2 := KKAPK0020.FDATECAL(NwSOSITU_BI, 0, 0, NwADD_MONTH, 0);
            IF NwSOSITU_BI2 IS NULL THEN
                NlRTN := c_NERR;
                VlSQLERRM := 'KKAPK0020.FDATECAL 喪失開始月算出' ||
                             '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                             ')' || SQLERRM;
                RETURN;
            END IF;
            NwS_IDX := funcMonth(NwSOSITU_BI2);
        ELSIF funcYear(NwSOSITU_BI) < i_NNENDO_BUN THEN
            NwS_IDX := 1;
        ELSE
            NwS_IDX := 0;
        END IF;
        IF NwS_IDX != 0 THEN
            FOR NwIDX IN NwS_IDX..12 LOOP
                subPoint(NwIDX, 0);
            END LOOP;
        END IF;
    END subSosituSet;
-------------------------------------------------------------------------------
-- 08 各月の資格区分(取得分)セット
-------------------------------------------------------------------------------
    PROCEDURE subShutokuSet(i_RSHIKAKU IN ZLBTSHIKAKU_TMP%ROWTYPE) IS
        NwSHUTOKU_BI        NUMBER(8);      -- Work取得日
        NwSHUTOKU_BI2       NUMBER(8);      -- Work取得日
        NwIDX               NUMBER;
        NwS_IDX             NUMBER;
        NwADD_MONTH         NUMBER;         -- ループ開始月
    BEGIN
        NwSHUTOKU_BI := i_RSHIKAKU.Z_SHUTOKU_BI;
        IF funcMonth(NwSHUTOKU_BI) >= 1 AND funcMonth(NwSHUTOKU_BI) <= 3 THEN
            -- 前年算出
            NwSHUTOKU_BI2 := KKAPK0020.FDATECAL(NwSHUTOKU_BI, 0, 0, 0, -1);
            IF NwSHUTOKU_BI2 IS NULL THEN
                NlRTN := c_NERR;
                VlSQLERRM := 'KKAPK0020.FDATECAL 取得日算出(前年)' ||
                             '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                             ')' || SQLERRM;
                RETURN;
            ELSE
                NwSHUTOKU_BI := NwSHUTOKU_BI2;
            END IF;
        END IF;
        IF funcYear(NwSHUTOKU_BI) = i_NNENDO_BUN THEN
            -- ループ制御用に月を変換(4～12月を1～9,1～3月を10～12)
            IF funcMonth(NwSHUTOKU_BI) >= 4 AND funcMonth(NwSHUTOKU_BI) <= 12 THEN
                NwADD_MONTH := -3;
            ELSE
                NwADD_MONTH := 9;
            END IF;
            NwSHUTOKU_BI2 := KKAPK0020.FDATECAL(NwSHUTOKU_BI, 0, 0, NwADD_MONTH, 0);
            IF NwSHUTOKU_BI2 IS NULL THEN
                NlRTN := c_NERR;
                VlSQLERRM := 'KKAPK0020.FDATECAL 取得開始月算出' ||
                             '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                             ')' || SQLERRM;
                RETURN;
            END IF;
            NwS_IDX := funcMonth(NwSHUTOKU_BI2);
        ELSIF funcYear(NwSHUTOKU_BI) < i_NNENDO_BUN THEN
            NwS_IDX := 1;
        ELSE
            NwS_IDX := 0;
        END IF;
        IF NwS_IDX != 0 THEN
            FOR NwIDX IN NwS_IDX..12 LOOP
                IF i_RSHIKAKU.SHIK_KBN IN (1, 7) THEN
                    subPoint(NwIDX, (TRUNC(funcPointGet(NwIDX), -1) + 1));
                ELSIF i_RSHIKAKU.SHIK_KBN IN (2, 8) THEN
                    subPoint(NwIDX, 2);
                ELSIF i_RSHIKAKU.SHIK_KBN IN (3, 9) THEN
                    subPoint(NwIDX, (TRUNC(funcPointGet(NwIDX), -1) + 3));
                ELSIF i_RSHIKAKU.SHIK_KBN = 5 AND funcPointGet(NwIDX) != 2 THEN
                    subPoint(NwIDX, 5);
                END IF;
            END LOOP;
        END IF;
    END subShutokuSet;
-- 2024/05/07 ZCZL.ZHOUGUILIN Add Start 0.3.000.100: 国保2次にマージ作業
-------------------------------------------------------------------------------
-- XX ポイントセット(産前産後)
-- 計算個人.：RlKOJINに産前産後区分をセット
-------------------------------------------------------------------------------
    PROCEDURE subPointSan(i_NIDX IN NUMBER, i_NKBN IN NUMBER) IS
    BEGIN
      CASE i_NIDX
        WHEN 1 THEN
          IF RlKOJIN.SAN_4 <> 1 THEN
            RlKOJIN.SAN_4 := i_NKBN;      --産前産後4月
          END IF;
        WHEN 2 THEN
          IF RlKOJIN.SAN_5 <> 1 THEN
            RlKOJIN.SAN_5 := i_NKBN;      --産前産後5月
          END IF;
        WHEN 3 THEN
          IF RlKOJIN.SAN_6 <> 1 THEN
            RlKOJIN.SAN_6 := i_NKBN;      --産前産後6月
          END IF;
        WHEN 4 THEN
          IF RlKOJIN.SAN_7 <> 1 THEN
          RlKOJIN.SAN_7 := i_NKBN;      --産前産後7月
          END IF;
        WHEN 5 THEN
          IF RlKOJIN.SAN_8 <> 1 THEN
            RlKOJIN.SAN_8 := i_NKBN;      --産前産後8月
          END IF;
        WHEN 6 THEN
          IF RlKOJIN.SAN_9 <> 1 THEN
            RlKOJIN.SAN_9 := i_NKBN;      --産前産後9月
          END IF;
        WHEN 7 THEN
          IF RlKOJIN.SAN_10 <> 1 THEN
            RlKOJIN.SAN_10 := i_NKBN;     --産前産後10月
          END IF;
        WHEN 8 THEN
          IF RlKOJIN.SAN_11 <> 1 THEN
            RlKOJIN.SAN_11 := i_NKBN;     --産前産後11月
          END IF;
        WHEN 9 THEN
          IF RlKOJIN.SAN_12 <> 1 THEN
            RlKOJIN.SAN_12 := i_NKBN;     --産前産後12月
          END IF;
        WHEN 10 THEN
          IF RlKOJIN.SAN_1 <> 1 THEN
            RlKOJIN.SAN_1 := i_NKBN;      --産前産後1月
          END IF;
        WHEN 11 THEN
          IF RlKOJIN.SAN_2 <> 1 THEN
            RlKOJIN.SAN_2 := i_NKBN;      --産前産後2月
          END IF;
        WHEN 12 THEN
          IF RlKOJIN.SAN_3 <> 1 THEN
            RlKOJIN.SAN_3 := i_NKBN;      --産前産後3月
          END IF;
        ELSE
          NULL;
       END CASE;
    END subPointSan;
-------------------------------------------------------------------------------
-- 産前産後区分セット処理
-------------------------------------------------------------------------------
    PROCEDURE subSanzenSet(i_RSHIKAKU IN ZLBTSHIKAKU_TMP%ROWTYPE) IS

      NwSanStartYM         NUMBER(6);  --産前産後開始年月
      NwSanEndYM           NUMBER(6);  --産前産後終了年月
      NwSHIK_KBN           NUMBER(2);  --資格区分
      NwSAN_KBN            NUMBER(2);  --産前産後資格区分

      --産前産後用緩和措置TMPカーソルを定義する。
      CURSOR CUR_KANWA_SAN(p_NKOKU_SETAI_NO     IN NUMBER,
                           p_NKOJIN_NO          IN NUMBER,
                           p_VSYS_TANMATSU_NO   IN NVARCHAR2)
      IS
        SELECT *
          FROM ZLBTKANWA_TAISHO_TMP KANWA_TAISHO
         WHERE KANWA_TAISHO.KOKU_SETAI_NO = p_NKOKU_SETAI_NO
           AND KANWA_TAISHO.KOJIN_NO = p_NKOJIN_NO
           AND KANWA_TAISHO.TAISHO_KBN IN (9, 10)
           AND KANWA_TAISHO.SAKUJO_KBN = 0
           AND KANWA_TAISHO.SYS_TANMATSU_NO = p_VSYS_TANMATSU_NO
      ORDER BY KANWA_TAISHO.R_NO;

    BEGIN
      --産前産後用緩和措置TMPカーソルループ
      FOR RCUR_KANWA IN CUR_KANWA_SAN(i_RSHIKAKU.KOKU_SETAI_NO,
                                      i_RSHIKAKU.KOJIN_NO,
                                      i_RSHIKAKU.SYS_TANMATSU_NO) LOOP
        --***************************
        --最新産前産後資格を判定する。
        --***************************
        --産前産後用緩和措置TMP.終了日 < 引数.賦課期日　の場合
        IF RCUR_KANWA.TEKIJOGAI_EBI < i_NFUKA_KIJITSU THEN
          --計算個人.最新産前産後資格区分 = 0
          RlKOJIN.NEW_SAN_KBN := 0;
        --産前産後用緩和措置TMP.開始日 < 引数.賦課期日 + 10000　かつ　産前産後用緩和措置TMP.終了日 >= 引数.基準年月日　の場合
        ELSIF RCUR_KANWA.TEKIJOGAI_SBI < i_NFUKA_KIJITSU + 10000 AND RCUR_KANWA.TEKIJOGAI_EBI >= i_NKIJUN_NENGAPPI THEN
          --計算個人.最新産前産後資格区分 = 1
          RlKOJIN.NEW_SAN_KBN := 1;
        --産前産後用緩和措置TMP.終了日 < 引数.基準年月日　の場合
        ELSIF RCUR_KANWA.TEKIJOGAI_EBI < i_NKIJUN_NENGAPPI THEN
          --計算個人.最新産前産後資格区分 = 2
          RlKOJIN.NEW_SAN_KBN := 2;
        ELSE
          NULL;
        END IF;

        --***************************
        --賦課期日時点産前産後資格を判定する。
        --***************************
        --産前産後用緩和措置TMP.開始日 < 引数.賦課期日　かつ　産前産後用緩和措置TMP.終了日 >= 引数.賦課期日　の場合
        IF RCUR_KANWA.TEKIJOGAI_SBI < i_NFUKA_KIJITSU AND RCUR_KANWA.TEKIJOGAI_EBI >= i_NFUKA_KIJITSU THEN
          --計算個人.賦課期日資格区分が1,3,5　または　（計算個人.賦課期日資格区分が2　かつ　引数.資格区分が5)　の場合
          IF RlKOJIN.F4_SHIK_KBN IN (1, 3, 5) OR (RlKOJIN.F4_SHIK_KBN = 2 AND i_RSHIKAKU.SHIK_KBN != 5) THEN
            --計算個人.賦課期日産前産後資格区分 = 1
            RlKOJIN.F4_SAN_KBN := 1;
          END IF;
        END IF;
        --変数.産前産後開始年月 = TRUNC(産前産後用緩和措置TMPカーソル.開始日 /100)
        NwSanStartYM := TRUNC(RCUR_KANWA.TEKIJOGAI_SBI / 100);
        --変数.産前産後終了年月 = TRUNC(産前産後用緩和措置TMPカーソル.終了日 /100)
        NwSanEndYM := TRUNC(RCUR_KANWA.TEKIJOGAI_EBI / 100);
        --変数.産前産後開始年月または変数.産前産後終了年月がNULLの場合
        IF NwSanStartYM IS NULL OR NwSanEndYM IS NULL THEN
          --Return値 = 異常
          NlRTN := c_NERR;
          --VlSQLERRM = '産前産後開始年月または産前産後終了年月はヌル' ||'( 国保世帯番号=' || i_NKOKU_SETAI_NO ||')' || SQLERRM;
          VlSQLERRM := '産前産後開始年月または産前産後終了年月はヌル' || '(国保世帯番号=' || i_NKOKU_SETAI_NO || ')' || SQLERRM;
          RETURN;
        END IF;
        --12ヶ月分ループ
        FOR NwIDX IN 1 .. 12 LOOP
          --変数.産前産後資格区分に0を入れる。
          NwSAN_KBN := 0;
          --変数.資格区分 = XX ポイント取得(NwIDX)
          NwSHIK_KBN := funcPointGet(NwIDX);
          --変数.資格区分が0(Null)、または、(変数.資格区分が2(擬制世帯主)かつ引数.資格区分が5(特定同一世帯所属者)以外)の場合
          IF NVL(NwSHIK_KBN, 0) = 0 OR (NwSHIK_KBN = 2 AND i_RSHIKAKU.SHIK_KBN != 5) THEN
            --変数.産前産後資格区分 = 0
            NwSAN_KBN := 0;
          ELSE
            --ループ回数が10未満の場合
            IF NwIDX < 10 THEN
              --変数.産前産後開始年月 <= 引数.年度分 * 100 + (NwIDX + 3) かつ 引数.年度分 * 100 + (NwIDX + 3) <= 変数.産前産後終了年月　の場合
              IF NwSanStartYM <= i_NNENDO_BUN * 100 + (NwIDX + 3) AND i_NNENDO_BUN * 100 + (NwIDX + 3) <= NwSanEndYM THEN
                --変数.産前産後資格区分 = 1
                NwSAN_KBN := 1;
              END IF;
            --上記以外の場合
            ELSE
              --変数.産前産後開始年月 <= (引数.年度分 + 1) * 100 + (NwIDX - 9) かつ (引数.年度分 + 1) * 100 + (NwIDX - 9) <= 変数.産前産後終了年月　の場合
              IF NwSanStartYM <= (i_NNENDO_BUN + 1) * 100 + (NwIDX - 9) AND (i_NNENDO_BUN + 1) * 100 + (NwIDX - 9) <= NwSanEndYM THEN
                 --変数.産前産後資格区分 = 1
                NwSAN_KBN := 1;
              END IF;
            END IF;
          END IF;

          --XX ポイントセット(産前産後)
          subPointSan(NwIDX, NwSAN_KBN);
        END LOOP;
        --計算個人.産前産後該当日 = 産前産後用緩和措置TMPカーソル.開始日
        RlKOJIN.SAN_GAI_BI := RCUR_KANWA.TEKIJOGAI_SBI;
        --計算個人.産前産後非該当日 = 産前産後用緩和措置TMPカーソル.終了日
        RlKOJIN.SAN_HIGAI_BI := RCUR_KANWA.TEKIJOGAI_EBI;
      --カーソルループ終了
      END LOOP;
    END subSanzenSet;
-- 2024/05/07 ZCZL.ZHOUGUILIN Add End
-------------------------------------------------------------------------------
-- 07 条件取得
-------------------------------------------------------------------------------
    FUNCTION funcJokenRead RETURN NUMBER IS
        NwRTN           NUMBER;
    BEGIN
        NwRTN := c_NOK;
        BEGIN
            SELECT KAIGO_KAISHI, KAIGO_SHURYO INTO NlKAIGO_KAISI, NlKAIGO_SHURYO
              FROM ZLBTJOKEN
             WHERE NENDO = i_NNENDO_BUN
               AND SANTEIDANTAI_CD = 1;
        EXCEPTION
            WHEN OTHERS THEN
                NwRTN := c_NERR;
                    VlSQLERRM := 'funJokenRead システム条件取得' ||
                                 '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                 ')' || SQLERRM;
        END;
        RETURN(NwRTN);
    END funcJokenRead;
-------------------------------------------------------------------------------
-- 06 出力対象フラグセットおよび各区分セット
-------------------------------------------------------------------------------
    PROCEDURE subKbnSet(i_RSHIKAKU IN ZLBTSHIKAKU_TMP%ROWTYPE) IS
        NwRTN           NUMBER;
        -- 介護事由ワーク
        NwKAI_GAI_JIYU      NUMBER(2);      -- 介護該当事由
        NwKAI_GAI_BI        NUMBER(8);      -- 介護該当日
        NwKAI_HIGAI_JIYU    NUMBER(2);      -- 介護非該当事由
        NwKAI_HIGAI_BI      NUMBER(8);      -- 介護非該当日
        NwKAI_END_BI        NUMBER(8);      -- 介護終了日
        NwNUSHI_KOJIN_NO    NUMBER;         --世帯主個人番号--
        IKAISU              PLS_INTEGER := 1;
        NwSOSHITSU_BI       NUMBER(8);
        -- 2024/05/07 ZCZL.ZHOUGUILIN Add 0.3.000.100: 国保2次にマージ作業
        NHANI               NUMBER;
      -- 主履歴のカーソル
      CURSOR ClNUSHI(p_NKOKU_SETAI_NO NUMBER) IS
          SELECT * FROM KHSTNUSHI
           WHERE KOKU_SETAI_NO  = p_NKOKU_SETAI_NO
             AND SAKUJO_KBN     = 0
             AND NUSHI_TEKI_SBI <= i_NFUKA_KIJITSU
          ORDER BY NUSHI_TEKI_SBI DESC, R_NO DESC;
      CURSOR CUR_KANWA(p_NKOKU_SETAI_NO NUMBER, p_NKOJIN_NO NUMBER) IS
      SELECT * FROM ZLBTKANWA_TAISHO_TMP
       WHERE KOKU_SETAI_NO = p_NKOKU_SETAI_NO
         AND KOJIN_NO     = p_NKOJIN_NO
         AND TAISHO_KBN   = 5
         AND SAKUJO_KBN   = 0
         --賦課期日以前に失業者のデータは取得しない(同一と同じ様に下記の条件が必要のでは)
         AND SYS_TANMATSU_NO = i_VMASIN_NO
       ORDER BY R_NO;
    BEGIN
        NwRTN := 0;
        -- 条件TBLより介護保険開始終了日を取得
        NlRTN := funcJokenRead;     -- 07 条件取得
        IF NlRTN != c_NOK THEN
            RETURN;
        END IF;
        -- 積算該当区分
        IF i_RSHIKAKU.SHIK_KBN IN (1, 3, 7, 9) THEN
            RlKOJIN.SEKISAN_GAI_KBN := 1;
        END IF;
        -- 最新資格区分
        IF NlSOSHITSU_BI > 0 AND NlSOSHITSU_BI <= i_NFUKA_KIJITSU THEN
            RlKOJIN.NEW_SHIK_KBN := 0;
        -- 未来日後期高齢該当で擬主になる人(NlNUSHI_75FLG = 1)は、基準日時点で資格有無を判定
        ELSIF i_RSHIKAKU.Z_SHUTOKU_BI > 0
--                                              国保資格取得日以前に即時計算画面または月例課税処理で行った場合、計算対象に世帯主が含まれない不具合の修正
          -- 先日付資格取得した75歳到達者は主喪失日の1日前で判定
          AND (NlNUSHI_75FLG = 0 OR (NlNUSHI_75FLG = 1 AND i_RSHIKAKU.Z_SHUTOKU_BI <= (KKAPK0020.FDATECAL(i_RSHIKAKU.Z_SOSHITSU_BI, 0, -1, 0, 0)))
                                 OR (NlNUSHI_75FLG = 1 AND i_RSHIKAKU.Z_SHUTOKU_BI > i_RSHIKAKU.SHUTOKU_TODOKE_BI
                                                       AND i_RSHIKAKU.SHUTOKU_TODOKE_BI <= i_NKIJUN_NENGAPPI
                                                       AND i_RSHIKAKU.Z_SHUTOKU_BI > i_NKIJUN_NENGAPPI) )
          AND (NlSOSHITSU_BI = 0 OR NlSOSHITSU_BI > i_NKIJUN_NENGAPPI) THEN
            IF i_RSHIKAKU.SHIK_KBN IN (1, 7) THEN
                RlKOJIN.NEW_SHIK_KBN := 1;
            ELSIF i_RSHIKAKU.SHIK_KBN IN (2, 8) THEN
                RlKOJIN.NEW_SHIK_KBN := 2;
            ELSIF i_RSHIKAKU.SHIK_KBN IN (3, 9) THEN
                RlKOJIN.NEW_SHIK_KBN := 3;
            ELSIF i_RSHIKAKU.SHIK_KBN = 5 AND RlKOJIN.NEW_SHIK_KBN = 0 THEN
                RlKOJIN.NEW_SHIK_KBN := 5;
            END IF;
        ELSIF i_RSHIKAKU.Z_SHUTOKU_BI > 0 AND NlSOSHITSU_BI > 0 AND NlSOSHITSU_BI <= i_NKIJUN_NENGAPPI THEN
            IF i_RSHIKAKU.SHIK_KBN IN (1, 7) THEN
                RlKOJIN.NEW_SHIK_KBN := 7;
            ELSIF i_RSHIKAKU.SHIK_KBN IN (2, 8) THEN
                RlKOJIN.NEW_SHIK_KBN := 8;
            ELSIF i_RSHIKAKU.SHIK_KBN IN (3, 9) THEN
                RlKOJIN.NEW_SHIK_KBN := 9;
            ELSIF i_RSHIKAKU.SHIK_KBN = 5 AND RlKOJIN.NEW_SHIK_KBN = 0 THEN
                RlKOJIN.NEW_SHIK_KBN := 5;
            END IF;
        END IF;
        -- 最新介護資格区分
        IF RlKOJIN.NEW_SHIK_KBN IN (0, 5, 7, 8, 9) THEN
            RlKOJIN.NEW_KAI_SHIK_KBN := 0;
        ELSIF RlKOJIN.NEW_SHIK_KBN = 2 THEN
            RlKOJIN.NEW_KAI_SHIK_KBN := 2;
        ELSIF RlKOJIN.NEW_SHIK_KBN IN (1, 3) THEN
-- 年月ではなく年月日で判定
--            -- 介護対象者判定
            -- 介護対象者判定
            NwRTN := KHSFKKAICHECK(c_NMODE, c_NHANKBN_D, i_NKOJIN_NO,
                                  i_NKIJUN_NENGAPPI, RlKOJIN.NEW_KAI_SHIK_KBN, i_VMASIN_NO);
        END IF;
        -- 最新退職区分
        IF NlHIGAI_BI > 0 AND NlHIGAI_BI <= i_NFUKA_KIJITSU THEN
            RlKOJIN.NEW_TAI_KBN := 0;
        ELSIF i_RSHIKAKU.Z_GAI_BI > 0 AND (NlHIGAI_BI = 0 OR NlHIGAI_BI > i_NKIJUN_NENGAPPI) THEN
            IF i_RSHIKAKU.TAISHOKU_KBN IN (1, 3) THEN
                RlKOJIN.NEW_TAI_KBN := 1;
            ELSIF i_RSHIKAKU.TAISHOKU_KBN IN (2, 4) THEN
                RlKOJIN.NEW_TAI_KBN := 2;
            END IF;
        ELSIF i_RSHIKAKU.Z_GAI_BI > 0 AND NlHIGAI_BI > 0 AND NlHIGAI_BI <= i_NKIJUN_NENGAPPI THEN
            IF i_RSHIKAKU.TAISHOKU_KBN IN (1, 3) THEN
                RlKOJIN.NEW_TAI_KBN := 3;
            ELSIF i_RSHIKAKU.TAISHOKU_KBN IN (2, 4) THEN
                RlKOJIN.NEW_TAI_KBN := 4;
            END IF;
        END IF;
        IF RlKOJIN.NEW_SHIK_KBN <> 5 THEN
        -- 介護事由と介護更正日
        ZLBSKKAIJIYHNT(c_NMODE_JL,
                       i_NKOJIN_NO,
                       i_NNENDO_BUN,
                       i_RSHIKAKU.SHUTOKU_JIYU,
                       i_RSHIKAKU.Z_SHUTOKU_BI,
                       i_RSHIKAKU.SOSHITSU_JIYU,
                       i_RSHIKAKU.Z_SOSHITSU_BI,
                       i_NKIJUN_NENGAPPI,
                       i_NKOKU_SETAI_NO,
                       NwJIKKOU_KBN,
                       i_VMASIN_NO,
                       i_NTRENBAN,
                       NwKAI_GAI_JIYU,
                       NwKAI_GAI_BI,
                       NwKAI_HIGAI_JIYU,
                       NwKAI_HIGAI_BI,
                       NwRTN);                  -- 介護事由判定
        IF NwRTN != c_NOK THEN
            NlRTN := c_NERR;
            RETURN;
        END IF;
        IF NwKAI_GAI_JIYU != 0 AND NwKAI_GAI_JIYU <> 17 THEN
            IF NwKAI_GAI_BI > NwKAI_HIGAI_BI THEN
                    RlKOJIN.KAI_KOSEI_BI := NwKAI_GAI_BI;       -- 介護更正日
                    RlKOJIN.KAI_JIYU := NwKAI_GAI_JIYU;         -- 介護事由
                RlKOJIN.KAI_GAI_BI := NwKAI_GAI_BI;         -- 介護該当日
                RlKOJIN.KAI_HIGAI_BI := NwKAI_HIGAI_BI;     -- 介護非該当日
            ELSE
                RlKOJIN.KAI_KOSEI_BI := NwKAI_HIGAI_BI;     -- 介護更正日
                RlKOJIN.KAI_JIYU := NwKAI_HIGAI_JIYU;       -- 介護事由
                RlKOJIN.KAI_GAI_BI := NwKAI_GAI_BI;         -- 介護該当日
                RlKOJIN.KAI_HIGAI_BI := NwKAI_HIGAI_BI;     -- 介護非該当日
            END IF;
            IF RlKOJIN.KAI_GAI_BI < 20000401 THEN
                RlKOJIN.KAI_GAI_BI := 20000401;             -- 介護該当日
            END IF;
            IF RlKOJIN.KAI_KOSEI_BI < 20000401 THEN
                RlKOJIN.KAI_KOSEI_BI := 20000401;           -- 介護更正日
            END IF;
            IF RlKOJIN.KAI_HIGAI_BI < 20000401 AND
               RlKOJIN.KAI_HIGAI_BI <> 0 THEN
                RlKOJIN.KAI_GAI_BI := 0;                    -- 介護該当日
                RlKOJIN.KAI_HIGAI_BI := 0;                  -- 介護非該当日
            END IF;
            IF RlKOJIN.KAI_GAI_BI = 0 THEN
                RlKOJIN.KAI_KOSEI_BI := 0;          -- 介護更正日
                RlKOJIN.KAI_JIYU := 0;              -- 介護事由
                RlKOJIN.KAI_GAI_BI := 0;            -- 介護該当日
                RlKOJIN.KAI_HIGAI_BI := 0;          -- 介護非該当日
                RlKOJIN.TANJO_65 := 0;              -- 誕生日65歳
            ELSE
                -- 介護終了日の取得(65年後の1日前)
                NwKAI_END_BI := KKAPK0020.FDATECAL(NlSEINENGAPI, 0, -1, 0,
                                                    NlKAIGO_SHURYO);
                IF NwKAI_END_BI IS NULL THEN
                    NlRTN := c_NERR;
                    VlSQLERRM := 'KKAPK0020.FDATECAL 介護終了日算出' ||
                                 '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                 ')' || SQLERRM;
                    RETURN;
                END IF;
                RlKOJIN.TANJO_65 := NwKAI_END_BI;           -- 誕生日65歳
            END IF;
        ELSE
            RlKOJIN.KAI_KOSEI_BI := 0;          -- 介護更正日
            RlKOJIN.KAI_JIYU := 0;              -- 介護事由
            RlKOJIN.KAI_GAI_BI := 0;            -- 介護該当日
            RlKOJIN.KAI_HIGAI_BI := 0;          -- 介護非該当日
            RlKOJIN.TANJO_65 := 0;              -- 誕生日65歳
        END IF;
        IF RlKOJIN.KAI_JIYU >= 71 AND RlKOJIN.KAI_JIYU <= 85 THEN
            RlKOJIN.KAI_JIYU := 66;         -- その他内容変更
        END IF;
        ELSE    -- 最新資格区分が特定同一(5)のとき
            RlKOJIN.KAI_KOSEI_BI := 0;          -- 介護更正日
            RlKOJIN.KAI_JIYU := 0;              -- 介護事由
            RlKOJIN.KAI_GAI_BI := 0;            -- 介護該当日
            RlKOJIN.KAI_HIGAI_BI := 0;          -- 介護非該当日
            RlKOJIN.TANJO_65 := 0;              -- 誕生日65歳
        END IF;
        IF i_RSHIKAKU.SHIK_KBN <> 5 THEN
        -- 最新資格取得日、喪失日
        RlKOJIN.NEW_SHUTOK_BI := i_RSHIKAKU.Z_SHUTOKU_BI;
        RlKOJIN.NEW_SOSHITSU_BI := NlSOSHITSU_BI;
        END IF;
        -- 続柄
        RlKOJIN.NEW_ZOKU := (i_RSHIKAKU.ZOKUGARA_CD1 * 1000000) +
                            (i_RSHIKAKU.ZOKUGARA_CD2 * 10000) +
                            (i_RSHIKAKU.ZOKUGARA_CD3 * 100) +
                            i_RSHIKAKU.ZOKUGARA_CD4;        -- 最新続柄
        RlKOJIN.ZOKU_NAME := i_RSHIKAKU.ZOKU_NAME;          -- 続柄名称
        RlKOJIN.SHIK_R_NO := i_RSHIKAKU.R_NO;               -- 資格履歴番号
        -- 4/1以前の主個人番号を取得する
        NwNUSHI_KOJIN_NO := 0;
        FOR CRNUSHI in ClNUSHI(i_RSHIKAKU.KOKU_SETAI_NO) LOOP
          NwNUSHI_KOJIN_NO := CRNUSHI.NUSHI_KOJIN_NO;
          EXIT;
        END LOOP;
        -- 賦課期日資格区分
        IF (i_RSHIKAKU.Z_SHUTOKU_BI <= i_NFUKA_KIJITSU) AND
           (i_RSHIKAKU.Z_SOSHITSU_BI > i_NFUKA_KIJITSU OR
           i_RSHIKAKU.Z_SOSHITSU_BI = 0) THEN
            IF i_RSHIKAKU.SHIK_KBN IN (1, 7) THEN
                -- 4/1の主個人番号と違うなら員とする。
                IF NwNUSHI_KOJIN_NO = i_RSHIKAKU.KOJIN_NO THEN
                  RlKOJIN.F4_SHIK_KBN := 1;
                ELSE
                  RlKOJIN.F4_SHIK_KBN := 3;
                END IF;
            END IF;
            IF i_RSHIKAKU.SHIK_KBN IN (2, 8) THEN
                -- 4/1の主個人番号と違うなら無とする。
                IF NwNUSHI_KOJIN_NO = i_RSHIKAKU.KOJIN_NO THEN
                  RlKOJIN.F4_SHIK_KBN := 2;
                ELSE
                  RlKOJIN.F4_SHIK_KBN := 0;
                END IF;
            END IF;
            IF i_RSHIKAKU.SHIK_KBN IN (3, 9) THEN
              -- 4/1の主個人番号と同じであるなら主とする。
              IF NwNUSHI_KOJIN_NO = i_RSHIKAKU.KOJIN_NO THEN
                RlKOJIN.F4_SHIK_KBN := 1;
              ELSE
                RlKOJIN.F4_SHIK_KBN := 3;
              END IF;
            END IF;
            IF i_RSHIKAKU.SHIK_KBN = 5 AND RlKOJIN.F4_SHIK_KBN <> 2 THEN
                RlKOJIN.F4_SHIK_KBN := 5;
            END IF;
        END IF;
        -- 賦課期日介護資格区分
        IF RlKOJIN.F4_SHIK_KBN = 0 THEN
            RlKOJIN.F4_KAI_KBN := 0;    -- 喪失(該当なし)
        ELSIF RlKOJIN.F4_SHIK_KBN = 2 THEN
            RlKOJIN.F4_KAI_KBN := 2;    -- 擬主
        ELSIF RlKOJIN.F4_SHIK_KBN IN (1, 3) THEN
-- 年月ではなく年月日で判定
--            -- 介護対象者判定
            -- 介護対象者判定
            NwRTN := KHSFKKAICHECK(c_NMODE, c_NHANKBN_D, i_NKOJIN_NO,
                                  i_NFUKA_KIJITSU, RlKOJIN.F4_KAI_KBN, i_VMASIN_NO);
            IF RlKOJIN.F4_SHIK_KBN = 5 THEN
                RlKOJIN.F4_KAI_KBN := 0;
            END IF;
        END IF;
        -- 賦課期日退職区分
        IF (i_RSHIKAKU.Z_GAI_BI <= i_NFUKA_KIJITSU) AND
           (i_RSHIKAKU.Z_GAI_BI > 0) AND
           ((i_RSHIKAKU.Z_HIGAI_BI > i_NFUKA_KIJITSU) OR
           (i_RSHIKAKU.Z_HIGAI_BI = 0)) THEN
            IF i_RSHIKAKU.TAISHOKU_KBN IN (1, 3) THEN
                RlKOJIN.F4_TAI_KBN := 1;
            END IF;
            IF i_RSHIKAKU.TAISHOKU_KBN IN (2, 4) THEN
                RlKOJIN.F4_TAI_KBN := 2;
            END IF;
        END IF;
        -- 各月の資格区分(取得)
        subShutokuSet(i_RSHIKAKU);      -- 08 各月の資格区分(取得分)セット
        IF NlRTN != c_NOK THEN
            RETURN;
        END IF;
        -- 各月の資格区分(喪失)
        subSosituSet(i_RSHIKAKU);       -- 09 各月の資格区分(喪失分)セット
        IF NlRTN != c_NOK THEN
            RETURN;
        END IF;
        -- 各月の退職区分(該当)
        subGaitoSet(i_RSHIKAKU);        -- 10 各月の退職区分(該当分)セット
        IF NlRTN != c_NOK THEN
            RETURN;
        END IF;
        -- 各月の退職区分(非該当)
        subHigaitoSet(i_RSHIKAKU);      -- 11 各月の退職区分(非該当分)セット
        IF NlRTN != c_NOK THEN
            RETURN;
        END IF;
        -- 各月の資格区分(再取得)
        IF i_RSHIKAKU.SHIK_KBN <> 5 THEN
        -- 各月の介護区分
        subKaiShutokuSet(i_RSHIKAKU);   -- 12 各月の介護区分セット
        IF NlRTN != c_NOK THEN
            RETURN;
        END IF;
        -- 身障減免・外国人留学生区分
        subShinsho_GaikokuSet(i_RSHIKAKU);   -- 13 身障減免・外国人留学生区分セット
        IF NlRTN != c_NOK THEN
            RETURN;
        END IF;
        -- 年齢区分
        subNenreiSet(i_NNENDO_BUN);          -- 14 年齢区分セット
        IF NlRTN != c_NOK THEN
            RETURN;
        END IF;
        END IF;
        IF i_NNENDO_BUN >= 2010 THEN
          FOR RCUR_KANWA in CUR_KANWA(i_RSHIKAKU.KOKU_SETAI_NO, i_RSHIKAKU.KOJIN_NO) LOOP
            --最新失業者資格を判定する
            IF RCUR_KANWA.TEKIJOGAI_EBI < i_NFUKA_KIJITSU THEN
                RlKOJIN.NEW_SHITSU_KBN := 0;
            ELSIF RCUR_KANWA.TEKIJOGAI_SBI < i_NFUKA_KIJITSU + 10000 AND RCUR_KANWA.TEKIJOGAI_EBI >= i_NKIJUN_NENGAPPI THEN
                RlKOJIN.NEW_SHITSU_KBN := 1;
                RlKOJIN.SHITSU_GAI_BI := RCUR_KANWA.TEKIJOGAI_SBI;
                RlKOJIN.SHITSU_HIGAI_BI := RCUR_KANWA.TEKIJOGAI_EBI;
            ELSIF RCUR_KANWA.TEKIJOGAI_EBI < i_NKIJUN_NENGAPPI THEN
                RlKOJIN.NEW_SHITSU_KBN := 2;
                RlKOJIN.SHITSU_GAI_BI := RCUR_KANWA.TEKIJOGAI_SBI;
                RlKOJIN.SHITSU_HIGAI_BI := RCUR_KANWA.TEKIJOGAI_EBI;
            ELSE
                NULL;
            END IF;
            --賦課期日時点失業者資格を判定する
            IF RCUR_KANWA.TEKIJOGAI_SBI <= i_NFUKA_KIJITSU AND RCUR_KANWA.TEKIJOGAI_EBI >= i_NFUKA_KIJITSU THEN
                IF RlKOJIN.F4_SHIK_KBN IN (1,3,5) OR (RlKOJIN.F4_SHIK_KBN = 2 AND i_RSHIKAKU.SHIK_KBN = 5) THEN
                    RlKOJIN.F4_SHITSU_KBN := 1;
                END IF;
            END IF;
            --失業軽減該当日、非該当日のセット
            --各月失業者資格のセット
            subShitsuGyoshaSet(i_RSHIKAKU, RCUR_KANWA.TEKIJOGAI_SBI, RCUR_KANWA.TEKIJOGAI_EBI, IKAISU);   -- 15 各月の失業者資格区分セット
            IF NlRTN != c_NOK THEN
                RETURN;
            END IF;
            IKAISU := IKAISU + 1;
          END LOOP;
          -- NEW_SHITSU_KBN再判定
          -- 擬主の場合は判定用喪失日に0をセット
          IF i_RSHIKAKU.SHIK_KBN = 2 THEN
            NwSOSHITSU_BI := 0;
          ELSE
            IF i_RSHIKAKU.Z_SOSHITSU_BI = 0 THEN
              NwSOSHITSU_BI := 99999999;
            ELSE
              NwSOSHITSU_BI := i_RSHIKAKU.Z_SOSHITSU_BI;
            END IF;
          END IF;
          -- 1.喪失日が賦課期日より前
          -- 2.賦課期日時点失業者区分＝0
          -- 3.各月失業者区分＝0
          -- 全てを満たす場合、NEW_SHITSU_KBNをクリアする
          IF NwSOSHITSU_BI < i_NFUKA_KIJITSU AND
             RlKOJIN.F4_SHITSU_KBN = 0 AND
             RlKOJIN.SHITSU_4 = 0 AND
             RlKOJIN.SHITSU_5 = 0 AND
             RlKOJIN.SHITSU_6 = 0 AND
             RlKOJIN.SHITSU_7 = 0 AND
             RlKOJIN.SHITSU_8 = 0 AND
             RlKOJIN.SHITSU_9 = 0 AND
             RlKOJIN.SHITSU_10 = 0 AND
             RlKOJIN.SHITSU_11 = 0 AND
             RlKOJIN.SHITSU_12 = 0 AND
             RlKOJIN.SHITSU_1 = 0 AND
             RlKOJIN.SHITSU_2 = 0 AND
             RlKOJIN.SHITSU_3 = 0 THEN
            RlKOJIN.NEW_SHITSU_KBN := 0;
            RlKOJIN.SHITSU_GAI_BI := 0;
            RlKOJIN.SHITSU_HIGAI_BI := 0;
          END IF;
        END IF;
-- 2024/05/07 ZCZL.ZHOUGUILIN Add Start 0.3.000.100: 国保2次にマージ作業
        --実行区分が1(オンライン：即時)の場合
--2025/12/02 ZCZL.LISHUAI UPDATE 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00081
--         IF i_NJIKKOU_KBN = 1 THEN
          --引数.基準日が2023年度1月以降の場合
          --引数.基準日が2024年度1月以降の場合
--2025/10/05 JSFIT.MORI Update 1.0.802.001:QA18011 基盤安定処理時は産前産後均等割減額をしない対応
--          IF i_NKIJUN_NENGAPPI >= 20240101 THEN
          IF i_NKIJUN_NENGAPPI >= 20240101 AND i_JOKEN_KBN3 <> 1 THEN
            --産前産後区分セット処理
            subSanzenSet(i_RSHIKAKU);
            IF NlRTN != c_NOK THEN
              RETURN;
            END IF;
          END IF;
--2025/12/02 ZCZL.LISHUAI UPDATE START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00081
--         ELSE
--           BEGIN
--              IF (i_NCHOTEI_NENDO <>  i_NNENDO_BUN) AND
--                 i_NNENDO_BUN >= 2023 THEN
--               SELECT COUNT(*)
--                 INTO NHANI
--                 FROM ZLBTSHORI_HANI
--                WHERE CHOTEI_NENDO = 2023
--                  AND NENDO_BUN = 2023
--                  AND SHIME_NENGETSU >= 202401;
--              ELSE
--                SELECT COUNT(*)
--                 INTO NHANI
--                 FROM ZLBTSHORI_HANI
--2025/08/11 ZCZL.LIUHUAJUN UPDATE START 1.1.200.000:子ども子育て支援金対応
--               WHERE CHOTEI_NENDO = i_NCHOTEI_NENDO
--                 AND NENDO_BUN = i_NNENDO_BUN
--                 AND SHIME_NENGETSU >= 202401
--                WHERE SHIME_NENGETSU >= 202401
--                ;
--2025/08/11 ZCZL.LIUHUAJUN UPDATE END
--              END IF;
--           EXCEPTION
--             WHEN OTHERS THEN
--               NHANI := 0;
--           END;
          --処理範囲テーブルに2023年度1月以降のデータがある場合
--           IF NHANI > 0 THEN
            --産前産後区分セット処理
--             subSanzenSet(i_RSHIKAKU);
--             IF NlRTN != c_NOK THEN
--               RETURN;
--             END IF;
--           END IF;
--         END IF;
--2025/12/02 ZCZL.LISHUAI UPDATE END

        --NEW_SAN_KBN再判定
        IF NwSOSHITSU_BI < i_NFUKA_KIJITSU AND
          RlKOJIN.F4_SAN_KBN = 0 AND
          RlKOJIN.SAN_4 = 0 AND
          RlKOJIN.SAN_5 = 0 AND
          RlKOJIN.SAN_6 = 0 AND
          RlKOJIN.SAN_7 = 0 AND
          RlKOJIN.SAN_8 = 0 AND
          RlKOJIN.SAN_9 = 0 AND
          RlKOJIN.SAN_10 = 0 AND
          RlKOJIN.SAN_11 = 0 AND
          RlKOJIN.SAN_12 = 0 AND
          RlKOJIN.SAN_1 = 0 AND
          RlKOJIN.SAN_2 = 0 AND
          RlKOJIN.SAN_3 = 0 THEN
            --計算個人.最新産前産後資格区分
            RlKOJIN.NEW_SAN_KBN := 0;
          RlKOJIN.SAN_GAI_BI := 0;
          --計算個人.産前産後非該当日 = 0
          RlKOJIN.SAN_HIGAI_BI := 0;
        END IF;
-- 2024/05/07 ZCZL.ZHOUGUILIN Add End
        NlINS_TAISHO := 1;      -- 出力対象
    END subKbnSet;
-------------------------------------------------------------------------------
-- 05 賦課発生時の取得日編集
-------------------------------------------------------------------------------
    PROCEDURE subSyutokubi(i_RSHIKAKU IN ZLBTSHIKAKU_TMP%ROWTYPE) IS
        NwRTN           NUMBER;         -- 介護対象者判定の戻り値
    BEGIN
        NwRTN   := 0;
        -- 当初軽減判定用取得日編集(準備)
        IF i_RSHIKAKU.Z_SOSHITSU_BI > 0 THEN
            IF i_RSHIKAKU.Z_SOSHITSU_BI <= i_NFUKA_KIJITSU THEN
                NlHENSHU_BI := 0;       -- 編集基準日=0
            ELSE
                IF i_RSHIKAKU.Z_SHUTOKU_BI >= i_NFUKA_KIJITSU THEN
                    NlHENSHU_BI := i_RSHIKAKU.Z_SHUTOKU_BI; -- 編集基準日=税用取得日
                ELSE
                    NlHENSHU_BI := i_NFUKA_KIJITSU;         -- 編集基準日=基準日
                END IF;
                NlFUKA_SHIK_KBN := i_RSHIKAKU.SHIK_KBN;
            END IF;
        ELSE
            IF i_RSHIKAKU.Z_SHUTOKU_BI < i_NFUKA_KIJITSU THEN
                NlHENSHU_BI := i_NFUKA_KIJITSU;             -- 編集基準日=基準日
            ELSE
                NlHENSHU_BI := i_RSHIKAKU.Z_SHUTOKU_BI;     -- 編集基準日=税用取得日
            END IF;
            NlFUKA_SHIK_KBN := i_RSHIKAKU.SHIK_KBN;
        END IF;
        -- 当初軽減判定用取得日編集
        IF NlHENSHU_BI > 0 THEN
            IF NlHENSHU_BI <= RlKOJIN.KEIGEN_BI THEN
                NlHENSHU_BI := RlKOJIN.KEIGEN_BI;       -- 編集基準日=軽減判定取得日
                RlKOJIN.FUKA_SHIK_KBN := NlFUKA_SHIK_KBN;
            ELSE
                IF RlKOJIN.KEIGEN_BI = 0 THEN
                    RlKOJIN.KEIGEN_BI := NlHENSHU_BI;
                    RlKOJIN.FUKA_SHIK_KBN := NlFUKA_SHIK_KBN;
                END IF;
            END IF;
            -- 介護
            IF RlKOJIN.FUKA_SHIK_KBN IN (0, 7, 8, 9) THEN
                RlKOJIN.FUKA_KAI_KBN := 0;      -- 喪失(該当なし)
            ELSIF RlKOJIN.FUKA_SHIK_KBN = 2 THEN
                RlKOJIN.FUKA_KAI_KBN := 2;      -- 擬主
            ELSIF RlKOJIN.FUKA_SHIK_KBN IN (1, 3) THEN
                -- 介護対象者判定
                NwRTN := KHSFKKAICHECK(c_NMODE, c_NHANKBN_M, i_NKOJIN_NO,
                                      RlKOJIN.KEIGEN_BI, RlKOJIN.FUKA_KAI_KBN, i_VMASIN_NO);
            END IF;
        END IF;
    END subSyutokubi;
-------------------------------------------------------------------------------
-- 04 計算個人に出力
-------------------------------------------------------------------------------
    FUNCTION funcInsert RETURN NUMBER IS
        NwRTN               NUMBER(1);
    BEGIN
        NwRTN   := 0;
        BEGIN
            INSERT INTO ZLBTKOJIN_CAL VALUES RlKOJIN;
        EXCEPTION
            WHEN OTHERS THEN
                NwRTN := c_NERR;
                VlSQLERRM := 'funcInsert 計算個人登録' ||
                             '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                             ')' || SQLERRM;
        END;
        RETURN(NwRTN);
    END funcInsert;
-------------------------------------------------------------------------------
-- 13 賦課個人データの検索
-------------------------------------------------------------------------------
    FUNCTION funcChkFuka(i_RSHIKAKU IN ZLBTSHIKAKU_TMP%ROWTYPE) RETURN NUMBER IS
        NwCNT               NUMBER;
    BEGIN
        NwCNT   := 0;
        -- 賦課個人を検索
        BEGIN
            SELECT COUNT(*) INTO NwCNT FROM ZLBTKOJIN_N
            WHERE KOKU_SETAI_NO   =  i_RSHIKAKU.KOKU_SETAI_NO
              AND KOJIN_NO        =  i_RSHIKAKU.KOJIN_NO
              AND NENDO_BUN       =  i_NNENDO_BUN;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlSQLERRM := 'funcChkFuka 賦課個人検索 ' ||
                             '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                             ')' || SQLERRM;
        END;
        RETURN(NwCNT);
    END funcChkFuka;
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
    FUNCTION funcChkFuka2(i_RSHIKAKU IN ZLBTSHIKAKU_TMP%ROWTYPE) RETURN NUMBER IS
        NwCNT               NUMBER;
    BEGIN
        NwCNT   := 0;
        -- 賦課個人を検索
        BEGIN
            SELECT COUNT(*) INTO NwCNT FROM ZLBTKOJIN_N
            WHERE KOKU_SETAI_NO   =  i_NKOKU_SETAI_NO
              AND KOJIN_NO        =  i_NKOJIN_NO
              AND R_NO > 0
              AND NENDO_BUN       =  i_NNENDO_BUN;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlSQLERRM := 'funcChkFuka2 賦課個人検索 ' ||
                             '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                             ')' || SQLERRM;
        END;
        RETURN(NwCNT);
    END funcChkFuka2;
-------------------------------------------------------------------------------
-- 03 主処理
-------------------------------------------------------------------------------
    PROCEDURE subMain(i_RSHIKAKU IN ZLBTSHIKAKU_TMP%ROWTYPE) IS
        IwYFUKA_KIJITU      PLS_INTEGER;    -- 日付増減結果
        NwCNT               NUMBER;         --件数
    BEGIN
        NlSOSHITSU_BI   := 0;           -- Work喪失日
        NlHIGAI_BI      := 0;           -- Work非該当日
        V_MSG := '賦課発生時の取得日編集';
        subSyutokubi(i_RSHIKAKU);       --05 賦課発生時の取得日編集
        IF NlRTN != c_NOK THEN
            RETURN;
        END IF;
        V_MSG := '翌年賦課期日日算出';
        -- 翌年賦課期日日算出
        IwYFUKA_KIJITU := KKAPK0020.FDATECAL(i_NFUKA_KIJITSU, 0, 0, 0, 1);
        IF IwYFUKA_KIJITU IS NULL THEN
            NlRTN := c_NERR;
            VlSQLERRM := 'KKAPK0020.FDATECAL 翌年賦課期日算出' ||
                         '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                         ')' || SQLERRM;
            RETURN;
        END IF;
        V_MSG := '資格喪失日の設定';
        -- 資格喪失日の設定
        IF i_RSHIKAKU.Z_SOSHITSU_BI >= IwYFUKA_KIJITU THEN
            NlSOSHITSU_BI := 0;
        ELSE
            NlSOSHITSU_BI := i_RSHIKAKU.Z_SOSHITSU_BI;
        END IF;
        V_MSG := '退職非該当日の設定';
        -- 退職非該当日の設定
        IF i_RSHIKAKU.Z_HIGAI_BI >= IwYFUKA_KIJITU THEN
          IF i_RSHIKAKU.Z_GAI_BI = i_RSHIKAKU.Z_HIGAI_BI THEN
              NlHIGAI_BI := i_RSHIKAKU.Z_HIGAI_BI;
      ELSE
              NlHIGAI_BI := 0;
      END IF;
        ELSE
            NlHIGAI_BI := i_RSHIKAKU.Z_HIGAI_BI;
        END IF;
        V_MSG := '設定対象チェック１';
        -- 設定対象チェック
        IF i_RSHIKAKU.Z_SHUTOKU_BI < IwYFUKA_KIJITU AND
           i_RSHIKAKU.Z_SHUTOKU_BI != NlSOSHITSU_BI THEN
            V_MSG := '設定対象チェック２';
            IF NlSOSHITSU_BI > 0 AND
               NlSOSHITSU_BI <= i_NFUKA_KIJITSU THEN
                -- 賦課個人データを検索する。
                NwCNT := funcChkFuka(i_RSHIKAKU);
                IF NlRTN != c_NOK THEN
                    RETURN;
                END IF;
                IF NwCNT = 0 THEN
                    -- 出力対象としない。
                    NlINS_TAISHO := 0;
                ELSE
                    -- 賦課個人が存在すれば出力対象とする。
                    V_MSG := ' 出力対象フラグセットおよび各区分セット';
                    -- 出力対象フラグセットおよび各区分セット
                    subKbnSet(i_RSHIKAKU);      -- 06 計算個人データセット
                END IF;
              V_MSG := '設定対象チェック３';
                -- 編集エリアの資格区分クリア
                RlKOJIN.NEW_SHIK_KBN := 0;          -- 最新資格区分
                RlKOJIN.NEW_KAI_SHIK_KBN := 0;      -- 最新介護資格区分
                RlKOJIN.NEW_TAI_KBN := 0;           -- 最新退職区分
                RlKOJIN.F4_SHIK_KBN := 0;           -- 賦課期日資格区分
                RlKOJIN.F4_KAI_KBN := 0;            -- 賦課期日介護資格区分
                RlKOJIN.F4_TAI_KBN := 0;            -- 賦課期日退職区分
                RlKOJIN.FUKA_SHIK_KBN := 0;         -- 賦課発生時資格区分
                RlKOJIN.FUKA_KAI_KBN := 0;          -- 賦課発生時介護資格区分
                RlKOJIN.SHIK_4 := 0;                -- 資格4月
                RlKOJIN.SHIK_5 := 0;                -- 資格5月
                RlKOJIN.SHIK_6 := 0;                -- 資格6月
                RlKOJIN.SHIK_7 := 0;                -- 資格7月
                RlKOJIN.SHIK_8 := 0;                -- 資格8月
                RlKOJIN.SHIK_9 := 0;                -- 資格9月
                RlKOJIN.SHIK_10 := 0;               -- 資格10月
                RlKOJIN.SHIK_11 := 0;               -- 資格11月
                RlKOJIN.SHIK_12 := 0;               -- 資格12月
                RlKOJIN.SHIK_1 := 0;                -- 資格1月
                RlKOJIN.SHIK_2 := 0;                -- 資格2月
                RlKOJIN.SHIK_3 := 0;                -- 資格3月
                RlKOJIN.KAI_SHIK_4 := 0;            -- 介護資格4月
                RlKOJIN.KAI_SHIK_5 := 0;            -- 介護資格5月
                RlKOJIN.KAI_SHIK_6 := 0;            -- 介護資格6月
                RlKOJIN.KAI_SHIK_7 := 0;            -- 介護資格7月
                RlKOJIN.KAI_SHIK_8 := 0;            -- 介護資格8月
                RlKOJIN.KAI_SHIK_9 := 0;            -- 介護資格9月
                RlKOJIN.KAI_SHIK_10 := 0;           -- 介護資格10月
                RlKOJIN.KAI_SHIK_11 := 0;           -- 介護資格11月
                RlKOJIN.KAI_SHIK_12 := 0;           -- 介護資格12月
                RlKOJIN.KAI_SHIK_1 := 0;            -- 介護資格1月
                RlKOJIN.KAI_SHIK_2 := 0;            -- 介護資格2月
                RlKOJIN.KAI_SHIK_3 := 0;            -- 介護資格3月
                RlKOJIN.NEW_SHITSU_KBN := 0;        -- 最新失業者資格区分
                RlKOJIN.F4_SHITSU_KBN := 0;         -- 賦課期日失業者資格区分
                RlKOJIN.SHITSU_4 := 0;               -- 失業者資格4月
                RlKOJIN.SHITSU_5 := 0;               -- 失業者資格5月
                RlKOJIN.SHITSU_6 := 0;               -- 失業者資格6月
                RlKOJIN.SHITSU_7 := 0;               -- 失業者資格7月
                RlKOJIN.SHITSU_8 := 0;               -- 失業者資格8月
                RlKOJIN.SHITSU_9 := 0;               -- 失業者資格9月
                RlKOJIN.SHITSU_10 := 0;              -- 失業者資格10月
                RlKOJIN.SHITSU_11 := 0;              -- 失業者資格11月
                RlKOJIN.SHITSU_12 := 0;              -- 失業者資格12月
                RlKOJIN.SHITSU_1 := 0;               -- 失業者資格1月
                RlKOJIN.SHITSU_2 := 0;               -- 失業者資格2月
                RlKOJIN.SHITSU_3 := 0;               -- 失業者資格3月
                RlKOJIN.SEKISAN_GAI_KBN := 0;       --積算該当区分
-- 2024/05/07 ZCZL.ZHOUGUILIN Add Start 0.3.000.100: 国保2次にマージ作業
                RlKOJIN.NEW_SAN_KBN := 0;           -- 最新産前産後資格区分
                RlKOJIN.F4_SAN_KBN := 0;            -- 賦課期日産前産後資格区分
                RlKOJIN.SAN_4 := 0;                 -- 産前産後4月
                RlKOJIN.SAN_5 := 0;                 -- 産前産後5月
                RlKOJIN.SAN_6 := 0;                 -- 産前産後6月
                RlKOJIN.SAN_7 := 0;                 -- 産前産後7月
                RlKOJIN.SAN_8 := 0;                 -- 産前産後8月
                RlKOJIN.SAN_9 := 0;                 -- 産前産後9月
                RlKOJIN.SAN_10 := 0;                -- 産前産後10月
                RlKOJIN.SAN_11 := 0;                -- 産前産後11月
                RlKOJIN.SAN_12 := 0;                -- 産前産後12月
                RlKOJIN.SAN_1 := 0;                 -- 産前産後1月
                RlKOJIN.SAN_2 := 0;                 -- 産前産後2月
                RlKOJIN.SAN_3 := 0;                 -- 産前産後3月
-- 2024/05/07 ZCZL.ZHOUGUILIN Add End
            ELSE
                V_MSG := '設定対象チェック４';
                IF NlHIGAI_BI > 0 AND
                   NlHIGAI_BI <= i_NFUKA_KIJITSU THEN
                    V_MSG := '設定対象チェック５';
                    -- 編集エリアの退職区分クリア
                    RlKOJIN.NEW_TAI_KBN := 0;       -- 最新退職区分
                    RlKOJIN.F4_TAI_KBN := 0;        -- 賦課期日退職区分
                END IF;
                V_MSG := ' 出力対象フラグセットおよび各区分セット';
                -- 出力対象フラグセットおよび各区分セット
                subKbnSet(i_RSHIKAKU);      -- 06 計算個人データセット
            END IF;
        END IF;
    END subMain;
-------------------------------------------------------------------------------
--    緩和対象TMPデータをZLBTSHIKAKU_TMPのワークエリアにセット
-------------------------------------------------------------------------------
    PROCEDURE subKanwaToKojin(I_RKanwa In ZLBTKANWA_TAISHO_TMP%ROWTYPE) IS
    BEGIN
        -- 資格ワークエリアへ設定
        RlSHIKAKU.KOKU_SETAI_NO   := I_RKanwa.KOKU_SETAI_NO;
        RlSHIKAKU.KOJIN_NO        := I_RKanwa.KOJIN_NO;
        RlSHIKAKU.SHIK_KBN        := 5;
        RlSHIKAKU.Z_SHUTOKU_BI    := I_RKanwa.TEKIJOGAI_SBI;
        RlSHIKAKU.SHUTOKU_JIYU    := 16;
        RlSHIKAKU.Z_SOSHITSU_BI   := I_RKanwa.TEKIJOGAI_EBI;
        RlSHIKAKU.SOSHITSU_JIYU   := 36;
        RlSHIKAKU.TAISHOKU_KBN    := 0;
        RlSHIKAKU.Z_GAI_BI        := 0;
        RlSHIKAKU.Z_HIGAI_BI      := 0;
        IF NVL(RlSHIKAKU.ZOKUGARA_CD1,0) = 0 THEN
            RlSHIKAKU.ZOKUGARA_CD1 := 93;
            RlSHIKAKU.ZOKUGARA_CD2 := 0;
            RlSHIKAKU.ZOKUGARA_CD3 := 0;
            RlSHIKAKU.ZOKUGARA_CD4 := 0;
            RlSHIKAKU.ZOKU_NAME    := '不明';
            RlSHIKAKU.R_NO         := 0;
        END IF;
    END subKanwaToKojin;
-------------------------------------------------------------------------------
-- 02 初期化処理
-------------------------------------------------------------------------------
    PROCEDURE subInit IS
    BEGIN
        -- 計算個人出力用ワークエリアをクリア(キー項目はセット)
        RlKOJIN.KOKU_SETAI_NO := i_NKOKU_SETAI_NO;      -- 国保世帯番号
        RlKOJIN.KOJIN_NO := i_NKOJIN_NO;                -- 個人番号
        RlKOJIN.SANTEIDANTAI_CD := 0;                   -- 算定団体コード
        RlKOJIN.CHOTEI_NENDO := i_NCHOTEI_NENDO;        -- 調定年度
        RlKOJIN.NENDO_BUN := i_NNENDO_BUN;              -- 年度分
        RlKOJIN.R_NO := 0;                              -- 履歴番号
        RlKOJIN.TSUCHI_NO := 0;                         -- 通知書番号
        RlKOJIN.NEW_SHIK_KBN := 0;                      -- 最新資格区分
        RlKOJIN.NEW_KAI_SHIK_KBN := 0;                  -- 最新介護資格区分
        RlKOJIN.NEW_TAI_KBN := 0;                       -- 最新退職区分
        RlKOJIN.F4_SHIK_KBN := 0;                       -- 賦課期日資格区分
        RlKOJIN.F4_KAI_KBN := 0;                        -- 賦課期日介護資格区分
        RlKOJIN.F4_TAI_KBN := 0;                        -- 賦課期日退職区分
        RlKOJIN.FUKA_SHIK_KBN := 0;                     -- 賦課発生時資格区分
        RlKOJIN.FUKA_KAI_KBN := 0;                      -- 賦課発生時介護資格区分
        RlKOJIN.KEIGEN_HANT_KBN := 0;                   -- 軽減判定区分
        RlKOJIN.SHIK_4 := 0;                            -- 資格4月
        RlKOJIN.SHIK_5 := 0;                            -- 資格5月
        RlKOJIN.SHIK_6 := 0;                            -- 資格6月
        RlKOJIN.SHIK_7 := 0;                            -- 資格7月
        RlKOJIN.SHIK_8 := 0;                            -- 資格8月
        RlKOJIN.SHIK_9 := 0;                            -- 資格9月
        RlKOJIN.SHIK_10 := 0;                           -- 資格10月
        RlKOJIN.SHIK_11 := 0;                           -- 資格11月
        RlKOJIN.SHIK_12 := 0;                           -- 資格12月
        RlKOJIN.SHIK_1 := 0;                            -- 資格1月
        RlKOJIN.SHIK_2 := 0;                            -- 資格2月
        RlKOJIN.SHIK_3 := 0;                            -- 資格3月
        RlKOJIN.KAI_SHIK_4 := 0;                        -- 介護資格4月
        RlKOJIN.KAI_SHIK_5 := 0;                        -- 介護資格5月
        RlKOJIN.KAI_SHIK_6 := 0;                        -- 介護資格6月
        RlKOJIN.KAI_SHIK_7 := 0;                        -- 介護資格7月
        RlKOJIN.KAI_SHIK_8 := 0;                        -- 介護資格8月
        RlKOJIN.KAI_SHIK_9 := 0;                        -- 介護資格9月
        RlKOJIN.KAI_SHIK_10 := 0;                       -- 介護資格10月
        RlKOJIN.KAI_SHIK_11 := 0;                       -- 介護資格11月
        RlKOJIN.KAI_SHIK_12 := 0;                       -- 介護資格12月
        RlKOJIN.KAI_SHIK_1 := 0;                        -- 介護資格1月
        RlKOJIN.KAI_SHIK_2 := 0;                        -- 介護資格2月
        RlKOJIN.KAI_SHIK_3 := 0;                        -- 介護資格3月
        RlKOJIN.SHOTOKU := 0;                           -- 所得額
        RlKOJIN.KAHYO := 0;                             -- 課税標準額
        RlKOJIN.SHOTOKU_WARI := 0;                      -- 所得割額
        RlKOJIN.KAI_SHOTOKU_WARI := 0;                  -- 介護所得割額
        RlKOJIN.KEIGEN_SHOTOKU := 0;                    -- 軽減判定所得
        RlKOJIN.SHISANZEI := 0;                         -- 資産税額
        RlKOJIN.SHISAN_WARI := 0;                       -- 資産割額
        RlKOJIN.KAI_SHISAN_WARI := 0;                   -- 介護資産割額
        RlKOJIN.SENJU_KBN := 0;                         -- 専従区分
        RlKOJIN.RONEN_KBN := 0;                         -- 老年者区分
        RlKOJIN.SHINKOKU_KBN := 0;                      -- 申告区分
        RlKOJIN.SHU_SHOTOKU_KBN := 0;                   -- 主所得区分
        RlKOJIN.J_KAZEI_KBN := 0;                       -- 住民税課税区分
        RlKOJIN.J_SHOTOKU_WARI := 0;                    -- 住民税所得割額
        RlKOJIN.J_KINTO_WARI := 0;                      -- 住民税均等割額
        RlKOJIN.NEW_SHUTOK_BI := 0;                     -- 最新資格取得日
        RlKOJIN.NEW_SOSHITSU_BI := 0;                   -- 最新資格喪失日
        RlKOJIN.NEW_ZOKU := 0;                          -- 最新続柄
        RlKOJIN.KAI_GAI_BI := 0;                        -- 介護該当日
        RlKOJIN.KAI_HIGAI_BI := 0;                      -- 介護非該当日
        RlKOJIN.TANJO_65 := 0;                          -- 誕生日65歳
        RlKOJIN.KOSEI_BI := 0;                          -- 更正日
        RlKOJIN.JIYU := 0;                              -- 事由
        RlKOJIN.KAI_KOSEI_BI := 0;                      -- 介護更正日
        RlKOJIN.KAI_JIYU := 0;                          -- 介護事由
        RlKOJIN.KEIGEN_BI := 0;                         -- 軽減判定取得日
        RlKOJIN.SEKISAN_GAI_KBN := 0;                   -- 積算該当区分
        RlKOJIN.KOJIN_NENZEI := 0;                      -- 個人年税額
        RlKOJIN.ZOKU_NAME := '';                        -- 続柄名称
        RlKOJIN.SHIK_R_NO := 0;                         -- 資格履歴番号
        RlKOJIN.SYS_SAKUSEIBI := 0;                     -- 作成日
        RlKOJIN.SYS_KOSHINBI := 0;                      -- 更新日
        RlKOJIN.SYS_JIKAN := 0;                         -- 更新時間
        RlKOJIN.SYS_SHOKUINKOJIN_NO := '0';             -- 更新職員個人番号
        RlKOJIN.SYS_TANMATSU_NO := i_VMASIN_NO;         -- 更新端末番号
        RlKOJIN.SEISAN_KBN := 0;                        -- 清算区分
        RlKOJIN.DIV_4 := 0;                             -- 対象4月
        RlKOJIN.DIV_5 := 0;                             -- 対象5月
        RlKOJIN.DIV_6 := 0;                             -- 対象6月
        RlKOJIN.DIV_7 := 0;                             -- 対象7月
        RlKOJIN.DIV_8 := 0;                             -- 対象8月
        RlKOJIN.DIV_9 := 0;                             -- 対象9月
        RlKOJIN.DIV_10 := 0;                            -- 対象10月
        RlKOJIN.DIV_11 := 0;                            -- 対象11月
        RlKOJIN.DIV_12 := 0;                            -- 対象12月
        RlKOJIN.DIV_1 := 0;                             -- 対象1月
        RlKOJIN.DIV_2 := 0;                             -- 対象2月
        RlKOJIN.DIV_3 := 0;                             -- 対象3月
        RlKOJIN.CUST_1 := 0;                            -- 独自項目1(身障減免)
        RlKOJIN.CUST_2 := 0;                            -- 独自項目2(外国人留学生)
        RlKOJIN.CUST_3 := 0;                            -- 独自項目3(22歳以下)
        RlKOJIN.NEW_SHITSU_KBN := 0;                    -- 最新失業者資格区分
        RlKOJIN.F4_SHITSU_KBN := 0;                     -- 賦課期日失業者資格区分
        RlKOJIN.SHITSU_4 := 0;                          -- 失業者資格4月
        RlKOJIN.SHITSU_5 := 0;                          -- 失業者資格5月
        RlKOJIN.SHITSU_6 := 0;                          -- 失業者資格6月
        RlKOJIN.SHITSU_7 := 0;                          -- 失業者資格7月
        RlKOJIN.SHITSU_8 := 0;                          -- 失業者資格8月
        RlKOJIN.SHITSU_9 := 0;                          -- 失業者資格9月
        RlKOJIN.SHITSU_10 := 0;                         -- 失業者資格10月
        RlKOJIN.SHITSU_11 := 0;                         -- 失業者資格11月
        RlKOJIN.SHITSU_12 := 0;                         -- 失業者資格12月
        RlKOJIN.SHITSU_1 := 0;                          -- 失業者資格1月
        RlKOJIN.SHITSU_2 := 0;                          -- 失業者資格2月
        RlKOJIN.SHITSU_3 := 0;                          -- 失業者資格3月
        RlKOJIN.SHITSU_GAI_BI := 0;                     -- 失業軽減該当日
        RlKOJIN.SHITSU_HIGAI_BI := 0;                   -- 失業軽減非該当日
        RlKOJIN.SHITSU_SHOTOKU := 0;                    -- 失業軽減適用後所得額
        RlKOJIN.SHITSU_KAHYO := 0;                      -- 失業軽減適用後課税標準額
        RlKOJIN.SHITSU_KEIGEN_SHOTOKU := 0;             -- 失業軽減適用後軽減判定所得
        RlKOJIN.KYUYO_SHOTOKU_KBN := 0;                 -- 給与所得者等該当区分
-- 2024/05/07 ZCZL.ZHOUGUILIN Add Start 0.3.000.100: 国保2次にマージ作業
        RlKOJIN.NEW_SAN_KBN := 0;                       -- 最新産前産後資格区分
        RlKOJIN.F4_SAN_KBN := 0;                        -- 賦課期日産前産後資格区分
        RlKOJIN.SAN_4 := 0;                             -- 産前産後4月
        RlKOJIN.SAN_5 := 0;                             -- 産前産後5月
        RlKOJIN.SAN_6 := 0;                             -- 産前産後6月
        RlKOJIN.SAN_7 := 0;                             -- 産前産後7月
        RlKOJIN.SAN_8 := 0;                             -- 産前産後8月
        RlKOJIN.SAN_9 := 0;                             -- 産前産後9月
        RlKOJIN.SAN_10 := 0;                            -- 産前産後10月
        RlKOJIN.SAN_11 := 0;                            -- 産前産後11月
        RlKOJIN.SAN_12 := 0;                            -- 産前産後12月
        RlKOJIN.SAN_1 := 0;                             -- 産前産後1月
        RlKOJIN.SAN_2 := 0;                             -- 産前産後2月
        RlKOJIN.SAN_3 := 0;                             -- 産前産後3月
        RlKOJIN.SAN_GAI_BI := 0;                        -- 産前産後該当日
        RlKOJIN.SAN_HIGAI_BI := 0;                      -- 産前産後非該当日
        RlKOJIN.SAN_IRYO_GEN_KINTO := 0;                -- 医療産前産後均等割軽減額
        RlKOJIN.SAN_IRYO_GEN_SHOTOKU := 0;              -- 医療産前産後所得割軽減額
        RlKOJIN.SAN_KAI_GEN_KINTO := 0;                 -- 介護産前産後均等割軽減額
        RlKOJIN.SAN_KAI_GEN_SHOTOKU := 0;               -- 介護産前産後所得割軽減額
        RlKOJIN.SAN_SIEN_GEN_KINTO := 0;                -- 支援産前産後均等割軽減額
        RlKOJIN.SAN_SIEN_GEN_SHOTOKU := 0;              -- 支援産前産後所得割軽減額
-- 2024/05/07 ZCZL.ZHOUGUILIN Add End
--2025/08/11 ZCZL.LIUHUAJUN ADD START 1.1.200.000:子ども子育て支援金対応
        RlKOJIN.SIEN_SHOTOKU_WARI := 0;                 -- 支援所得割額
        RlKOJIN.SIEN_SHISAN_WARI := 0;                  -- 支援資産割額
        RlKOJIN.KDM_18_KBN := 0;                        -- 子ども18歳以上該当区分
        RlKOJIN.KDM_SHOTOKU_WARI := 0;                  -- 子ども所得割額
        RlKOJIN.KDM_SHISAN_WARI := 0;                   -- 子ども資産割額
        RlKOJIN.KDM_KEIGEN_KITO := 0;                   -- 子ども均等割軽減額
        RlKOJIN.KDM_KEIGEN_KITO18 := 0;                 -- 子ども18歳以上均等割軽減額
        RlKOJIN.KDM_SAN_GEN_KINTO := 0;                 -- 子ども産前産後均等割軽減額
        RlKOJIN.KDM_SAN_GEN_SHOTOKU := 0;               -- 子ども産前産後所得割軽減額
        RlKOJIN.KDM_SAN_GEN_KINTO18 := 0;               -- 子ども産前産後18歳以上均等割軽減額
        RlKOJIN.KDM18UN_KEIGEN_KITO := 0;               -- 子ども18歳未満均等割軽減額
--2025/08/11 ZCZL.LIUHUAJUN ADD END
--  2025/12/12 ZCZL.XIESHUN ADD START 1.1.200.000:子ども子育て支援金対応_故障対応_IT_ZLB_00109
        RlKOJIN.KDM_KODOMO_KEIGEN_KITO := 0;            -- 子ども均等割軽減額（未就学児）
        RlKOJIN.KDM_KINTO := 0;                         -- 子ども均等割額
        RlKOJIN.KDM_KINTO18 := 0;                       -- 子ども18歳以上均等割額
--  2025/12/12 ZCZL.XIESHUN ADD END
    END subInit;
-------------------------------------------------------------------------------
-- 01 生年月日取得
-------------------------------------------------------------------------------
    FUNCTION funcUmare RETURN NUMBER IS
        NwRTN           NUMBER;
    BEGIN
        NwRTN := c_NOK;
        BEGIN
            -- 個人番号で宛名基本を参照し生年月日を取得
            SELECT SEINENGAPI INTO NlSEINENGAPI FROM GABTATENAKIHON
             WHERE KOJIN_NO = i_NKOJIN_NO;
        EXCEPTION
            WHEN OTHERS THEN
                NwRTN := c_NERR;
                VlSQLERRM := 'funcUmare 宛名基本取得' ||
                             '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                             ')' || SQLERRM;
        END;
        RETURN(NwRTN);
    END funcUmare;
------------------------------------------------------------------------------
--  遡及賦課資格自動補正判定
------------------------------------------------------------------------------
FUNCTION FUNC_CAL_SOKYUHANTEI(o_VlSQLERRM OUT VARCHAR2
                             ) RETURN NUMBER IS
  NwRTN                       PLS_INTEGER := 0;
  V_YEAR                      VARCHAR2(4);
  V_MONTH                     VARCHAR2(3);
  NwKENSU                     NUMBER;
  NwTODOKE_BI                 NUMBER(8) := 0;
  NwHANTEI_BI                 NUMBER(8) := 0;
  NwHANTEI_NENDO              NUMBER(4);
  NwSHUTOKU_BI                NUMBER(8) := 0;
  NwSOSHITSU_BI               NUMBER(8) := 0;
BEGIN
  BEGIN
    -- 資格基本TMPカーソル
    FOR REC_SHIKAKU_TMP IN
      (SELECT *
       FROM   ZLBTSHIKAKU_TMP
       WHERE  KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
         AND  KOJIN_NO        = i_NKOJIN_NO
         AND  SAKUJO_KBN      = 0
         AND  SYS_TANMATSU_NO = i_VMASIN_NO
       ORDER  BY R_NO
      ) LOOP
        NwSHUTOKU_BI := 0;
        NwSOSHITSU_BI := 0;

      IF NlSOKYU_CALKBN <> 9 THEN

        -- 1遡及年月日編集[個人取得]
        IF REC_SHIKAKU_TMP.SHUTOKU_TODOKE_BI > 0 THEN
          -- 資格取得届出日の3年前の日付を算出
          NwTODOKE_BI := KKAPK0020.FDATECAL(REC_SHIKAKU_TMP.SHUTOKU_TODOKE_BI,0,0,0,-3);
          -- 資格取得届出日の3年前の日付から該当年度を算出
          NwHANTEI_NENDO := KKAPK0020.FDAYNENDO(NwTODOKE_BI,0);
          -- 資格取得届出日の3年前の法定納期限を取得
          BEGIN
            SELECT NOKIGEN
            INTO   NwHANTEI_BI
            FROM   ZLBTSHUNOJKNK
            WHERE  KAMOKU_CD       = 15
              AND  KAMOKUS_CD      = 1
              AND  KIWARIDANTAI_CD = 1
              AND  CHOTEINENDO     = NwHANTEI_NENDO
              AND  DANTAING_KBN    = 0
              AND  GENNENKANEN_KBN = 0
              AND  HYOJIYOKIBETSU  = 1;
          EXCEPTION
            WHEN OTHERS THEN
              NwRTN       := c_NERR;
              o_VlSQLERRM  := '遡及賦課資格自動補正判定エラー①' ||SQLCODE||SQLERRM;
          END;
          -- 該当年度の4/1において有資格の場合
          IF REC_SHIKAKU_TMP.Z_SHUTOKU_BI <= NwHANTEI_NENDO || '0401' AND
            (REC_SHIKAKU_TMP.Z_SOSHITSU_BI = 0 OR
             REC_SHIKAKU_TMP.Z_SOSHITSU_BI > NwHANTEI_NENDO || '0401') THEN
            -- 判定日はそのまま
            NULL;
          -- 該当年度の4/1において無資格の場合
          ELSE
            -- 判定日を資格取得日とする
            NwHANTEI_BI := REC_SHIKAKU_TMP.Z_SHUTOKU_BI;
          END IF;
          -- 資格取得届出日が判定日（3年前の法定納期限 or 資格取得日）より後の時、翌年度の4/1
          IF NwHANTEI_BI < NwTODOKE_BI THEN
            NwHANTEI_BI := NwHANTEI_NENDO + 1 || '0401';
          -- 資格取得届出日が判定日（3年前の法定納期限 or 資格取得日）より前の時、該当年度の4/1
          ELSE
            NwHANTEI_BI := NwHANTEI_NENDO || '0401';
          END IF;
          -- 資格取得日補正
          IF REC_SHIKAKU_TMP.Z_SHUTOKU_BI < NwHANTEI_BI THEN
            NwSHUTOKU_BI := NwHANTEI_BI;
          ELSE
            NwSHUTOKU_BI := REC_SHIKAKU_TMP.Z_SHUTOKU_BI;
          END IF;
        END IF;
        -- 2遡及年月日編集[個人喪失]
        IF REC_SHIKAKU_TMP.SOSHITSU_TODOKE_BI > 0 THEN
          -- 資格喪失届出日の5年前の日付を算出
          NwTODOKE_BI := KKAPK0020.FDATECAL(REC_SHIKAKU_TMP.SOSHITSU_TODOKE_BI,0,0,0,-5);
          -- 資格喪失届出日の5年前の日付から該当年度を算出
          NwHANTEI_NENDO := KKAPK0020.FDAYNENDO(NwTODOKE_BI,0);
          -- 資格喪失届出日の5年前の法定納期限を取得
          BEGIN
            SELECT NOKIGEN
            INTO   NwHANTEI_BI
            FROM   ZLBTSHUNOJKNK
            WHERE  KAMOKU_CD       = 15
              AND  KAMOKUS_CD      = 1
              AND  KIWARIDANTAI_CD = 1
              AND  CHOTEINENDO     = NwHANTEI_NENDO
              AND  DANTAING_KBN    = 0
              AND  GENNENKANEN_KBN = 0
              AND  HYOJIYOKIBETSU  = 1;
          EXCEPTION
            WHEN OTHERS THEN
              NwRTN       := c_NERR;
              o_VlSQLERRM  := '遡及賦課資格自動補正判定エラー②' ||SQLCODE||SQLERRM;
          END;
          -- 資格喪失届出日が5年前の法定納期限より後の時、翌年度の4/1
          IF NwHANTEI_BI < NwTODOKE_BI THEN
            NwHANTEI_BI := NwHANTEI_NENDO + 1 || '0401';
          -- 資格喪失届出日が5年前の法定納期限より前の時、該当年度の4/1
          ELSE
            NwHANTEI_BI := NwHANTEI_NENDO || '0401';
          END IF;
          -- 資格喪失日補正
          IF REC_SHIKAKU_TMP.Z_SOSHITSU_BI < NwHANTEI_BI THEN
            NwSOSHITSU_BI := NwHANTEI_BI;
          ELSE
            NwSOSHITSU_BI := REC_SHIKAKU_TMP.Z_SOSHITSU_BI;
          END IF;
        END IF;
        -- 3資格基本TMPを更新
        UPDATE ZLBTSHIKAKU_TMP
        SET   Z_SHUTOKU_BI    = NwSHUTOKU_BI    --取得日
            , Z_SOSHITSU_BI   = NwSOSHITSU_BI   --喪失日
        WHERE KOKU_SETAI_NO   = REC_SHIKAKU_TMP.KOKU_SETAI_NO
          AND KOJIN_NO        = REC_SHIKAKU_TMP.KOJIN_NO
          AND R_NO            = REC_SHIKAKU_TMP.R_NO
          AND TAI_R_NO        = REC_SHIKAKU_TMP.TAI_R_NO
          AND IDO_RENBAN      = REC_SHIKAKU_TMP.IDO_RENBAN
          AND SYS_KOSHINBI    = REC_SHIKAKU_TMP.SYS_KOSHINBI
          AND SYS_TANMATSU_NO = REC_SHIKAKU_TMP.SYS_TANMATSU_NO;

      --過年度遡及計算の資格自動補正機能の設定が１より大きい場合
      ELSIF NlSOKYU_CALKBN = 9 THEN

          UPDATE ZLBTSHIKAKU_TMP
          SET   Z_SHUTOKU_BI    = NwSHUTOKU_BI    --取得日
              , Z_SOSHITSU_BI   = NwSOSHITSU_BI   --喪失日
          WHERE KOKU_SETAI_NO   = REC_SHIKAKU_TMP.KOKU_SETAI_NO
            AND KOJIN_NO        = REC_SHIKAKU_TMP.KOJIN_NO
            AND R_NO            = REC_SHIKAKU_TMP.R_NO
            AND TAI_R_NO        = REC_SHIKAKU_TMP.TAI_R_NO
            AND IDO_RENBAN      = REC_SHIKAKU_TMP.IDO_RENBAN
            AND SYS_KOSHINBI    = REC_SHIKAKU_TMP.SYS_KOSHINBI
            AND SYS_TANMATSU_NO = REC_SHIKAKU_TMP.SYS_TANMATSU_NO;

      END IF;

    END LOOP;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      NwRTN       := c_NERR;
      o_VlSQLERRM  := '遡及賦課資格自動補正判定エラー③' ||SQLCODE||SQLERRM;
  END;
  RETURN( NwRTN );
END FUNC_CAL_SOKYUHANTEI ;
------------------------------------------------------------------------------
--  失業軽減終了日特定同一判定
------------------------------------------------------------------------------
FUNCTION FUNC_CAL_SHITSUHANTEI(o_VlSQLERRM OUT VARCHAR2
                             ) RETURN NUMBER IS
  NwRTN                       PLS_INTEGER := 0;
  V_YEAR                      VARCHAR2(4);
  V_MONTH                     VARCHAR2(3);
  NwKENSU                     NUMBER;
  NwTEKIJOGAI_EBI_SHITSU      NUMBER(8);
  NwTEKIJOGAI_EBI_KANWA       NUMBER(8);
  NwHANTEIBI                  NUMBER(8);
BEGIN
  BEGIN
    -- 失業者カーソル
    FOR REC_SHITSU_TAISHO IN
      (SELECT *
       FROM   ZLBTKANWA_TAISHO_TMP
       WHERE  KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
         AND  KOJIN_NO        = i_NKOJIN_NO
         AND  TAISHO_KBN      = 5
         AND  SAKUJO_KBN      = 0
         AND  SYS_TANMATSU_NO = i_VMASIN_NO
       ORDER  BY R_NO
      ) LOOP
        -- 失業軽減終了日以降に特定同一の資格があるかどうかチェック
        SELECT COUNT(*) INTO NwKENSU
        FROM   ZLBTKANWA_TAISHO_TMP
        WHERE  KOKU_SETAI_NO   = REC_SHITSU_TAISHO.KOKU_SETAI_NO
          AND  KOJIN_NO        = REC_SHITSU_TAISHO.KOJIN_NO
          AND  TAISHO_KBN      = 1
          AND  SAKUJO_KBN      = 0
          AND  SYS_TANMATSU_NO = i_VMASIN_NO
          AND  R_NO            > REC_SHITSU_TAISHO.R_NO
          AND  TEKIJOGAI_SBI  <= REC_SHITSU_TAISHO.TEKIJOGAI_EBI
          AND  TEKIJOGAI_EBI  >= REC_SHITSU_TAISHO.TEKIJOGAI_EBI;
        -- 特定同一の資格が存在する場合
        IF NwKENSU > 0 THEN
          -- 失業軽減開始日から失業軽減終了日を算出
          V_YEAR  := SUBSTR(TO_CHAR(REC_SHITSU_TAISHO.TEKIJOGAI_SBI),1,4);
          V_MONTH := SUBSTR(TO_CHAR(REC_SHITSU_TAISHO.TEKIJOGAI_SBI),5,2);
          IF TO_NUMBER(V_MONTH) >= 4  AND
             TO_NUMBER(V_MONTH) <= 12 THEN
            -- 4～12月
            NwTEKIJOGAI_EBI_SHITSU := TO_NUMBER(TO_CHAR(ADD_MONTHS(TO_DATE(V_YEAR || '0331','YYYYMMDD'),12 * 2),'YYYYMMDD'));
          ELSE
            -- 1～3月
            NwTEKIJOGAI_EBI_SHITSU := TO_NUMBER(TO_CHAR(ADD_MONTHS(TO_DATE(V_YEAR || '0331','YYYYMMDD'),12),'YYYYMMDD'));
          END IF;
          -- 特定同一終了日の判定
          NwHANTEIBI := 0;
          NwTEKIJOGAI_EBI_KANWA := 0;
          -- 特定同一カーソル
          FOR REC_KANWA_TAISHO IN
            (SELECT *
             FROM   ZLBTKANWA_TAISHO_TMP
             WHERE  KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
               AND  KOJIN_NO        = i_NKOJIN_NO
               AND  TAISHO_KBN      = 1
               AND  SAKUJO_KBN      = 0
               AND  SYS_TANMATSU_NO = i_VMASIN_NO
               AND  TEKIJOGAI_EBI  >= REC_SHITSU_TAISHO.TEKIJOGAI_EBI
               AND  TEKIJOGAI_EBI  <  NwTEKIJOGAI_EBI_SHITSU
             ORDER  BY R_NO
            ) LOOP
              IF REC_KANWA_TAISHO.TEKIJOGAI_SBI <> NwHANTEIBI THEN
                  NwTEKIJOGAI_EBI_KANWA := REC_KANWA_TAISHO.TEKIJOGAI_EBI;
              END IF;
              NwHANTEIBI := REC_KANWA_TAISHO.TEKIJOGAI_EBI;
          END LOOP;
          IF NwTEKIJOGAI_EBI_KANWA > 0 THEN
              NwTEKIJOGAI_EBI_SHITSU := NwTEKIJOGAI_EBI_KANWA;
          END IF;
          -- 緩和措置TMPを更新
          UPDATE ZLBTKANWA_TAISHO_TMP
          SET   TEKIJOGAI_EBI       = NwTEKIJOGAI_EBI_SHITSU   --終了日
              , SHORIBI             = c_ISYSDATE               --処理日
              , SYS_KOSHINBI        = c_ISYSDATE               --更新日
              , SYS_JIKAN           = c_ISYSTIME               --更新時間
          WHERE KOJIN_NO            = REC_SHITSU_TAISHO.KOJIN_NO
            AND R_NO                = REC_SHITSU_TAISHO.R_NO
            AND SYS_TANMATSU_NO     = i_VMASIN_NO;
        END IF;
      END LOOP;
      COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      NwRTN       := c_NERR;
      o_VlSQLERRM  := '失業軽減終了日特定同一判定エラー ' ||SQLCODE||SQLERRM;
  END;
  RETURN( NwRTN );
END FUNC_CAL_SHITSUHANTEI ;
------------------------------------------------------------------------------
--  緩和終了日判定処理
------------------------------------------------------------------------------
FUNCTION FUNC_CAL_KANWAHANTEI(o_VlSQLERRM OUT VARCHAR2
                             ) RETURN NUMBER IS
  NwRTN                       PLS_INTEGER := 0;
  NSYS_SHOKUINKOJIN_NO        CHAR(12);
  NTEKIJOGAI_EBI              NUMBER(8);
  NTAISHO2_UMU                NUMBER;
  --2024/02/29 ZCZL.HAODAPENG UPDATE 0.3.000.000:新WizLIFE２次開発
  --NSAVE_KOJIN_NO              NUMBER(12) := 0;
  NSAVE_KOJIN_NO              NUMBER := 0;
  --緩和措置判定ワークテーブル
  o_RKANWAHANTEI KHSW_KANWAHANTEI%ROWTYPE;
  TYPE CURTYPE IS REF CURSOR;
  CRCUR CURTYPE;
  -- カーソル
  CURSOR cur_KANWA_TAISHO(i_NKOKU_SETAI_NO    IN NUMBER --国保世帯番号
                         )
    IS
  SELECT JL1.*
  FROM   ZLBTKANWA_TAISHO_TMP JL1,
        (SELECT KOJIN_NO,KOKU_SETAI_NO,TAISHO_KBN,MAX(R_NO) R_NO
           FROM ZLBTKANWA_TAISHO_TMP
          WHERE KOKU_SETAI_NO = i_NKOKU_SETAI_NO
            AND TAISHO_KBN = 1
            AND NVL(SAKUJO_KBN,0) <> 9
            AND SYS_TANMATSU_NO = i_VMASIN_NO
          GROUP BY KOJIN_NO,KOKU_SETAI_NO,TAISHO_KBN) JL2
  WHERE  JL1.KOJIN_NO = JL2.KOJIN_NO
    AND  JL1.KOKU_SETAI_NO = JL2.KOKU_SETAI_NO
    AND  JL1.TAISHO_KBN = JL2.TAISHO_KBN
    AND  JL1.R_NO = JL2.R_NO
    AND  JL1.SYS_TANMATSU_NO = i_VMASIN_NO
  ORDER  BY JL1.KOJIN_NO;
BEGIN
  BEGIN
    FOR REC_KANWA_TAISHO IN cur_KANWA_TAISHO(i_NKOKU_SETAI_NO    --国保世帯番号
                                           )
    LOOP
      IF NSAVE_KOJIN_NO <> REC_KANWA_TAISHO.KOJIN_NO THEN
        BEGIN
          --緩和措置終了日判定用の日付は対象区分8の終了日とする
          SELECT TEKIJOGAI_EBI
            INTO NTEKIJOGAI_EBI
            FROM ZLBTKANWA_TAISHO_TMP
           WHERE KOKU_SETAI_NO     = i_NKOKU_SETAI_NO
             AND KOJIN_NO          = REC_KANWA_TAISHO.KOJIN_NO
             AND TAISHO_KBN        = 8
             AND TEKIJOGAI_SBI     = REC_KANWA_TAISHO.TEKIJOGAI_EBI
             AND SYS_TANMATSU_NO   = i_VMASIN_NO
             AND NVL(SAKUJO_KBN,0) <> 9;
          NTAISHO2_UMU := 1;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN --対象区分1の間に終了している場合
            NTEKIJOGAI_EBI := REC_KANWA_TAISHO.TEKIJOGAI_EBI;
            NTAISHO2_UMU := 0;
          WHEN OTHERS THEN
            NwRTN       := c_NERR;
            o_VlSQLERRM  := '緩和（2）終了日判定エラー 国保世帯番号 =  ' || i_NKOKU_SETAI_NO || ' ,宛名番号 =  ' || i_NKOJIN_NO;
        END;
      END IF;
      --緩和措置終了日判定
      KHSSBKNWAHTEI(REC_KANWA_TAISHO.KOKU_SETAI_NO,
                       REC_KANWA_TAISHO.KOJIN_NO,
                       REC_KANWA_TAISHO.TAISHO_KBN,
                       REC_KANWA_TAISHO.TEKIJOGAI_SBI,
                       NTEKIJOGAI_EBI,
                       i_NKIJUN_NENGAPPI,
                       i_VMASIN_NO,
                       i_NTRENBAN,
                       o_RKANWAHANTEI,
                       NwRTN);
      IF NwRTN = c_NOK THEN
        --変更前緩和終了日≠判定後緩和終了日の場合
        IF NTEKIJOGAI_EBI <> o_RKANWAHANTEI.KANWA_EBI THEN
          NSYS_SHOKUINKOJIN_NO := REC_KANWA_TAISHO.SYS_SHOKUINKOJIN_NO;
          -- 判定結果が、対象区分1の終了日以下の場合
          IF o_RKANWAHANTEI.KANWA_EBI <= REC_KANWA_TAISHO.TEKIJOGAI_EBI THEN
            --緩和措置TMPを更新
            UPDATE ZLBTKANWA_TAISHO_TMP
               SET TEKIJOGAI_EBI       = o_RKANWAHANTEI.KANWA_EBI --終了日
                 , SHORIBI             = c_ISYSDATE               --処理日
                 , SYS_KOSHINBI        = c_ISYSDATE               --更新日
                 , SYS_JIKAN           = c_ISYSTIME               --更新時間
             WHERE KOJIN_NO            = REC_KANWA_TAISHO.KOJIN_NO
               AND KOKU_SETAI_NO       = REC_KANWA_TAISHO.KOKU_SETAI_NO
               AND R_NO                = REC_KANWA_TAISHO.R_NO
               AND TAISHO_KBN          = 1
               AND SYS_TANMATSU_NO     = i_VMASIN_NO;
            IF NTAISHO2_UMU =  1 THEN
              UPDATE ZLBTKANWA_TAISHO_TMP
                 SET SAKUJO_KBN          = 9
               WHERE KOJIN_NO            = REC_KANWA_TAISHO.KOJIN_NO
                 AND KOKU_SETAI_NO       = REC_KANWA_TAISHO.KOKU_SETAI_NO
                 AND TEKIJOGAI_SBI       = REC_KANWA_TAISHO.TEKIJOGAI_EBI
                 AND TAISHO_KBN          = 8
                 AND SYS_TANMATSU_NO     = i_VMASIN_NO;
            END IF;
            --緩和終了日の自動補正機能が「2」の場合
            IF NlKANWA_CALKBN = 2 THEN
              --緩和措置テーブルを更新
              UPDATE KHSTKANWA_TAISHO
                 SET TEKIJOGAI_EBI       = o_RKANWAHANTEI.KANWA_EBI --終了日
                   , SHORIBI             = c_ISYSDATE               --処理日
                   , SYS_KOSHINBI        = c_ISYSDATE               --更新日
                   , SYS_JIKAN           = c_ISYSTIME               --更新時間
                   , SYS_SHOKUINKOJIN_NO = NSYS_SHOKUINKOJIN_NO     --更新職員個人番号
                   , SYS_TANMATSU_NO     = i_VMASIN_NO              --更新端末番号
               WHERE KOJIN_NO            = REC_KANWA_TAISHO.KOJIN_NO
                 AND KOKU_SETAI_NO       = REC_KANWA_TAISHO.KOKU_SETAI_NO
                 AND TAISHO_KBN          = 1
                 AND R_NO                = REC_KANWA_TAISHO.R_NO;
              -- 異動日連番の最大値を取得
              SELECT NVL(MAX(B.IDO_RENBAN),0) + 1
                INTO NIDO_RENBAN
                FROM KHSTKANWA_TAISHO_IDOKEI B
               WHERE B.KOJIN_NO = REC_KANWA_TAISHO.KOJIN_NO
                 AND B.R_NO = REC_KANWA_TAISHO.R_NO
                 AND B.SYS_KOSHINBI = c_ISYSDATE;
              -- 緩和措置対象異動累計追加
              INSERT INTO KHSTKANWA_TAISHO_IDOKEI (
                          KOJIN_NO,
                          R_NO,
                          TAISHO_KBN,
                          NEW_KBN,
                          TODOKE_BI,
                          TEKIJOGAI_SBI,
                          TEKIJOGAI_EBI,
                          SETAI_NO,
                          KOKU_SETAI_NO,
                          SAKUJO_KBN,
                          SHORIBI,
                          SYS_SAKUSEIBI,
                          SYS_KOSHINBI,
                          SYS_JIKAN,
                          SYS_SHOKUINKOJIN_NO,
                          SYS_TANMATSU_NO,
                          KOKI_SHUTOKU_JIYU,
                          IDO_RENBAN
                          )
                   SELECT A.KOJIN_NO,
                          A.R_NO,
                          A.TAISHO_KBN,
                          A.NEW_KBN,
                          A.TODOKE_BI,
                          A.TEKIJOGAI_SBI,
                          o_RKANWAHANTEI.KANWA_EBI,
                          A.SETAI_NO,
                          A.KOKU_SETAI_NO,
                          A.SAKUJO_KBN,
                          A.SHORIBI,
                          A.SYS_SAKUSEIBI,
                          c_ISYSDATE,
                          c_ISYSTIME,
                          NSYS_SHOKUINKOJIN_NO,
                          i_VMASIN_NO,
                          A.KOKI_SHUTOKU_JIYU,
                          NIDO_RENBAN
                     FROM KHSTKANWA_TAISHO A
                    WHERE A.KOJIN_NO = REC_KANWA_TAISHO.KOJIN_NO
                      AND A.KOKU_SETAI_NO = REC_KANWA_TAISHO.KOKU_SETAI_NO
                      AND A.TAISHO_KBN = 1
                      AND A.R_NO = REC_KANWA_TAISHO.R_NO;
              IF NTAISHO2_UMU =  1 THEN
                UPDATE KHSTKANWA_TAISHO
                   SET SAKUJO_KBN          = 9
                 WHERE KOJIN_NO            = REC_KANWA_TAISHO.KOJIN_NO
                   AND KOKU_SETAI_NO       = REC_KANWA_TAISHO.KOKU_SETAI_NO
                   AND TEKIJOGAI_SBI       = REC_KANWA_TAISHO.TEKIJOGAI_EBI
                   AND TAISHO_KBN          = 8;
                -- 緩和措置対象異動累計追加
                INSERT INTO KHSTKANWA_TAISHO_IDOKEI (
                            KOJIN_NO,
                            R_NO,
                            TAISHO_KBN,
                            NEW_KBN,
                            TODOKE_BI,
                            TEKIJOGAI_SBI,
                            TEKIJOGAI_EBI,
                            SETAI_NO,
                            KOKU_SETAI_NO,
                            SAKUJO_KBN,
                            SHORIBI,
                            SYS_SAKUSEIBI,
                            SYS_KOSHINBI,
                            SYS_JIKAN,
                            SYS_SHOKUINKOJIN_NO,
                            SYS_TANMATSU_NO,
                            KOKI_SHUTOKU_JIYU,
                            IDO_RENBAN
                            )
                     SELECT A.KOJIN_NO,
                            A.R_NO,
                            A.TAISHO_KBN,
                            A.NEW_KBN,
                            A.TODOKE_BI,
                            A.TEKIJOGAI_SBI,
                            A.TEKIJOGAI_EBI,
                            A.SETAI_NO,
                            A.KOKU_SETAI_NO,
                            9,
                            A.SHORIBI,
                            A.SYS_SAKUSEIBI,
                            c_ISYSDATE,
                            c_ISYSTIME,
                            NSYS_SHOKUINKOJIN_NO,
                            i_VMASIN_NO,
                            A.KOKI_SHUTOKU_JIYU,
                            NVL(B.MAX_IDO_RENBAN, 0) + 1  AS  IDO_RENBAN
                     FROM KHSTKANWA_TAISHO A
                          , (SELECT KOJIN_NO,
                                    R_NO,
                                    SYS_KOSHINBI,
                                    MAX(IDO_RENBAN) AS MAX_IDO_RENBAN
                              FROM  KHSTKANWA_TAISHO_IDOKEI
                              WHERE KOJIN_NO            = REC_KANWA_TAISHO.KOJIN_NO
                                AND KOKU_SETAI_NO       = REC_KANWA_TAISHO.KOKU_SETAI_NO
                                AND TEKIJOGAI_SBI       = REC_KANWA_TAISHO.TEKIJOGAI_EBI
                                AND TAISHO_KBN          = 8
                                AND SYS_KOSHINBI        = c_ISYSDATE
                              GROUP BY KOJIN_NO, R_NO, SYS_KOSHINBI
                             ) B
                      WHERE A.KOJIN_NO = REC_KANWA_TAISHO.KOJIN_NO
                        AND A.KOKU_SETAI_NO = REC_KANWA_TAISHO.KOKU_SETAI_NO
                        AND A.TEKIJOGAI_SBI = REC_KANWA_TAISHO.TEKIJOGAI_EBI
                        AND A.TAISHO_KBN = 8
                        AND B.KOJIN_NO(+) = A.KOJIN_NO
                        AND B.R_NO(+) = A.R_NO;
              END IF;
            END IF;
          ELSE
          -- 判定結果が、対象区分1の終了日より大きく20871231より小さい時は対象区分8のみ更新（対象区分1はそのまま）
            --緩和措置TMPを更新
            UPDATE ZLBTKANWA_TAISHO_TMP
               SET TEKIJOGAI_EBI       = o_RKANWAHANTEI.KANWA_EBI --終了日
                 , SHORIBI             = c_ISYSDATE               --処理日
                 , SYS_KOSHINBI        = c_ISYSDATE               --更新日
                 , SYS_JIKAN           = c_ISYSTIME               --更新時間
             WHERE KOJIN_NO            = REC_KANWA_TAISHO.KOJIN_NO
               AND KOKU_SETAI_NO       = REC_KANWA_TAISHO.KOKU_SETAI_NO
               AND TEKIJOGAI_SBI       = REC_KANWA_TAISHO.TEKIJOGAI_EBI
               AND TAISHO_KBN          = 8
               AND SYS_TANMATSU_NO     = i_VMASIN_NO;
            --緩和終了日の自動補正機能が「2」の場合
            IF NlKANWA_CALKBN = 2 THEN
              --緩和措置テーブルを更新
              UPDATE KHSTKANWA_TAISHO
                 SET TEKIJOGAI_EBI       = o_RKANWAHANTEI.KANWA_EBI --終了日
                   , SHORIBI             = c_ISYSDATE               --処理日
                   , SYS_KOSHINBI        = c_ISYSDATE               --更新日
                   , SYS_JIKAN           = c_ISYSTIME               --更新時間
                   , SYS_SHOKUINKOJIN_NO = NSYS_SHOKUINKOJIN_NO     --更新職員個人番号
                   , SYS_TANMATSU_NO     = i_VMASIN_NO              --更新端末番号
               WHERE KOJIN_NO            = REC_KANWA_TAISHO.KOJIN_NO
                 AND KOKU_SETAI_NO       = REC_KANWA_TAISHO.KOKU_SETAI_NO
                 AND TEKIJOGAI_SBI       = REC_KANWA_TAISHO.TEKIJOGAI_EBI
                 AND TAISHO_KBN          = 8;
              -- 緩和措置対象異動累計追加
              INSERT INTO KHSTKANWA_TAISHO_IDOKEI (
                          KOJIN_NO,
                          R_NO,
                          TAISHO_KBN,
                          NEW_KBN,
                          TODOKE_BI,
                          TEKIJOGAI_SBI,
                          TEKIJOGAI_EBI,
                          SETAI_NO,
                          KOKU_SETAI_NO,
                          SAKUJO_KBN,
                          SHORIBI,
                          SYS_SAKUSEIBI,
                          SYS_KOSHINBI,
                          SYS_JIKAN,
                          SYS_SHOKUINKOJIN_NO,
                          SYS_TANMATSU_NO,
                          KOKI_SHUTOKU_JIYU,
                          IDO_RENBAN
                          )
                   SELECT A.KOJIN_NO,
                          A.R_NO,
                          A.TAISHO_KBN,
                          A.NEW_KBN,
                          A.TODOKE_BI,
                          A.TEKIJOGAI_SBI,
                          o_RKANWAHANTEI.KANWA_EBI,
                          A.SETAI_NO,
                          A.KOKU_SETAI_NO,
                          A.SAKUJO_KBN,
                          A.SHORIBI,
                          A.SYS_SAKUSEIBI,
                          c_ISYSDATE,
                          c_ISYSTIME,
                          NSYS_SHOKUINKOJIN_NO,
                          i_VMASIN_NO,
                          A.KOKI_SHUTOKU_JIYU,
                          NVL(B.MAX_IDO_RENBAN, 0) + 1  AS  IDO_RENBAN
                     FROM KHSTKANWA_TAISHO A
                          , (SELECT KOJIN_NO,
                                    R_NO,
                                    SYS_KOSHINBI,
                                    MAX(IDO_RENBAN) AS MAX_IDO_RENBAN
                              FROM  KHSTKANWA_TAISHO_IDOKEI
                              WHERE KOJIN_NO            = REC_KANWA_TAISHO.KOJIN_NO
                                AND KOKU_SETAI_NO       = REC_KANWA_TAISHO.KOKU_SETAI_NO
                                AND TEKIJOGAI_SBI       = REC_KANWA_TAISHO.TEKIJOGAI_EBI
                                AND TAISHO_KBN          = 8
                                AND SYS_KOSHINBI        = c_ISYSDATE
                              GROUP BY KOJIN_NO, R_NO, SYS_KOSHINBI
                             ) B
                    WHERE A.KOJIN_NO = REC_KANWA_TAISHO.KOJIN_NO
                      AND A.KOKU_SETAI_NO = REC_KANWA_TAISHO.KOKU_SETAI_NO
                      AND A.TEKIJOGAI_SBI = REC_KANWA_TAISHO.TEKIJOGAI_EBI
                      AND A.TAISHO_KBN = 8
                      AND B.KOJIN_NO(+) = A.KOJIN_NO
                      AND B.R_NO(+) = A.R_NO;
            END IF;
          END IF;
        END IF;
      END IF;
      NSAVE_KOJIN_NO := REC_KANWA_TAISHO.KOJIN_NO;
    END LOOP;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      NwRTN       := c_NERR;
      o_VlSQLERRM  := '緩和終了日判定エラー ' ||SQLCODE||SQLERRM;
  END;
  RETURN( NwRTN );
END FUNC_CAL_KANWAHANTEI ;
-------------------------------------------------------------------------------
-- 00 メイン
-------------------------------------------------------------------------------
BEGIN
    NlRTN           := c_NOK;
    NlINS_TAISHO    := 0;   -- 出力対象外
    NSHIK_CNT       := 0;
    NLOOP_CNT       := 0;
    -- 税率試算経由で起動された場合、実行区分=2で呼び出す様に変更
    -- (今までは実行区分=0で呼び出されていた)
    -- 上記に伴い、本ストアドから呼び出すストアドの引数(実行区分)をここで作成
    IF i_NJIKKOU_KBN = c_NZER THEN
        NwJIKKOU_KBN := c_NBATCH;
    ELSE
        NwJIKKOU_KBN := i_NJIKKOU_KBN;
    END IF;
    --緩和終了日の自動補正機能条件取得
    NlKANWA_CALKBN := ZLBPK00010.FCFFJKN2(58);
    --自動補正機能がオンの場合、緩和終了日判定処理を行なう
    IF NlKANWA_CALKBN > 0 THEN
        NlRTN := FUNC_CAL_KANWAHANTEI(VlSQLERRM);
    END IF;
    IF NlRTN = c_NOK THEN
      NlRTN := FUNC_CAL_SHITSUHANTEI(VlSQLERRM);
    END IF;
    -- 過年度計算の場合
    IF i_NCHOTEI_NENDO <> i_NNENDO_BUN THEN
        --遡及賦課の資格自動補正機能条件取得
        NlSOKYU_CALKBN := ZLBPK00010.FCFFJKN2(59);
        --自動補正機能がオンの場合、遡及賦課判定処理を行なう
        IF NlSOKYU_CALKBN > 0 THEN
            NlRTN := FUNC_CAL_SOKYUHANTEI(VlSQLERRM);
       END IF;
    END IF;
    NlRTN := funcUmare;     -- 01 生年月日取得
    IF NlRTN = c_NOK THEN
        subInit;            -- 02 初期化処理
    END IF;
    IF NlRTN = c_NOK THEN
        -- 資格基本の読込み
        BEGIN
            FOR RlSHIKAKU IN ClSHIKAKU(i_NKOKU_SETAI_NO, i_NKOJIN_NO) LOOP
              IF NLOOP_CNT = 0 THEN
                BEGIN
                  SELECT COUNT(9)
                    INTO NSHIK_CNT
                    FROM ZLBTSHIKAKU_TMP
                   WHERE KOKU_SETAI_NO   = i_NKOKU_SETAI_NO
                     AND KOJIN_NO        = i_NKOJIN_NO
                     AND SAKUJO_KBN      = 0
                     AND SYS_TANMATSU_NO = i_VMASIN_NO;
                EXCEPTION
                  WHEN OTHERS THEN
                    NlRTN := c_NERR;
                    VlSQLERRM := '資格基本TMP件数取得' ||
                                 '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                 ')' || SQLERRM;
                  EXIT;
                END;
              END IF;
              NLOOP_CNT := NLOOP_CNT + 1;
                -- 主75歳到達フラグ初期化
                NlNUSHI_75FLG := 0;
                IF  i_NJIKKOU_KBN IN ( c_NBATCH, c_NONLNIN )  THEN
                  NSHIKAKU_KIJUN_NENGAPPI  :=  TO_NUMBER( i_NNENDO_BUN + 1 || '0331' ) ;
                ELSE
                  NSHIKAKU_KIJUN_NENGAPPI  :=  i_NKIJUN_NENGAPPI ;
                END IF ;
                IF RlSHIKAKU.SHIK_KBN!=2 AND RlSHIKAKU.SHIK_KBN!=8 THEN
                    -- 後期高齢該当による喪失事由・喪失日再セット(擬主以外)
                    ZLBSBSKKJYHNT(i_NKOJIN_NO,
                                      i_NNENDO_BUN,
                                      RlSHIKAKU.SHUTOKU_JIYU,
                                      RlSHIKAKU.Z_SHUTOKU_BI,
                                      RlSHIKAKU.SOSHITSU_JIYU,
                                      RlSHIKAKU.Z_SOSHITSU_BI,
                                      NSHIKAKU_KIJUN_NENGAPPI,
                                      i_NKOKU_SETAI_NO,
                                      NwJIKKOU_KBN,
                                      i_VMASIN_NO,
                                      i_NTRENBAN,
                                      NwSIKAKU_GAI_JIYU,
                                      NwSIKAKU_GAI_BI,
                                      NwSIKAKU_HIGAI_JIYU,
                                      NwSIKAKU_HIGAI_BI,
                                      NwRTN);                  -- 資格事由判定
                    IF NwRTN != c_NOK THEN
                        NlRTN := c_NERR;
                        VlSQLERRM := '資格事由判定(ZLBSBSKKJYHNT)エラー ' ||
                               '(宛名番号=' || i_NKOJIN_NO ||
                               '、年度分=' || i_NNENDO_BUN ||
                               ')' || SQLERRM;
                        EXIT;
                    END IF;
                    -- ストアド戻りの喪失事由 = 後期高齢対象  AND 資格_TMPの喪失事由 != 後期高齢対象
                    -- AND (資格_TMPの喪失日  > ストアド戻りの喪失日 OR 資格_TMPの喪失日 = 0)
                    IF((i_NJIKKOU_KBN = c_NZER AND  NwSIKAKU_HIGAI_JIYU IN (39,40) ) OR
                        (i_NJIKKOU_KBN != c_NZER AND NwSIKAKU_HIGAI_JIYU IN (39,40) AND RlSHIKAKU.SOSHITSU_JIYU NOT IN (39,40)))AND
                       RlSHIKAKU.SHIK_KBN NOT IN (2,8) AND
                       NLOOP_CNT = NSHIK_CNT           AND
                       (RlSHIKAKU.Z_SOSHITSU_BI = 0 OR RlSHIKAKU.Z_SOSHITSU_BI > NwSIKAKU_HIGAI_BI) AND
                       RlSHIKAKU.Z_SHUTOKU_BI < NwSIKAKU_HIGAI_BI THEN
                      -- 世帯主チェック
                      -- 主が基準日より以前でも資格を喪失していた場合
                      IF RlSHIKAKU.SHIK_KBN IN (1,7) THEN
                        -- 主75歳到達フラグに1セット
                        NlNUSHI_75FLG := 1;
                      END IF;
                      -- 後期高齢該当による喪失事由・喪失日再セット
                      RlSHIKAKU.SOSHITSU_TODOKE_BI := NwSIKAKU_HIGAI_BI;    -- 喪失届出日
                      RlSHIKAKU.Z_SOSHITSU_BI := NwSIKAKU_HIGAI_BI;         -- 喪失日
                      RlSHIKAKU.SOSHITSU_JIYU := NwSIKAKU_HIGAI_JIYU;       -- 喪失事由
                      IF RlSHIKAKU.SHIK_KBN IN (1,3) THEN                   -- 資格区分(喪失セット)
                        RlSHIKAKU.SHIK_KBN  := RlSHIKAKU.SHIK_KBN + 6;
                      END IF;
                      -- 退職該当
                      IF RlSHIKAKU.TAISHOKU_KBN IN (1,2,3,4) AND
                        (RlSHIKAKU.Z_HIGAI_BI=0 OR RlSHIKAKU.Z_HIGAI_BI>NwSIKAKU_HIGAI_BI)  THEN
                        RlSHIKAKU.Z_HIGAI_BI       := NwSIKAKU_HIGAI_BI;  -- 退職非該当日
                        RlSHIKAKU.HIGAI_TODOKE_BI  := NwSIKAKU_HIGAI_BI;  -- 退職非該当届出日
                        IF RlSHIKAKU.TAISHOKU_KBN IN (1,2) THEN           -- 退職区分(非該当セット)
                          RlSHIKAKU.TAISHOKU_KBN := RlSHIKAKU.TAISHOKU_KBN + 2;
                        END IF;
                      END IF;
                      BEGIN
                        -- 資格基本TMP更新
                        UPDATE ZLBTSHIKAKU_TMP   SET   SHIK_KBN =  RlSHIKAKU.SHIK_KBN,
                                                       Z_SOSHITSU_BI = RlSHIKAKU.Z_SOSHITSU_BI
                                                 WHERE KOKU_SETAI_NO = RlSHIKAKU.KOKU_SETAI_NO
                                                   AND KOJIN_NO = RlSHIKAKU.KOJIN_NO
                                                   AND SAKUJO_KBN = RlSHIKAKU.SAKUJO_KBN
                                                   AND SYS_TANMATSU_NO = RlSHIKAKU.SYS_TANMATSU_NO
                                                   AND R_NO = RlSHIKAKU.R_NO
                                                   AND IDO_RENBAN = RlSHIKAKU.IDO_RENBAN
                                                   AND TAI_R_NO = RlSHIKAKU.TAI_R_NO;
                      EXCEPTION
                        WHEN OTHERS THEN
                            NlRTN := c_NERR;
                            VlSQLERRM := '資格基本TMP更新' ||
                                         '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                         ')' || SQLERRM;
                            EXIT;
                      END;
                    END IF;
                END IF;
                -- 退職区分(2，4) AND 退職本人個人番号＝0
                IF RlSHIKAKU.TAISHOKU_KBN IN (2,4) AND RlSHIKAKU.KOJIN_NO = 0 THEN
                  NwTAI_HIGAI_BI := 0;
                END IF;
                -- 退職該当(本人)
                IF RlSHIKAKU.TAISHOKU_KBN IN (1,3) THEN
                    ZLBSBTJYHNT(i_NKOJIN_NO,
                                   i_NNENDO_BUN,
                                   RlSHIKAKU.Z_GAI_BI,
                                   RlSHIKAKU.Z_HIGAI_BI,
                                   i_NKIJUN_NENGAPPI,
                                   NwJIKKOU_KBN,
                                   i_NTRENBAN,
                                   NwTAI_HIGAI_BI,
                                   NwRTN);                  -- 退職非該当判定
                    IF NwRTN != c_NOK THEN
                        NlRTN := c_NERR;
                        VlSQLERRM := '退職事由判定(ZLBSBTJYHNT)エラー ' ||
                               '(宛名番号=' || i_NKOJIN_NO ||
                               '、年度分=' || i_NNENDO_BUN ||
                               ')' || SQLERRM;
                        EXIT;
                    END IF;
                -- 退職該当(扶養) ※退職本人の個人番号が存在する時のみ
                ELSIF RlSHIKAKU.TAISHOKU_KBN IN (2,4) AND RlSHIKAKU.TAI_HONIN > 0 THEN
                    ZLBSBTJYHNT(RlSHIKAKU.TAI_HONIN,
                                   i_NNENDO_BUN,
                                   RlSHIKAKU.Z_GAI_BI,
                                   RlSHIKAKU.Z_HIGAI_BI,
                                   i_NKIJUN_NENGAPPI,
                                   NwJIKKOU_KBN,
                                   i_NTRENBAN,
                                   NwTAI_HIGAI_BI,
                                   NwRTN);                  -- 退職非該当判定
                    IF NwRTN = c_NOK THEN
                        NwTAI_HIGAI_BI_FUYO := 0;
                        -- 退職扶養で判定
                        ZLBSBTJYHNT(i_NKOJIN_NO,
                                       i_NNENDO_BUN,
                                       RlSHIKAKU.Z_GAI_BI,
                                       RlSHIKAKU.Z_HIGAI_BI,
                                       i_NKIJUN_NENGAPPI,
                                       NwJIKKOU_KBN,
                                       i_NTRENBAN,
                                       NwTAI_HIGAI_BI_FUYO,
                                       NwRTN);              -- 退職非該当判定
                    END IF;
                    IF NwRTN != c_NOK THEN
                        NlRTN := c_NERR;
                        VlSQLERRM := '退職事由判定(ZLBSBTJYHNT)エラー ' ||
                               '(宛名番号=' || i_NKOJIN_NO ||
                               '、年度分=' || i_NNENDO_BUN ||
                               ')' || SQLERRM;
                        EXIT;
                    END IF;
                    -- 非該当日が扶養＜本人の場合、扶養者の非該当日をセット
                    IF NwTAI_HIGAI_BI_FUYO != 0 AND
                       CASE NwTAI_HIGAI_BI WHEN 0 THEN 99999999 ELSE NwTAI_HIGAI_BI END > NwTAI_HIGAI_BI_FUYO THEN
                        NwTAI_HIGAI_BI  :=  NwTAI_HIGAI_BI_FUYO;
                    END IF;
                END IF;
                IF RlSHIKAKU.TAISHOKU_KBN IN (1,2,3,4) THEN
                -- 退職非該当日が算出した退職非該当日より後なら
                    IF NwTAI_HIGAI_BI != 0  AND
                             (RlSHIKAKU.Z_HIGAI_BI > NwTAI_HIGAI_BI OR RlSHIKAKU.Z_HIGAI_BI = 0) THEN
                        RlSHIKAKU.Z_HIGAI_BI       := NwTAI_HIGAI_BI;  -- 退職非該当日
                        RlSHIKAKU.HIGAI_TODOKE_BI  := NwTAI_HIGAI_BI;  -- 退職非該当届出日
                        IF RlSHIKAKU.TAISHOKU_KBN IN (1,2) THEN           -- 退職区分(非該当セット)
                            RlSHIKAKU.TAISHOKU_KBN := RlSHIKAKU.TAISHOKU_KBN + 2;
                        END IF;
                    END IF;
                END IF;
                subMain(RlSHIKAKU);     -- 03 主処理
                EXIT WHEN NlRTN != c_NOK;
                -- 資格喪失による擬主の場合擬主の情報をセット
                IF(NlNUSHI_75FLG = 1) THEN
                  RlSHIKAKU.SHUTOKU_TODOKE_BI := NwSIKAKU_HIGAI_BI;    -- 取得届出日
                  RlSHIKAKU.Z_SHUTOKU_BI := NwSIKAKU_HIGAI_BI;         -- 取得日
                  RlSHIKAKU.SHUTOKU_JIYU := 17;                        -- 取得事由(擬主取得)
                  RlSHIKAKU.SOSHITSU_TODOKE_BI := 0;                   -- 喪失届出日
                  RlSHIKAKU.Z_SOSHITSU_BI := 0;                        -- 喪失日
                  RlSHIKAKU.SOSHITSU_JIYU := 0;                        -- 喪失事由
                  RlSHIKAKU.SHIK_KBN  := 2;                            -- 資格区分=擬主
                  -- 軽減判定用資格基本TMP追加
                  BEGIN
                    RlSHIKAKU.R_NO := RlSHIKAKU.R_NO + 1;
                    INSERT INTO ZLBTSHIKAKU_TMP VALUES  RlSHIKAKU;
                  EXCEPTION
                    WHEN OTHERS THEN
                        NlRTN := c_NERR;
                        VlSQLERRM := '資格基本TMP更新' ||
                                     '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                                     ')' || SQLERRM;
                        EXIT;
                  END;
                  subMain(RlSHIKAKU);     -- 03 主処理
                  EXIT WHEN NlRTN != c_NOK;
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlSQLERRM := '資格基本TMP取得 ' || V_MSG || '時エラー ' ||
                             '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                             ')' || SQLERRM;
        END;
    END IF;
    IF RlKOJIN.NEW_SHIK_KBN = 0 THEN
      NwCNT2 := funcChkFuka2(RlSHIKAKU);
      IF NwCNT2 = 0 THEN
        -- 出力対象としない。
        NlINS_TAISHO := 0;
      END IF;
    END IF;
    IF NlRTN = c_NOK THEN
        -- 緩和対象テーブルより作成計算個人TBLを作成
        BEGIN
            --特定同一設定前に各月資格区分をセーブ(資格再取得時の情報保持)
            RlKOJIN_SAVE := RlKOJIN;
            FOR RlKANWATAISHO IN CUR_KANWA(i_NKOKU_SETAI_NO, i_NKOJIN_NO) LOOP
                subKanwaToKojin(RlKANWATAISHO);
                subMain(RlSHIKAKU);         -- 03 主処理
                EXIT WHEN NlRTN != c_NOK;

                -- 続柄は KHSTSHIKAKU_IDOKEI からセットしている。
                -- 当該市町村で後期該当になった人は、資格データがあるので、
                -- セーブしたデータをセットする。
                -- 資格データがない人（後期該当になってから転入してきた人）は、
                -- 当初の仕様通り"不明"とする。
                IF NVL(RlKOJIN_SAVE.NEW_ZOKU,0) <> 0 THEN
                    RlKOJIN.NEW_ZOKU  := RlKOJIN_SAVE.NEW_ZOKU;
                    RlKOJIN.ZOKU_NAME := RlKOJIN_SAVE.ZOKU_NAME;
                END IF;

                --特定同一非該当が設定されている月はセーブしている各月資格を再セット
                IF RlKANWATAISHO.TEKIJOGAI_EBI >  0 AND
                   RlKANWATAISHO.TEKIJOGAI_EBI >= i_NFUKA_KIJITSU AND         -- 賦課期日
                   RlKANWATAISHO.TEKIJOGAI_EBI <  i_NFUKA_KIJITSU+10000 THEN  -- 賦課期日の1年後
                    -- 非該当月抽出
                    NlTOKUDO_HIGAI_TUKI := TRUNC((RlKANWATAISHO.TEKIJOGAI_EBI-TRUNC(RlKANWATAISHO.TEKIJOGAI_EBI/10000)*10000)/100);
                    IF NlTOKUDO_HIGAI_TUKI = 4 THEN
                        subPoint( 1, RlKOJIN_SAVE.SHIK_4);
                    END IF;
                    IF NlTOKUDO_HIGAI_TUKI IN (4,5) THEN
                        subPoint( 2, RlKOJIN_SAVE.SHIK_5);
                    END IF;
                    IF NlTOKUDO_HIGAI_TUKI IN (4,5,6) THEN
                        subPoint( 3, RlKOJIN_SAVE.SHIK_6);
                    END IF;
                    IF NlTOKUDO_HIGAI_TUKI IN (4,5,6,7) THEN
                        subPoint( 4, RlKOJIN_SAVE.SHIK_7);
                    END IF;
                    IF NlTOKUDO_HIGAI_TUKI IN (4,5,6,7,8) THEN
                        subPoint( 5, RlKOJIN_SAVE.SHIK_8);
                    END IF;
                    IF NlTOKUDO_HIGAI_TUKI IN (4,5,6,7,8,9) THEN
                        subPoint( 6, RlKOJIN_SAVE.SHIK_9);
                    END IF;
                    IF NlTOKUDO_HIGAI_TUKI IN (4,5,6,7,8,9,10) THEN
                        subPoint( 7, RlKOJIN_SAVE.SHIK_10);
                    END IF;
                    IF NlTOKUDO_HIGAI_TUKI IN (4,5,6,7,8,9,10,11) THEN
                        subPoint( 8, RlKOJIN_SAVE.SHIK_11);
                    END IF;
                    IF NlTOKUDO_HIGAI_TUKI IN (4,5,6,7,8,9,10,11,12) THEN
                        subPoint( 9, RlKOJIN_SAVE.SHIK_12);
                    END IF;
                    IF NlTOKUDO_HIGAI_TUKI IN (1,4,5,6,7,8,9,10,11,12) THEN
                        subPoint(10, RlKOJIN_SAVE.SHIK_1);
                    END IF;
                    IF NlTOKUDO_HIGAI_TUKI IN (1,2,4,5,6,7,8,9,10,11,12) THEN
                        subPoint(11, RlKOJIN_SAVE.SHIK_2);
                    END IF;
                    IF NlTOKUDO_HIGAI_TUKI IN (1,2,3,4,5,6,7,8,9,10,11,12) THEN
                        subPoint(12, RlKOJIN_SAVE.SHIK_3);
                    END IF;
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                  NlRTN := c_NERR;
                VlSQLERRM := '資格基本TMP取得 ' || V_MSG || '時エラー ' ||
                             '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                             ')' || SQLERRM;
        END;
    END IF;
    -- 出力対象か判定
    IF NlRTN = c_NOK AND NlINS_TAISHO = 1 THEN         -- 出力対象
        NlRTN := funcInsert();          -- 04 計算個人に出力
    END IF;
    -- 終了処理
    IF NlRTN = c_NOK THEN        -- 正常に処理完了
        BEGIN
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                NlRTN := c_NERR;
                VlSQLERRM := 'COMMIT発行' ||
                             '(国保世帯番号=' || i_NKOKU_SETAI_NO ||
                             ')' || SQLERRM;
        END;
    END IF;
    IF NlRTN != c_NOK THEN       -- 処理異常
        BEGIN
            NlRTN := c_NERR;
            IF NwJIKKOU_KBN = c_NBATCH THEN    -- バッチ起動時
                BlRTN := KKBPK5551.FSETBLOG (i_NTRENBAN,'ZLBSKCALSHK', 1, '', '','ZLBSKCALSHK ' || VlSQLERRM, NULL, i_VMASIN_NO);
            ELSIF i_NTRENBAN = -1 THEN
                -- テストの時のみ有効
                DBMS_OUTPUT.PUT_LINE('ZLBSKCALSHK ' || VlSQLERRM);
            END IF;
            ROLLBACK;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;       -- 既に異常が確定の為
        END;
    END IF;
    o_NRESULT := NlRTN;
END ZLBSKCALSHK;
/